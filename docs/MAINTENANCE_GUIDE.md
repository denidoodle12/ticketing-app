# Maintenance Guide — Tixcora Mobile App

> **Audience:** the developer or team handling day-to-day maintenance.
> For handover and initial setup, see [HANDOVER.md](../HANDOVER.md).

This document is a "cookbook" for the maintenance tasks that come up most often.

---

## Table of Contents

1. [Daily Workflow](#1-daily-workflow)
2. [Deploy to Testers (Firebase App Distribution)](#2-deploy-to-testers-firebase-app-distribution)
3. [Bump Version](#3-bump-version)
4. [Swap Backend URL](#4-swap-backend-url)
5. [Update a Dependency](#5-update-a-dependency)
6. [Add or Change a Feature](#6-add-or-change-a-feature)
7. [Debugging Native SSE](#7-debugging-native-sse)
8. [Rotate Keystore (Update Signature)](#8-rotate-keystore-update-signature)
9. [Handle Backend API Changes](#9-handle-backend-api-changes)
10. [Add an Android Permission](#10-add-an-android-permission)
11. [Performance Tuning](#11-performance-tuning)
12. [Troubleshooting Common Errors](#12-troubleshooting-common-errors)

---

## 1. Daily Workflow

### Start Of Day
```bash
git checkout dev
git pull enigma dev

# Create a feature branch
git checkout -b feature/<feature-name>
```

### Develop
```bash
# Run on device/emulator
flutter run

# Hot reload is automatic. If you change native deps (jni/), a full restart is required.
```

### Before Committing
```bash
# Format & lint
flutter analyze
# Must show: "No issues found!"

# Tests (if any)
flutter test
```

### Commit & Push
Commit message format: `<type>: <subject>` — see [docs/GIT_WORKFLOW.md](./GIT_WORKFLOW.md).

```bash
git add -A
git commit -m "feat: add knowledge tag filter bottom sheet"
git push enigma feature/<feature-name>
```

### Merge Into `dev`
```bash
git checkout dev
git pull enigma dev
git merge feature/<feature-name>
git push enigma dev
```

---

## 2. Deploy to Testers (Firebase App Distribution)

### Quick Way (Recommended)
```bash
.\deploy.bat "v0.16.0 - fix knowledge filter + offline shimmer"
```

### Manual Way
```bash
# 1. Build the release APK
flutter build apk --release

# 2. Upload
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:866621809782:android:34d880d6e90da18c93eb57 \
  --groups "enigma-ticketing-app" \
  --release-notes "Your notes"
```

### Tester Did Not Get The Email?
1. Open Firebase Console → App Distribution → Releases → click the latest release → Testers tab.
2. Make sure the tester accepted the original invite (the baseline). If not, resend the invite manually.
3. Check that the tester's email has no typos in the `enigma-ticketing-app` group.

### Build Error During Deploy?
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

If it still fails, check:
- `android/key.properties` exists and the password is valid.
- `android/local.properties` has the correct `ndk.dir`.
- `android/app/src/main/jni/curl/` and `rapidjson/` are present.

---

## 3. Bump Version

### Edit `pubspec.yaml`
```yaml
version: 0.17.0+17
```

Format: `<semver>+<buildNumber>`
- `<semver>` → shown in the app and release notes
- `+<buildNumber>` → optional, used as a unique-per-upload identifier in Play Store (auto-mapped to Android's `versionCode`)

### Versioning Convention
| Change type | Bump |
|---|---|
| Small bug fix | patch (`0.16.0` → `0.16.1`) |
| New feature | minor (`0.16.0` → `0.17.0`) |
| Breaking change | major (`0.16.0` → `1.0.0`) |

### Manual Native Update (Optional)
The Android Manifest reads `versionName` from Flutter today. No native edits needed.

### Verify
```bash
flutter build apk --release
# Inspect APK metadata
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep version
# Should print: versionCode='17' versionName='0.17.0'
```

---

## 4. Swap Backend URL

### Option A: Edit The Default
File: `lib/core/constants/api_config.dart`
```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://prod-new.example.com',  // change here
);
```

### Option B: Override Per Build (No Code Change)
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://staging.example.com
```

### What Follows Automatically
- Auth endpoints
- User endpoints
- Ticket endpoints
- WebSocket URL (auto-converts `https://` → `wss://`)
- SSE URL

### What Does NOT Follow
- The CA bundle in `assets/certs/cacert.pem` — if the new backend uses a non-standard CA, the bundle must be updated.
- Domain whitelist in the network security config (if any).

---

## 5. Update a Dependency

### Edit `pubspec.yaml`
```yaml
dependencies:
  dio: ^5.5.0  # was 5.4.0
```

### Resolve & Test
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release  # check for new ProGuard warnings
```

### If a ProGuard Warning Appears
Edit `android/app/proguard-rules.pro` — add a keep rule:
```
-keep class com.example.newpackage.** { *; }
-dontwarn com.example.newpackage.**
```

### Audit Dependencies
Before a major version upgrade:
```bash
flutter pub outdated
flutter pub upgrade --major-versions  # careful — may include breaking changes
```

---

## 6. Add or Change a Feature

### New Folder Layout
Each feature follows the pattern in [docs/FEATURE_BASED_ARCHITECTURE.md](./FEATURE_BASED_ARCHITECTURE.md):
```
lib/features/<feature_name>/
├── datasources/      # remote (Dio call), mock, local (sqflite/prefs)
├── models/           # data classes with fromJson/toJson
├── providers/        # ChangeNotifier (state)
├── repositories/     # interface + impl
├── screens/          # page widgets
└── widgets/          # feature-specific widgets
```

### Add a New Provider
1. Create `lib/features/<feature>/providers/<feature>_provider.dart`.
2. Register in `lib/app.dart`:
   ```dart
   ChangeNotifierProvider<MyNewProvider>(
     create: (context) => MyNewProvider(context.read<MyNewRepository>()),
   ),
   ```

### Add a New Route
File: `lib/routes/app_routes.dart`
```dart
GoRoute(
  path: '/my-new-route',
  name: 'myNewRoute',
  builder: (context, state) => const MyNewScreen(),
),
```

### Add a New API Endpoint
1. Add the path in `lib/core/constants/api_endpoints.dart`.
2. Add a method in the datasource: `lib/features/<feature>/datasources/<feature>_remote_datasource.dart`.
3. Wrap it in the repository.
4. Consume it via the provider.

### Loading State Pattern (Established)
**For lists/grids:** use a shimmer from `lib/shared/widgets/ticket_card_shimmer.dart` or `home_shimmers.dart`. Gate it with `provider.isInitialXxxLoad` (see the walkthrough doc for the full pattern).

**For buttons/atoms:** use an inline `CircularProgressIndicator` in the button (`CustomButton` already supports `isLoading`).

---

## 7. Debugging Native SSE

### Confirm SSE Is Active
```bash
adb logcat JavaLoader:V flutter:V *:S
```

You should see:
```
JavaLoader: [SSE] Starting connection to https://...
JavaLoader: [SSE] stream established
```

### Notification Does Not Show In The Tray
1. Check permission: Settings → Apps → Tixcora → Notifications → enabled?
2. Check the `ticketing_notifications` channel exists with `MAX` importance.
3. Check the log: `adb logcat | grep -i notification`.
4. Trigger manually from the backend (or Postman to an admin endpoint).

### Notification Shows But Tap Does Not Open The Detail
1. Check that `LocalNotificationService.onNotificationTap` is registered.
2. Check the payload JSON is valid (`ticket_id` is in metadata).
3. Check that `MainScreen._handleNotificationPayload` runs.

### SSE Reconnects Frequently
1. Check the nginx backend log: `proxy_read_timeout` must be at least 24h (see [docs/NATIVE_SSE_SETUP.md Section 7](./NATIVE_SSE_SETUP.md#7-nginx-backend-di-server)).
2. If you use Cloudflare: the subdomain must be DNS-only (grey cloud).
3. Check the device is not aggressively killing the background service:
   - Xiaomi/Huawei: Battery Saver → Tixcora → No restrictions.
   - Samsung: Device Care → Battery → App Power Management → "Apps that won't be put to sleep" → add Tixcora.

### Background Service Dies When App Is Killed
1. Confirm `autoStartOnBoot: true` in `BackgroundNotificationService.initialize()`.
2. Confirm `<service ... android:stopWithTask="false" />` is in the Manifest.
3. Test: kill the app from recents → wait 1 minute → run `adb shell dumpsys activity services | grep flutter_background_service`. The service must still be alive.

---

## 8. Rotate Keystore (Update Signature)

> [!WARNING]
> This is the most sensitive operation. A mistake means existing users cannot update the APK (they must uninstall manually). Strongly discouraged unless required (keystore lost or compromised).

### Step 1: Generate The New Keystore
```bash
keytool -genkey -v -keystore Enigma_v2.p12 -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias enigma
```

### Step 2: Compute The Certificate SHA-256
```bash
keytool -list -v -keystore Enigma_v2.p12 -storetype PKCS12 -alias enigma | grep SHA256
# Output: SHA256: 6A:3B:5C:...
# Strip the colons → lowercase → "6a3b5c..."
```

### Step 3: Update The Hash In Native Code
File: `android/app/src/main/jni/security/signature_checker.cpp` (or a related header).

Find the hardcoded hash constant (it may be obfuscated). Typically:
```cpp
const uint8_t EXPECTED_SHA256[32] = { 0x6A, 0x3B, 0x5C, ... };
```

Replace it with the new hash.

### Step 4: Replace `Enigma.p12`
```bash
mv Enigma_v2.p12 android/app/Enigma.p12
```

Update `android/key.properties` with the new password.

### Step 5: Rebuild & Verify
```bash
flutter clean
flutter pub get
flutter build apk --release

# Confirm the APK is signed with the new keystore
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# The SHA-256 must match the new value
```

### Step 6: Boot Test
Install on a test device → must boot to the home screen, not `SecurityErrorScreen`.

### Step 7: Communicate With Users/Testers
Because the new APK cannot update the old one (different signatures), testers must **uninstall** first. Send a heads-up:
> "Version 0.20.0 requires uninstalling the previous version because the keystore has been rotated. Local data will be lost. Please log in again."

---

## 9. Handle Backend API Changes

### New Field In The Response
1. Update the model in `lib/features/<feature>/models/<model>.dart`:
   ```dart
   factory MyModel.fromJson(Map<String, dynamic> json) {
     return MyModel(
       newField: json['new_field'] as String?,  // nullable for backward compatibility
       ...
     );
   }
   ```
2. Update the UI consuming the field.

### Endpoint Path Changed
1. Update `lib/core/constants/api_endpoints.dart`.
2. Test with Postman before deploying.

### Response Format Changed
1. Discuss with backend about versioning (`/v2/...`) so behaviour stays backward compatible.
2. If it has to break, update the model + bump the minor version.

### Error Response Format Changed
File: `lib/core/network/api_interceptor.dart`. Look for `case 422:` (validation) or `case >= 500:` — adjust the parsing.

---

## 10. Add an Android Permission

File: `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.NEW_PERMISSION"/>
```

### Runtime Permission (Android 6+)
Use the `permission_handler` package (already included):
```dart
import 'package:permission_handler/permission_handler.dart';

final status = await Permission.camera.request();
if (status.isGranted) { ... }
```

### Will Testers Need To Reinstall?
- **Adding a permission** → Android 6+ shows a runtime prompt on first use; no reinstall needed.
- **Removing a permission** → no impact.
- **Changing a signature permission** → reinstall required.

---

## 11. Performance Tuning

### Profile Frame Rate
```bash
flutter run --profile
# Trigger interactions → record in DevTools timeline
```

### Profile Startup Time
```bash
flutter run --trace-startup
# Look for "Total startup time: Xms"
```

### Reduce APK Size
- Make sure R8 minify is enabled (already the default in `build.gradle.kts`).
- Drop unused architectures in `abiFilters` (currently only `arm64-v8a` and `x86_64`).
- Inspect large assets: `du -sh assets/* | sort -h`.

### Profile Memory
DevTools → Memory tab → take a heap snapshot:
- After login.
- After scrolling a long ticket list.
- After returning from a long chat.

Look for memory that is not released after popping a screen.

---

## 12. Troubleshooting Common Errors

### `flutter pub get` Fails
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### `flutter build apk` — `CXX1400`
Conflict in the native folder. Make sure there is no `externalNativeBuild { ndkBuild { ... } }` block in `build.gradle.kts`. Use the `Exec` task that is already there.

### `flutter build apk` — `ndk.dir is not set`
`android/local.properties` has the wrong format. On Windows use double backslashes:
```
ndk.dir=C:\\Users\\...\\ndk\\27.0.12077973
```

### App Boots Into `SecurityErrorScreen`
Possible causes:
1. The APK is signed with a different keystore than the one expected by the native code.
2. The APK was tampered (re-signed after build).
3. `libjavaloader.so` is missing from the APK.

Debug:
```bash
# 1. Verify the cert in the APK
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# Note the SHA-256

# 2. Check the hash in the native code
strings android/app/src/main/jniLibs/arm64-v8a/libjavaloader.so | grep -i sha
# Compare them
```

If they do not match → rebuild with the right keystore or update the hash (see Section 8).

### Login Succeeds But Immediately Returns To Login
Likely the refresh token failed. Check:
1. `adb logcat | grep -i token`.
2. Is the backend `/auth/refresh` endpoint up?
3. Is the token format in the response still as expected?

### Notifications Are Not Realtime
See [Section 7 — Debugging Native SSE](#7-debugging-native-sse).

### Build Error: "Could not resolve all files for configuration"
Network issue. Try:
```bash
flutter clean
flutter pub get
cd android && ./gradlew --refresh-dependencies && cd ..
```

### Hot Reload Not Working
- Changing files in `lib/` and not seeing changes → try hot restart (R in the terminal).
- Changing `pubspec.yaml` or native code → a full rebuild is required (`flutter run`).

### `Database locked` (sqflite)
Multiple async accesses to the database. Make sure every call goes through the `DatabaseHelper.instance` singleton. Do not instantiate it again.

---

## Quick Reference: Common Commands

```bash
# Development
flutter run                                    # debug run
flutter run --release                          # local release run
flutter analyze                                # lint
flutter test                                   # unit tests
flutter clean && flutter pub get               # reset state

# Build
flutter build apk --debug                      # debug APK
flutter build apk --release                    # signed release APK
flutter build apk --release --dart-define=API_BASE_URL=https://staging.example.com
flutter build appbundle --release              # AAB for Play Store

# Deploy
.\deploy.bat "release notes"                   # deploy to testers

# Native
adb logcat JavaLoader:V flutter:V *:S          # watch SSE log
adb uninstall com.enigma.ticketing_app         # force uninstall

# Git
git checkout dev && git pull enigma dev
git checkout -b feature/xxx
git add -A && git commit -m "feat: xxx"
git push enigma feature/xxx
```

---

**Update this document when:** a new repeatable procedure shows up, or a new troubleshooting case becomes common.
