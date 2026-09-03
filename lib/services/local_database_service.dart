import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_model.dart';

class LocalDatabaseService {
  static const String _offlineEmergenciesKey = 'offline_emergencies';

  static final StreamController<EmergencyModel> _emergencyUpdatesController =
      StreamController<EmergencyModel>.broadcast();

  /// Stream of local emergency updates for offline real-time UI refresh
  static Stream<EmergencyModel> get emergencyUpdatesStream => _emergencyUpdatesController.stream;

  /// Save or update an emergency locally and broadcast update event
  Future<void> saveEmergencyLocally(EmergencyModel emergency) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_offlineEmergenciesKey) ?? [];

    Map<String, dynamic> map = emergency.toMap();
    map['isSynced'] = false;

    // Filter out existing document with same emergencyId
    list.removeWhere((item) {
      try {
        var existing = jsonDecode(item);
        return existing['id'] == emergency.id;
      } catch (_) {
        return false;
      }
    });

    Map<String, dynamic> jsonSafeMap = _makeJsonSafe(map) as Map<String, dynamic>;
    list.add(jsonEncode(jsonSafeMap));
    await prefs.setStringList(_offlineEmergenciesKey, list);

    // Broadcast local update
    _emergencyUpdatesController.add(emergency);
  }

  /// Get all locally saved emergencies (for offline history display)
  Future<List<EmergencyModel>> getAllLocalEmergencies() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_offlineEmergenciesKey) ?? [];
    List<EmergencyModel> result = [];

    for (var item in list) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic>) {
          var restoredMap = _restoreFirestoreMap(map);
          result.add(EmergencyModel.fromMap(restoredMap, restoredMap['id'] ?? ''));
        }
      } catch (_) {}
    }
    return result;
  }

  /// Get unsynchronized offline emergencies
  Future<List<EmergencyModel>> getUnsyncedEmergencies() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_offlineEmergenciesKey) ?? [];
    List<EmergencyModel> result = [];

    for (var item in list) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic> && map['isSynced'] == false) {
          var restoredMap = _restoreFirestoreMap(map);
          result.add(EmergencyModel.fromMap(restoredMap, restoredMap['id'] ?? ''));
        }
      } catch (_) {}
    }
    return result;
  }

  /// Mark emergency as synchronized
  Future<void> markAsSynced(String emergencyId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_offlineEmergenciesKey) ?? [];

    List<String> updated = list.map((item) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic> && map['id'] == emergencyId) {
          map['isSynced'] = true;
          return jsonEncode(map);
        }
      } catch (_) {}
      return item;
    }).toList();

    await prefs.setStringList(_offlineEmergenciesKey, updated);
  }

  /// Get an individual emergency by ID from local storage
  Future<EmergencyModel?> getEmergencyById(String emergencyId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_offlineEmergenciesKey) ?? [];

    for (var item in list) {
      try {
        var map = jsonDecode(item);
        if (map is Map<String, dynamic> && map['id'] == emergencyId) {
          var restoredMap = _restoreFirestoreMap(map);
          return EmergencyModel.fromMap(restoredMap, emergencyId);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Recursively convert Firestore Timestamps and DateTimes into JSON-safe ISO-8601 strings
  static dynamic _makeJsonSafe(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _makeJsonSafe(v)));
    } else if (value is List) {
      return value.map(_makeJsonSafe).toList();
    }
    return value;
  }

  /// Restore Firestore Timestamps from stored JSON-safe map so EmergencyModel.fromMap can parse it
  static Map<String, dynamic> _restoreFirestoreMap(Map<String, dynamic> jsonMap) {
    Map<String, dynamic> restored = Map<String, dynamic>.from(jsonMap);

    // 1. Top-level dates
    if (restored['createdAt'] is String) {
      try {
        restored['createdAt'] = Timestamp.fromDate(DateTime.parse(restored['createdAt']));
      } catch (_) {
        restored['createdAt'] = Timestamp.now();
      }
    } else if (restored['createdAt'] is int) {
      restored['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(restored['createdAt']);
    }

    if (restored['updatedAt'] is String) {
      try {
        restored['updatedAt'] = Timestamp.fromDate(DateTime.parse(restored['updatedAt']));
      } catch (_) {
        restored['updatedAt'] = Timestamp.now();
      }
    } else if (restored['updatedAt'] is int) {
      restored['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(restored['updatedAt']);
    }

    // 2. Responders map dates
    if (restored['responders'] != null && restored['responders'] is Map) {
      Map<String, dynamic> responders = Map<String, dynamic>.from(restored['responders']);
      responders.forEach((key, val) {
        if (val is Map) {
          Map<String, dynamic> rMap = Map<String, dynamic>.from(val);
          if (rMap['acceptedAt'] is String) {
            try {
              rMap['acceptedAt'] = Timestamp.fromDate(DateTime.parse(rMap['acceptedAt']));
            } catch (_) {
              rMap['acceptedAt'] = Timestamp.now();
            }
          } else if (rMap['acceptedAt'] is int) {
            rMap['acceptedAt'] = Timestamp.fromMillisecondsSinceEpoch(rMap['acceptedAt']);
          }

          if (rMap['lastLocationUpdate'] is String) {
            try {
              rMap['lastLocationUpdate'] = Timestamp.fromDate(DateTime.parse(rMap['lastLocationUpdate']));
            } catch (_) {
              rMap['lastLocationUpdate'] = Timestamp.now();
            }
          } else if (rMap['lastLocationUpdate'] is int) {
            rMap['lastLocationUpdate'] = Timestamp.fromMillisecondsSinceEpoch(rMap['lastLocationUpdate']);
          }

          if (rMap['assignedAt'] != null) {
            if (rMap['assignedAt'] is String) {
              try {
                rMap['assignedAt'] = Timestamp.fromDate(DateTime.parse(rMap['assignedAt']));
              } catch (_) {
                rMap['assignedAt'] = null;
              }
            } else if (rMap['assignedAt'] is int) {
              rMap['assignedAt'] = Timestamp.fromMillisecondsSinceEpoch(rMap['assignedAt']);
            }
          }
          responders[key] = rMap;
        }
      });
      restored['responders'] = responders;
    }

    return restored;
  }
}
