# 🚨 Jan Sarthi (जन सारथी) — Real-Time Emergency Response Network

[![Flutter Tests](https://img.shields.io/badge/Flutter%20Tests-Passing-brightgreen.svg)](test/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue.svg)](pubspec.yaml)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

**Jan Sarthi** is a resilient, hybrid emergency dispatch and responder coordination platform designed to save lives during critical first-response minutes. It combines online cloud infrastructure with offline peer-to-peer mesh connectivity to guarantee uninterrupted alert delivery even in zero-connectivity disaster zones.

---

## 🌟 Key Capabilities

- 🚨 **One-Tap Instant SOS**: Broadcasts emergency alerts with high-precision GPS coordinates instantly.
- 📡 **Dual-Mode Hybrid Transport**:
  - **Online**: Firebase Firestore streams + Cloud Functions geofencing + FCM push notifications.
  - **Offline**: Google Nearby Connections P2P mesh over BLE / Wi-Fi Direct with zero internet dependency.
  - **Mutual Exclusion**: Seamless automatic fallback and background sync when network is restored.
- 👥 **Multi-Tier Responder Pool**: Supports `PRIMARY`, `STANDBY`, and `SECONDARY` responder roles with atomic concurrency guarantees.
- ⚡ **Dynamic Reliability Watchdog & Auto-Handover**: Continuously monitors responder ETA, progress, and GPS staleness. Automatically promotes a standby helper if the primary helper is delayed or at-risk.
- 🗺️ **Open-Source Navigation**: Powered by OpenStreetMap and OSRM for live road routing, polylines, and dynamic ETA with zero Google Maps billing.
- 🛡️ **Freshness Guarantees**: 120-second stale alert suppression prevents ghost notifications on app boot.

---

## 🏗️ Architecture Overview

```
                                [ User Presses SOS ]
                                         │
                    ┌────────────────────┴────────────────────┐
                    ▼                                         ▼
            [ Online Mode ]                            [ Offline Mode ]
        Firebase + FCM + OSRM                      Nearby P2P Mesh (BLE/Wi-Fi)
                    │                                         │
                    └────────────────────┬────────────────────┘
                                         ▼
                             [ Multi-Responder Pool ]
                             • PRIMARY (Live Route HUD)
                             • STANDBY (Hot Backup)
                                         │
                                         ▼
                        [ ResponderReliabilityMonitor ]
                             • Staleness Watchdog (>15s)
                             • Progress Watchdog (>30s)
                             • Auto-Handover Trigger
```

---

## 📁 Repository Structure

```text
├── android/               # Android native Gradle configuration & manifests
├── functions/             # Firebase Cloud Functions (backend dispatch)
├── lib/
│   ├── core/              # Theme, styling, & global constants
│   ├── models/            # Schemas for users, emergencies, & responders
│   ├── screens/           # UI screens (Home, SOS Map, Emergency Details, Auth)
│   ├── services/          # Business logic, P2P networking, OSRM routing, reliability monitor
│   └── widgets/           # Custom UI widgets (Pulsing SOS button, OSM Map)
├── test/                  # Automated unit and widget tests
├── pubspec.yaml           # Dependencies and asset declarations
└── PROJECT_REPORT.md      # Comprehensive technical architecture report
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- [Android Studio](https://developer.android.com/studio) / Android SDK (API 21+)
- [Firebase CLI](https://firebase.google.com/docs/cli) (optional for deploying functions)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ayushp-123/jan-sarthi.git
   cd jan-sarthi
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run tests:**
   ```bash
   flutter test
   ```

4. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

Run the full test suite with:
```bash
flutter test
```

Tests cover:
- Data model serialization and edge cases
- Offline database caching and timestamp conversions
- Nearby connections payload handling and deduplication
- SOS button rendering and user interactions

---

## 📄 Documentation

For full architecture details, state machines, and failover workflows, check out [PROJECT_REPORT.md](PROJECT_REPORT.md).
