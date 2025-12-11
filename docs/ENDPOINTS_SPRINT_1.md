# API ENDPOINTS - SPRINT 1

## Overview

| Service | Base URL | Port |
|---------|----------|------|
| Auth Service | `http://localhost:8080` | 8080 |
| User Service | `http://localhost:8081` | 8081 |

**Authentication:** JWT Bearer Token

---

## Auth Service (`ms-auth`)

### 1. Register User

Mendaftarkan user baru ke sistem.

```
POST /auth/register
```

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "minimal6karakter",
  "role": "customer"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `name` | string | ✅ | Nama lengkap |
| `email` | string | ✅ | Format email valid |
| `password` | string | ✅ | Minimal 6 karakter |
| `role` | string | ❌ | Enum: `customer`, `agent`, `admin`, `super_admin`. Default: `customer` |

**Response Success (201):**
```json
{
  "success": true,
  "message": "Registration successful. Please login.",
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "budi@example.com",
    "created_at": "2024-11-26T09:00:00Z"
  }
}
```

**Response Error (400):**
```json
{
  "success": false,
  "message": "Email already registered",
  "data": null
}
```

**Response Error (422) - Validation:**
```json
{
  "success": false,
  "message": "Validation failed",
  "data": {
    "errors": [
      {
        "field": "email",
        "message": "Email format is invalid"
      },
      {
        "field": "password",
        "message": "Password must be at least 6 characters"
      }
    ]
  }
}
```

---

### 2. Login User

Autentikasi user dan mendapatkan JWT token.

```
POST /auth/login
```

**Headers:**
```
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "budi@example.com",
  "password": "password123"
}
```

| Field | Type | Required |
|-------|------|----------|
| `email` | string | ✅ |
| `password` | string | ✅ |

**Response Success (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
    "expires_in": 3600,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "full_name": "Budi Santoso",
      "email": "budi@example.com",
      "role": "customer",
      "avatar_url": null
    }
  }
}
```

**Response Error (401):**
```json
{
  "success": false,
  "message": "Invalid email or password",
  "data": null
}
```

**Response Error (403) - Account Disabled:**
```json
{
  "success": false,
  "message": "Your account has been disabled. Please contact admin.",
  "data": null
}
```

---

## User Service (`ms-user`)

### 3. Get User by ID

Mendapatkan data user berdasarkan ID.

```
GET /users/{id}
```

**Headers:**
```
Authorization: Bearer {access_token}
Content-Type: application/json
```

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | uuid | User ID |

**Response Success (200):**
```json
{
  "success": true,
  "message": "User retrieved successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "full_name": "Budi Santoso",
    "email": "budi@example.com",
    "phone_number": "081234567890",
    "avatar_url": "https://storage.example.com/avatars/budi.jpg",
    "role": "customer",
    "department": null,
    "created_at": "2024-11-26T09:00:00Z",
    "updated_at": "2024-11-26T09:00:00Z"
  }
}
```

**Response Error (401) - Unauthorized:**
```json
{
  "success": false,
  "message": "Invalid or expired token",
  "data": null
}
```

**Response Error (404):**
```json
{
  "success": false,
  "message": "User not found",
  "data": null
}
```

---

## Internal Endpoints (Service-to-Service)

> ⚠️ **Note:** Endpoint ini TIDAK digunakan oleh Mobile App. Hanya untuk komunikasi antar microservices.

### Create User (Internal)

```
POST /internal/users
```

**Headers:**
```
X-Internal-Token: {internal_service_token}
Content-Type: application/json
```

### Validate User Credentials (Internal)

```
POST /internal/users/validate
```

---

## Error Codes Reference

| HTTP Code | Meaning | When |
|-----------|---------|------|
| 200 | OK | Request berhasil |
| 201 | Created | Resource berhasil dibuat |
| 400 | Bad Request | Request body invalid |
| 401 | Unauthorized | Token invalid/expired |
| 403 | Forbidden | Akun disabled atau tidak punya akses |
| 404 | Not Found | Resource tidak ditemukan |
| 422 | Unprocessable Entity | Validation error |
| 500 | Internal Server Error | Server error |

---

## Flutter Implementation Notes

### 1. Dio Interceptor untuk Auth

```dart
// Attach token ke setiap request
options.headers['Authorization'] = 'Bearer $accessToken';

// Handle 401 → refresh token atau logout
if (response.statusCode == 401) {
  // Try refresh token
  // If fail, clear storage & redirect to login
}
```

### 2. Secure Storage untuk Token

```dart
// JANGAN gunakan SharedPreferences untuk token!
// Gunakan flutter_secure_storage

final storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: token);
await storage.write(key: 'refresh_token', value: refreshToken);
```

### 3. Model Classes

```dart
// LoginRequest
class LoginRequest {
  final String email;
  final String password;
}

// LoginResponse
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final User user;
}

// RegisterRequest
class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String? role; // optional, default: customer
}
```

---

## Testing dengan cURL

### Register:
```bash
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"test123"}'
```

### Login:
```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

### Get User:
```bash
curl -X GET http://localhost:8081/users/{user_id} \
  -H "Authorization: Bearer {access_token}"
```
