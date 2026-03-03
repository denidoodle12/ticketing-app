# CLAUDE.md - Enterprise Ticketing System (Mobile App)

## Project Overview

Ini adalah aplikasi mobile **Enterprise Ticketing System** untuk end-user (pelapor) yang dibangun menggunakan **Flutter**. Aplikasi ini memungkinkan user untuk membuat laporan/tiket, melacak status, dan berkomunikasi dengan agent.

### Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** (Provider)
- **HTTP Client:** Dio
- **Local Storage:** flutter_secure_storage (untuk token), shared_preferences
- **Push Notification:** Firebase Cloud Messaging (FCM)
- **Image Picker:** image_picker

### Target Platform
- Android (Primary)
- iOS (Secondary)

---

## Project Context

### Peran Saya
Saya adalah **Deny** - Mobile Developer yang bertanggung jawab penuh untuk aplikasi Flutter end-user.

### Backend Team
- API dikembangkan dengan **Golang + Gin**
- Base URL: `[AKAN_DIISI]`
- Authentication: JWT (access_token + refresh_token)

---

## Dokumen Referensi

Sebelum mengerjakan fitur, SELALU baca dokumen berikut:
- `docs/MASTERPLAN.md` - Gambaran besar project dan sprint timeline
- `docs/ERD.md` - Struktur database dan relasi (jika ada)
- `docs/ENDPOINTS_SPRINT_1.md` - API endpoints Sprint 1
- `docs/ENDPOINTS_SPRINT_2.md` - API endpoints Sprint 2
- `docs/GIT_WORKFLOW.md` - Aturan commit, push, dan merge

---

## Folder Structure

```
lib/
├── main.dart
├── app.dart                    # MaterialApp configuration
│
├── core/                       # Core/Shared utilities
│   ├── constants/              # App constants, API endpoints
│   │   ├── app_constants.dart
│   │   ├── api_endpoints.dart
│   │   └── storage_keys.dart
│   ├── errors/                 # Error handling
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/                # Dio setup
│   │   ├── dio_client.dart
│   │   ├── api_interceptor.dart
│   │   └── network_info.dart
│   ├── utils/                  # Helper functions
│   │   ├── date_formatter.dart
│   │   ├── validators.dart
│   │   └── helpers.dart
│   └── themes/                 # App theming
│       ├── app_theme.dart
│       ├── app_colors.dart
│       └── text_styles.dart
│
├── data/                       # Data Layer
│   ├── models/                 # Data models (from API)
│   │   ├── user_model.dart
│   │   ├── ticket_model.dart
│   │   ├── comment_model.dart
│   │   └── category_model.dart
│   ├── repositories/           # Repository implementations
│   │   ├── auth_repository.dart
│   │   ├── ticket_repository.dart
│   │   └── user_repository.dart
│   └── datasources/            # API calls
│       ├── remote/
│       │   ├── auth_remote_datasource.dart
│       │   └── ticket_remote_datasource.dart
│       └── local/
│           └── local_storage.dart
│
├── providers/                  # State Management (Provider)
│   ├── auth_provider.dart
│   ├── ticket_provider.dart
│   ├── user_provider.dart
│   └── theme_provider.dart
│
├── features/                   # Feature-based modules
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   └── widgets/
│   │       └── auth_form.dart
│   │
│   ├── splash/
│   │   └── screens/
│   │       └── splash_screen.dart
│   │
│   ├── home/
│   │   ├── screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │
│   ├── tickets/
│   │   ├── screens/
│   │   │   ├── ticket_list_screen.dart
│   │   │   ├── ticket_detail_screen.dart
│   │   │   └── create_ticket_screen.dart
│   │   └── widgets/
│   │       ├── ticket_card.dart
│   │       ├── ticket_status_badge.dart
│   │       └── chat_bubble.dart
│   │
│   ├── profile/
│   │   ├── screens/
│   │   │   ├── profile_screen.dart
│   │   │   └── edit_profile_screen.dart
│   │   └── widgets/
│   │
│   └── notifications/
│       └── screens/
│           └── notification_screen.dart
│
├── shared/                     # Shared/Reusable widgets
│   └── widgets/
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── loading_widget.dart
│       ├── error_widget.dart
│       └── empty_state_widget.dart
│
└── routes/                     # Navigation
    └── app_routes.dart
```

---

## Coding Conventions

### Naming
- **Files:** snake_case (`ticket_detail_page.dart`)
- **Classes:** PascalCase (`TicketDetailPage`)
- **Variables/Functions:** camelCase (`getUserTickets()`)
- **Constants:** SCREAMING_SNAKE_CASE atau camelCase dengan `const`

### Code Style
- Gunakan `const` constructor jika memungkinkan
- Prefer `final` untuk variabel yang tidak di-reassign
- Maksimal 80 karakter per baris
- Selalu tambahkan trailing comma untuk better formatting

### Comments
- Tambahkan dokumentasi untuk public API
- Gunakan `// TODO:` untuk task yang pending
- Gunakan `// FIXME:` untuk bug yang perlu diperbaiki

---

## API Response Handling

### Standard Response Model
```dart
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
}
```

### Pagination Model
```dart
class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMeta meta;
}

class PaginationMeta {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int limit;
  final bool hasNext;
  final bool hasPrev;
}
```

---

## Current Sprint Focus

### Sprint 1 (Current)
- [ ] Setup Project Structure
- [ ] Setup Dio + Interceptors
- [ ] Splash Screen
- [ ] Login Screen
- [ ] Secure Token Storage

### Sprint 2 (Next)
- [ ] Integrasi API Login
- [ ] Profile Page
- [ ] Register Screen

---

## Commands

```bash
# Run app
flutter run

# Build APK
flutter build apk --release

# Run tests
flutter test

# Generate code (jika pakai build_runner)
flutter pub run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze
```

---

## Important Notes

1. **SELALU** validasi input sebelum submit ke API
2. **SELALU** handle loading state dan error state
3. **SELALU** simpan token di secure storage, BUKAN shared_preferences
4. **JANGAN** hardcode API URL, gunakan environment config
5. **JANGAN** commit file `.env` ke repository

---

## Contact & Resources

- **Backend API Docs:** [Link Swagger/Postman]
- **Figma Design:** [Link Design - jika ada]
- **Scrum Master:** Riana
- **Backend PIC:** Abiel (Auth), Arifin (User)
