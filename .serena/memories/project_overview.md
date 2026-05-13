# Mobile Ticketing App — Overview

## Project Identity
- **Nama:** `ticketing_app` (pubspec), aplikasi mobile **Enterprise Ticketing System** sisi end-user (pelapor).
- **Peran Developer:** Deny (Mobile Developer).
- **Backend:** Golang + Gin, dikonsumsi via HTTPS gateway `https://magang.damarbrawijaya.my.id`.
- **Target Platform:** Android (primary) + iOS (secondary). Ada folder windows/linux/macos/web tapi fokus mobile.
- **Dokumen referensi:** `CLAUDE.md`, `docs/MASTERPLAN.md`, `docs/ENDPOINTS_SPRINT_*.md`, `docs/GIT_WORKFLOW.md`.

## Tech Stack
- **Framework:** Flutter (Dart `^3.9.2`), version `0.10.0`.
- **State Management:** `provider ^6.1.1` (MultiProvider di `app.dart`).
- **Routing:** `go_router ^13.0.0` (di `lib/routes/app_routes.dart`, central `navigatorKey`).
- **HTTP:** `dio ^5.4.0` + `pretty_dio_logger`.
- **WebSocket:** `web_socket_channel` (chat real-time per ticket).
- **Realtime Notifications:** SSE via `dart:io HttpClient` + `flutter_background_service` (foreground service) + `flutter_local_notifications`.
- **Storage:** `flutter_secure_storage` (token), `shared_preferences` (settings, SSE cache), `sqflite` (ticket cache offline).
- **UI:** `google_fonts` (Inter/Roboto/Outfit), `toastification`, `flutter_svg`, `fl_chart`, `shimmer`, `infinite_scroll_pagination`, `cached_network_image`.
- **Utilities:** `image_picker`, `image_cropper`, `file_picker`, `path_provider`, `share_plus`, `permission_handler`, `connectivity_plus`, `app_settings`, `url_launcher`, `gal`, `package_info_plus`.
- **Firebase:** `firebase_core` (FCM disiapkan tapi realtime notif utama via SSE + background service).

## Entry Point
- `lib/main.dart`: init Firebase, set SystemUiOverlayStyle, init `ConnectivityService`, `LocalNotificationService`, `BackgroundNotificationService`, `AppInfo`, `SharedPreferences`, `FlutterSecureStorage`, lalu `runApp(MyApp)`.
- `lib/app.dart`: `MultiProvider` merangkai semua DI (LocalStorage → repositories → providers), dibungkus `ToastificationWrapper` + `MaterialApp.router` + `ConnectivityWrapper`.

## Folder Structure (feature-based)
```
lib/
├── main.dart
├── app.dart
├── firebase_options.dart
├── core/
│   ├── constants/  (api_config, api_endpoints, app_constants, asset_paths, storage_keys)
│   ├── errors/     (exceptions, failures — typed: Network/Server/Unauthorized/Forbidden/NotFound/Validation/SessionRefreshed)
│   ├── network/    (dio_client, api_interceptor, chat_websocket_service, connectivity_service)
│   ├── services/   (background_notification_service, local_notification_service, token_refresh_service)
│   ├── themes/     (app_theme, app_colors, text_styles)
│   └── utils/      (app_info, image_picker_helper, toast_helper, validators)
├── data/
│   ├── datasources/local/  (database_helper [sqflite], local_storage [secure+prefs])
│   └── models/api_response.dart (generic ApiResponse<T>)
├── providers/ (auth, ticket, profile, notification, connectivity — shared top-level ChangeNotifiers)
├── features/
│   ├── auth/        (login, change-password, forgot-password 4-digit code flow, reset-password, verification-code)
│   ├── splash/
│   ├── onboarding/
│   ├── home/        (dashboard stats, recent tickets, charts)
│   ├── tickets/     (list, detail dengan tabs [Detail/Chat/Files], create, chat WS, rating bottom sheet)
│   ├── knowledge/   (KB categories, articles, article detail, search — punya provider sendiri)
│   ├── notifications/
│   ├── profile/
│   ├── search/
│   └── main/        (MainScreen wrapper with bottom nav)
├── shared/widgets/  (custom_button, custom_text_field, form_card, gradient_header, loading_*, connectivity_wrapper, offline_page, no_internet_dialog, offline_banner, section_label)
└── routes/app_routes.dart
```

