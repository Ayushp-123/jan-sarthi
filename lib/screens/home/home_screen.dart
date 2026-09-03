import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/communication_manager.dart';
import '../../services/emergency_service.dart';
import '../../services/notification_service.dart';
import '../../services/accident_detection_service.dart';
import '../../services/accident_detection_evaluator.dart';
import '../../models/user_model.dart';
import '../../models/communication_mode.dart';
import '../../models/emergency_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/map_widget.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/offline_mode_bento_banner.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/accident_detection_dialog.dart';
import '../../widgets/permission_request_dialog.dart';
import '../../core/navigation/app_navigator.dart';
import '../profile/profile_screen.dart';
import '../history/emergency_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final CommunicationManager _communicationManager = CommunicationManager();
  final EmergencyService _emergencyService = EmergencyService();
  final NotificationService _notificationService = NotificationService();
  final AccidentDetectionService _accidentDetectionService = AccidentDetectionService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Position? _currentPosition;
  UserModel? _userProfile;
  bool _isLoadingLocation = true;
  bool _isCreatingSOS = false;
  int _currentIndex = 0;
  CommunicationMode _currentMode = CommunicationMode.online;

  StreamSubscription<List<EmergencyModel>>? _nearbySubscription;
  StreamSubscription<CommunicationMode>? _modeSubscription;
  StreamSubscription<AccidentEvaluationResult>? _accidentSubscription;
  final Set<String> _alertedEmergencyIds = {};

  @override
  void initState() {
    super.initState();
    _communicationManager.initialize();
    _currentMode = _communicationManager.activeMode;

    _modeSubscription = _communicationManager.modeStream.listen((mode) {
      if (mounted && _currentMode != mode) {
        setState(() => _currentMode = mode);
        if (_currentPosition != null) {
          _listenToAlerts(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _auth.currentUser?.uid ?? 'offline_user',
          );
        }
      }
    });

    _notificationService.init();
    _initLocation();
    _initAccidentDetection();
    _loadUserProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        PermissionRequestDialog.showIfNeeded(context);
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      UserModel? profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() => _userProfile = profile);
      }
    }
  }

  Future<void> _initAccidentDetection() async {
    await _accidentDetectionService.initialize();
    _accidentSubscription = _accidentDetectionService.possibleAccidentStream.listen((result) {
      if (mounted && !_isCreatingSOS) {
        AccidentDetectionDialog.show(
          context: context,
          reasoning: result.reasoning,
          onConfirmAutoSOS: _executeSOS,
          onCancel: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Emergency cancelled — you're safe."),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );
      }
    });
  }

  Future<void> _initLocation() async {
    Position? pos = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
    }
    _locationService.startLocationUpdates();

    if (pos != null) {
      _listenToAlerts(pos.latitude, pos.longitude, _auth.currentUser?.uid ?? 'offline_user');
    }
  }

  void _listenToAlerts(double lat, double lon, String uid) {
    _nearbySubscription?.cancel();
    _nearbySubscription = _communicationManager
        .listenForAlerts(userLat: lat, userLon: lon, currentUserId: uid)
        .listen((emergencies) {
      if (emergencies.isNotEmpty && mounted) {
        final currentUid = _auth.currentUser?.uid ?? uid;
        for (var alert in emergencies) {
          // CRITICAL: A victim must NEVER be alerted or asked to volunteer for their own emergency!
          if (alert.isVictim(currentUid) ||
              alert.victimId == currentUid ||
              (currentUid == 'offline_user' && alert.isOffline && alert.victimId == 'offline_user')) {
            continue;
          }

          if (alert.status == EmergencyStatus.SEARCHING &&
              !_alertedEmergencyIds.contains(alert.id) &&
              !_emergencyService.isEmergencyDeclined(alert.id)) {
            _alertedEmergencyIds.add(alert.id);
            // Discard stale emergencies older than 5 minutes so opening the app doesn't show old test alerts
            if (DateTime.now().difference(alert.createdAt).inMinutes.abs() > 5) {
              continue;
            }
            if (_currentMode == CommunicationMode.online && currentUid != 'offline_user') {
              _emergencyService.markUserNotified(alert.id, currentUid);
            }
            _showNearbyEmergencyDialog(alert);
            break;
          }
        }
      }
    });
  }

  void _showNearbyEmergencyDialog(EmergencyModel emergency) {
    if (!mounted) return;
    AppDialogs.showNearbyEmergencyDialog(
      context: context,
      emergency: emergency,
      mode: _currentMode,
      userRole: _userProfile?.userRole ?? 'CITIZEN',
      vehicleNumber: _userProfile?.vehicleNumber,
      onViewEmergency: () {
        if (mounted) {
          AppNavigator.navigateToEmergencyDetails(context, emergency.id);
        }
      },
      onDecline: () {
        _emergencyService.markEmergencyDeclined(emergency.id);
      },
    );
  }

  void _triggerSOSConfirmation() async {
    Position? pos = _currentPosition ?? await _locationService.getCurrentLocation();

    if (!mounted) return;
    await AppDialogs.showSOSConfirmationBottomSheet(
      context: context,
      currentAddress: pos != null
          ? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (Current Coordinates)'
          : 'Pinpoint Satellite GPS Coordinates',
      isOnline: _currentMode == CommunicationMode.online,
      onConfirmSOS: _executeSOS,
    );
  }

  void _executeSOS() async {
    if (_isCreatingSOS) return;

    if (mounted) setState(() => _isCreatingSOS = true);
    try {
      Position? pos = _currentPosition ?? await _locationService.getCurrentLocation();
      pos ??= Position(
        latitude: 28.6139,
        longitude: 77.2090,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      String emergencyId = await _communicationManager.broadcastSOS(
        position: pos,
        currentUserId: _auth.currentUser?.uid ?? 'offline_user',
      );
      _alertedEmergencyIds.add(emergencyId);
      // Play victim confirmation chime and haptic feedback
      EmergencySoundService.playSOSSentSound();

      if (!mounted) return;

      AppNavigator.navigateToEmergencyMap(context, emergencyId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger SOS: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isCreatingSOS = false);
    }
  }

  @override
  void dispose() {
    _accidentSubscription?.cancel();
    _modeSubscription?.cancel();
    _nearbySubscription?.cancel();
    _notificationService.dispose();
    _communicationManager.dispose();
    _locationService.stopLocationUpdates();
    super.dispose();
  }

  void _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildAppDrawer(BuildContext context) {
    final user = _auth.currentUser;
    String email = user?.email ?? 'offline_user@jansarthi.org';
    bool isOnline = _currentMode == CommunicationMode.online;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainer,
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryContainerRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'JAN SARTHI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryRed,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOnline ? '🟢 ONLINE' : '📡 OFFLINE P2P',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Navigation Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined, color: AppTheme.primaryRed),
                    title: const Text('Home Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history, color: AppTheme.secondaryBlue),
                    title: const Text('Emergency History', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppTheme.secondaryBlue),
                    title: const Text('My Profile & Medical ID', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.navigateToProfile(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.contact_phone_outlined, color: AppTheme.primaryRed),
                    title: const Text('Emergency Contacts (Auto-SMS)', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      AppNavigator.navigateToProfile(context);
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // Sensor AI & Automation Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'SENSOR AI & AUTOMATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.car_crash_outlined, color: AppTheme.errorRed),
                    title: const Text('Crash & Impact Sensor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Autonomously detects collisions & hard falls', style: TextStyle(fontSize: 11)),
                    value: _accidentDetectionService.isEnabled,
                    activeThumbColor: AppTheme.errorRed,
                    onChanged: (val) async {
                      await _accidentDetectionService.setEnabled(val);
                      setState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                    title: const Text('Simulate Crash (Judge Demo)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryRed, fontSize: 13)),
                    subtitle: const Text('1-Tap demo trigger for stage presentation', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.pop(context);
                      _accidentDetectionService.simulateAccidentEvent();
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),

                  // Helplines Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'EMERGENCY HELPLINES (1-TAP CALL)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_police_outlined, color: AppTheme.secondaryBlue),
                    title: const Text('100 - Police Control Room'),
                    onTap: () => _callHelpline('100'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emergency_outlined, color: Colors.teal),
                    title: const Text('1070 - Disaster Management & Relief'),
                    onTap: () => _callHelpline('1070'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_hospital_outlined, color: AppTheme.primaryRed),
                    title: const Text('108 - Medical Ambulance'),
                    onTap: () => _callHelpline('108'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined, color: Colors.deepOrange),
                    title: const Text('101 - Fire Rescue'),
                    onTap: () => _callHelpline('101'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.security, color: Colors.purple),
                    title: const Text('1090 - Women Helpline'),
                    onTap: () => _callHelpline('1090'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorRed),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
              onTap: () async {
                await _auth.signOut();
                if (!context.mounted) return;
                Navigator.pop(context);
                AppNavigator.navigateToLogin(context);
              },
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'Jan Sarthi v2.0 • Real-Time Emergency Network',
                style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex == 1) {
      return EmergencyHistoryScreen(
        onBackPressed: () => setState(() => _currentIndex = 0),
      );
    }
    if (_currentIndex == 2) {
      return ProfileScreen(
        onBackPressed: () => setState(() => _currentIndex = 0),
      );
    }

    bool isOnline = _currentMode == CommunicationMode.online;
    bool isAmbulance = _userProfile?.userRole == 'AMBULANCE_DRIVER';
    bool isPolice = _userProfile?.userRole == 'POLICE_PCR';

    return Scaffold(
      drawer: _buildAppDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.onSurface, size: 26),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'JAN SARTHI',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Connection & Role Status Header
              if (!isOnline) ...[
                const OfflineModeBentoBanner(),
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.green.shade200, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.emeraldGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.emeraldGreen.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ONLINE • RADAR ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_accidentDetectionService.isEnabled) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _accidentDetectionService.simulateAccidentEvent(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.errorRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.car_crash_outlined, size: 13, color: AppTheme.errorRed),
                              SizedBox(width: 4),
                              Text(
                                'CRASH AI: ON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.errorRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (isAmbulance || isPolice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAmbulance ? AppTheme.primaryContainerRed : AppTheme.secondaryContainerBlue,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAmbulance ? AppTheme.primaryRed.withValues(alpha: 0.4) : AppTheme.secondaryBlue.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isAmbulance ? '🚑 108 AMBULANCE' : '🚓 PCR UNIT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isAmbulance ? AppTheme.primaryRed : AppTheme.secondaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 2. Location Command Card
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGlassGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.my_location_rounded, color: AppTheme.secondaryBlue, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'LIVE GPS TELEMETRY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurfaceVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.satellite_alt_rounded, size: 12, color: AppTheme.secondaryBlue),
                              SizedBox(width: 4),
                              Text(
                                '±3m Fix',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 135,
                        width: double.infinity,
                        child: _isLoadingLocation
                            ? const Center(child: CircularProgressIndicator())
                            : _currentPosition != null
                                ? RealMapWidget(initialPosition: _currentPosition!)
                                : const Center(child: Text('GPS coordinates unavailable')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_rounded, size: 16, color: AppTheme.primaryRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentPosition != null
                                ? '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                                : 'Acquiring high-precision lock...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. SOS Trigger Zone
              const Text(
                'NEED EMERGENCY HELP?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryRed,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap button below for immediate emergency dispatch',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Multi-Ring Interactive SOS Button
              _isCreatingSOS
                  ? const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    )
                  : SOSButton(onPressed: _triggerSOSConfirmation),

              const SizedBox(height: 20),

              // 4. Safety Network Status Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.emeraldGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autonomous Safety Mesh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI Crash Detection & Dispatch Active',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? AppTheme.emeraldGreen : AppTheme.tertiaryAmber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'ACTIVE' : 'P2P MESH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isOnline ? const Color(0xFF047857) : const Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            currentIndex: _currentIndex,
            selectedItemColor: AppTheme.primaryRed,
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_rounded),
                activeIcon: Icon(Icons.radar_rounded, color: AppTheme.primaryRed),
                label: 'Radar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_toggle_off_rounded),
                activeIcon: Icon(Icons.history_rounded, color: AppTheme.primaryRed),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded, color: AppTheme.primaryRed),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
