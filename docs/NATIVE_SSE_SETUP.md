# Native SSE (C++/libcurl) — Setup Guide

Panduan untuk mengaktifkan implementasi SSE native (C++ + libcurl) untuk real-time notification, menggantikan Dart `HttpClient` yang sering reconnect.

Dokumen ini ditujukan untuk **AI coding assistant** atau developer yang perlu re-apply perubahan setelah `git clone` (folder `jni/` dan beberapa file generated tidak di-commit).

---

## Prasyarat

Sebelum mulai, pastikan:

1. **Android NDK terinstall** — versi `28.2.13676358` (atau sesuaikan).
   - Install via Android Studio → SDK Manager → SDK Tools → NDK (Side by side).
2. **Folder `jni/` sudah di-copy** secara manual ke `android/app/src/main/jni/` dengan isi:
   ```
   android/app/src/main/jni/
   ├── Android.mk
   ├── Application.mk
   ├── javaloader.cpp
   ├── curl/                           # prebuilt static libs (NOT in git)
   │   ├── curl-android-arm64-v8a/
   │   ├── curl-android-armeabi-v7a/
   │   ├── curl-android-x86_64/
   │   ├── openssl-android-arm64-v8a/
   │   ├── openssl-android-armeabi-v7a/
   │   └── openssl-android-x86_64/
   └── rapidjson/                      # header-only JSON (NOT in git)
   ```
3. **CA bundle** — `assets/certs/cacert.pem` harus ada (download dari `https://curl.se/ca/cacert.pem`).

---

## Checklist Penerapan

Gunakan ini sebagai task list saat mengaktifkan native SSE di fresh clone.

### 1. Konfigurasi NDK Path

Edit `android/local.properties` — tambah satu baris:

```properties
flutter.sdk=E:\\flutter
sdk.dir=E:\\SDKANDROIDSTUDIO
ndk.dir=E:\\SDKANDROIDSTUDIO\\ndk\\28.2.13676358
flutter.buildMode=debug
flutter.versionName=0.10.0
```

> [!IMPORTANT]
> Gunakan **double backslash** (`\\`) untuk Windows. File ini **tidak di-commit** — tiap dev harus set manual.

### 2. Gradle: ndk-build Task

File `android/app/build.gradle.kts` harus punya:

- Plugin `com.android.application` & `kotlin-android` (standard)
- Property loader untuk `ndk.dir` dari `local.properties`
- Task `ndkBuildNative` type `Exec` yang panggil `ndk-build.cmd` langsung
- `afterEvaluate { preBuild dependsOn ndkBuildNative }` hook
- `ndkVersion = "28.2.13676358"`
- `abiFilters` = `["arm64-v8a", "x86_64"]`
- `isCoreLibraryDesugaringEnabled = true` (butuh `desugar_jdk_libs:2.1.4`)
- `sourceSets.main.jniLibs.srcDirs("src/main/jniLibs")` (hasil output ndk-build)

> [!WARNING]
> JANGAN pakai `externalNativeBuild { ndkBuild { ... } }` block — itu konflik dengan plugin lain (`CXX1400`). Pakai pendekatan Exec task manual.

Struktur task-nya seperti ini:

```kotlin
val ndkBuildNative = tasks.register<Exec>("ndkBuildNative") {
    group = "build"
    description = "Builds libjavaloader.so via ndk-build (Android.mk)"

    val ndkDir = ndkDirProp
        ?: System.getenv("ANDROID_NDK_HOME")
        ?: System.getenv("ANDROID_NDK_ROOT")
    require(ndkDir != null) { "ndk.dir is not set" }

    val isWindows = org.gradle.internal.os.OperatingSystem.current().isWindows
    val ndkBuildName = if (isWindows) "ndk-build.cmd" else "ndk-build"
    val ndkBuildFile = file("$ndkDir/$ndkBuildName")

    inputs.dir(jniSrcDir)
    outputs.dir(jniLibsDir)

    commandLine(
        ndkBuildFile.absolutePath,
        "NDK_PROJECT_PATH=${projectDir}",
        "APP_BUILD_SCRIPT=${file("$jniSrcDir/Android.mk").absolutePath}",
        "NDK_APPLICATION_MK=${file("$jniSrcDir/Application.mk").absolutePath}",
        "NDK_LIBS_OUT=${jniLibsDir.absolutePath}",
        "NDK_OUT=${layout.buildDirectory.dir("intermediates/ndkBuild/obj").get().asFile.absolutePath}",
        "V=1"
    )
}

afterEvaluate {
    tasks.named("preBuild") { dependsOn(ndkBuildNative) }
}
```

