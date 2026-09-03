# 📋 JAN SARTHI V2 — COMPREHENSIVE MASTER PROJECT REPORT

---

## 1. Executive Summary & Core Mission

**Jan Sarthi** (जन सारथी V2) is an emergency response platform engineered to bridge the critical first-responder gap during medical emergencies, road accidents, crimes, and natural disasters.

```
+-----------------------------------------------------------------------------------+
|                                  JAN SARTHI V2                                    |
|                                                                                   |
|  +-------------------------------------+   +-----------------------------------+  |
|  |           MANUAL TRIGGER            |   |         AUTOMATIC TRIGGER         |  |
|  |  Hold SOS Button for 3 Seconds      |   |  Multi-Sensor Crash Evaluator     |  |
|  +------------------+------------------+   +-----------------+-----------------+  |
|                     |                                        |                    |
|                     +-------------------+--------------------+                    |
|                                         |                                         |
|                              +----------v----------+                              |
|                              |  Confirmation Guard |                              |
|                              |  (15s Countdown)    |                              |
|                              +----------+----------+                              |
|                                         |                                         |
|                              +----------v----------+                              |
|                              |  Existing SOS Engine|                              |
|                              +----------+----------+                              |
|                                         |                                         |
|                 +-----------------------+-----------------------+                 |
|                 |                                               |                 |
|        [ONLINE MODE DETECTED]                          [OFFLINE MODE DETECTED]    |
|        - Firestore Geo-Queries                         - Nearby Connections P2P   |
|        - Cloud Functions & FCM                         - Star/Mesh Topology       |
|                 |                                               |                 |
|                 +-----------------------+-----------------------+                 |
|                                         |                                         |
|                              +----------v----------+                              |
|                              | Multi-Tier Responders|                             |
|                              | PRIMARY / STANDBY   |                              |
|                              +----------+----------+                              |
|                                         |                                         |
|                              +----------v----------+                              |
|                              | Live OpenStreetMap  |                              |
|                              | Dynamic Route & ETA |                              |
|                              +---------------------+                              |
+-----------------------------------------------------------------------------------+
```

---

## 2. Core Systems & Architecture

### A. Dual Transport Network Engine (`CommunicationManager`)
- **Online Mode**: Communicates via Firebase Firestore & Cloud Messaging FCM. Broadcasts SOS payload to nearby registered volunteers using radial expansion ($2\text{ km} \rightarrow 5\text{ km} \rightarrow 10\text{ km}$).
- **Offline P2P Mesh Mode**: Automatically detects network loss via `ConnectivityService` and falls back to Google `nearby_connections` (Wi-Fi Direct & Bluetooth LE star/mesh topology). Broadcasts `JS-OFF-` payloads locally.

### B. Multi-Tier Responder Pool & Automatic Failover Handover
- **First Helper to Accept**: Designated as **`PRIMARY`** responder. Gets live road polyline route to victim.
- **Subsequent Helpers**: Assigned to **`STANDBY`** pool.
- **Reliability Monitor (`ResponderReliabilityMonitor`)**: Continuously monitors primary helper GPS movement. If helper stalls for $>30\text{ seconds}$ or becomes unresponsive, system automatically transitions helper to `AT_RISK` and promotes top `STANDBY` helper to `PRIMARY` without terminating the SOS session.

### C. Automatic Accident & Crash Detection Engine
- **Multi-Sensor Fusion Evaluator (`AccidentDetectionEvaluator`)**: Evaluates linear acceleration ($\Delta a$ via `sensors_plus`), angular rotation ($\omega$ via gyroscope), GPS speed drop ($\Delta v$ via `LocationService`), vehicle speed context, and post-impact stillness.
- **Confidence Scoring Matrix**:
  - Net Impact Acceleration ($\ge 25\text{ m/s}^2$: +40, $\ge 18\text{ m/s}^2$: +25, $\ge 12\text{ m/s}^2$: +10)
  - Speed Drop ($\ge 5\text{ m/s}$ / $18\text{ km/h}$: +25, $\ge 3\text{ m/s}$: +15)
  - Angular Rotation ($\ge 4\text{ rad/s}$: +15, $\ge 2.5\text{ rad/s}$: +10)
  - Vehicle Speed Context ($\ge 5\text{ m/s}$ prior speed): +10
  - Post-Impact Stillness: +10
  - Threshold $\ge 70$ triggers `SUSPECTED` accident confirmation dialog.
- **False-Positive Protection**: Isolated single acceleration spikes without secondary signals are capped at 45 (below 70 threshold), preventing false triggers when phone is dropped.
- **15-Second Confirmation Countdown**: Renders a bottom sheet modal (`AccidentDetectionDialog`). User can tap **"I'M OKAY"** to cancel. Expiry triggers existing SOS engine.