## Architecture Pattern
Lapisan klasik Clean-ish Architecture per feature:
```
Screen/Widget → Provider (ChangeNotifier) → Repository (interface+impl) → Datasource (remote+mock+local)
```
- **Repository** mengembalikan `Result<T>` (success/failure) atau throw typed exceptions (Network/Server/Validation/Unauthorized).
- **Provider** punya state enum (`AuthState`, `TicketState`, `ProfileState`, dll) + error message + loading flags.
- **Mock datasource** dipakai bila `ApiConfig.useMockData = true` (saat ini `false` — production gateway).
- **Local datasource** (sqflite) dipakai sebagai cache offline untuk tickets, categories, statuses, rating. Strategi: fetch API → cache on success → fallback to cache saat NetworkException.

## Backend Services (via gateway)
- **ms-auth (port 8080):** `/auth/login`, `/auth/refresh`, `/auth/logout`.
- **ms-user-management (port 8081):** `/users/me`, `/users/me/permissions`, `/users/me/change-password`, `/users/me/profile-picture`, `/profile-pictures/{file}`.
- **ms-ticket:** `/tickets`, `/tickets/{id}`, `/ticket-categories/active`, `/ticket-statuses/active`, `/upload`, `/uploads/{file}`, `/tickets/{id}/rating`, `/dashboard/stats`.
- **ms-chat:** `/tickets/{id}/comments`, `/tickets/{id}/comments/upload`, `/chat-uploads/{file}`, `wss://.../ws/tickets/{id}?token=...`.
- **ms-notification:** `GET /notifications/stream` (SSE), `/notifications`, `/notifications/unread-count`, `/notifications/{id}/read`, `/notifications/read-all`.
- **ms-knowledge:** `/knowledge-categories`, `/knowledge`, `/knowledge/{id}`.

## Authentication & Token Lifecycle
- **Login:** `AuthRepository.login(identifier, password)` — menerima email **atau** username.
  - Validasi role: hanya `allowedRole` (lihat `AppConstants`) diizinkan. Bila bukan → `ForbiddenFailure` (aplikasi khusus user, bukan admin/agent).
  - Simpan `access_token` + `refresh_token` ke `FlutterSecureStorage`.
  - Simpan user data (id, email, username, name, lastName, phoneNumber, profilePicture, role, isFirstLogin) ke `SharedPreferences` via `LocalStorage`.
  - Start `TokenRefreshService.startProactiveRefresh(tokenLifetimeSeconds: expiresIn)`.
- **`TokenRefreshService` (singleton):**
  - `refreshToken()` thread-safe (pakai `_isRefreshing` bool + `Completer<String?>`), hit `/auth/refresh` via **Dio tanpa interceptor** (hindari loop).
  - **Proactive timer:** refresh 120 detik **sebelum** expiry (atau half-life bila token < 4 min). Menjaga WS + SSE + Create Ticket tetap valid.
  - `onTokenRefreshed`: callback untuk SSE background service.
  - `onSessionExpired`: callback (dipakai `AuthProvider.forceLogout`) bila refresh token juga invalid → auto-redirect ke login.
- **`ApiInterceptor`:** pada 401:
  - Skip refresh untuk `/auth/login`, `/auth/refresh`, `/auth/logout`.
  - Panggil `TokenRefreshService.refreshToken()`, lalu retry request menggunakan Dio **baru tanpa interceptor** via `request.uri.toString()` (hindari duplikasi baseUrl + path).
  - **Kasus khusus FormData:** stream sudah consumed, tidak bisa retry → throw `SessionRefreshedException` supaya UI tampil pesan "Session refreshed. Please try again.".
- **Logout:** panggil `/auth/logout` (best-effort), stop proactive timer + background service, clear secure storage + prefs.
- **forceLogout:** dipakai saat refresh token expired — skip API call karena server-side sudah invalid.

## Realtime Features
1. **WebSocket Chat (`ChatWebSocketService`)** — per-ticket, `wss://.../ws/tickets/{id}?token=...`.
   - State enum: `disconnected, connecting, connected, reconnecting, error`.
   - Auto-reconnect hingga 5× dengan delay 3 detik, ambil fresh token via `onTokenRefreshNeeded` callback.
   - `pauseConnection()` saat offline, `reconnect()` saat online.
   - Kirim message `{type:'message', content, attachment}`.
