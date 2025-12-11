# API ENDPOINTS - SPRINT 2

## Overview

Sprint 2 berfokus pada:
- Forgot/Reset Password
- Profile Management (Get & Edit)
- Master Data (Categories, Departments, Priorities)

---

## Auth Service (`ms-auth`)

### 1. Forgot Password

Mengirim email reset password ke user.

```
POST /auth/forgot-password
```

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "budi@example.com"
}
```

| Field | Type | Required |
|-------|------|----------|
| `email` | string | ✅ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Password reset link has been sent to your email",
  "data": null
}
```

**Response Error (404):**
```json
{
  "success": false,
  "message": "Email not registered",
  "data": null
}
```

> **Note:** Untuk keamanan, beberapa implementasi selalu return success meskipun email tidak terdaftar.

---

### 2. Reset Password

Mereset password dengan token dari email.

```
POST /auth/reset-password
```

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "token": "reset_token_dari_email",
  "new_password": "passwordbaru123",
  "confirm_password": "passwordbaru123"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `token` | string | ✅ | Token dari email |
| `new_password` | string | ✅ | Minimal 6 karakter |
| `confirm_password` | string | ✅ | Harus sama dengan new_password |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Password has been reset successfully. Please login.",
  "data": null
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Invalid or expired reset token",
  "data": null
}
```

---

## User Service (`ms-user`)

### 3. Get Current User Profile

Mendapatkan profil user yang sedang login.

```
GET /users/me
```

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile retrieved successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "full_name": "Budi Santoso",
    "email": "budi@example.com",
    "phone_number": "081234567890",
    "avatar_url": "https://storage.example.com/avatars/budi.jpg",
    "role": "customer",
    "department": null,
    "stat_tickets_created_count": 5,
    "stat_tickets_resolved_count": 3,
    "created_at": "2024-11-26T09:00:00Z",
    "updated_at": "2024-12-01T10:30:00Z"
  }
}
```

---

### 4. Update Current User Profile

Mengupdate profil user yang sedang login.

```
PUT /users/me
```

**Headers:**
```
Authorization: Bearer {access_token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "full_name": "Budi Santoso Updated",
  "phone_number": "081234567899",
  "avatar_url": "https://storage.example.com/avatars/budi-new.jpg"
}
```

| Field | Type | Required | Note |
|-------|------|----------|------|
| `full_name` | string | ❌ | Kirim jika ingin update |
| `phone_number` | string | ❌ | Kirim jika ingin update |
| `avatar_url` | string | ❌ | URL setelah upload avatar |

> **Note:** Hanya kirim field yang ingin diupdate. Field yang tidak dikirim tidak akan berubah.

**Response Success (200):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "full_name": "Budi Santoso Updated",
    "email": "budi@example.com",
    "phone_number": "081234567899",
    "avatar_url": "https://storage.example.com/avatars/budi-new.jpg",
    "role": "customer",
    "updated_at": "2024-12-01T11:00:00Z"
  }
}
```

---

## Master Data Endpoints

> **Access:** Endpoints ini tersedia untuk semua authenticated user (read-only untuk customer).

### 5. List Categories

Mendapatkan daftar kategori tiket.

```
GET /categories
```

**Headers:**
```
Authorization: Bearer {access_token}
```

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | Halaman |
| `limit` | integer | 10 | Item per halaman |
| `search` | string | | Filter by name |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Categories retrieved successfully",
  "data": {
    "items": [
      {
        "id": "cat-001",
        "name": "Jaringan"
      },
      {
        "id": "cat-002",
        "name": "Hardware"
      },
      {
        "id": "cat-003",
        "name": "Software"
      },
      {
        "id": "cat-004",
        "name": "Akun & Password"
      },
      {
        "id": "cat-005",
        "name": "Lainnya"
      }
    ],
    "meta": {
      "current_page": 1,
      "total_pages": 1,
      "total_items": 5,
      "limit": 10,
      "has_next": false,
      "has_prev": false
    }
  }
}
```

---

### 6. List Departments

Mendapatkan daftar departemen.

