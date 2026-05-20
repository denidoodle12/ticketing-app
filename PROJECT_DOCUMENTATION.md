# 📱 Tixcora — Mobile Ticketing App Documentation

> **Dokumen ini ditulis untuk persiapan UAT, onboarding developer baru, dan referensi internal.**
> Status: Sprint aktif (versi pubspec `0.14.2`). Backend gateway `https://prod.damarbrawijaya.my.id`.

---

## Daftar Isi

1. [Identitas Project](#1-identitas-project)
2. [Arsitektur Tingkat Tinggi](#2-arsitektur-tingkat-tinggi)
3. [Tech Stack Lengkap](#3-tech-stack-lengkap)
4. [Struktur Folder](#4-struktur-folder)
5. [Entry Point & Bootstrapping](#5-entry-point--bootstrapping)
6. [Daftar Fitur Detail](#6-daftar-fitur-detail)
7. [Networking Layer](#7-networking-layer)
8. [Authentication & Token Lifecycle](#8-authentication--token-lifecycle)
9. [Realtime: WebSocket Chat](#9-realtime-websocket-chat)
10. [Realtime: SSE Notification (Foreground Service)](#10-realtime-sse-notification-foreground-service)
11. [Storage Strategy](#11-storage-strategy)
12. [Offline & Caching](#12-offline--caching)
13. [Error Handling](#13-error-handling)
14. [Timeout Configuration](#14-timeout-configuration)
15. [Validation Rules](#15-validation-rules)
16. [File Upload Constraints](#16-file-upload-constraints)
17. [Routing](#17-routing)
18. [State Management Pattern](#18-state-management-pattern)
19. [Security](#19-security)
20. [Android Permissions](#20-android-permissions)
21. [API Endpoints Reference](#21-api-endpoints-reference)
22. [Coding Conventions](#22-coding-conventions)
23. [Known Issues / Edge Cases](#23-known-issues--edge-cases)

---

## 1. Identitas Project

| Item | Nilai |
|---|---|
| **Nama Aplikasi (display)** | Tixcora |
| **Tagline** | Secure Enterprise Ticketing |
| **Powered by** | EnigmaCamp |
| **Package name (pubspec)** | `ticketing_app` |
| **Versi (pubspec)** | `0.14.2` |
| **Dart SDK** | `^3.9.2` |
| **Target Platform** | Android (primary), iOS (secondary), folder web/windows/linux/macos tersedia tapi tidak difokuskan |
| **Backend** | Golang + Gin (microservices), single API Gateway HTTPS |
| **Base URL (default / prod)** | `https://prod.damarbrawijaya.my.id` |
| **Base URL (staging / magang)** | `https://magang.damarbrawijaya.my.id` (override via `--dart-define`) |
| **Tipe User** | End-user / pelapor (bukan admin/agent) |
| **Bahasa UI** | English |

---

## 2. Arsitektur Tingkat Tinggi

Pola yang dipakai: **Clean-ish Architecture per feature** dengan layering klasik:

```
┌──────────────────────────────────────────────────────┐
│  UI LAYER (Screen / Widget)                          │
│  - Konsumsi state via Provider/ChangeNotifier        │
│  - Validasi input + tampilkan loading/error          │
└─────────────┬────────────────────────────────────────┘
              │ context.read / context.watch
┌─────────────▼────────────────────────────────────────┐
│  STATE LAYER (Provider / ChangeNotifier)             │
│  - Hold state enum (loading/loaded/error)            │
│  - Orchestrate repository calls                      │
│  - Catch typed exceptions → set error message        │
└─────────────┬────────────────────────────────────────┘
              │ method calls
┌─────────────▼────────────────────────────────────────┐
│  REPOSITORY LAYER                                    │
│  - Abstrak interface + Impl                          │
│  - Pilih remote/mock berdasarkan ApiConfig           │
│  - Cache-first fallback ke local datasource          │
│  - Return Result<T> atau throw typed exception       │
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
- **DI**: `MultiProvider` di `lib/app.dart` merangkai LocalStorage → Repository → Provider.
- **Toggle mock**: `ApiConfig.useMockData` (saat ini `false`).
- **Result<T>** type: success/failure wrapper dipakai di layer auth (lihat `auth_repository.dart`).
- **Typed exceptions**: layer ticket/notification langsung throw exception, di-catch oleh provider.

---

## 3. Tech Stack Lengkap

### State Management
| Package | Versi | Kegunaan |
|---|---|---|
| `provider` | `^6.1.1` | DI + ChangeNotifier untuk state global |

### Networking
| Package | Versi | Kegunaan |
|---|---|---|
| `dio` | `^5.4.0` | HTTP client utama (REST API) |
| `pretty_dio_logger` | `^1.3.1` | Logging request/response saat dev |
| `connectivity_plus` | `^6.1.4` | Cek status koneksi WiFi/cellular |
| `web_socket_channel` | `^3.0.1` | WebSocket chat per ticket |
| `http` | `^1.2.0` | Backup HTTP client (jarang dipakai) |

### Local Storage
| Package | Versi | Kegunaan |
|---|---|---|
| `flutter_secure_storage` | `^9.0.0` | Token (Keystore Android / Keychain iOS) |
| `shared_preferences` | `^2.2.2` | User profile cache, settings, isFirstLogin |
| `sqflite` | `^2.3.0` | Cache offline tickets/categories/statuses/ratings |
| `path` | `^1.8.0` | Manipulasi path DB |

### Routing & Navigation
| Package | Versi | Kegunaan |
|---|---|---|
| `go_router` | `^13.0.0` | Declarative routing dengan `navigatorKey` global |

### UI / UX
| Package | Versi | Kegunaan |
|---|---|---|
| `toastification` | `^3.0.3` | Toast success/error/info/warning |
| `google_fonts` | `^6.3.3` | Font Inter / Roboto / Outfit |
| `flutter_svg` | `^2.2.3` | Render asset SVG |
| `cached_network_image` | `^3.4.1` | Cache gambar dari URL (avatar, attachment) |
| `shimmer` | `^3.0.0` | Loading skeleton |
| `infinite_scroll_pagination` | `^4.1.0` | Paging list ticket & search |
| `fl_chart` | `^0.69.0` | Bar/pie chart di home dashboard |
| `flutter_html` | `^3.0.0` | Render HTML article (knowledge base) |
| `flutter_password_strength` | `^0.1.6` | Indikator kekuatan password |

### File / Media
| Package | Versi | Kegunaan |
|---|---|---|
| `image_picker` | `^1.0.7` | Ambil foto dari kamera/galeri |
| `image_cropper` | `^8.0.2` | Crop avatar bentuk lingkaran |
| `file_picker` | `^8.0.0` | Pilih file attachment ticket/chat |
| `path_provider` | `^2.1.2` | Akses temp/document directory |
| `share_plus` | `^10.0.0` | Share file/text |
| `gal` | `^2.3.0` | Save image ke galeri |

### Utilities
| Package | Versi | Kegunaan |
|---|---|---|
| `intl` | `^0.19.0` | Format date/time/currency |
| `app_settings` | `^5.1.1` | Buka settings device (untuk minta permission) |
| `permission_handler` | `^11.3.0` | Request permission camera/storage/notif |
| `package_info_plus` | `^8.3.0` | Baca versi app dinamis |
| `url_launcher` | `^6.3.2` | Buka URL/email/tel |

### Notifications & Background
| Package | Versi | Kegunaan |
|---|---|---|
| `flutter_local_notifications` | `^18.0.1` | Tampilkan notif di tray |
| `flutter_background_service` | `^5.0.12` | Foreground Service untuk SSE |
| `flutter_background_service_android` | `^6.2.6` | Implementasi Android |
| `firebase_core` | `^4.4.0` | Init Firebase (FCM siap, tapi belum jadi notif utama) |

### Native
| Package | Versi | Kegunaan |
|---|---|---|
| `ffi` | `^2.1.0` | FFI ke `libjavaloader.so` (C++) untuk SSE & signature check |

### Dev Dependencies
| Package | Versi | Kegunaan |
|---|---|---|
| `flutter_lints` | `^5.0.0` | Lint rules standar |
| `mockito` | `^5.4.4` | Mocking untuk unit test |
| `build_runner` | `^2.4.8` | Code generation |
| `flutter_launcher_icons` | `^0.14.4` | Generate icon launcher |

---

## 4. Struktur Folder

```
lib/
├── main.dart                    # Entry point + bootstrap services
├── app.dart                     # MultiProvider + MaterialApp.router
├── firebase_options.dart        # FCM config (auto-generated)
│
├── core/
│   ├── constants/
│   │   ├── api_config.dart      # Base URL + timeout + useMockData
│   │   ├── api_endpoints.dart   # Path semua endpoint
│   │   ├── app_constants.dart   # appName, validation limits, allowedRoles
│   │   ├── asset_paths.dart     # Path asset images/icons
│   │   └── storage_keys.dart    # Key untuk SharedPreferences/SecureStorage
│   ├── errors/
│   │   ├── exceptions.dart      # NetworkException, ServerException, dll.
│   │   └── failures.dart        # Failure counterpart untuk Result<T>
│   ├── native/
│   │   ├── ca_bundle.dart       # Extract CA bundle untuk libcurl native
│   │   └── native_sse.dart      # FFI binding ke libjavaloader.so SSE
│   ├── network/
│   │   ├── dio_client.dart      # Dio singleton + interceptor
│   │   ├── api_interceptor.dart # 401 handler + auto refresh
│   │   ├── chat_websocket_service.dart  # WS chat
│   │   └── connectivity_service.dart    # Singleton connectivity
│   ├── security/
│   │   ├── signature_checker.dart       # FFI verify APK signature
│   │   └── security_error_screen.dart   # Tampilan saat tampered
│   ├── services/
│   │   ├── token_refresh_service.dart      # Proactive refresh + mutex
│   │   ├── local_notification_service.dart # Tray notification
│   │   └── background_notification_service.dart  # Foreground SSE
│   ├── themes/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── text_styles.dart
│   └── utils/
│       ├── app_info.dart
│       ├── image_picker_helper.dart
│       ├── toast_helper.dart
│       └── validators.dart
│
├── data/
│   ├── datasources/local/
│   │   ├── database_helper.dart  # sqflite singleton + migration
│   │   └── local_storage.dart    # Wrapper SecureStorage + Prefs
│   └── models/
│       └── api_response.dart     # Generic ApiResponse<T>
│
├── providers/                    # Top-level shared ChangeNotifier
│   ├── auth_provider.dart
│   ├── ticket_provider.dart
│   ├── profile_provider.dart
│   ├── notification_provider.dart
│   └── connectivity_provider.dart
│
├── features/                     # Feature-based modules
│   ├── auth/
│   ├── home/
│   ├── knowledge/
│   ├── main/
│   ├── notifications/
│   ├── onboarding/
│   ├── profile/
│   ├── search/
│   ├── splash/
│   └── tickets/
│
├── routes/
│   └── app_routes.dart           # GoRouter config
│
└── shared/widgets/               # Reusable widgets across features
    ├── connectivity_wrapper.dart
    ├── custom_button.dart
    ├── custom_text_field.dart
    ├── empty_state_widget.dart
    ├── form_card.dart
    ├── gradient_header.dart
    ├── loading_overlay.dart
    ├── loading_widget.dart
    ├── no_internet_dialog.dart
    ├── offline_banner.dart
    ├── offline_page.dart
    ├── profile_picture_viewer.dart
    └── section_label.dart
```

Setiap folder fitur mengikuti pola identik:
```
features/<nama_fitur>/
├── datasources/      # remote + mock + local
├── models/           # data class fromJson/toJson
├── providers/        # ChangeNotifier (jika fitur punya state khusus)
├── repositories/     # interface + impl
├── screens/          # widget halaman
├── utils/            # helper khusus fitur (opsional)
└── widgets/          # widget khusus fitur
```

---

## 5. Entry Point & Bootstrapping

### `main.dart` — urutan eksekusi

```dart
1. WidgetsFlutterBinding.ensureInitialized()
2. Firebase.initializeApp(options: ...)        // FCM siap, tapi notif via SSE
3. SignatureChecker.verify()                   // FFI cek APK signature (Android only)
   └─> Jika gagal → tampilkan SecurityErrorScreen, abort runApp
4. SystemChrome.setSystemUIOverlayStyle(...)   // Status bar transparan
5. ConnectivityService().initialize()          // Listen connectivity changes
6. LocalNotificationService.initialize()       // Init plugin + load app logo
7. LocalNotificationService.requestPermission()  // Android 13+ POST_NOTIFICATIONS
8. BackgroundNotificationService.initialize()  // Configure foreground service
9. AppInfo.init()                              // Read versi dari pubspec
10. SharedPreferences.getInstance()
11. FlutterSecureStorage()
12. runApp(MyApp(prefs, secureStorage))
```

### `app.dart` — DI tree

`MultiProvider` membuat singleton-like instances dengan urutan dependency:

```
LocalStorage (secureStorage + prefs)
    ↓
AuthRepository ──> AuthProvider
TicketRepository (+ DatabaseHelper) ──> TicketProvider
ProfileRepository ──> ProfileProvider (+ LocalStorage callback)
NotificationRepository ──> NotificationProvider
KnowledgeRepository ──> KnowledgeProvider
    ↓
ToastificationWrapper
    └─ MaterialApp.router (AppRoutes.router)
        └─ ConnectivityWrapper (offline banner + dialog)
```

---

## 6. Daftar Fitur Detail

### 6.1 Splash & Onboarding
- **Splash** (2 detik via `AppConstants.splashDurationMs`): cek auth status → redirect ke `/onboarding` (first launch), `/login`, atau `/home`.
- **Onboarding**: 3 halaman pengenalan, page indicator, tombol Skip/Next/Get Started.

### 6.2 Authentication
| Sub-fitur | Endpoint | Catatan |
|---|---|---|
| **Login** | `POST /auth/login` | Terima email **atau** username via field `identifier` |
| **Logout** | `POST /auth/logout` | Best-effort (lanjut clear lokal walau gagal) |
| **Refresh token** | `POST /auth/refresh` | Otomatis via interceptor + proactive timer |
| **Change password** | `PUT /users/me/change-password` | Wajib jika `isFirstLogin = true` |
| **Forgot password** | `POST /auth/forgot-password` | Kirim 4-digit code ke email |
| **Verify code** | `POST /auth/verify-reset-token` | Cek 4-digit code valid/expired |
| **Reset password** | `POST /auth/reset-password` | Pakai code yang sudah diverifikasi |

**Validasi role**: hanya role yang ada di `AppConstants.allowedRoles` (`user`, `end_user`, `employee`, `client`, `customer`) yang bisa login. Selain itu → `ForbiddenFailure: "Access denied. This application is for end users only."`.

### 6.3 Home / Dashboard
- Stats card: jumlah ticket per status, per priority, per category.
- Stats dihitung **client-side** dari pull 1000 tickets pertama (`loadTicketStats`).
- "All" count **exclude** ticket dengan status `closed`.
- Recent tickets (5 ticket terbaru).
- Bar chart aktivitas mingguan via `fl_chart`.

### 6.4 Tickets
- **List** dengan pagination (limit 10, infinite scroll), filter status & priority, search bar.
- **Create**: subject (5–200 char), description (min 10 char), category dropdown, priority radio, optional attachment (max 5MB).
- **Detail**: 3 tab — Detail, Chat (WebSocket), Files (attachment list).
- **Rating**: bottom sheet 1–5 bintang + komentar opsional, hanya untuk ticket `closed` yang belum di-rate. Mapping error backend → pesan user-friendly (forbidden → "Only ticket creators can submit ratings", conflict → "This ticket has already been rated", dst.).
- **Cache offline**: ticket, kategori, status, rating tersimpan di sqflite.

### 6.5 Chat (per Ticket)
- Real-time via WebSocket `wss://.../ws/tickets/{id}?token=...`.
- Auto-reconnect maks 5× dengan delay 3 detik.
- Sebelum reconnect, refresh token via callback `onTokenRefreshNeeded`.
- Send message: `{type:'message', content?, attachment?}` (minimal salah satu wajib).
- Pause saat offline, reconnect saat online.
- Upload attachment via `POST /tickets/{id}/comments/upload` (kembali URL `/chat-uploads/...`), lalu kirim URL via WS.

### 6.6 Notifications
- **Tray notification** real-time via SSE foreground service.
- **In-app list** dengan filter All/Unread, mark-as-read individual atau all.
- **6 tipe notifikasi**: `status_change`, `assignment`, `overdue`, `warning`, `auto_close`, `new_comment`.
- Tap notif → navigate ke ticket detail (kalau ada `ticket_id` di metadata).

### 6.7 Profile
- View: avatar, nama, email, username, phone, role.
- Edit: ubah firstname/lastname/phone, upload avatar (max 2MB JPG/JPEG/PNG, dipotong lingkaran).
- Change password: validasi old/new/confirm, indicator strength + match.

### 6.8 Search
- Search global tickets (subject/description) — pakai `setSearchQueryForPaging` + `infinite_scroll_pagination`.
- Filter bottom sheet: status + priority.
- Recent searches disimpan di `SharedPreferences` (key `recent_searches`).
- Tips card untuk panduan search.

### 6.9 Knowledge Base
- **Categories**: list kategori dengan jumlah artikel (paralel fetch `total` per kategori, limit=1).
- **Articles**: list per kategori dengan pagination, sort by `updated_at DESC`.
- **Detail**: render HTML via `flutter_html`.
- **Search**: debounce 400ms.
- **Filter by tag**: bottom sheet dengan semua tag unik.
- **AI Chat** (`/knowledge/ask`): tanya AI tentang artikel, tampil bubble chat dengan loading placeholder.

### 6.10 Connectivity
- Offline banner di-overlay saat tidak ada koneksi.
- `NoInternetDialog` muncul saat user tap action yang butuh koneksi (e.g., create ticket).
- `OfflinePage` jadi fallback saat tidak ada cache sama sekali.

---

## 7. Networking Layer

### 7.1 Dio Configuration

Dua Dio instance singleton (lihat `dio_client.dart`):
- `DioClient.authInstance` → base URL = `ApiEndpoints.authBaseUrl`
- `DioClient.userInstance` → base URL = `ApiEndpoints.userBaseUrl`

Karena semua microservice via gateway tunggal (default `https://prod.damarbrawijaya.my.id`), keduanya **base URL-nya sama**. Pemisahan ini siap untuk migrasi multi-host nanti.

#### Switching Environments

Base URL di-bake saat compile via `String.fromEnvironment('API_BASE_URL', defaultValue: 'https://prod.damarbrawijaya.my.id')` di `lib/core/constants/api_config.dart`. Tidak ada file `.env` runtime — value masuk binary saat build.

```bash
# Default (prod)
flutter run
flutter build apk --release

# Staging / dev (magang)
flutter run --dart-define=API_BASE_URL=https://magang.damarbrawijaya.my.id
flutter build apk --release --dart-define=API_BASE_URL=https://magang.damarbrawijaya.my.id
```

WebSocket URL otomatis ikut (`https://` → `wss://` di `chat_websocket_service.dart`).

### 7.2 Headers Default
```
Content-Type: application/json
Accept: application/json
Authorization: Bearer <access_token>   // diinject oleh interceptor jika ada
```

### 7.3 ApiInterceptor — Lifecycle

**onRequest:**
1. Baca `accessToken` dari `FlutterSecureStorage`.
2. Inject `Authorization: Bearer <token>` jika ada.

**onError:**
- `connectionTimeout` / `sendTimeout` / `receiveTimeout` → `NetworkException("Connection timeout. Please try again.")`
- `connectionError` / `unknown` → `NetworkException("No internet connection. Please check your network.")`
- `badResponse`:
  - **401**:
    - Kalau path-nya `/auth/login`, `/auth/refresh`, `/auth/logout` → langsung `UnauthorizedException`, jangan refresh (anti-loop).
    - Selain itu → panggil `TokenRefreshService.refreshToken()`.
      - Sukses + body bukan FormData → retry request dengan token baru via Dio fresh tanpa interceptor (pakai full URI agar tidak duplikat baseUrl).
      - Sukses + body FormData → throw `SessionRefreshedException` (stream sudah consumed, tidak bisa retry).
      - Gagal → clear tokens + `UnauthorizedException("Session expired. Please login again.")`.
  - **403** → `ForbiddenException`.
  - **404** → `NotFoundException`.
  - **422** → parse `data.errors[]` jadi `Map<String,String>` → `ValidationException`.
  - **>= 500** → `ServerException`.

### 7.4 SessionRefreshedException — kasus FormData

Saat user upload file (create ticket / chat attachment) dan token kedaluwarsa di tengah jalan:
1. Request dikirim dengan token lama.
2. Server kembalikan 401.
3. Interceptor refresh token sukses.
4. **Tidak bisa retry** karena `FormData` adalah stream yang sudah dikonsumsi.
5. Throw `SessionRefreshedException` → Provider tampilkan toast "Session refreshed. Please try again." → user tap submit lagi (sekarang token sudah valid).

---

## 8. Authentication & Token Lifecycle

### 8.1 Login Flow

```
User input identifier + password
  ↓
AuthProvider.login()
  ↓
AuthRepository.login()
  ↓
AuthRemoteDatasource.login() → POST /auth/login
  ↓
Response: { data: { access_token, refresh_token, expires_in, user: {...} } }
  ↓
Validasi: user.role ∈ allowedRoles? Tidak → ForbiddenFailure.
  ↓
LocalStorage.saveTokens()         // ke SecureStorage
LocalStorage.saveUserData()       // ke SharedPreferences
TokenRefreshService.startProactiveRefresh(tokenLifetimeSeconds: expiresIn)
AuthProvider.setupSessionExpiredHandler()
  ↓
Navigate ke /home (atau /change-password kalau isFirstLogin)
```

### 8.2 TokenRefreshService — singleton

**Mutex**:
- Field `_isRefreshing: bool` + `_refreshCompleter: Completer<String?>?`.
- Jika 5 request bersamaan dapat 401, hanya 1 yang melakukan refresh; sisanya `await _refreshCompleter.future`.

**Proactive timer**:
- `startProactiveRefresh({tokenLifetimeSeconds})`:
  - Kalau token > 240s → refresh `tokenLifetime - 120s` sebelum expiry.
  - Kalau token < 4 menit → refresh di setengah lifetime.
- Auto-reschedule setelah refresh sukses.
- Kalau refresh return null → trigger `onSessionExpired` → `AuthProvider.forceLogout()`.

**Refresh request**:
- Pakai **Dio fresh tanpa interceptor** (anti-loop).
- Timeout 10 detik (lebih ketat dari main Dio).
- Body: `{"refresh_token": "..."}`.
- Response: `{ data: { access_token, expires_in } }`.

**Callback**:
- `onTokenRefreshed(String newToken)` → dipakai background SSE service via `service.invoke('updateToken', ...)`.
- `onSessionExpired()` → `AuthProvider.forceLogout()`:
  - **Skip API call** (karena server-side sudah invalid).
  - Stop proactive timer.
  - Clear secure storage + prefs.
  - Stop background SSE service.
  - Trigger `_onLogoutCallback` (clear sqflite cache).
  - Set state `unauthenticated` → router redirect ke `/login`.

### 8.3 Logout Flow

**Normal logout** (user tap tombol):
1. `POST /auth/logout` dengan `{refresh_token: "..."}` (best-effort, error di-ignore).
2. Stop proactive timer + clear `onSessionExpired`.
3. Stop `BackgroundNotificationService`.
4. `_onLogoutCallback?.call()` → bersihkan sqflite cache.
5. Clear `LocalStorage` (token + user data).
6. State → `unauthenticated`.

**Force logout** (refresh token expired): skip step 1.

---

## 9. Realtime: WebSocket Chat

File: `lib/core/network/chat_websocket_service.dart`.

### 9.1 State Machine
```
disconnected → connecting → connected
                              ↓ (error / done)
                          reconnecting (max 5×)
                              ↓ (jika gagal terus)
                            error → disconnected
```

### 9.2 URL
```
wss://prod.damarbrawijaya.my.id/ws/tickets/{ticketId}?token=<access_token>
```
(`https` → `wss`, `http` → `ws` otomatis di getter `_getWebSocketUrl`)

### 9.3 Reconnection
- Maks **5 attempts** dengan delay **3 detik** per attempt.
- Sebelum reconnect, panggil `onTokenRefreshNeeded()` callback untuk dapat token segar.
- Kalau habis semua attempt → `onError("Unable to reconnect after 5 attempts")`.

### 9.4 Pause/Resume
- `pauseConnection()` saat offline → close socket tanpa hapus `_currentTicketId` & `_token`.
- `reconnect()` saat online → reuse `_currentTicketId` + ambil token segar lewat callback.
- `disconnect()` saat keluar dari ticket → clear semua + reset state.

### 9.5 Format Message
**Outgoing (kirim):**
```json
{
  "type": "message",
  "content": "Halo",            // optional
  "attachment": "/chat-uploads/file.pdf"  // optional, minimal salah satu wajib
}
```

**Incoming (terima):**
- Dianggap valid kalau punya `id` + minimal salah satu dari `content` / `attachment`.
- Parse via `Comment.fromJson()`.

---

## 10. Realtime: SSE Notification (Foreground Service)

File: `lib/core/services/background_notification_service.dart`.

### 10.1 Kenapa Foreground Service?
- Android Doze + vendor-specific killing (Xiaomi, Oppo, Huawei) sering kill app background → notif FCM bisa tertunda atau tidak terkirim sama sekali.
- Foreground Service punya prioritas tinggi, OS jarang kill.
- Notifikasi service-nya sendiri dibuat **silent & invisible** (importance NONE) di channel `sse_bg_silent`.

### 10.2 Arsitektur
```
Main Isolate (UI)
    ↓ service.invoke('updateToken', ...)
Background Isolate
    ↓ FFI
NativeSse (libjavaloader.so → libcurl)
    ↓ HTTP long-polling SSE
Server: GET /notifications/stream
    ↓ event stream
NativeCallable.listener → Dart callback (in background isolate)
    ↓ service.invoke('newNotification', json) — IPC ke main isolate
    + flutterLocalNotificationsPlugin.show() — tampil di tray
Main Isolate
    ↓ service.on('newNotification').listen(...)
NotificationProvider.listenToBackgroundService()
    → Update unread count, refresh list
```

### 10.3 Konfigurasi
```dart
AndroidConfiguration(
  onStart: _onStart,
  autoStart: false,                            // Start manual setelah login
  autoStartOnBoot: true,                       // Restart setelah reboot
  isForegroundMode: true,
  foregroundServiceNotificationId: 888,
  initialNotificationTitle: '',                // Kosong → tidak terlihat
  initialNotificationContent: '',
  foregroundServiceTypes: [AndroidForegroundType.dataSync],
  notificationChannelId: 'sse_bg_silent',      // Importance.none
)
```

### 10.4 Token Sync Flow
```
Login sukses
  → BackgroundNotificationService.startService(accessToken, refreshToken: ...)
  → SharedPreferences.setString('sse_access_token', ...)
  → service.startService()
  → service.invoke('updateToken', {token, refreshToken})

Token di-refresh oleh main isolate
  → TokenRefreshService.onTokenRefreshed callback fires
  → service.invoke('updateToken', {token: newToken})
  → background isolate: NativeSse.updateToken(newToken)
  → koneksi SSE pakai token baru
```

### 10.5 Auto-Recovery
Jika OS restart background service tanpa main app aktif:
1. Background isolate baca `sse_access_token` dari SharedPreferences.
2. Jika ada, langsung connect SSE.
3. Jika SSE return 401, panggil `_handleUnauthorized` yang refresh token sendiri (HttpClient native, timeout 10 detik).
4. Persist token baru ke SharedPreferences.

### 10.6 Tipe Event
| Event | Dari | Aksi |
|---|---|---|
| `connected` | Server | Set foreground notif "Notification active" |
| `notification` | Server | Show tray notif + invoke `newNotification` ke main |

### 10.7 Tipe Notifikasi
Mapping `type` → judul tray:
| Type | Display Title |
|---|---|
| `status_change` | Ticket Status Updated |
| `assignment` | Ticket Assigned |
| `overdue` | Ticket Overdue! |
| `warning` | SLA Warning |
| `auto_close` | Ticket Auto-Closed |
| `new_comment` | New Comment |
| `unknown` | (fallback ke `title` dari payload) |

### 10.8 Tap Handler
- Cold start (app killed → tap notif): payload disimpan di `_pendingNotificationPayload`, lalu `MainScreen` consume setelah ready.
- Warm tap: handler langsung navigate via `navigatorKey`.

---

## 11. Storage Strategy

Tiga lapis storage dengan fungsi terpisah:

### 11.1 FlutterSecureStorage (Keystore Android / Keychain iOS)
**Hanya untuk data sensitive:**
- `access_token`
- `refresh_token`

❌ **Jangan** simpan token di `SharedPreferences`.

### 11.2 SharedPreferences (key-value plain text)
**User profile cache + app settings:**
- `user_id`, `user_email`, `user_username`, `user_name`, `user_last_name`, `user_phone_number`, `user_profile_picture`, `user_role`, `user_avatar_url`
- `user_is_first_login: bool`
- `is_first_launch: bool` (untuk skip onboarding)
- `is_dark_mode: bool` (belum diimplementasi penuh)
- `has_completed_onboarding: bool`
- `recent_searches: List<String>`
- `sse_access_token`, `sse_refresh_token` (dipakai oleh background isolate)

### 11.3 sqflite (`ticketing_cache.db`, version 3)

**Tabel:**

| Tabel | Kolom Utama | Kegunaan |
|---|---|---|
| `tickets` | id, subject, description, category_id, status_id, priority, attachment, created_by, assigned_to, creator_info (JSON), assignee_info (JSON), category_json, status_json, due_date, is_overdue, created_at, updated_at | Cache offline ticket list & detail |
| `ticket_categories` | id, name, description, is_active, created_at, updated_at | Dropdown create ticket offline |
| `ticket_statuses` | id, name, description, is_final, display_order, is_active, created_at, updated_at | Filter offline |
| `ticket_ratings` | id, ticket_id (UNIQUE), agent_id, rated_by, rating, comment, created_at | Cache rating sudah disubmit |
| `dashboard_cache` | cache_key (PK), data (JSON), cached_at | Cache stats home |
| `cache_metadata` | table_name (PK), last_synced_at | Tracking sync time |

**Indexes:**
- `idx_tickets_status`
- `idx_tickets_priority`
- `idx_tickets_created_at`
- `idx_ticket_ratings_ticket_id`

**Migration history:**
- v1 → v2: tambah tabel `ticket_ratings`.
- v2 → v3: tambah kolom `due_date` + `is_overdue` di `tickets`.

---

## 12. Offline & Caching

### 12.1 Strategi Cache-First

Setiap repository method (categories/statuses/tickets/rating):
```dart
try {
  result = await remoteDatasource.fetch();
  await localDatasource.cache(result);   // SUCCESS: simpan
  return result;
} on NetworkException {
  cached = await localDatasource.getCached();  // FALLBACK: ambil cache
  if (cached != null && cached.isNotEmpty) return cached;
  rethrow;
} catch (e) {
  if (_isNetworkError(e)) {  // unwrap DioException
    return _fallbackToCache();
  }
  throw ServerException(...);
}
```

### 12.2 `_isNetworkError(e)` — unwrap DioException

```dart
bool _isNetworkError(dynamic e) {
  if (e is NetworkException) return true;
  if (e is DioException) {
    return e.error is NetworkException ||
           e.type == DioExceptionType.connectionError ||
           e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.unknown;
  }
  return false;
}
```

### 12.3 Cache Filter Logic (sqflite)

Saat load tickets dengan filter status, jika `statusId` tidak match (misalnya backend ID berubah), fallback retry dengan **name-based matching** pada kolom `status_json`:
```sql
status_json LIKE '%"name":"In Progress"%' OR status_json LIKE '%"name":"in_progress"%'
```

### 12.4 Ticket Detail Offline
- Kalau offline + cache ada → tampilkan ticket dengan `comments: []` (graceful degradation).
- Comments tidak di-cache (karena ms-chat punya volume tinggi & realtime via WS).

### 12.5 Logout Cache Cleanup
`AuthProvider.setOnLogoutCallback` dipanggil dengan `TicketLocalDatasource.clearAllCache()` yang truncate semua tabel sqflite.

### 12.6 ConnectivityWrapper
Widget root yang tampilkan:
- **OfflineBanner** (top) saat offline.
- **NoInternetDialog** saat user tap action butuh koneksi.
- **OfflinePage** sebagai fallback page.

---

## 13. Error Handling

### 13.1 Typed Exceptions (`core/errors/exceptions.dart`)

| Class | Code | Trigger |
|---|---|---|
| `NetworkException` | `NETWORK_ERROR` | Timeout, no internet, connectionError |
| `ServerException` | `SERVER_ERROR` | 5xx |
| `UnauthorizedException` | `UNAUTHORIZED` | 401 setelah refresh gagal |
| `ForbiddenException` | `FORBIDDEN` | 403 |
| `NotFoundException` | `NOT_FOUND` | 404 |
| `ValidationException` | `VALIDATION_ERROR` | 422 (parse `data.errors[]` ke `Map<String, String>`) |
| `CacheException` | `CACHE_ERROR` | sqflite error |
| `SessionRefreshedException` | `SESSION_REFRESHED` | 401 + body FormData (tidak bisa retry) |

### 13.2 Typed Failures (`core/errors/failures.dart`)
Counterpart untuk `Result<T>` di repository auth (success/failure pattern). Setiap exception punya pasangan failure-nya (kecuali `SessionRefreshedException`).

### 13.3 Pattern Catching di Provider
```dart
try {
  data = await repository.someAction();
  state = TicketState.loaded;
} on NetworkException catch (e) {
  errorMessage = e.message;
  state = TicketState.error;
} on ServerException catch (e) {
  errorMessage = e.message;
  state = TicketState.error;
} on ValidationException catch (e) {
  errorMessage = e.message;
  state = TicketState.error;
} on SessionRefreshedException catch (e) {
  errorMessage = e.message;  // "Session refreshed. Please try again."
  state = TicketState.error;
} catch (e) {
  errorMessage = 'Failed to ...';
  state = TicketState.error;
}
notifyListeners();
```

### 13.4 Backend Error Code Mapping (Rating)
```dart
case 'bad_request': return 'This ticket has no assigned agent';
case 'forbidden':   return 'Only ticket creators can submit ratings';
case 'conflict':    return 'This ticket has already been rated';
case 'not_found':   return 'Ticket not found';
```

---

## 14. Timeout Configuration

| Komponen | Connect Timeout | Receive Timeout | Lokasi |
|---|---|---|---|
| Dio (main) | 30 detik | 30 detik | `AppConstants.connectionTimeoutMs` / `receiveTimeoutMs` |
| `ApiConfig.connectTimeout` | 30 detik | 30 detik | `api_config.dart` |
| TokenRefreshService Dio | 10 detik | 10 detik | `token_refresh_service.dart` |
| Background SSE refresh HttpClient | 10 detik | (default) | `background_notification_service.dart` |
| WebSocket reconnect | — | — | Delay 3 detik × 5 attempts |
| SSE reconnect (native) | — | — | Exponential backoff 2–60s, maks 50 attempts |
| Search debounce (Knowledge) | — | — | 400ms |

**Kenapa refresh token timeout lebih ketat?** Karena kalau refresh menggantung lama, semua request lain ikut menggantung (mereka `await` Completer yang sama). Mending fail cepat dan force logout.

---

## 15. Validation Rules

File: `lib/core/utils/validators.dart` + `app_constants.dart`.

### 15.1 Email
Regex: `^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+`

### 15.2 Email or Username
- Email regex (di atas), atau
- Username regex: `^[a-zA-Z0-9_]{3,20}$`

### 15.3 Password
- Min 8 karakter (`AppConstants.minPasswordLength`).
- Min 1 huruf besar.
- Min 1 huruf kecil.
- Min 1 angka.
- (Tidak wajib special character.)

### 15.4 Profile First Name
- Required, no whitespace-only.
- Max 100 char (`AppConstants.maxNameLength`).

### 15.5 Profile Last Name
- Optional. Kalau diisi → no whitespace-only.
- Max 100 char.

### 15.6 Phone Number (Indonesian umum)
Regex: `^(\+62|62|0)[0-9]{9,12}$`

### 15.7 Profile Phone Number (lebih longgar)
- Optional.
- Hanya digit (boleh `+` di awal).
- Max 20 char (`AppConstants.maxPhoneNumberLength`).

### 15.8 Ticket Subject
- Required, trim non-empty.
- Min 5 char, max 200 char.

### 15.9 Ticket Description
- Required, trim non-empty.
- Min 10 char.

### 15.10 Confirm Password
- Required + harus sama dengan password baru.

---

## 16. File Upload Constraints

| Tipe Upload | Max Size | Format Allowed | Endpoint |
|---|---|---|---|
| Profile picture | 2 MB | JPG, JPEG, PNG | `POST /users/me/profile-picture` |
| Ticket attachment | 5 MB | jpg, jpeg, png, gif, pdf, doc, docx, txt, zip | `POST /upload` |
| Chat attachment | 5 MB | (sama seperti ticket) | `POST /tickets/{id}/comments/upload` |

Konstanta:
```dart
AppConstants.maxProfilePictureSizeMB = 2
AppConstants.maxAttachmentSizeMB = 5
AppConstants.maxChatAttachmentSizeMB = 5
```

Validasi dilakukan **client-side dulu** (`Validators.fileSize`) sebelum kirim ke server, supaya hemat bandwidth + UX cepat.

---

## 17. Routing

Library: `go_router ^13.0.0`. Semua route di `lib/routes/app_routes.dart`.

### 17.1 Daftar Route

| Path | Name | Builder Args |
|---|---|---|
| `/` | splash | — |
| `/onboarding` | onboarding | — |
| `/login` | login | — |
| `/forgot-password` | forgotPassword | — |
| `/verification-code` | verificationCode | `extra: String email` |
| `/reset-password` | resetPassword | `extra: String token` |
| `/reset-password-success` | resetPasswordSuccess | — |
| `/change-password` | changePassword | `extra: bool isFirstLogin` |
| `/change-password-success` | changePasswordSuccess | — |
| `/home` | home | `extra: Map<String, dynamic>? {showWelcomeToast}` |
| `/search` | search | `extra: String? initialQuery` |
| `/tickets/create` | createTicket | — |
| `/tickets/detail` | ticketDetail | `extra: Ticket ticket` |
| `/profile/edit` | editProfile | — |
| `/knowledge` | knowledge | — |
| `/knowledge/article` | knowledgeArticleDetail | `extra: int articleId` (re-provide `KnowledgeProvider`) |
| `/knowledge/ai-chat` | aiChat | (re-provide `KnowledgeProvider`) |
| `/notifications` | notifications | — |

### 17.2 navigatorKey Global
```dart
static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```
Dipakai oleh service (background notif, token refresh) untuk akses `Navigator` tanpa `BuildContext`.

### 17.3 Re-provide Pattern
Route `/knowledge/article` dan `/knowledge/ai-chat` melakukan `ChangeNotifierProvider.value(value: context.read<KnowledgeProvider>(), ...)` agar state di layar pemanggil (search query, filter tag) tidak hilang saat masuk ke detail.

---

## 18. State Management Pattern

Semua provider extend `ChangeNotifier` dengan **state enum + error message + loading flag** pattern.

### 18.1 Contoh AuthProvider
```dart
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthState get state => _state;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  // ...
}
```

### 18.2 Contoh TicketProvider (multi-state per operation)
Punya state terpisah untuk berbagai operation:
- `_categoriesState`, `_statusesState`, `_ticketsState`
- `_ticketDetailState`, `_createTicketState`, `_createCommentState`
- `_recentTicketsState`, `_statsState`
- Plus rating: `_isRatingLoading`, `_isSubmittingRating`, `_hasRated`, `_isRatingChecked`

Tujuan: layar bisa menunjukkan loading per section (mis. saat refresh recent tickets, list ticket utama tetap visible).

### 18.3 Cross-Provider Communication
- `AuthProvider.setOnLogoutCallback(VoidCallback)` → `TicketProvider/Repository` register callback untuk clear cache.
- `ProfileProvider.onUserUpdated` → callback ke `AuthProvider.updateCurrentUser` setelah edit profile.
- `TokenRefreshService.onSessionExpired` → `AuthProvider.forceLogout`.
- `BackgroundNotificationService.on('newNotification')` → `NotificationProvider.listenToBackgroundService`.

### 18.4 Pagination Pattern (infinite_scroll_pagination)
```dart
// Provider menyediakan method tanpa side-effect
Future<TicketListResponse> fetchTicketsPage({required int page, required int limit});
void setFilterStatusForPaging(int? statusId);  // tidak panggil notifyListeners
void setSearchQueryForPaging(String? query);
```
Screen pakai `PagingController.addPageRequestListener((pageKey) async { ... })` yang panggil method ini.

---

## 19. Security

### 19.1 APK Signature Verification (Native FFI)
File: `lib/core/security/signature_checker.dart` + `libjavaloader.so` (C++).

**Tujuan:** mencegah APK di-tampered atau di-resign dengan keystore lain (anti-piracy / anti-modding).

**Cara kerja:**
1. C++ baca APK pakai **raw syscalls** (bukan libc) → bypass hook Frida/Xposed.
2. Extract certificate dari `META-INF/`.
3. Hitung SHA-256 hash.
4. Bandingkan dengan expected hash dari `Enigma.p12` (di-obfuscate di binary).
5. Return `1` (valid) atau `0` (invalid).

**Konsekuensi:**
- Kalau invalid → `runApp(const SecurityErrorScreen())`, app berhenti di sini.
- Hanya aktif di Android (`Platform.isAndroid`).

### 19.2 Token Storage
- Access + refresh token → `FlutterSecureStorage` (Keystore Android, AES256-GCM).
- **Tidak pernah** disimpan di SharedPreferences atau dilog ke console.

### 19.3 HTTPS-Only
- `ApiConfig.baseUrl` = `https://...`
- WebSocket → `wss://...` (auto-converted dari `https://`).

### 19.4 Network Security Config Android
File: `android/app/src/main/res/xml/network_security_config.xml` (kalau ada) — pin certificate.

CA bundle native: `assets/certs/` di-extract via `CaBundle.ensureExtracted()` untuk libcurl di background isolate.

### 19.5 Role-Based Login Restriction
Hanya role di `AppConstants.allowedRoles` yang boleh login:
```dart
{'user', 'end_user', 'employee', 'client', 'customer'}
```
Admin/agent/supervisor → ditolak dengan `ForbiddenFailure`.

### 19.6 Token Refresh Race Condition Prevention
Mutex via `_isRefreshing` + `Completer` di `TokenRefreshService` (lihat Section 8.2).

### 19.7 FormData Retry Protection
Kalau token expired di tengah upload file, tidak retry diam-diam (stream sudah consumed). Throw `SessionRefreshedException` agar user re-submit eksplisit (mencegah double-upload).

---

## 20. Android Permissions

File: `android/app/src/main/AndroidManifest.xml`.

| Permission | Kegunaan |
|---|---|
| `INTERNET` | API calls |
| `ACCESS_NETWORK_STATE` | `connectivity_plus` cek WiFi/cellular |
| `READ_EXTERNAL_STORAGE` | Pilih file (Android < 13) |
| `WRITE_EXTERNAL_STORAGE` | Save file (Android < 11) |
| `MANAGE_EXTERNAL_STORAGE` | Akses file luas (Android 11+) |
| `READ_MEDIA_IMAGES` | Galeri (Android 13+) |
| `READ_MEDIA_VIDEO` | Galeri video (Android 13+) |
| `POST_NOTIFICATIONS` | Tampilkan notif (Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Restart background service setelah reboot |
| `VIBRATE` | Notif bergetar |
| `FOREGROUND_SERVICE` | Foreground service untuk SSE |
| `FOREGROUND_SERVICE_DATA_SYNC` | Tipe foreground service "dataSync" (Android 14+) |
| `WAKE_LOCK` | Jaga CPU saat SSE aktif |

**Service declaration:**
```xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="dataSync"
    android:stopWithTask="false"
    android:exported="false"
    tools:replace="android:exported,android:stopWithTask" />
```

`stopWithTask="false"` → service tetap jalan meskipun user swipe app dari recent.

---

## 21. API Endpoints Reference

Semua endpoint via gateway. Default base URL = `https://prod.damarbrawijaya.my.id` (lihat [Section 7.1](#71-dio-configuration) untuk override staging).

### 21.1 ms-auth
| Method | Path | Kegunaan |
|---|---|---|
| POST | `/auth/login` | Login (identifier + password) |
| POST | `/auth/refresh` | Refresh access token |
| POST | `/auth/logout` | Blacklist tokens |
| POST | `/auth/forgot-password` | Kirim 4-digit code ke email |
| POST | `/auth/verify-reset-token` | Verifikasi 4-digit code |
| POST | `/auth/reset-password` | Reset password dengan code |

### 21.2 ms-user-management
| Method | Path | Kegunaan |
|---|---|---|
| GET | `/users/me` | Profile user current |
| GET | `/users/me/permissions` | List permission |
| PUT | `/users/me/change-password` | Ubah password |
| POST | `/users/me/profile-picture` | Upload avatar |
| GET | `/profile-pictures/{filename}` | Download avatar |

### 21.3 ms-ticket
| Method | Path | Kegunaan |
|---|---|---|
| GET | `/ticket-categories/active` | Dropdown kategori |
| GET | `/ticket-statuses/active` | Filter status |
| GET | `/tickets` | List ticket (paginated) |
| POST | `/tickets` | Create ticket |
| GET | `/tickets/{id}` | Detail ticket |
| POST | `/upload` | Upload attachment ticket |
| GET | `/uploads/{filename}` | Download attachment |
| GET | `/dashboard/stats` | Stats dashboard |
| POST | `/tickets/{id}/rating` | Submit rating |
| GET | `/tickets/{id}/rating` | Get rating |

### 21.4 ms-chat
| Method | Path | Kegunaan |
|---|---|---|
| GET | `/tickets/{id}/comments` | List comments |
| POST | `/tickets/{id}/comments` | Create comment |
| POST | `/tickets/{id}/comments/upload` | Upload chat attachment |
| GET | `/chat-uploads/{filename}` | Download chat attachment |
| WS | `/ws/tickets/{id}?token=...` | WebSocket chat |

### 21.5 ms-notification
| Method | Path | Kegunaan |
|---|---|---|
| GET | `/notifications/stream` | SSE stream notifikasi |
| GET | `/notifications` | List notifikasi (paginated) |
| GET | `/notifications/unread-count` | Jumlah unread |
| PATCH | `/notifications/{id}/read` | Mark as read |
| PATCH | `/notifications/read-all` | Mark all as read |

### 21.6 ms-knowledge
| Method | Path | Kegunaan |
|---|---|---|
| GET | `/knowledge-categories` | List kategori KB |
| GET | `/knowledge` | List artikel (paginated, search, filter tag) |
| GET | `/knowledge/{id}` | Detail artikel |
| POST | `/knowledge/ask` | AI Assistant Q&A |

### 21.7 Format Response Umum
```json
// Success
{
  "data": { ... } | [ ... ],
  "pagination": { "page": 1, "limit": 10, "total": 50, "has_next": true, "has_prev": false },
  "message": "..."  // optional
}

// Error
{
  "message": "Human-readable error",
  "data": {
    "errors": [
      { "field": "email", "message": "Email is required" }
    ]
  }
}
```

---

## 22. Coding Conventions

### 22.1 File & Class Naming
- File: `snake_case.dart`
- Class: `PascalCase`
- Function/var: `camelCase`
- Private: prefix `_`

### 22.2 Dart Style
- Pakai `const` constructor sebanyak mungkin.
- Trailing comma di list parameter.
- Max 80 columns (per `analysis_options.yaml`).
- Pakai `final` untuk immutable.

### 22.3 Imports Order
1. `dart:` imports
2. Package imports (`package:flutter/...`, `package:dio/...`)
3. Relative imports (`../../core/...`)

### 22.4 Don'ts
- ❌ Hardcode URL → pakai `ApiConfig`/`ApiEndpoints`.
- ❌ Hardcode string user-facing tanpa alasan → siapkan untuk i18n nanti.
- ❌ Simpan token di `SharedPreferences`.
- ❌ Commit `.env` atau file dengan secret.
- ❌ Catch generic `Exception` tanpa typed exception spesifik (kecuali di `catch (e)` paling akhir sebagai fallback).
- ❌ Skip validasi input.
- ❌ Skip handle loading & error state.

### 22.5 Do's
- ✅ Validasi input client-side dulu (UX cepat) + server-side wajib.
- ✅ Tampilkan loading indicator untuk semua async operation.
- ✅ Tampilkan error message yang actionable.
- ✅ Pakai `debugPrint` (bukan `print`) — auto-stripped di release build.
- ✅ Cache success → fallback to cache on network error.
- ✅ Pakai `context.mounted` setelah `await` sebelum akses `BuildContext`.

---

## 23. Known Issues / Edge Cases

### 23.1 Edge Cases yang Sudah Ditangani
| Kasus | Solusi |
|---|---|
| 5 request bersamaan dapat 401 | Mutex Completer → 1× refresh, retry semua |
| FormData upload + token expired | `SessionRefreshedException` → user retry |
| Token expired pas WS chat aktif | Reconnect dengan token segar via callback |
| Background isolate token kedaluwarsa | Auto-refresh native HttpClient |
| OS kill background SSE service | `autoStartOnBoot: true` + persist token di prefs |
| User offline buka ticket detail | Show cached ticket + comments kosong |
| Backend ID status berubah | Fallback name-based matching di sqflite query |
| Cold-launch dari tap notif | `_pendingNotificationPayload` consumed by MainScreen |
| Race condition saat refresh+request bareng | `_refreshCompleter.future` dipakai semua caller |

### 23.2 Edge Cases yang Belum / Bisa Improve
- Knowledge article detail tidak di-cache offline (perlu konfirmasi product).
- Comments di ticket detail tidak di-cache offline (sengaja, karena volume tinggi).
- FCM Firebase di-init tapi belum jadi notif utama (SSE foreground service jadi primary).
- Belum ada retry button eksplisit di banyak error state (bisa ditambah).
- Belum ada skeleton loading di semua list (hanya beberapa).
- `is_dark_mode` di prefs tapi UI belum support dark mode penuh.
- Knowledge AI chat tidak punya history persistence (hilang saat keluar layar).

### 23.3 Hal yang Perlu Disiapkan untuk UAT
- Akun staging dengan kondisi:
  - User baru (`isFirstLogin: true`).
  - User existing dengan banyak ticket.
  - User dengan notifikasi unread > 0.
- Test flow:
  - Login → idle 5 menit → action (cek proactive refresh).
  - Chat sambil airplane mode toggle (cek pause/reconnect).
  - Minimize app → trigger notif dari sisi admin (cek tray muncul).
  - Offline buka list ticket (cek banner + cache).
  - Upload file > 5MB (cek validasi client-side).
  - Login dengan akun role admin (cek ForbiddenFailure).
  - Test rating ticket yang sudah closed.

---

## Lampiran: Quick Command Reference

```bash
# Install dependency
flutter pub get

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Build debug APK
flutter build apk --debug

# Build release APK (signing pakai Enigma.p12)
flutter build apk --release

# Build release AAB (untuk Play Store)
flutter build appbundle --release

# Run on connected device
flutter run

# Run dengan flavor (kalau ada)
flutter run --release

# Lint check
flutter analyze

# Test
flutter test
```

---

**Dokumen disusun berdasarkan kode terbaru di branch aktif. Update saat ada perubahan signifikan pada:**
- API contract
- Tech stack (tambah/hapus dependency)
- Storage schema (sqflite version up)
- Authentication flow
- Error handling strategy
