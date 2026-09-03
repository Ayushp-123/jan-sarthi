import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_model.dart';
import '../models/responder_model.dart';
import 'local_database_service.dart';

class OfflineNearbyService {
  static final OfflineNearbyService _instance = OfflineNearbyService._internal();
  factory OfflineNearbyService() => _instance;
  OfflineNearbyService._internal();

  final Strategy strategy = Strategy.P2P_STAR;
  final Map<String, ConnectionInfo> _connectedPeers = {};
  final Set<String> _connectedEndpoints = {};
  Function(Map<String, dynamic>)? onSOSReceivedCallback;

  /// Request permissions for Offline P2P (Bluetooth, Location, Nearby Devices)
  Future<bool> checkOfflinePermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  /// Start P2P advertising (Victim broadcasting SOS to multiple nearby peers)
  Future<void> startSOSBroadcast({
    required String emergencyId,
    required double latitude,
    required double longitude,
    required String victimId,
  }) async {
    await checkOfflinePermissions();
    String userName = "JanSarthi_Victim_$victimId";

    Map<String, dynamic> payloadMap = {
      'eventType': 'SOS_BROADCAST',
      'emergencyId': emergencyId,
      'victimId': victimId,
      'latitude': latitude,
      'longitude': longitude,
      'type': 'MEDICAL',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    String payloadJson = jsonEncode(payloadMap);

    try {
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) async {
          _connectedPeers[id] = info;
          _connectedEndpoints.add(id);
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (String endpointId, Payload payload) async {
              if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                try {
                  String str = utf8.decode(payload.bytes!);
                  Map<String, dynamic> data = jsonDecode(str);
                  if (data['eventType'] == 'RESPONDER_ACCEPTANCE' || data.containsKey('responderId')) {
                    await processAcceptancePayload(data, LocalDatabaseService());
                  } else if (data['eventType'] == 'STATUS_UPDATE') {
                    await processStatusUpdatePayload(data, LocalDatabaseService());
                  }
                  if (onSOSReceivedCallback != null) {
                    onSOSReceivedCallback!(data);
                  }
                } catch (_) {}
              }
            },
          );
        },
        onConnectionResult: (String id, Status status) async {
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(id);
            try {
              await Nearby().sendBytesPayload(
                id,
                Uint8List.fromList(utf8.encode(payloadJson)),
              );
            } catch (_) {}
          } else {
            _connectedEndpoints.remove(id);
          }
        },
        onDisconnected: (String id) {
          _connectedPeers.remove(id);
          _connectedEndpoints.remove(id);
        },
      );
    } catch (e) {
      // Offline advertising exception handling
    }
  }

  /// Start P2P discovery (Nearby users discovering broadcasting victims)
  Future<void> startSOSDiscovery({
    required String currentUserId,
    required Function(Map<String, dynamic>) onSOSDiscovered,
  }) async {
    onSOSReceivedCallback = onSOSDiscovered;
    await checkOfflinePermissions();

    try {
      await Nearby().startDiscovery(
        "JanSarthi_Helper_$currentUserId",
        strategy,
        onEndpointFound: (String id, String userName, String serviceId) async {
          await Nearby().requestConnection(
            "JanSarthi_Helper_$currentUserId",
            id,
            onConnectionInitiated: (String endpointId, ConnectionInfo info) async {
              _connectedEndpoints.add(endpointId);
              await Nearby().acceptConnection(
                endpointId,
                onPayLoadRecieved: (String epId, Payload payload) async {
                  if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                    try {
                      String str = utf8.decode(payload.bytes!);
                      Map<String, dynamic> data = jsonDecode(str);
                      if (data['eventType'] == 'RESPONDER_ACCEPTANCE' || data.containsKey('responderId')) {
                        await processAcceptancePayload(data, LocalDatabaseService());
                      } else if (data['eventType'] == 'STATUS_UPDATE') {
                        await processStatusUpdatePayload(data, LocalDatabaseService());
                      } else {
                        onSOSDiscovered(data);
                      }
                    } catch (_) {}
                  }
                },
              );
            },
            onConnectionResult: (String endpointId, Status status) {
              if (status == Status.CONNECTED) {
                _connectedEndpoints.add(endpointId);
              } else {
                _connectedEndpoints.remove(endpointId);
              }
            },
            onDisconnected: (String endpointId) {
              _connectedEndpoints.remove(endpointId);
            },
          );
        },
        onEndpointLost: (String? id) {
          if (id != null) _connectedEndpoints.remove(id);
        },
      );
    } catch (e) {
      // Discovery exception handling
    }
  }

  /// Transmit an acceptance payload from Helper to Victim over Nearby Connections
  Future<bool> sendAcceptancePayload({
    required String emergencyId,
    required String responderId,
    required String responderName,
    String? phoneNumber,
    String? bloodGroup,
    required double latitude,
    required double longitude,
    required ResponderRole role,
  }) async {
    Map<String, dynamic> payloadMap = {
      'eventType': 'RESPONDER_ACCEPTANCE',
      'emergencyId': emergencyId,
      'responderId': responderId,
      'responderName': responderName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'role': role.name,
      'status': (role == ResponderRole.PRIMARY ? ResponderStatus.RESPONDING : ResponderStatus.STANDBY).name,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    String jsonStr = jsonEncode(payloadMap);
    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));

    bool sentAny = false;
    for (String endpointId in _connectedEndpoints) {
      try {
        await Nearby().sendBytesPayload(endpointId, bytes);
        sentAny = true;
      } catch (_) {}
    }
    return sentAny;
  }

  /// Transmit status updates (ARRIVED, COMPLETED, CANCELLED, LOCATION_UPDATE) over P2P
  Future<bool> sendStatusUpdatePayload({
    required String emergencyId,
    required String status,
    String? responderId,
    double? latitude,
    double? longitude,
  }) async {
    Map<String, dynamic> payloadMap = {
      'eventType': 'STATUS_UPDATE',
      'emergencyId': emergencyId,
      'status': status,
      'responderId': responderId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    String jsonStr = jsonEncode(payloadMap);
    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));

    bool sentAny = false;
    for (String endpointId in _connectedEndpoints) {
      try {
        await Nearby().sendBytesPayload(endpointId, bytes);
        sentAny = true;
      } catch (_) {}
    }
    return sentAny;
  }

  /// Process an incoming acceptance payload deterministically and persist to LocalDatabaseService
  static Future<EmergencyModel?> processAcceptancePayload(
    Map<String, dynamic> data,
    LocalDatabaseService localDb,
  ) async {
    if (data['eventType'] != 'RESPONDER_ACCEPTANCE' && !data.containsKey('responderId')) {
      return null;
    }
    String? emergencyId = data['emergencyId'];
    String? responderId = data['responderId'];
    if (emergencyId == null || emergencyId.isEmpty || responderId == null || responderId.isEmpty) {
      return null;
    }

    EmergencyModel? existingEmergency = await localDb.getEmergencyById(emergencyId);
    if (existingEmergency == null) {
      return null;
    }

    if (existingEmergency.responders.containsKey(responderId)) {
      return existingEmergency;
    }

    bool hasPrimary = existingEmergency.helperId != null &&
        existingEmergency.helperId!.isNotEmpty &&
        existingEmergency.responders.values.any((r) => r.role == ResponderRole.PRIMARY);

    ResponderRole assignedRole = hasPrimary ? ResponderRole.STANDBY : ResponderRole.PRIMARY;
    ResponderStatus assignedStatus = hasPrimary ? ResponderStatus.STANDBY : ResponderStatus.RESPONDING;

    DateTime acceptedTime = data['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int)
        : DateTime.now();

    ResponderModel newResponder = ResponderModel(
      userId: responderId,
      userName: data['responderName'] ?? 'Offline Responder',
      phoneNumber: data['phoneNumber'],
      bloodGroup: data['bloodGroup'],
      role: assignedRole,
      status: assignedStatus,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: acceptedTime,
      lastLocationUpdate: acceptedTime,
      assignedAt: assignedRole == ResponderRole.PRIMARY ? acceptedTime : null,
    );

    Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existingEmergency.responders);
    updatedResponders[responderId] = newResponder;

    EmergencyModel updatedEmergency = EmergencyModel(
      id: existingEmergency.id,
      victimId: existingEmergency.victimId,
      type: existingEmergency.type,
      latitude: existingEmergency.latitude,
      longitude: existingEmergency.longitude,
      status: assignedRole == ResponderRole.PRIMARY ? EmergencyStatus.ASSIGNED : existingEmergency.status,
      helperId: assignedRole == ResponderRole.PRIMARY ? responderId : existingEmergency.helperId,
      currentRadiusMeters: existingEmergency.currentRadiusMeters,
      notifiedUserIds: existingEmergency.notifiedUserIds,
      responders: updatedResponders,
      createdAt: existingEmergency.createdAt,
      updatedAt: DateTime.now(),
      lastVictimLocation: existingEmergency.lastVictimLocation,
      lastHelperLocation: assignedRole == ResponderRole.PRIMARY
          ? {
              'latitude': newResponder.latitude,
              'longitude': newResponder.longitude,
              'updatedAt': DateTime.now().toIso8601String(),
            }
          : existingEmergency.lastHelperLocation,
    );

    await localDb.saveEmergencyLocally(updatedEmergency);
    return updatedEmergency;
  }

  /// Process an incoming status update payload (ARRIVED, COMPLETED, CANCELLED, LOCATION_UPDATE)
  static Future<EmergencyModel?> processStatusUpdatePayload(
    Map<String, dynamic> data,
    LocalDatabaseService localDb,
  ) async {
    String? emergencyId = data['emergencyId'];
    if (emergencyId == null || emergencyId.isEmpty) return null;

    EmergencyModel? existingEmergency = await localDb.getEmergencyById(emergencyId);
    if (existingEmergency == null) return null;

    String? newStatusStr = data['status'];
    EmergencyStatus updatedStatus = existingEmergency.status;
    if (newStatusStr != null) {
      updatedStatus = EmergencyStatus.values.firstWhere(
        (e) => e.name == newStatusStr,
        orElse: () => existingEmergency.status,
      );
    }

    double? lat = (data['latitude'] as num?)?.toDouble();
    double? lon = (data['longitude'] as num?)?.toDouble();
    String? responderId = data['responderId'];

    Map<String, ResponderModel> updatedResponders = Map<String, ResponderModel>.from(existingEmergency.responders);
    Map<String, dynamic>? updatedLastHelperLoc = existingEmergency.lastHelperLocation;

    if (responderId != null && updatedResponders.containsKey(responderId) && lat != null && lon != null) {
      ResponderModel r = updatedResponders[responderId]!;
      updatedResponders[responderId] = ResponderModel(
        userId: r.userId,
        userName: r.userName,
        phoneNumber: r.phoneNumber,
        bloodGroup: r.bloodGroup,
        role: r.role,
        status: newStatusStr != null
            ? ResponderStatus.values.firstWhere(
                (e) => e.name == newStatusStr,
                orElse: () => r.status,
              )
            : r.status,
        latitude: lat,
        longitude: lon,
        acceptedAt: r.acceptedAt,
        lastLocationUpdate: DateTime.now(),
        assignedAt: r.assignedAt,
        distanceToVictim: r.distanceToVictim,
        etaText: r.etaText,
        etaMinutes: r.etaMinutes,
        problemReason: r.problemReason,
      );

      if (existingEmergency.helperId == responderId) {
        updatedLastHelperLoc = {
          'latitude': lat,
          'longitude': lon,
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }
    }

    EmergencyModel updatedEmergency = EmergencyModel(
      id: existingEmergency.id,
      victimId: existingEmergency.victimId,
      type: existingEmergency.type,
      latitude: existingEmergency.latitude,
      longitude: existingEmergency.longitude,
      status: updatedStatus,
      helperId: existingEmergency.helperId,
      currentRadiusMeters: existingEmergency.currentRadiusMeters,
      notifiedUserIds: existingEmergency.notifiedUserIds,
      responders: updatedResponders,
      createdAt: existingEmergency.createdAt,
      updatedAt: DateTime.now(),
      lastVictimLocation: existingEmergency.lastVictimLocation,
      lastHelperLocation: updatedLastHelperLoc,
    );

    await localDb.saveEmergencyLocally(updatedEmergency);
    return updatedEmergency;
  }

  /// Stop all offline advertising & discovery
  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _connectedPeers.clear();
    _connectedEndpoints.clear();
  }
}