```
GET /departments
```

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Departments retrieved successfully",
  "data": {
    "items": [
      {
        "id": "dept-001",
        "name": "IT Support"
      },
      {
        "id": "dept-002",
        "name": "Human Resources"
      },
      {
        "id": "dept-003",
        "name": "Finance"
      },
      {
        "id": "dept-004",
        "name": "Operations"
      }
    ],
    "meta": {
      "current_page": 1,
      "total_pages": 1,
      "total_items": 4,
      "limit": 10,
      "has_next": false,
      "has_prev": false
    }
  }
}
```

---

### 7. List Priorities

Mendapatkan daftar prioritas tiket.

```
GET /priorities
```

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Priorities retrieved successfully",
  "data": {
    "items": [
      {
        "id": "LOW",
        "name": "Low",
        "color": "#28a745",
        "response_time_minutes": 480,
        "resolution_time_minutes": 4320
      },
      {
        "id": "MEDIUM",
        "name": "Medium",
        "color": "#ffc107",
        "response_time_minutes": 240,
        "resolution_time_minutes": 1440
      },
      {
        "id": "HIGH",
        "name": "High",
        "color": "#fd7e14",
        "response_time_minutes": 60,
        "resolution_time_minutes": 480
      },
      {
        "id": "URGENT",
        "name": "Urgent",
        "color": "#dc3545",
        "response_time_minutes": 30,
        "resolution_time_minutes": 240
      }
    ],
    "meta": {
      "current_page": 1,
      "total_pages": 1,
      "total_items": 4,
      "limit": 10,
      "has_next": false,
      "has_prev": false
    }
  }
}
```

---

## Admin Only Endpoints

> ⚠️ **Access:** Membutuhkan `role: admin` atau `super_admin`. **TIDAK** digunakan di Mobile End-User App.

### User Management (Admin)

```
GET    /users          - List all users
POST   /users          - Create user manual
PUT    /users/:id      - Update user
DELETE /users/:id      - Delete user
```

### Master Data Management (Admin)

```
POST   /categories/:id    - Create category
PUT    /categories/:id    - Update category
DELETE /categories/:id    - Delete category

POST   /departments/:id   - Create department
PUT    /departments/:id   - Update department
DELETE /departments/:id   - Delete department

POST   /priorities/:id    - Create priority
PUT    /priorities/:id    - Update priority
DELETE /priorities/:id    - Delete priority
```

---

## Endpoints untuk Mobile End-User (Summary)

| Method | Endpoint | Sprint | Description |
|--------|----------|--------|-------------|
| POST | `/auth/register` | 1 | Register |
| POST | `/auth/login` | 1 | Login |
| POST | `/auth/forgot-password` | 2 | Forgot password |
| POST | `/auth/reset-password` | 2 | Reset password |
| GET | `/users/:id` | 1 | Get user by ID |
| GET | `/users/me` | 2 | Get my profile |
| PUT | `/users/me` | 2 | Update my profile |
| GET | `/categories` | 2 | List categories |
| GET | `/departments` | 2 | List departments |
| GET | `/priorities` | 2 | List priorities |

---

## Flutter Implementation Notes

### 1. Model Classes untuk Sprint 2

```dart
// ForgotPasswordRequest
class ForgotPasswordRequest {
  final String email;
}

// ResetPasswordRequest
class ResetPasswordRequest {
  final String token;
  final String newPassword;
  final String confirmPassword;
}

// UpdateProfileRequest
class UpdateProfileRequest {
  final String? fullName;
  final String? phoneNumber;
  final String? avatarUrl;
}

// Category
class Category {
  final String id;
  final String name;
}

// Department
class Department {
  final String id;
  final String name;
}

// Priority
class Priority {
  final String id;
  final String name;
  final String color;
  final int responseTimeMinutes;
  final int resolutionTimeMinutes;
}
```

### 2. Cache Strategy untuk Master Data

```dart
// Master data (categories, departments, priorities) jarang berubah
// Gunakan cache dengan expiry time

class MasterDataCache {
  static const Duration cacheExpiry = Duration(hours: 24);
  
  List<Category>? _categories;
  DateTime? _categoriesCachedAt;
  
  Future<List<Category>> getCategories() async {
    if (_shouldRefreshCache(_categoriesCachedAt)) {
      _categories = await _fetchFromApi();
      _categoriesCachedAt = DateTime.now();
    }
    return _categories!;
  }
}
```

### 3. Profile Update Flow

```dart
// 1. User edit profile form
// 2. Jika ada avatar baru, upload dulu ke storage
// 3. Dapat URL avatar
// 4. Kirim PUT /users/me dengan data + avatar_url
// 5. Update local user state
```

---

## Testing dengan cURL

### Forgot Password:
```bash
curl -X POST http://localhost:8080/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

### Get My Profile:
```bash
curl -X GET http://localhost:8081/users/me \
  -H "Authorization: Bearer {access_token}"
```

### Update Profile:
```bash
curl -X PUT http://localhost:8081/users/me \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{"full_name":"New Name","phone_number":"08123456789"}'
```

### Get Categories:
```bash
curl -X GET http://localhost:8081/categories \
  -H "Authorization: Bearer {access_token}"
```