### 3. Gitignore

Pastikan `android/.gitignore` ignore output generated:

```
.cxx/
# Generated native build outputs (ndk-build)
/app/src/main/jniLibs/
```

### 4. `pubspec.yaml`

Dependencies yang dibutuhkan:

```yaml
dependencies:
  ffi: ^2.1.0
  path_provider: ^2.1.0     # untuk CA bundle extraction
  shared_preferences: ^2.2.0 # (sudah ada)
  flutter_background_service: ^5.0.0
  flutter_local_notifications: ^18.0.0
```

Assets:

```yaml
flutter:
  assets:
    - assets/certs/   # berisi cacert.pem
```

### 5. File Dart yang Dibutuhkan

| File | Tujuan |
|------|--------|
| `lib/core/native/native_sse.dart` | FFI wrapper untuk `libjavaloader.so` |
| `lib/core/native/ca_bundle.dart` | Extract `cacert.pem` dari asset ke filesystem |
| `lib/core/services/background_notification_service.dart` | Foreground service yang panggil `NativeSse` |
| `lib/providers/notification_provider.dart` | Auto-subscribe di konstruktor |
| `lib/features/notifications/models/notification_model.dart` | `fromJson` terima `Map<dynamic, dynamic>` |

**Detail penting yang mudah kelupaan:**

#### a. `native_sse.dart` — Free heap pointer

```dart
static void _trampolineEvent(Pointer<Utf8> event, Pointer<Utf8> data) {
  // NativeCallable.listener dispatch ASYNC — native strdup string di heap
  // supaya buffer tetap valid. Dart WAJIB malloc.free() setelah convert.
  if (event != nullptr) {
    evt = event.toDartString();
    malloc.free(event);
  }
  if (data != nullptr) {
    dta = data.toDartString();
    malloc.free(data);
  }
  // ...
}
```

#### b. `background_notification_service.dart` — Pre-create notification channel

Di dalam `_onStart` (background isolate), **sebelum** `plugin.show()` pertama:

```dart
const AndroidNotificationChannel notifChannel = AndroidNotificationChannel(
  'ticketing_notifications',
  'Ticketing Notifications',
  description: 'Notifications for ticket updates and system alerts',
  importance: Importance.max,   // WAJIB max, bukan default
  playSound: true,
  enableVibration: true,
  showBadge: true,
);
await notificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(notifChannel);
```

> [!WARNING]
> JANGAN panggil `requestNotificationsPermission()` di background isolate — butuh activity context, bikin `_onStart` hang.

#### c. `notification_model.dart` — Handle IPC `Map<Object?, Object?>`

`service.invoke('newNotification', json)` round-trip via platform codec bikin nested map kehilangan type `<String, dynamic>`:

```dart
factory NotificationItem.fromJson(Map<dynamic, dynamic> json) {
  final rawMeta = json['metadata'];
  final Map<String, dynamic> meta = rawMeta is Map
      ? rawMeta.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        )
      : <String, dynamic>{};
  // ...
}
```

#### d. `notification_provider.dart` — Auto-subscribe di konstruktor

```dart
NotificationProvider(this._repository) {
  // Event bisa datang sebelum MainScreen mount (dari splash/login).
  listenToBackgroundService();
}
```

### 6. Android Manifest

`android/app/src/main/AndroidManifest.xml` harus punya:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Service declaration:

```xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="dataSync"
    android:stopWithTask="false"
    android:exported="false"
    tools:replace="android:exported,android:stopWithTask" />
```

### 7. Nginx Backend (di server)

SSE endpoint harus punya location khusus **di atas** `location /`:

```nginx
location /notifications/stream {
    proxy_pass http://localhost:8000;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $http_cf_connecting_ip;
    proxy_set_header X-Forwarded-For $http_cf_connecting_ip;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";

    proxy_connect_timeout 60s;
    proxy_send_timeout    24h;
    proxy_read_timeout    24h;

    proxy_buffering off;
    proxy_cache off;
    chunked_transfer_encoding off;
    add_header X-Accel-Buffering no;
}
```