### D. Safe Accident-Detection Demo Mode
- **Developer / Demo Trigger**: Added **`🧪 Test Accident Detection`** in `ProfileScreen` under a Developer/Demo section.
- **Release-Build Protection**: Guarded by `!kReleaseMode` (`package:flutter/foundation.dart`). Hidden in production release builds.
- **Simulated Event Injection**: Passes simulated high-impact parameters ($a_{\text{net}} = 27.2\text{ m/s}^2$, $\omega = 4.5\text{ rad/s}$, $\Delta v = 6.0\text{ m/s}$, $v_{\text{prior}} = 10.0\text{ m/s}$) into `AccidentDetectionEvaluator.evaluate()` and triggers the existing 15s countdown sheet, cancellation, or auto-SOS pipeline.

---

## 3. UI ↔ Backend Compliance Matrix

| Screen | Key UI Component / Button | Backend Service / Controller | Online Transport | Offline Transport | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Splash Screen** | App Initialization & Radar Badge | `FirebaseAuth.instance.currentUser` | Firebase Auth | Cached Session | **WORKING** |
| **Login Screen** | "LOGIN" Button | `AuthService.loginWithEmailAndPassword` | Firebase Auth | N/A | **WORKING** |
| **Login Screen** | "CREATE ACCOUNT" Link | `AppNavigator.navigateToRegister` | N/A | N/A | **WORKING** |
| **Register Screen** | "CREATE ACCOUNT" Button | `AuthService.registerWithEmailAndPassword` | Firebase Auth + Firestore `users/{uid}` | N/A | **WORKING** |
| **Home Dashboard** | 3-Second Hold `SOSButton` | `CommunicationManager.broadcastSOS` | Firestore Geo-Query + FCM | `LocalDatabaseService` + Nearby P2P Mesh | **WORKING** |
| **Home Dashboard** | Online / Offline Banner | `ConnectivityService.modeStream` | `ConnectivityService` | `ConnectivityService` | **WORKING** |
| **Home Dashboard** | Current Location Map | `LocationService.getCurrentLocation` | `Geolocator` | `Geolocator` | **WORKING** |
| **Emergency Details** | "I CAN HELP" Button | `EmergencyClaimService.acceptAndRespond` | Firestore Transaction (`PRIMARY`/`STANDBY`) | Nearby P2P `JS-OFF-` Payload | **WORKING** |
| **Emergency Map** | Top Floating Status HUD | `EmergencyModel.status` & `ResponderRole` | Real-time Stream | `LocalDatabaseService.emergencyUpdatesStream` | **WORKING** |
| **Emergency Map** | Helper Route & ETA | `RoutingService.fetchRoadRoute` | OSRM / OpenStreetMap | Direct Haversine Fallback | **WORKING** |
| **Emergency Map** | Helper "ARRIVED" Button | `EmergencyService.updateEmergencyStatus` | Firestore `ARRIVED` Update | Nearby P2P `STATUS_UPDATE` | **WORKING** |
| **Emergency Map** | Helper "END EMERGENCY" | `EmergencyService.updateEmergencyStatus` | Firestore `COMPLETED` Update | Nearby P2P `STATUS_UPDATE` | **WORKING** |
| **Emergency Map** | Victim "CANCEL SOS" | `EmergencyService.cancelEmergency` | Firestore `CANCELLED` Update | Nearby P2P `STATUS_UPDATE` | **WORKING** |
| **Emergency Map** | Helper Profile Card & CALL | `url_launcher` (`tel:<phone>`) | Direct Telephony | Direct Telephony | **WORKING** |
| **Emergency History** | History List Cards | Firestore Stream & `LocalDatabaseService` | Firestore `emergencies` | `LocalDatabaseService.getAllLocalEmergencies` | **WORKING** |
| **Profile Screen** | Tappable Avatar & Edit Dialog | `AuthService.updateUserProfile` | Firestore `users/{uid}` | Local State | **WORKING** |
| **Profile Screen** | Accident Detection Switch | `AccidentDetectionService.setEnabled` | Local `SharedPreferences` | Local `SharedPreferences` | **WORKING** |
| **Profile Screen** | `🧪 Test Accident Detection` | `AccidentDetectionService.simulateAccidentEvent` | Simulated Sensor Stream | Simulated Sensor Stream | **WORKING** |
| **Profile Screen** | "LOG OUT" Button | `AuthService.signOut` | Firebase Auth | Local Cache Clear | **WORKING** |
| **Accident Modal** | 15s Countdown / "I'M OKAY" | `AccidentDetectionService` Stream | Local Countdown Timer | Local Countdown Timer | **WORKING** |

---

## 4. Master Verification Metrics

- **Static Analyzer**: `flutter analyze` passed with **0 errors**.
- **Automated Test Suite**: **15/15 tests passed** (`flutter test`), including:
  - 6 Accident Evaluator & Demo Simulation tests
  - 3 Data Model & Local DB tests
  - 5 Master Stability & Handover tests
  - 1 Widget UI test
- **Release Binary Build**:
  - Status: **SUCCESS (Exit Code 0)**
  - Output Path: [app-release.apk](file:///d:/sih/build/app/outputs/flutter-apk/app-release.apk)
  - Size: **53.8 MB**
  - Demo Control: Verified hidden in release mode via `!kReleaseMode`.
