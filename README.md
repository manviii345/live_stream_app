# Live Stream App

A Flutter-based live streaming camera application with real-time controls including torch/flashlight support and permission management.

---

## Requirements

| Tool | Version |
|------|---------|
| Flutter | ≥ 3.0.0 |
| Dart SDK | ≥ 3.0.0 < 4.0.0 |
| Android compileSdk | 36 |
| Android minSdk | 23 (Android 6.0+) |
| NDK | 27.0.12077973 |

---

### 1. Navigate to project directory

```bash
cd live_stream_app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

> **Note:** A physical Android or iOS device is required. Camera and torch hardware features are not available on emulators/simulators.

---

## Clean Build (Recommended after dependency changes)

```bash
flutter clean
flutter pub get
flutter run
```

---

## Android Setup

The Android build targets **API 36** with a minimum of **API 23** (Android 6.0). No additional Android configuration is required.

Ensure you have **NDK 27.0.12077973** installed via Android Studio:

> **Android Studio → SDK Manager → SDK Tools → NDK (Side by Side)**

---

## Permissions

The app will request the following permissions at runtime:

- **Camera** — required for live streaming
- **Flashlight/Torch** — required for torch control

Grant these when prompted on first launch.

---