Juga, kalau pakai Cloudflare: subdomain harus **DNS only (grey cloud)** supaya CF tidak cut stream.

---

## Troubleshooting

### Build Errors

| Error | Penyebab | Fix |
|-------|----------|-----|
| `CXX1400` | `externalNativeBuild` konflik dengan plugin lain | Pakai `Exec` task manual (bagian 2) |
| `ndk.dir is not set` | `local.properties` salah format atau ter-append dengan baris lain | Rewrite file `local.properties` (satu property per baris, escape `\\`) |
| `__sync_add_and_fetch_4` undefined | Prebuilt libcrypto untuk `armeabi-v7a` pakai GCC intrinsic lama | Drop `armeabi-v7a` dari `APP_ABI` & `abiFilters` |
| `CURLcode=60` | SSL verify failed (CA bundle tidak ditemukan) | Pastikan `cacert.pem` ter-extract & path di-pass ke native |

### Runtime Errors

| Gejala | Penyebab | Fix |
|--------|----------|-----|
| `CURLcode=18` tiap ~30s | Nginx `proxy_read_timeout` default 60s + buffering on | Update nginx config (bagian 7) |
| Popup notif tidak muncul tapi log `[DartSSE] plugin.show() returned OK` | Channel auto-created dengan importance LOW | Pre-create channel dengan `Importance.max` di background isolate |
| Badge lonceng tidak update realtime, harus tap baru update | `fromJson` crash di IPC map cast | Gunakan `Map<dynamic, dynamic>` signature |
| Event `event=""` sampai Dart tapi native log `event='notification'` | Use-after-free di async NativeCallable | `strdup` di native, `malloc.free` di Dart trampoline |
| Background isolate hang, tidak ada LOGI | `requestNotificationsPermission()` di background isolate | Hapus call itu — permission cuma bisa di main isolate |

### Debug Commands

```powershell
# Build apk debug
flutter clean
flutter pub get
flutter build apk --debug
flutter install

# Monitor log (native + Dart side)
adb logcat JavaLoader:V flutter:V *:S

# Uninstall supaya notification channel lama di-reset
adb uninstall com.enigma.ticketing_app

# Verify .so di APK
Expand-Archive build\app\outputs\flutter-apk\app-debug.apk -DestinationPath build\apk-extracted -Force
Get-ChildItem build\apk-extracted\lib -Recurse -Filter *.so
```

---

## Arsitektur Ringkas

```
Flutter UI (main isolate)
    │
    ├── NotificationProvider (listens 'newNotification')
    │
    ▼
flutter_background_service (foreground)
    │
    ├── Dart background isolate
    │   ├── NativeSse.start(url, token, caPath, onEvent, onStatus)
    │   ├── Creates AndroidNotificationChannel (Importance.max)
    │   ├── plugin.show() on event
    │   └── service.invoke('newNotification', json) → main isolate
    │
    ▼ (via dart:ffi)
libjavaloader.so (C++)
    │
    ├── worker thread
    │   ├── libcurl GET /notifications/stream (keep-alive, no body timeout)
    │   ├── Parse SSE lines (event:, data:, blank = dispatch)
    │   ├── strdup → NativeCallable.listener → Dart isolate
    │   └── Exponential backoff reconnect (1s quick for HTTP 200 cuts)
```

---

## Summary: Checklist Final

Setelah semua langkah di atas:

- [ ] `ndk.dir` set di `local.properties`
- [ ] Folder `jni/curl/`, `jni/rapidjson/` ada
- [ ] `assets/certs/cacert.pem` ada
- [ ] `pubspec.yaml` include `ffi` + `path_provider` + `assets/certs/`
- [ ] 5 file Dart sesuai bagian 5
- [ ] Nginx backend configured (bagian 7)
- [ ] `flutter build apk --debug` sukses
- [ ] `adb logcat JavaLoader:V` menunjukkan `[SSE] stream established`
- [ ] Notif popup muncul saat app di-close
- [ ] Badge lonceng update realtime tanpa user tap
