import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_constants.dart';
import 'emergency_service.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<Position>? _emergencyPositionSubscription;
  final EmergencyService _emergencyService = EmergencyService();

  Position? _cachedPosition;
  DateTime? _lastFetchTime;

  /// Get current speed in meters per second
  double get lastSpeedMps => _cachedPosition?.speed ?? 0.0;

  /// Check and request location permission from device
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current GPS position with high accuracy
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPosition != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inSeconds < 3) {
        return _cachedPosition;
      }
    }

    bool hasPermission = await checkLocationPermission();
    if (!hasPermission) return null;

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 8),
    );

    _cachedPosition = pos;
    _lastFetchTime = DateTime.now();
    return pos;
  }

  /// Start streaming live GPS updates to Firestore users/{userId} while user is active
  void startLocationUpdates() async {
    bool hasPermission = await checkLocationPermission();
    if (!hasPermission) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _cachedPosition = position;
      _lastFetchTime = DateTime.now();
      _updateUserLocationInFirestore(user.uid, position);
    });
  }

  /// Start streaming live GPS updates to active emergency session with 1m high-precision updates
  void startEmergencyLocationUpdates({
    required String emergencyId,
    required bool isVictim,
  }) async {
    bool hasPermission = await checkLocationPermission();
    if (!hasPermission) return;

    final user = FirebaseAuth.instance.currentUser;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
    );

    _emergencyPositionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _cachedPosition = position;
      _lastFetchTime = DateTime.now();

      String fieldKey = isVictim ? 'lastVictimLocation' : 'lastHelperLocation';

      // 1. Update top-level location
      if (!emergencyId.startsWith('JS-OFF-')) {
        FirebaseFirestore.instance
            .collection(AppConstants.emergenciesCollection)
            .doc(emergencyId)
            .update({
          fieldKey: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. If responder, update persistent responder pool coordinates
        if (!isVictim && user != null) {
          _emergencyService.updateResponderLocation(
            emergencyId: emergencyId,
            userId: user.uid,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }
    });
  }

  /// Stop emergency location updates
  void stopEmergencyLocationUpdates() {
    _emergencyPositionSubscription?.cancel();
    _emergencyPositionSubscription = null;
  }

  /// Stop regular location updates
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Update Firestore users/{userId} document
  Future<void> _updateUserLocationInFirestore(String uid, Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationAccuracy': position.accuracy,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (_) {}
  }
}
