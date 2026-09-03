import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';
import '../models/responder_model.dart';
import '../models/emergency_model.dart';
import '../models/user_model.dart';
import 'location_service.dart';
import 'offline_nearby_service.dart';
import 'local_database_service.dart';
import 'auth_service.dart';
import 'impact_reward_service.dart';

class EmergencyClaimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final OfflineNearbyService _offlineNearbyService = OfflineNearbyService();
  final AuthService _authService = AuthService();

  /// Atomic claim & responder acceptance method
  /// Automatically branches between ONLINE (Firestore Transaction) and OFFLINE (P2P + Local Storage)
  Future<ResponderRole?> acceptAndRespond(String emergencyId) async {
    User? currentUser = _auth.currentUser;
    String userId = currentUser?.uid ?? 'offline_user';
    String userName = currentUser?.displayName ?? 'Responder';

    String? phoneNumber;
    String? bloodGroup;
    String userRole = 'CITIZEN';
    String? vehicleNumber;

    // Try fetching user profile details
    if (currentUser != null) {
      UserModel? profile = await _authService.getUserProfile(currentUser.uid);
      if (profile != null) {
        phoneNumber = profile.phoneNumber;
        bloodGroup = profile.bloodGroup;
        userRole = profile.userRole;
        vehicleNumber = profile.vehicleNumber;
      }
    }

    Position? currentPos = await _locationService.getCurrentLocation();
    double lat = currentPos?.latitude ?? 0.0;
    double lon = currentPos?.longitude ?? 0.0;

    // OFFLINE ACCEPTANCE BRANCH (Do NOT depend on or call Firestore!)
    if (emergencyId.startsWith('JS-OFF-')) {
      EmergencyModel? localEmergency = await _localDb.getEmergencyById(emergencyId);
      if (localEmergency == null) return null;

      // Authoritative check: Victim cannot volunteer for their own emergency
      if (localEmergency.victimId == userId) {
        return null;
      }

      // Authoritative check: Cannot claim closed or inactive emergency
      if (localEmergency.isClosed || !localEmergency.isActive) {
        return null;
      }

      // Duplicate acceptance protection: If already a responder, return current role
      if (localEmergency.responders.containsKey(userId)) {
        return localEmergency.responders[userId]?.role;
      }

      bool hasPrimary = localEmergency.helperId != null &&
          localEmergency.helperId!.isNotEmpty &&
          localEmergency.responders.values.any((r) => r.role == ResponderRole.PRIMARY);

      ResponderRole role = hasPrimary ? ResponderRole.STANDBY : ResponderRole.PRIMARY;

      Map<String, dynamic> acceptancePayload = {
        'eventType': 'RESPONDER_ACCEPTANCE',
        'emergencyId': emergencyId,
        'responderId': userId,
        'responderName': userName,
        'phoneNumber': phoneNumber,
        'bloodGroup': bloodGroup,
        'userRole': userRole,
        'vehicleNumber': vehicleNumber,
        'role': role.name,
        'status': (role == ResponderRole.PRIMARY
                ? ResponderStatus.RESPONDING
                : ResponderStatus.STANDBY)
            .name,
        'latitude': lat,
        'longitude': lon,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 1. Send P2P payload over Nearby Connections
      await _offlineNearbyService.sendAcceptancePayload(
        emergencyId: emergencyId,
        responderId: userId,
        responderName: userName,
        phoneNumber: phoneNumber,
        bloodGroup: bloodGroup,
        latitude: lat,
        longitude: lon,
        role: role,
      );

      // 2. Process locally
      await OfflineNearbyService.processAcceptancePayload(acceptancePayload, _localDb);
      await ImpactRewardService().recordEmergencyAccepted(userId, emergencyId);

      return role;
    }

    // ONLINE ACCEPTANCE BRANCH (Firestore Atomic Transaction)
    DocumentReference emergencyRef = _firestore
        .collection(AppConstants.emergenciesCollection)
        .doc(emergencyId);

    ResponderRole assignedRole = ResponderRole.STANDBY;

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(emergencyRef);
        if (!snapshot.exists) {
          throw Exception("Emergency does not exist");
        }

        var data = snapshot.data() as Map<String, dynamic>;
        String victimId = data['victimId'] ?? '';
        // Authoritative validation: Victim cannot volunteer for their own emergency
        if (victimId == userId) {
          throw Exception("You cannot volunteer for your own emergency.");
        }

        String? currentHelperId = data['helperId'];
        String emergencyStatus = (data['status'] ?? 'SEARCHING').toString().toUpperCase();

        // Authoritative validation: closed/terminal emergencies cannot be claimed
        if (emergencyStatus == 'COMPLETED' ||
            emergencyStatus == 'CANCELLED' ||
            emergencyStatus == 'RESOLVED' ||
            emergencyStatus == 'ENDED') {
          throw Exception("This emergency is no longer active.");
        }

        if (emergencyStatus != AppConstants.statusSearching &&
            emergencyStatus != AppConstants.statusAssigned &&
            emergencyStatus != AppConstants.statusApproaching) {
          throw Exception("Emergency status is not claimable: $emergencyStatus");
        }

        Map<String, dynamic> existingResponders = data['responders'] != null
            ? Map<String, dynamic>.from(data['responders'])
            : {};

        // Duplicate acceptance protection: If already in responders map, keep existing role
        if (existingResponders.containsKey(userId)) {
          String roleName = existingResponders[userId]['role'] ?? 'STANDBY';
          assignedRole = ResponderRole.values.firstWhere(
            (e) => e.name == roleName,
            orElse: () => ResponderRole.STANDBY,
          );
          return;
        }

        if ((currentHelperId == null || currentHelperId.isEmpty) &&
            emergencyStatus == AppConstants.statusSearching) {
          assignedRole = ResponderRole.PRIMARY;

          ResponderModel primaryModel = ResponderModel(
            userId: userId,
            userName: userName,
            phoneNumber: phoneNumber,
            bloodGroup: bloodGroup,
            userRole: userRole,
            vehicleNumber: vehicleNumber,
            role: ResponderRole.PRIMARY,
            status: ResponderStatus.RESPONDING,
            latitude: lat,
            longitude: lon,
            acceptedAt: DateTime.now(),
            lastLocationUpdate: DateTime.now(),
            assignedAt: DateTime.now(),
          );

          existingResponders[userId] = primaryModel.toMap();

          transaction.update(emergencyRef, {
            'helperId': userId,
            'status': AppConstants.statusAssigned,
            'responders': existingResponders,
            'lastHelperLocation': {
              'latitude': lat,
              'longitude': lon,
              'timestamp': FieldValue.serverTimestamp(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          assignedRole = ResponderRole.STANDBY;

          ResponderModel standbyModel = ResponderModel(
            userId: userId,
            userName: userName,
            phoneNumber: phoneNumber,
            bloodGroup: bloodGroup,
            userRole: userRole,
            vehicleNumber: vehicleNumber,
            role: ResponderRole.STANDBY,
            status: ResponderStatus.STANDBY,
            latitude: lat,
            longitude: lon,
            acceptedAt: DateTime.now(),
            lastLocationUpdate: DateTime.now(),
            assignedAt: DateTime.now(),
          );

          existingResponders[userId] = standbyModel.toMap();

          transaction.update(emergencyRef, {
            'responders': existingResponders,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      await ImpactRewardService().recordEmergencyAccepted(userId, emergencyId);
      return assignedRole;
    } catch (e) {
      return null;
    }
  }

  /// Legacy helper claim method for backward compatibility
  Future<bool> claimEmergency(String emergencyId) async {
    ResponderRole? role = await acceptAndRespond(emergencyId);
    return role == ResponderRole.PRIMARY;
  }
}