2. **SSE Notifications (`BackgroundNotificationService`)** — **FOREGROUND SERVICE** Android agar tetap jalan saat app minimized.
   - Isolate terpisah via `@pragma('vm:entry-point')`, pakai `HttpClient` + `LineSplitter`.
   - Auto-reconnect dengan exponential backoff (maks 50 attempts, 2-60 detik).
   - Bila 401 → coba refresh token via `/auth/refresh` (last resort, main app seharusnya sudah push token baru via `invoke('updateToken')`).
   - Terima event `connected` dan `notification` (type: `status_change`, `assignment`, `overdue`, `warning`, `auto_close`, `new_comment`).
   - `service.invoke('newNotification', json)` ke main isolate → `NotificationProvider.listenToBackgroundService()` menerima via `service.on('newNotification')`.
   - Main app push token baru via `service.invoke('updateToken', {...})` tiap token di-refresh.

## Offline & Caching Strategy
- `ConnectivityService` (singleton) + `ConnectivityWrapper` + `offline_banner`/`no_internet_dialog`/`offline_page`.
- Tickets/categories/statuses/rating: cache-first fallback (fetch → cache on success → cache fallback on NetworkException).
- Ticket detail: bila offline, load ticket dari cache + comments kosong (graceful degradation).
- `_isNetworkError(e)` helper di `TicketRepository` unwrap `DioException` → cek `error is NetworkException` atau tipe koneksi.

## Error Handling
- Typed **Exceptions** (`core/errors/exceptions.dart`): `NetworkException`, `ServerException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ValidationException` (dengan field errors), `SessionRefreshedException`.
- Typed **Failures** (`core/errors/failures.dart`): counterpart Result-oriented.
- `ApiInterceptor` parse response body, mapping 401/403/404/422/5xx → exception yang sesuai. 422 parse `data.errors[]` jadi `Map<String,String>`.

## Routing (GoRouter)
Routes: `/`, `/onboarding`, `/login`, `/forgot-password`, `/verification-code`, `/reset-password`, `/reset-password-success`, `/change-password`, `/change-password-success`, `/home`, `/search`, `/tickets/create`, `/tickets/detail` (ticket via `state.extra`), `/profile/edit`, `/knowledge`, `/knowledge/article`, `/notifications`.
- `navigatorKey` GlobalKey untuk akses global dari services.
- Route `knowledgeArticleDetail` re-provide `KnowledgeProvider` via `.value` untuk preserve state dari layar pemanggil.

## Key Conventions
- **Naming:** snake_case file, PascalCase class, camelCase fn/var.
- **Style:** `const` constructors, trailing commas, max 80 cols.
- **Jangan hardcode URL** → pakai `ApiConfig`/`ApiEndpoints`.
- **Jangan commit `.env`**, tidak boleh simpan token di `SharedPreferences` (token selalu di secure storage).
- **SELALU** validasi input, handle loading & error state.

## Current Sprint
- **Sprint 1:** Setup project, Dio+Interceptors, Splash, Login, Secure token storage.
- **Sprint 2:** Integrasi API Login (done), Profile page, Register.

## Notable Implementation Details
- `ApiConfig.useMockData` currently `false`. Mock datasources (`AuthMockDatasource`, `TicketMockDatasource`) tetap tersedia untuk testing.
- `ProfileProvider.onUserUpdated` callback → sync user ke `AuthProvider.updateCurrentUser` setelah edit profile/upload avatar.
- `AuthProvider.setOnLogoutCallback` dipakai untuk clear local cache (sqflite) on logout.
- `home_screen.dart` tampil dashboard stats (status/priority/category counts) yang dihitung di client dari list tickets (`loadTicketStats` pull 1000 tickets).
- `'closed'` tickets di-exclude dari "All" view (client-side filter di getter `tickets`).
- `infinite_scroll_pagination` dipakai di tickets screen + search via `fetchTicketsPage(page, limit)` + `setFilterStatusForPaging` (tanpa `notifyListeners`).
- `KnowledgeProvider._loadArticleCountsForCategories` parallel fetch count per kategori (limit=1, baca `total`).
