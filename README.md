# Tixcora — Mobile Ticketing App

> **Secure Enterprise Ticketing**, powered by EnigmaCamp.
>
> A Flutter end-user mobile application for the Enterprise Ticketing System. Lets users submit support tickets, track status in realtime, chat with assigned agents, browse a knowledge base, and receive instant push notifications.

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-^3.9.2-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)]()
[![Status](https://img.shields.io/badge/Status-Production-success)]()

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Building](#building)
- [Deploying](#deploying)
- [Running Tests](#running-tests)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Support](#support)

---

## About

**Tixcora** is the mobile face of an internal Enterprise Ticketing System used by employees and clients to report issues, request services, and follow them through to resolution. The app is built in Flutter and connects to a Golang + Gin backend via a single API gateway.

It is purpose-built for end-users (the people who **file** tickets), not agents or admins. Role-based access is enforced at login: only roles in `AppConstants.allowedRoles` (`user`, `end_user`, `employee`, `client`, `customer`) are allowed to sign in.

### Key Highlights

- **Realtime notifications** via a native C++ SSE foreground service (libcurl over FFI), engineered to survive aggressive OEM battery optimization.
- **APK signature verification** using raw syscalls in C++ (Frida-resistant) to detect tampering.
- **Offline-first cache** for tickets, categories, statuses, and ratings via sqflite — the app stays usable without a network.
- **Single-source-of-truth backend URL** baked at build time via `--dart-define`, no runtime `.env` files.
- **Loading-state consistency** with shimmer skeletons on cold-start and silent background refreshes on warm visits.
- **WebSocket chat** per ticket with auto-reconnect and graceful pause/resume on connectivity changes.

---

## Features

### Authentication
- Login with email or username
- Forgot password (4-digit email code)
- First-login forced password change
- Proactive token refresh with mutex (no 401 storms)
- Force-logout on refresh failure

### Tickets
- Paginated list with status & priority filters
- Create ticket with attachment (max 5 MB)
- Detail view with three tabs: Detail, Chat, Files
- Realtime WebSocket chat with attachment upload
- Star rating (1-5) with optional comment, available once a ticket closes
- Offline cache fallback

### Knowledge Base
- Browse categories with article counts
- Paginated articles, sorted by recency
- HTML article rendering
- Tag filter (UI-side, backend pending)
- AI assistant Q&A endpoint

### Notifications
- Tray notifications via native SSE foreground service
- Six notification types (status change, assignment, overdue, warning, auto-close, new comment)
- In-app list with All/Unread filter
- Mark-as-read individual or all
- Tap-to-navigate deep linking (cold-launch supported)

### Profile
- View user info (avatar, name, email, role)
- Edit profile (firstname, lastname, phone)
- Avatar upload with circular crop (max 2 MB)
- Change password with strength indicator

### Search & Connectivity
- Global ticket search with infinite scroll
- Recent searches stored locally
- Offline banner overlay
- "No internet" dialog gating online-only actions
- Offline fallback page when no cache exists

---

## Tech Stack

| Category | Library | Version | Purpose |
|---|---|---|---|
| **State Management** | `provider` | `^6.1.1` | DI + ChangeNotifier |
| **HTTP Client** | `dio` | `^5.4.0` | REST API |
| **WebSocket** | `web_socket_channel` | `^3.0.1` | Chat per ticket |
| **Connectivity** | `connectivity_plus` | `^6.1.4` | Network state monitoring |
| **Routing** | `go_router` | `^13.0.0` | Declarative navigation |
| **Pagination** | `infinite_scroll_pagination` | `^4.1.0` | Ticket & search list |
| **Charts** | `fl_chart` | `^0.69.0` | Home dashboard |
| **HTML** | `flutter_html` | `^3.0.0` | Knowledge article rendering |
| **Secure Storage** | `flutter_secure_storage` | `^9.0.0` | Tokens (Keystore/Keychain) |
| **Plain Storage** | `shared_preferences` | `^2.2.2` | App settings |
| **Cache DB** | `sqflite` | `^2.3.0` | Offline data |
| **Notifications** | `flutter_local_notifications` | `^18.0.1` | Tray notifications |
| **Background** | `flutter_background_service` | `^5.0.12` | Foreground service for SSE |
| **Native FFI** | `ffi` | `^2.1.0` | C++ SSE & signature checker |
| **Firebase** | `firebase_core` | `^4.4.0` | FCM ready (currently SSE primary) |
| **UI** | `toastification`, `google_fonts`, `flutter_svg`, `cached_network_image`, `shimmer` | — | Premium look & feel |
| **Files** | `image_picker`, `image_cropper`, `file_picker`, `share_plus`, `gal` | — | Media handling |

Full dependency list in [`pubspec.yaml`](./pubspec.yaml).

---

## Architecture

The app follows a clean-ish **layered architecture per feature**, with strict layering between UI, state, repositories, and data sources.

```
┌──────────────────────────────────────────────────────┐
│  UI LAYER (Screen / Widget)                          │
│  - Consume state via Provider/ChangeNotifier         │
│  - Validate input + render loading/error             │
└─────────────┬────────────────────────────────────────┘
              │ context.read / context.watch
┌─────────────▼────────────────────────────────────────┐
│  STATE LAYER (ChangeNotifier)                        │
│  - Hold state enums (loading/loaded/error)           │
│  - Orchestrate repository calls                      │
│  - Catch typed exceptions → set error message        │
└─────────────┬────────────────────────────────────────┘
              │ method calls
┌─────────────▼────────────────────────────────────────┐
│  REPOSITORY LAYER                                    │
│  - Abstract interface + implementation               │
│  - Pick remote/mock based on ApiConfig               │
│  - Cache-first fallback to local datasource          │
│  - Return Result<T> or throw typed exceptions        │
└─────────────┬────────────────────────────────────────┘
              │
       ┌──────┴──────┬──────────────┐
       │             │              │
┌──────▼──────┐ ┌────▼────────┐ ┌───▼─────────┐
│ Remote DS   │ │ Mock DS     │ │ Local DS    │
│ (Dio API)   │ │ (in-memory) │ │ (sqflite +  │
│             │ │             │ │  secure st.)│
└─────────────┘ └─────────────┘ └─────────────┘
```

**Key components:**

- **Dependency Injection:** `MultiProvider` in `lib/app.dart` wires `LocalStorage → Repository → Provider`.
- **Mock toggle:** `ApiConfig.useMockData` (currently `false`).
- **Result<T>** type: success/failure wrapper used by the auth layer.
- **Typed exceptions:** ticket / notification layers throw exceptions caught by providers.
- **Native bridge:** `lib/core/native/native_sse.dart` and `lib/core/security/signature_checker.dart` use `dart:ffi` to call into `libjavaloader.so`.

For full architecture details see [PROJECT_DOCUMENTATION.md](./PROJECT_DOCUMENTATION.md) and [docs/FEATURE_BASED_ARCHITECTURE.md](./docs/FEATURE_BASED_ARCHITECTURE.md).

---

## Project Structure

```
ticketing_app/
├── android/                    # Android platform code
│   └── app/src/main/jni/       # Native C++ (SSE, signature checker)
├── ios/                        # iOS platform code
├── lib/
│   ├── main.dart               # Entry point + bootstrap
│   ├── app.dart                # MultiProvider + MaterialApp.router
│   ├── core/                   # Cross-cutting infrastructure
│   │   ├── constants/          # API config, endpoints, keys
│   │   ├── errors/             # Typed exceptions & failures
│   │   ├── native/             # FFI bindings
│   │   ├── network/            # Dio, interceptors, connectivity
│   │   ├── security/           # Signature checker
│   │   ├── services/           # Token refresh, notifications, background
│   │   ├── themes/             # Colors, typography
│   │   └── utils/              # Helpers, validators
│   ├── data/                   # Generic data models & datasources
│   ├── providers/              # Top-level shared ChangeNotifiers
│   ├── features/               # Feature modules (auth, tickets, etc.)
│   ├── routes/                 # GoRouter config
│   └── shared/widgets/         # Reusable widgets
├── assets/                     # Images, icons, certs
├── docs/                       # Reference docs (API, architecture, guides)
├── test/                       # Unit & widget tests
├── pubspec.yaml                # Dart deps & manifest
├── deploy.bat                  # Firebase App Distribution helper (Windows)
├── README.md                   # This file
├── HANDOVER.md                 # Handover guide
└── PROJECT_DOCUMENTATION.md    # Full technical reference
```

Each feature folder follows an identical pattern:
```
features/<feature_name>/
├── datasources/      # remote + mock + local
├── models/           # data classes (fromJson/toJson)
├── providers/        # ChangeNotifier (when feature has state)
├── repositories/     # interface + implementation
├── screens/          # page widgets
├── utils/            # feature-specific helpers (optional)
└── widgets/          # feature-specific widgets
```

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | ≥ 3.9.2 (stable) | Run `flutter --version` to verify |
| Dart SDK | bundled with Flutter | — |
| Android Studio | latest | Required for SDK + emulator |
| Android SDK | API 36 (compile), API 21 (min) | via Android Studio SDK Manager |
| Android NDK | `27.0.12077973` | exact match to `build.gradle.kts` |
| Java | 11+ | bundled with Android Studio |
| Firebase CLI | latest | `npm install -g firebase-tools` for deploys |
| Git | any modern version | for source control |

> [!IMPORTANT]
> The NDK version is critical because the project compiles native C++ libraries against it. A different NDK version may produce link errors.

---

## Getting Started

### 1. Clone the Repository

```bash
git clone <enigma-remote-url> ticketing_app
cd ticketing_app
```

### 2. Drop In The Off-Repo Files

This project depends on a handful of files that are **not in Git** (signing keys, Firebase configs, prebuilt libs). Get them from the previous developer or rebuild — see the full checklist in [docs/CREDENTIALS_HANDOVER.md](./docs/CREDENTIALS_HANDOVER.md).

Minimum required to build:
- `android/key.properties` (release signing password)
- `android/app/google-services.json` (Firebase Android config)
- `lib/firebase_options.dart` (FlutterFire init)
- `android/local.properties` (local SDK + NDK paths)
- `android/app/src/main/jni/curl/` (prebuilt libcurl + OpenSSL)
- `android/app/src/main/jni/rapidjson/` (header-only JSON)

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Verify The Setup

```bash
flutter analyze
# → No issues found!

flutter build apk --debug
# → Builds to build/app/outputs/flutter-apk/app-debug.apk
```

### 5. Run The App

```bash
# On a connected device or emulator
flutter run

# Or specify a device
flutter devices
flutter run -d <device-id>
```

---

## Configuration

### Backend URL

The base URL is baked at compile time via `String.fromEnvironment('API_BASE_URL')`, defined in [`lib/core/constants/api_config.dart`](./lib/core/constants/api_config.dart). The default is the production gateway.

| Environment | URL |
|---|---|
| Production (default) | `https://prod.damarbrawijaya.my.id` |
| Staging | `https://magang.damarbrawijaya.my.id` |

To override at build time:

```bash
flutter run --dart-define=API_BASE_URL=https://magang.damarbrawijaya.my.id
flutter build apk --release --dart-define=API_BASE_URL=https://staging.example.com
```

WebSocket and SSE URLs are derived automatically (`https://` becomes `wss://`).

### Signing

Release builds are signed with the `Enigma.p12` keystore. The password is read from `android/key.properties`:

```properties
storePassword=<...>
keyPassword=<...>
keyAlias=<...>
storeFile=Enigma.p12
storeType=pkcs12
```

If `key.properties` is missing, debug builds fall back to the debug keystore. Release builds require the file present and valid.

### Native NDK Path

`android/local.properties` must include:

```properties
ndk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk\\ndk\\27.0.12077973
```

(Use double backslashes on Windows.)

---

## Building

### Debug APK
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (signed)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Release APK with Backend Override
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://magang.damarbrawijaya.my.id
```

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Build Output Verification
```bash
# Verify the APK is signed with the expected keystore
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk

# Inspect APK metadata
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "version|package"
```

---

## Deploying

### Firebase App Distribution (Tester Channel)

Quick way:
```bash
.\deploy.bat "v0.16.0 - fix knowledge filter + offline shimmer"
```

Manual way:
```bash
flutter build apk --release
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:866621809782:android:34d880d6e90da18c93eb57 \
  --groups "enigma-ticketing-app" \
  --release-notes "Your release notes"
```

The `enigma-ticketing-app` tester group receives an email + install link. Manage testers in Firebase Console → App Distribution → Testers & Groups.

### Bumping the Version

Edit `pubspec.yaml`:
```yaml
version: 0.17.0+17   # <semver>+<buildNumber>
```

For full deploy procedures, signature rotation, and version conventions, see [docs/MAINTENANCE_GUIDE.md](./docs/MAINTENANCE_GUIDE.md).

---

## Running Tests

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Run with coverage
flutter test --coverage
```

> [!NOTE]
> Test coverage is currently minimal. Adding integration tests for the auth flow and ticket CRUD is on the maintenance backlog.

---

## Documentation

| Document | Purpose |
|---|---|
| [HANDOVER.md](./HANDOVER.md) | **Start here** if you are a new developer receiving this project. Covers ownership transfer, credentials, and signature checker. |
| [docs/CREDENTIALS_HANDOVER.md](./docs/CREDENTIALS_HANDOVER.md) | Checklist of off-repo secret files plus recovery procedures. |
| [docs/MAINTENANCE_GUIDE.md](./docs/MAINTENANCE_GUIDE.md) | Day-to-day cookbook: deploy, bump version, rotate keystore, troubleshooting. |
| [PROJECT_DOCUMENTATION.md](./PROJECT_DOCUMENTATION.md) | Full technical reference (1,200+ lines): architecture, every feature, networking, security, storage, error handling. |
| [docs/NATIVE_SSE_SETUP.md](./docs/NATIVE_SSE_SETUP.md) | Re-applying the native C++ SSE setup on a fresh clone. |
| [docs/FEATURE_BASED_ARCHITECTURE.md](./docs/FEATURE_BASED_ARCHITECTURE.md) | Per-feature folder layout & architecture details. |
| [docs/GIT_WORKFLOW.md](./docs/GIT_WORKFLOW.md) | Branch & commit conventions. |
| [docs/MASTERPLAN.md](./docs/MASTERPLAN.md) | Sprint timeline & big-picture project plan. |
| [docs/ColorDesignPattern.md](./docs/ColorDesignPattern.md) | Color tokens & design system. |

### API Contracts

| Document | Microservice |
|---|---|
| [docs/API_CONTRACT_SPECIFICATION_NEW_UPDATED.md](./docs/API_CONTRACT_SPECIFICATION_NEW_UPDATED.md) | Auth, user, ticket, comment, upload |
| [docs/DASHBOARD_API_DOCUMENTATION _UPDATED.md](./docs/DASHBOARD_API_DOCUMENTATION%20_UPDATED.md) | Dashboard statistics |
| [docs/MS_KNOWLEDGE_API_DOCUMENTATION_UPDATED_AI.md](./docs/MS_KNOWLEDGE_API_DOCUMENTATION_UPDATED_AI.md) | Knowledge base + AI assistant |
| [docs/API_CONTRACT_SLA_NOTIFICATION_UPDATED.md](./docs/API_CONTRACT_SLA_NOTIFICATION_UPDATED.md) | SLA & notifications |

---

## Contributing

This is an internal project. Contribution flow follows [docs/GIT_WORKFLOW.md](./docs/GIT_WORKFLOW.md):

1. Branch from `dev`: `git checkout -b feature/<feature-name>`
2. Make changes with conventional commit messages: `feat: ...`, `fix: ...`, `refactor: ...`
3. Run `flutter analyze` and `flutter test` (must pass)
4. Push to `enigma` (the primary remote): `git push enigma feature/<feature-name>`
5. Merge into `dev` after review, then push `dev` to `enigma`

> [!IMPORTANT]
> Never force-push to `dev` or `master`. Never commit `.env`, `key.properties`, or any file containing credentials. Always run a release build smoke test before deploying to testers.

### Code Style

- File names: `snake_case.dart`
- Class names: `PascalCase`
- Functions / variables: `camelCase`
- Private members: prefix with `_`
- Prefer `const` constructors and `final` variables
- Trailing commas on multi-line parameter lists
- Imports ordered: `dart:` → `package:` → relative

---

## Support

| Audience | Where to ask |
|---|---|
| **New developer onboarding** | Start with [HANDOVER.md](./HANDOVER.md) |
| **Day-to-day issues** | [docs/MAINTENANCE_GUIDE.md](./docs/MAINTENANCE_GUIDE.md) — Troubleshooting section |
| **Native SSE problems** | [docs/NATIVE_SSE_SETUP.md](./docs/NATIVE_SSE_SETUP.md) — Troubleshooting section |
| **Architecture questions** | [PROJECT_DOCUMENTATION.md](./PROJECT_DOCUMENTATION.md) |
| **Backend / API contract** | Coordinate via Scrum Master — backend is a separate Golang team |

---

## License

Internal project — proprietary to EnigmaCamp. Not for public distribution.

---

**Maintained by:** Mobile team
**Backend by:** Golang + Gin team
**Built with:** Flutter ❤
