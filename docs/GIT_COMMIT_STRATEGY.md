# Git Commit Strategy - Sprint 1

## Commit Convention

Menggunakan **Conventional Commits** format:
```
<type>: <subject>

<body>
```

### Types:
- **feat**: Fitur baru
- **fix**: Bug fix
- **docs**: Perubahan dokumentasi
- **style**: Format code (tidak mengubah logic)
- **refactor**: Refactoring code
- **test**: Menambah/update tests
- **chore**: Maintenance tasks

---

## Sprint 1 Commit History

### ✅ Commit 1: Setup Initial Project Structure
```bash
git commit -m "chore: setup initial project structure

- Created Flutter project with multi-platform support (Android, iOS, Web, Desktop)
- Setup basic routing structure with named routes
- Configured analysis options and project dependencies
- Setup .gitignore for Flutter project and sensitive data"
```
**Commit Hash**: `d1e6073`
**Status**: ✅ DONE

---

### ✅ Commit 2: Setup Dio HTTP Client with Interceptors
```bash
git commit -m "feat: setup Dio HTTP client with interceptors

- Configured Dio client with base URL configuration
- Added authentication token interceptor for secure API calls
- Implemented request/response logging interceptor for debugging
- Added custom error handling with exceptions and failures
- Created API endpoints constants for maintainability"
```
**Commit Hash**: `30ea265`
**Status**: ✅ DONE

**Files**:
- `lib/core/network/dio_client.dart`
- `lib/core/network/api_interceptor.dart`
- `lib/core/constants/api_endpoints.dart`
- `lib/core/errors/exceptions.dart`
- `lib/core/errors/failures.dart`

---

### ✅ Commit 3: Setup Core Utilities and Theming
```bash
git commit -m "feat: setup core utilities and theming

- Created app theme with light/dark mode support
- Defined app colors palette for consistent design
- Added text styles for typography consistency
- Implemented form validators for email, password, and phone
- Setup storage keys constants for secure data management"
```
**Commit Hash**: `13ac5b3`
**Status**: ✅ DONE

**Files**:
- `lib/core/themes/app_theme.dart`
- `lib/core/themes/app_colors.dart`
- `lib/core/themes/text_styles.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/constants/storage_keys.dart`
- `lib/core/utils/validators.dart`

---

### ✅ Commit 4: Setup Data Layer Architecture
```bash
git commit -m "feat: setup data layer architecture

- Created data models (User, Auth, API Response)
- Implemented AuthRepository following repository pattern
- Setup remote datasource for API integration
- Added local datasource for secure token storage
- Created mock datasource for development and testing
- Established clean architecture data flow"
```
**Commit Hash**: `e2970ea`
**Status**: ✅ DONE

**Files**:
- `lib/data/models/user_model.dart`
- `lib/data/models/auth_models.dart`
- `lib/data/models/api_response.dart`
- `lib/data/repositories/auth_repository.dart`
- `lib/data/datasources/remote/auth_remote_datasource.dart`
- `lib/data/datasources/local/local_storage.dart`
- `lib/data/datasources/mock/auth_mock_datasource.dart`

---

### ✅ Commit 5: Create Reusable UI Components
```bash
git commit -m "feat: create reusable UI components

- Created CustomButton widget with loading state support
- Created CustomTextField with validation and icons
- Implemented LoadingWidget with circular progress indicator
- Setup consistent styling across all shared components
- Added reusable widgets for faster development"
```
**Commit Hash**: `ee6ee11`
**Status**: ✅ DONE

**Files**:
- `lib/shared/widgets/custom_button.dart`
- `lib/shared/widgets/custom_text_field.dart`
- `lib/shared/widgets/loading_widget.dart`

---

### ✅ Commit 6: Setup State Management with Provider
```bash
git commit -m "feat: setup state management with Provider

- Created AuthProvider for authentication state management
- Implemented login/logout functionality with repository integration
- Added loading and error state handling
- Integrated secure token storage with authentication flow
- Setup ChangeNotifier pattern for reactive UI updates"
```
**Commit Hash**: `acc31be`
**Status**: ✅ DONE

**Files**:
- `lib/providers/auth_provider.dart`

---

### ✅ Commit 7: Implement Splash Screen
```bash
git commit -m "feat: implement splash screen with auth check

- Created splash screen UI with app branding
- Added auto-navigation after initialization delay
- Implemented token check for authentication state
- Navigate to login screen if not authenticated
- Navigate to home screen if already authenticated
- Integrated with AuthProvider for state checking"
```
**Commit Hash**: `d0b5446`
**Status**: ✅ DONE

**Files**:
- `lib/features/splash/screens/splash_screen.dart`

---

### ✅ Commit 8: Implement Login Screen
```bash
git commit -m "feat: implement login screen

- Created login form with email and password fields
- Added input validation using custom validators
- Implemented loading state during authentication
- Added error message display for failed login attempts
- Integrated CustomTextField and CustomButton widgets
- Connected to AuthProvider for authentication flow
- Added navigation to home screen on successful login"
```
**Commit Hash**: `4a630cc`
**Status**: ✅ DONE

**Files**:
- `lib/features/auth/screens/login_screen.dart`

---

### ✅ Commit 9: Implement Home Screen
```bash
git commit -m "feat: implement home screen

- Created home screen layout for authenticated users
- Added logout functionality with confirmation
- Display user information from authentication state
- Integrated with AuthProvider for logout flow
- Navigate back to login screen after logout
- Setup basic home screen structure for future features"
```
**Commit Hash**: `8bc9340`
**Status**: ✅ DONE

**Files**:
- `lib/features/home/screens/home_screen.dart`

---

## Sprint 1 Summary

**Total Commits**: 9
**Status**: ✅ COMPLETED

### Sprint 1 Checklist:
- [x] Setup Project Structure
- [x] Setup Dio + Interceptors
- [x] Setup Core Utilities & Theming
- [x] Setup Data Layer
- [x] Create Reusable Widgets
- [x] Setup State Management
- [x] Implement Splash Screen
- [x] Implement Login Screen
- [x] Implement Home Screen

---

## Best Practices

1. **Commit saat fitur sudah berfungsi** - Jangan commit code yang broken
2. **One feature per commit** - Satu commit untuk satu fitur lengkap
3. **Write descriptive messages** - Jelaskan "what" dan "why", bukan "how"
4. **Test before commit** - Pastikan app bisa running
5. **Use branches** (Optional) - Buat branch untuk fitur besar

---

## Useful Git Commands

```bash
# Check status
git status

# View commit history
git log --oneline

# View detailed commit
git log --stat

# View changes in specific commit
git show <commit-hash>

# View changes between commits
git diff <commit-hash-1> <commit-hash-2>

# Create branch
git checkout -b feature/nama-fitur

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View file at specific commit
git show <commit-hash>:path/to/file
```

---

## Notes

- Commit history menjadi dokumentasi lengkap progress Sprint 1
- Setiap commit merepresentasikan satu fitur/layer yang complete
- Mudah untuk rollback ke state tertentu jika diperlukan
- Git log dapat di-review kapan saja untuk tracking progress
