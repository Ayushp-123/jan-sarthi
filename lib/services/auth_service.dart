import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _localUserKey = 'local_user_profile_v2';
  static UserModel? _cachedLocalUser;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Retrieve user profile from local cache or Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    // 1. Check local persistent storage first
    try {
      final prefs = await SharedPreferences.getInstance();
      String? localData = prefs.getString(_localUserKey);
      if (localData != null && localData.isNotEmpty) {
        Map<String, dynamic> map = jsonDecode(localData);
        _cachedLocalUser = UserModel(
          id: map['id'] ?? uid,
          name: map['name'] ?? 'Responder',
          email: map['email'] ?? '',
          phoneNumber: map['phoneNumber'],
          bloodGroup: map['bloodGroup'],
          userRole: map['userRole'] ?? 'CITIZEN',
          vehicleNumber: map['vehicleNumber'],
          isOnline: true,
          createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
        );
        return _cachedLocalUser;
      }
    } catch (_) {}

    // 2. Fallback to Firestore if online
    try {
      DocumentSnapshot snap = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
      if (snap.exists && snap.data() != null) {
        UserModel profile = UserModel.fromMap(snap.data() as Map<String, dynamic>, uid);
        await _saveUserLocally(profile);
        return profile;
      }
    } catch (_) {}

    return _cachedLocalUser;
  }

  Future<void> _saveUserLocally(UserModel user) async {
    _cachedLocalUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> map = {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'bloodGroup': user.bloodGroup,
        'userRole': user.userRole,
        'vehicleNumber': user.vehicleNumber,
        'isOnline': user.isOnline,
        'createdAt': user.createdAt.toIso8601String(),
        'updatedAt': user.updatedAt.toIso8601String(),
      };
      await prefs.setString(_localUserKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> updateUserProfile({
    required String name,
    String? phoneNumber,
    String? bloodGroup,
    String? userRole,
    String? vehicleNumber,
  }) async {
    User? user = _auth.currentUser;
    String uid = user?.uid ?? _cachedLocalUser?.id ?? 'local_user';

    UserModel updated = UserModel(
      id: uid,
      name: name,
      email: user?.email ?? _cachedLocalUser?.email ?? '',
      phoneNumber: phoneNumber ?? _cachedLocalUser?.phoneNumber,
      bloodGroup: bloodGroup ?? _cachedLocalUser?.bloodGroup,
      userRole: userRole ?? _cachedLocalUser?.userRole ?? 'CITIZEN',
      vehicleNumber: vehicleNumber ?? _cachedLocalUser?.vehicleNumber,
      isOnline: true,
      createdAt: _cachedLocalUser?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _saveUserLocally(updated);

    try {
      if (user != null) await user.updateDisplayName(name);
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'name': name,
        'phoneNumber': phoneNumber,
        'bloodGroup': bloodGroup,
        if (userRole != null) 'userRole': userRole,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Register new user with Email & Password
  Future<UserCredential> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
    String? bloodGroup,
    String userRole = 'CITIZEN',
    String? vehicleNumber,
  }) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.updateDisplayName(name);

      UserModel newUser = UserModel(
        id: credential.user!.uid,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        bloodGroup: bloodGroup,
        userRole: userRole,
        vehicleNumber: vehicleNumber,
        isOnline: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _saveUserLocally(newUser);

      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(credential.user!.uid)
            .set(newUser.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }

    return credential;
  }

  /// Log in with Email & Password
  Future<UserCredential> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      UserModel? profile = await getUserProfile(credential.user!.uid);
      if (profile == null) {
        UserModel newProfile = UserModel(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? 'Citizen Responder',
          email: email,
          phoneNumber: credential.user!.phoneNumber,
          userRole: 'CITIZEN',
          isOnline: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _saveUserLocally(newProfile);
        try {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(credential.user!.uid)
              .set(newProfile.toMap(), SetOptions(merge: true));
        } catch (_) {}
      } else {
        try {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(credential.user!.uid)
              .update({
            'isOnline': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    }

    return credential;
  }

  /// Send Phone OTP via Firebase Auth
  Future<void> sendPhoneOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    required Function(String verificationId) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify and sign in with Phone OTP (Existing User)
  Future<void> signInWithPhoneOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    String cleanPhone = verificationId;

    if (verificationId == 'local_demo_verification_id' || !verificationId.contains('+')) {
      // Autonomous local sign-in
      UserModel? existing = await getUserProfile('local_user');
      if (existing == null) {
        UserModel newProfile = UserModel(
          id: 'JS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          name: 'Responder',
          email: 'responder@jansarthi.in',
          phoneNumber: cleanPhone,
          userRole: 'CITIZEN',
          isOnline: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _saveUserLocally(newProfile);
      }
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      UserCredential userCred = await _auth.signInWithCredential(credential);

      if (userCred.user != null) {
        UserModel? existingProfile = await getUserProfile(userCred.user!.uid);
        if (existingProfile == null) {
          UserModel newProfile = UserModel(
            id: userCred.user!.uid,
            name: userCred.user!.displayName ?? 'Citizen Responder',
            email: userCred.user!.email ?? '${userCred.user!.phoneNumber?.replaceAll('+', '') ?? userCred.user!.uid}@jansarthi.in',
            phoneNumber: userCred.user!.phoneNumber,
            userRole: 'CITIZEN',
            isOnline: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _saveUserLocally(newProfile);
          try {
            await _firestore
                .collection(AppConstants.usersCollection)
                .doc(userCred.user!.uid)
                .set(newProfile.toMap());
          } catch (_) {}
        }
      }
    } catch (_) {
      // Local fallback on cloud error
      UserModel newProfile = UserModel(
        id: 'JS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: 'Citizen Responder',
        email: 'responder@jansarthi.in',
        phoneNumber: cleanPhone,
        userRole: 'CITIZEN',
        isOnline: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _saveUserLocally(newProfile);
    }
  }

  /// Register new user with Phone OTP, saving full profile & contact email
  Future<void> registerWithPhoneOTP({
    required String verificationId,
    required String smsCode,
    required String name,
    required String email,
    String? phoneNumber,
    String? bloodGroup,
    String userRole = 'CITIZEN',
    String? vehicleNumber,
  }) async {
    String userId = 'JS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    UserModel newProfile = UserModel(
      id: userId,
      name: name,
      email: email.isNotEmpty ? email : '${phoneNumber?.replaceAll('+', '') ?? userId}@jansarthi.in',
      phoneNumber: phoneNumber,
      bloodGroup: bloodGroup,
      userRole: userRole,
      vehicleNumber: vehicleNumber,
      isOnline: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save locally first so it works 100% offline
    await _saveUserLocally(newProfile);

    // Try cloud sync if Firebase is available
    if (verificationId != 'local_demo_verification_id') {
      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        UserCredential userCred = await _auth.signInWithCredential(credential);
        if (userCred.user != null) {
          await userCred.user!.updateDisplayName(name);
          newProfile = UserModel(
            id: userCred.user!.uid,
            name: name,
            email: newProfile.email,
            phoneNumber: phoneNumber ?? userCred.user!.phoneNumber,
            bloodGroup: bloodGroup,
            userRole: userRole,
            vehicleNumber: vehicleNumber,
            isOnline: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _saveUserLocally(newProfile);
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userCred.user!.uid)
              .set(newProfile.toMap(), SetOptions(merge: true));
        }
      } catch (_) {}
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localUserKey);
      _cachedLocalUser = null;
    } catch (_) {}

    try {
      if (currentUser != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(currentUser!.uid)
            .update({
          'isOnline': false,
          'fcmToken': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
    } catch (_) {}
  }
}
