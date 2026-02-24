# API Contract Specification

**Golang Clean Architecture Microservices - Version 2.0 (RBAC Edition)**

---

## Base URLs

| Service                | URL                     |
| ---------------------- | ----------------------- |
| **Gateway**            | `http://localhost:8000` |
| **ms-auth**            | `http://localhost:8080` |
| **ms-user-management** | `http://localhost:8081` |
| **ms-ticket**          | `http://localhost:8082` |
| **ms-chat**            | `http://localhost:8083` |
| **ms-sla**             | `http://localhost:8084` |
| **ms-notification**    | `http://localhost:8085` |

---

## V2.0 Breaking Changes

> [!WARNING]
>
> - JWT tokens now include `role` claim
> - `/auth/register` now requires JWT authentication (admin/super_admin only)
> - Customer/Agent CANNOT self-register

**New Features:**

- Complete RBAC implementation with roles, permissions, and role_permissions
- New endpoints for role and permission management
- Enhanced validation error messages
- User profile endpoints (`/users/me`) with **Profile Picture** support
- **NEW:** Ticket Service (ms-ticket) with:
  - Ticket Categories CRUD
  - Ticket Status CRUD with dynamic transitions
  - **Tickets CRUD** (main entity) with filters & pagination
  - File upload for attachments (10MB limit)
  - Priority levels (low, medium, high, critical)
  - **SLA Integration** - automatic due date calculation
  - **Auto-Close** - automatically closes inactive tickets
- **NEW:** Chat Service (ms-chat) with:
  - Real-time WebSocket chat for ticket comments
  - REST API for chat history
  - Room-based messaging (per ticket)
  - Automatic message persistence
  - **Attachment support** (upload files in chat, max 5MB)
  - **User activity tracking** for auto-close feature
- **NEW:** SLA Service (ms-sla) with:
  - SLA Configuration per priority (CRUD)
  - Automatic due date calculation based on priority
  - Overdue ticket checking (cron job every 5 minutes)
  - Warning notifications before deadline
  - **Auto-close inactive tickets** (cron job every hour)
  - **System configuration** for auto-close days
- **NEW:** Notification Service (ms-notification) with:
  - Email notifications via SMTP
  - HTML email templates for overdue/warning alerts
  - **Auto-close notification** email template

---

# Authentication Service (ms-auth)

## 1. Login User ⚠️ UPDATED (Refresh Token)

| Method | Endpoint      | Access |
| ------ | ------------- | ------ |
| `POST` | `/auth/login` | Public |

**Description:** Authenticate user with email/username and password. Returns access token (short-lived) and refresh token (long-lived).

**Request:**

```json
{
  "identifier": "string (required, email or username)",
  "password": "string (required)"
}
```

**Success Response (200):**

```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "609c1f38-a65a-4ba5-aa1c-f2e3c142915e",
    "expires_in": 900,
    "user": {
      "id": 1,
      "email": "admin@test.com",
      "username": "admin",
      "name": "Admin User",
      "role": "admin",
      "role_id": 2,
      "role_level": 5,
      "is_active": true,
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    }
  }
}
```

> [!IMPORTANT]
>
> - **`access_token`** — JWT token for API requests, expires in `expires_in` seconds (default: **15 minutes**)
> - **`refresh_token`** — UUID for obtaining new access token, expires in **7 days** (stored in Redis)
> - **`expires_in`** — Access token lifetime in seconds (900 = 15 minutes)
> - Use `access_token` in `Authorization: Bearer <access_token>` header
> - When access token expires (401), call `POST /auth/refresh` to get a new one

**Error Responses:**

- **401 Unauthorized** - Account inactive:

```json
{
  "error": "account_inactive",
  "message": "your account has been deactivated, please contact administrator"
}
```

- **401 Unauthorized** - Invalid credentials:

```json
{
  "error": "invalid credentials"
}
```

- **429 Too Many Requests** - Rate limited:

```json
{
  "error": "too_many_requests",
  "message": "too many login attempts, please try again in 5 minutes",
  "retry_after": 300
}
```

> [!WARNING]
>
> **Rate Limiting:** Login endpoint is rate limited to **5 attempts per IP** with a **5 minute cooldown**.
>
> - After 5 failed/successful attempts from the same IP → returns **429** for 5 minutes
> - Response headers on every login request:
>   - `X-RateLimit-Limit: 5` — maximum attempts allowed
>   - `X-RateLimit-Remaining: 3` — remaining attempts in current window
> - Counter resets automatically after 5 minutes (stored in Redis)
> - If Redis is unavailable, rate limiting is bypassed (fail-open)

**JWT Access Token Claims:**

```json
{
  "user_id": 1,
  "email": "admin@test.com",
  "firstname": "Admin",
  "role": "admin",
  "role_id": 2,
  "role_level": 5,
  "exp": 1702036500,
  "iat": 1702035600
}
```

---

## 1b. Refresh Token

| Method | Endpoint        | Access |
| ------ | --------------- | ------ |
| `POST` | `/auth/refresh` | Public |

**Description:** Get a new access token using a valid refresh token. Call this when access token expires (401 response).

**Request:**

```json
{
  "refresh_token": "609c1f38-a65a-4ba5-aa1c-f2e3c142915e"
}
```

**Success Response (200):**

```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 900
  }
}
```

**Error Responses:**

- **401 Unauthorized** - Invalid or expired refresh token:

```json
{
  "error": "invalid_refresh_token",
  "message": "invalid or expired refresh token"
}
```

> [!TIP]
>
> **Flutter/Mobile Implementation:**
>
> 1. Store `refresh_token` securely (e.g., Flutter Secure Storage)
> 2. When any API returns 401, call `/auth/refresh` with stored `refresh_token`
> 3. Update stored `access_token` with the new one
> 4. Retry the failed request with new `access_token`
> 5. If `/auth/refresh` also returns 401, redirect user to login screen

---

## 1c. Logout

| Method | Endpoint       | Access          |
| ------ | -------------- | --------------- |
| `POST` | `/auth/logout` | JWT (All Users) |

**Description:** Logout user by blacklisting the access token and deleting the refresh token from Redis.

**Headers:**

```
Authorization: Bearer <access_token>
```

**Request:**

```json
{
  "refresh_token": "609c1f38-a65a-4ba5-aa1c-f2e3c142915e"
}
```

**Success Response (200):**

```json
{
  "message": "logged out successfully"
}
```

> [!NOTE]
>
> After logout:
>
> - Access token is blacklisted in Redis (cannot be reused)
> - Refresh token is deleted from Redis (cannot refresh)
> - User must login again to get new tokens

---

## 2. Register User ⚠️ CHANGED

| Method | Endpoint         | Access            |
| ------ | ---------------- | ----------------- |
| `POST` | `/auth/register` | Admin/Super Admin |

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Request:**

```json
{
  "email": "string (required, email format)",
  "username": "string (required, min 3 chars, max 50 chars)",
  "password": "string (required, min 8 chars)",
  "name": "string (required)",
  "last_name": "string (optional)",
  "role": "string (optional, any custom role name that exists in database)"
}
```

> [!NOTE]
>
> - **Role Field:** Can be any role name that exists in the database (e.g., "customer", "admin", "dev", "manager")
> - **Default:** If not provided, defaults to "customer"
> - **Super Admin:** Cannot be created via this endpoint (use `/auth/super` instead)
> - **Validation:** Role name will be validated against the database roles table

**Authorization Rules:**

| Requester Role | Can Create                                        |
| -------------- | ------------------------------------------------- |
| Admin (lvl 5)  | Any role with level < 5 (Customer)                |
| Super Admin    | Any role with level < 10 (all except Super Admin) |
| Customer/Agent | ❌ Cannot create                                  |

**Success Response (201):**

```json
{
  "message": "user registered successfully by admin",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 5,
      "email": "customer1@test.com",
      "username": "customer1",
      "name": "Customer One",
      "last_name": "User",
      "role": "customer"
    }
  }
}
```

**Errors:**
| Code | Error |
|------|-------|
| 401 | Authorization header required / Invalid token |
| 403 | Insufficient permissions |
| 400 | Validation failed |
| 500 | Email already exists |

---

## 3. Register Super Admin

| Method | Endpoint      | Access                     |
| ------ | ------------- | -------------------------- |
| `POST` | `/auth/super` | Protected by Secret Header |

**Headers:**

```
X-Super-Admin-Secret: <secret_key>
```

**Request:**

```json
{
  "email": "string (required, email format)",
  "username": "string (required, min 3 chars, max 50 chars)",
  "password": "string (required, min 8 chars)",
  "name": "string (required)",
  "last_name": "string (optional)"
}
```

**Success Response (201):**

```json
{
  "message": "super admin registered successfully",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "superadmin@company.com",
      "username": "superadmin",
      "name": "Super Administrator",
      "last_name": "Admin",
      "role": "super_admin"
    }
  }
}
```

---

## 3.1. Forgot Password ✨ NEW

| Method | Endpoint                | Access |
| ------ | ----------------------- | ------ |
| `POST` | `/auth/forgot-password` | Public |

**Description:** Request a password reset email. An email will be sent with a 4-digit reset code that expires in 1 hour.

**Request:**

```json
{
  "email": "string (required, email format)"
}
```

**Success Response (200):**

```json
{
  "message": "if your email is registered, you will receive a password reset link"
}
```

**Notes:**

- For security, the response is the same whether the email exists or not
- Reset code is a 4-digit number (1000-9999)
- Code expires in 1 hour
- Email contains the 4-digit code to be used in reset-password endpoint

---

## 3.2. Verify Reset Token ✨ NEW

| Method | Endpoint                   | Access |
| ------ | -------------------------- | ------ |
| `POST` | `/auth/verify-reset-token` | Public |

**Description:** Verify if the 4-digit reset code is valid. Call this endpoint after user inputs the code to check validity before showing the new password form.

**Request:**

```json
{
  "token": "string (required, 4-digit code)"
}
```

**Example:**

```json
{
  "token": "1234"
}
```

**Success Response (200):**

```json
{
  "message": "token is valid",
  "valid": true
}
```

**Error Responses:**

| Code | Error                    |
| ---- | ------------------------ |
| 400  | Validation failed        |
| 400  | invalid or expired token |
| 400  | token has expired        |

> [!NOTE]
>
> - This endpoint only **validates** the token, it does NOT mark it as used
> - Token remains valid for use in `/auth/reset-password`
> - Use this to verify code before showing new password form

---

## 3.3. Reset Password ✨ NEW

| Method | Endpoint               | Access |
| ------ | ---------------------- | ------ |
| `POST` | `/auth/reset-password` | Public |

**Description:** Reset password using the 4-digit code received via email. Token will be marked as used after successful password reset.

**Request:**

```json
{
  "token": "string (required, 4-digit code)",
  "new_password": "string (required, min 8 chars, notblank)"
}
```

**Example:**

```json
{
  "token": "1234",
  "new_password": "NewPass123!"
}
```

**Success Response (200):**

```json
{
  "message": "password reset successfully, you can now login with your new password"
}
```

**Error Responses:**

| Code | Error                       |
| ---- | --------------------------- |
| 400  | Validation failed           |
| 400  | invalid or expired token    |
| 400  | token has expired           |
| 400  | token has already been used |

---

## Password Reset Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PASSWORD RESET FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. POST /auth/forgot-password                                  │
│     Body: { "email": "user@example.com" }                       │
│     → User receives 4-digit code via email                      │
│                                                                 │
│  2. POST /auth/verify-reset-token                               │
│     Body: { "token": "1234" }                                   │
│     → If valid: show new password form                          │
│     → If invalid: show error, let user retry                    │
│                                                                 │
│  3. POST /auth/reset-password                                   │
│     Body: { "token": "1234", "new_password": "NewPass123!" }    │
│     → Password changed, token marked as used                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

# User Management Service (ms-user-management)

## 4. Get My Profile ⚠️ UPDATED

| Method | Endpoint    | Access        |
| ------ | ----------- | ------------- |
| `GET`  | `/users/me` | Authenticated |

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Success Response (200):**

```json
{
  "data": {
    "id": 5,
    "email": "customer1@test.com",
    "username": "customer1",
    "name": "Customer One",
    "last_name": "User",
    "profile_picture": "/profile-pictures/profile_5_20260127.jpg",
    "phone": "081234567890",
    "role": {
      "id": 1,
      "name": "customer",
      "description": "Regular customer",
      "level": 1
    },
    "is_active": true,
    "is_first_login": true,
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2025-12-08T10:00:00Z"
  }
}
```

> [!NOTE]
>
> - `phone` field is optional and may be `null` if not set
> - `profile_picture` contains URL path to user's profile picture

---

## 5. Get My Permissions ✨ NEW

| Method | Endpoint                | Access        |
| ------ | ----------------------- | ------------- |
| `GET`  | `/users/me/permissions` | Authenticated |

**Success Response (200):**

```json
{
  "data": {
    "user_id": 5,
    "role": "customer",
    "permissions": [
      {
        "id": 1,
        "name": "view_tickets",
        "action": "view",
        "resource": "tickets"
      }
    ]
  }
}
```

---

## 5.1. Change Own Password ✨ NEW

| Method | Endpoint                    | Access        |
| ------ | --------------------------- | ------------- |
| `PUT`  | `/users/me/change-password` | Authenticated |

**Description:** Allows any authenticated user to change their own password. After successful password change, `is_first_login` is automatically set to `false`.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Request:**

```json
{
  "old_password": "string (required, min 8 chars)",
  "new_password": "string (required, min 8 chars, notblank)"
}
```

**Success Response (200):**

```json
{
  "message": "password changed successfully"
}
```

**Error Responses:**

| Code | Error                     |
| ---- | ------------------------- |
| 400  | Validation failed         |
| 400  | old password is incorrect |
| 401  | Invalid or missing token  |
| 500  | Failed to update password |

---

## 5.2. Update My Profile ✨ NEW

| Method | Endpoint    | Access        |
| ------ | ----------- | ------------- |
| `PUT`  | `/users/me` | Authenticated |

**Description:** Allows any authenticated user to update their own profile information (name, last_name, phone). Cannot update email, username, or role.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Request:**

```json
{
  "name": "string (optional, min 1 char)",
  "last_name": "string (optional, can be empty to clear)",
  "phone": "string (optional, max 20 chars, can be empty to clear)"
}
```

**Request Examples:**

```json
// Update all fields
{
  "name": "John",
  "last_name": "Doe",
  "phone": "081234567890"
}

// Update only name
{
  "name": "Jane"
}

// Clear phone number
{
  "phone": ""
}
```

**Success Response (200):**

```json
{
  "message": "profile updated successfully",
  "data": {
    "id": 5,
    "email": "customer1@test.com",
    "username": "customer1",
    "name": "John",
    "last_name": "Doe",
    "profile_picture": "/profile-pictures/profile_5_20260127.jpg",
    "phone": "081234567890",
    "role": {
      "id": 1,
      "name": "customer",
      "description": "Regular customer",
      "level": 1
    },
    "is_active": true,
    "is_first_login": false,
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2026-01-27T15:30:00Z"
  }
}
```

**Error Responses:**

| Code | Error                    |
| ---- | ------------------------ |
| 400  | Validation failed        |
| 401  | Invalid or missing token |
| 500  | Failed to update profile |

> [!NOTE]
>
> - This endpoint only updates the authenticated user's own profile
> - Cannot update email, username, or role through this endpoint
> - Use `PUT /users/:id` with admin privileges to update other users
> - `phone` field accepts any string up to 20 characters

---

## 6. List All Users ⚠️ UPDATED

| Method | Endpoint | Access            |
| ------ | -------- | ----------------- |
| `GET`  | `/users` | Admin/Super Admin |

**Description:** Get all users. Only Admin (level 5+) can access.

**Query Parameters:**

- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10, max: 100)

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "email": "user@test.com",
      "username": "user1",
      "name": "User One",
      "last_name": "User",
      "role": "customer",
      "role_id": 1,
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 25
  }
}
```

**Error Response:**

- **403 Forbidden** - Non-admin accessing:

```json
{
  "error": "forbidden",
  "message": "admin role required (level 5+)"
}
```

---

## 6.1. Get All Agents ✨ NEW

| Method | Endpoint        | Access                  |
| ------ | --------------- | ----------------------- |
| `GET`  | `/users/agents` | Agent/Admin/Super Admin |

**Description:** Get all agents (users with role level = 2). Accessible by agents and above. Useful for assigning tickets.

**Query Parameters:**

- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10, max: 100)

**Success Response (200):**

```json
{
  "message": "agents retrieved successfully",
  "data": [
    {
      "id": 5,
      "email": "agent1@test.com",
      "username": "agent1",
      "name": "Agent One",
      "last_name": "Support",
      "role": "agent",
      "role_id": 2,
      "is_active": true,
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 5
  }
}
```

**Error Response:**

- **403 Forbidden** - Customer accessing:

```json
{
  "error": "forbidden",
  "message": "agent role or higher required to view agents"
}
```

---

## 7. Get User By ID

| Method | Endpoint     | Access        |
| ------ | ------------ | ------------- |
| `GET`  | `/users/:id` | Authenticated |

**Success Response (200):**

```json
{
  "data": {
    "id": 1,
    "email": "user@test.com",
    "username": "user1",
    "name": "User One",
    "last_name": "User",
    "role": "customer",
    "role_id": 1,
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2025-12-08T10:00:00Z"
  }
}
```

---

## 8. Get User With Role Details ✨ NEW

| Method | Endpoint               | Access        |
| ------ | ---------------------- | ------------- |
| `GET`  | `/users/:id/with-role` | Authenticated |

**Success Response (200):**

```json
{
  "data": {
    "id": 1,
    "email": "user@test.com",
    "username": "user1",
    "name": "User One",
    "last_name": "User",
    "role": {
      "id": 1,
      "name": "customer",
      "description": "Regular customer user",
      "level": 1,
      "is_system_role": true,
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    },
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2025-12-08T10:00:00Z"
  }
}
```

---

## 9. Update User

| Method | Endpoint     | Access            |
| ------ | ------------ | ----------------- |
| `PUT`  | `/users/:id` | Admin/Super Admin |

**Request:**

```json
{
  "name": "string (optional)",
  "last_name": "string (optional, can be empty to clear)",
  "email": "string (optional, email format)",
  "role": "string (optional, role name)",
  "role_id": "integer (optional, role ID)"
}
```

**Request Examples:**

```json
// Update name and last_name
{
  "name": "John",
  "last_name": "Doe"
}

// Clear last_name (set to empty)
{
  "last_name": ""
}

// Update role
{
  "role_id": 1
}
```

> [!NOTE] > **Field Notes:**
>
> - `name`: Update first name
> - `last_name`: Update last name, send `""` (empty string) to clear the field
> - `email`: Update email (must be unique)
> - `role`: Update by role name (e.g., "customer", "admin", "dev")
> - `role_id`: Update by role ID (preferred method)
> - If both `role` and `role_id` provided, `role_id` takes priority
>
> **Authorization Rules:**
>
> - Users can update themselves (except role change)
> - Only STRICTLY higher level can update lower level users
> - Admin (level 5) CANNOT update another Admin (level 5)
> - Super Admin (level 10) CANNOT update another Super Admin (level 10)
>
> **Role Assignment Restrictions:**
>
> - Can only assign roles with level **STRICTLY lower** than your own
> - Admin (level 5) can assign: Customer (1), Agent (2), custom roles < 5
> - Admin (level 5) **CANNOT** assign: Admin (5), Super Admin (10)
> - Only Super Admin (level 10) can assign any role

**Success Response (200):**

```json
{
  "message": "user updated successfully",
  "data": {
    "id": 59,
    "email": "user@example.com",
    "username": "username123",
    "name": "Updated Name",
    "last_name": "Updated LastName",
    "role": "customer",
    "role_id": 1,
    "is_first_login": false,
    "created_at": "2025-12-16T08:18:17Z",
    "updated_at": "2025-12-16T08:30:00Z"
  }
}
```

**Error Responses:**

- **400 Bad Request** - Invalid role name:

```json
{
  "error": "invalid_role",
  "message": "role not found: the specified role name does not exist in the database",
  "hint": "please check the role name or use role_id instead"
}
```

- **404 Not Found** - User not found:

```json
{
  "error": "not_found",
  "message": "user not found"
}
```

- **409 Conflict** - Email already exists:

```json
{
  "error": "conflict",
  "message": "email already exists"
}
```

- **403 Forbidden** - Cannot assign role equal/higher than own level:

```json
{
  "error": "forbidden",
  "message": "you cannot assign a role with level equal to or higher than your own role level",
  "hint": "only users with strictly higher role level can assign this role"
}
```

---

## 10. Delete User

| Method   | Endpoint     | Access            |
| -------- | ------------ | ----------------- |
| `DELETE` | `/users/:id` | Admin/Super Admin |

**Success Response (200):**

```json
{
  "message": "user deleted successfully"
}
```

> [!NOTE] > **Authorization Rules:**
>
> - Cannot delete yourself
> - Only STRICTLY higher level can delete lower level users
> - Admin (level 5) CANNOT delete another Admin (level 5)
> - Super Admin (level 10) CANNOT delete another Super Admin (level 10)

---

## 11. Update Account Status

| Method | Endpoint            | Access           |
| ------ | ------------------- | ---------------- |
| `PUT`  | `/users/:id/status` | Super Admin Only |

**Request Examples:**

```json
// Activate account
{
  "is_active": true
}

// Deactivate account
{
  "is_active": false
}
```

> [!IMPORTANT] > **Field Requirements:**
>
> - `is_active`: **Boolean value** (NOT string "true" or "false")
> - Use `true` (without quotes) to activate account
> - Use `false` (without quotes) to deactivate account
> - Field is **required** - must be present in request body
>
> **Authorization Rules:**
>
> - Only Super Admin (level 10) can update account status
> - Inactive users will be blocked from logging in

**Success Response (200):**

```json
{
  "message": "account activated successfully",
  "data": {
    "id": 59,
    "email": "user@example.com",
    "username": "user123",
    "name": "John",
    "last_name": "Doe",
    "role": "customer",
    "role_id": 1,
    "is_active": true,
    "is_first_login": false,
    "created_at": "2025-12-16T08:18:17Z",
    "updated_at": "2025-12-17T09:30:00Z"
  }
}
```

**Error Responses:**

- **400 Bad Request** - Invalid request (wrong data type):

```json
{
  "error": "invalid_request",
  "message": "is_active field is required and must be a boolean value",
  "hint": "use true to activate account or false to deactivate account",
  "example": {
    "is_active": false
  }
}
```

- **403 Forbidden** - Not Super Admin:

```json
{
  "error": "forbidden",
  "message": "only super admin can update account status"
}
```

- **404 Not Found** - User not found:

```json
{
  "error": "not_found",
  "message": "user not found"
}
```

---

## 12. Change User Role ✨ NEW

| Method | Endpoint          | Access           |
| ------ | ----------------- | ---------------- |
| `PUT`  | `/users/:id/role` | Super Admin Only |

**Request:**

```json
{
  "role_id": 3
}
```

---

# Role Management (RBAC) ✨ NEW

> [!NOTE] > **Access Control:**
>
> - **Admin & Super Admin** can **VIEW** roles and permissions
> - **Only Super Admin** can **CREATE, UPDATE, DELETE** roles and permissions

## 13. List All Roles

| Method | Endpoint | Access            |
| ------ | -------- | ----------------- |
| `GET`  | `/roles` | Admin/Super Admin |

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "name": "customer",
      "description": "Regular customer",
      "level": 1,
      "is_system_role": true
    },
    {
      "id": 2,
      "name": "admin",
      "description": "System administrator",
      "level": 5,
      "is_system_role": true
    },
    {
      "id": 3,
      "name": "super_admin",
      "description": "Super administrator",
      "level": 10,
      "is_system_role": true
    }
  ]
}
```

---

## 14. Get Role By ID

| Method | Endpoint     | Access            |
| ------ | ------------ | ----------------- |
| `GET`  | `/roles/:id` | Admin/Super Admin |

---

## 15. Create Role

| Method | Endpoint | Access           |
| ------ | -------- | ---------------- |
| `POST` | `/roles` | Super Admin Only |

**Request:**

```json
{
  "name": "string (required)",
  "description": "string (required)",
  "level": "integer (required, 1-10)"
}
```

**Success Response (201):**

```json
{
  "message": "role created successfully",
  "data": {
    "id": 4,
    "name": "manager",
    "description": "Manager role",
    "level": 6
  }
}
```

**Error Responses:**

- **409 Conflict** - Role name already exists:

```json
{
  "error": "conflict",
  "message": "role name already exists"
}
```

---

## 16. Update Role

| Method | Endpoint     | Access           |
| ------ | ------------ | ---------------- |
| `PUT`  | `/roles/:id` | Super Admin Only |

**Success Response (200):**

```json
{
  "message": "role updated successfully",
  "data": {
    "id": 4,
    "name": "manager",
    "description": "Updated description",
    "level": 6
  }
}
```

**Error Responses:**

- **404 Not Found** - Role not found:

```json
{
  "error": "not_found",
  "message": "role not found"
}
```

- **403 Forbidden** - Cannot update super admin role:

```json
{
  "error": "forbidden",
  "message": "cannot update super admin role"
}
```

- **403 Forbidden** - Cannot update system role:

```json
{
  "error": "forbidden",
  "message": "cannot update system role"
}
```

- **403 Forbidden** - Cannot set level to 10:

```json
{
  "error": "forbidden",
  "message": "cannot set role level to super admin level"
}
```

> [!NOTE]
>
> - Cannot update Super Admin role (level 10)
> - Cannot update system roles (customer, admin, super_admin)
> - Cannot set any role level to 10 (Super Admin level is protected)

---

## 17. Delete Role

| Method   | Endpoint     | Access           |
| -------- | ------------ | ---------------- |
| `DELETE` | `/roles/:id` | Super Admin Only |

**Success Response (200):**

```json
{
  "message": "role deleted successfully"
}
```

**Error Responses:**

- **404 Not Found** - Role not found:

```json
{
  "error": "not_found",
  "message": "role not found"
}
```

- **403 Forbidden** - Cannot delete super admin role:

```json
{
  "error": "forbidden",
  "message": "cannot delete super admin role"
}
```

- **403 Forbidden** - Cannot delete system role:

```json
{
  "error": "forbidden",
  "message": "cannot delete system role"
}
```

- **409 Conflict** - Role is assigned to users:

```json
{
  "error": "conflict",
  "message": "role is assigned to users"
}
```

> [!NOTE]
>
> - Cannot delete Super Admin role (level 10)
> - Cannot delete system roles (customer, admin, super_admin)
> - Cannot delete roles with assigned users

---

## 18. Get Role Permissions

| Method | Endpoint                 | Access            |
| ------ | ------------------------ | ----------------- |
| `GET`  | `/roles/:id/permissions` | Admin/Super Admin |

---

## 19. Assign Permissions to Role

| Method | Endpoint                 | Access           |
| ------ | ------------------------ | ---------------- |
| `POST` | `/roles/:id/permissions` | Super Admin Only |

**Request:**

```json
{
  "permission_ids": [1, 2, 5, 8]
}
```

**Success Response (200):**

```json
{
  "message": "permissions assigned successfully"
}
```

**Error Responses:**

- **404 Not Found** - Role not found:

```json
{
  "error": "not_found",
  "message": "role not found"
}
```

- **404 Not Found** - Invalid permission IDs:

```json
{
  "error": "not_found",
  "message": "one or more permission IDs are invalid"
}
```

- **403 Forbidden** - Cannot modify system role:

```json
{
  "error": "forbidden",
  "message": "cannot modify system role permissions"
}
```

---

## 20. Remove Permissions from Role

| Method   | Endpoint                 | Access           |
| -------- | ------------------------ | ---------------- |
| `DELETE` | `/roles/:id/permissions` | Super Admin Only |

**Request:**

```json
{
  "permission_ids": [1, 2]
}
```

**Success Response (200):**

```json
{
  "message": "permissions removed successfully"
}
```

**Error Responses:**

- **404 Not Found** - Role not found:

```json
{
  "error": "not_found",
  "message": "role not found"
}
```

- **403 Forbidden** - Cannot modify system role:

```json
{
  "error": "forbidden",
  "message": "cannot modify system role permissions"
}
```

---

# Permission Management ✨ NEW

> [!NOTE] > **Access Control:**
>
> - **Admin & Super Admin** can **VIEW** permissions
> - **Only Super Admin** can **CREATE, UPDATE, DELETE** permissions

## 21. List All Permissions

| Method | Endpoint       | Access            |
| ------ | -------------- | ----------------- |
| `GET`  | `/permissions` | Admin/Super Admin |

**Query Parameters:**

- `action`: Filter by action (view, create, update, delete)
- `resource`: Filter by resource (users, tickets, roles, etc)

---

## 22. Get Permission By ID

| Method | Endpoint           | Access            |
| ------ | ------------------ | ----------------- |
| `GET`  | `/permissions/:id` | Admin/Super Admin |

---

## 23. Create Permission

| Method | Endpoint       | Access           |
| ------ | -------------- | ---------------- |
| `POST` | `/permissions` | Super Admin Only |

**Request:**

```json
{
  "name": "string (required, min 3 chars, cannot be blank or whitespace only)",
  "action": "string (required, min 3 chars, cannot be blank or whitespace only)",
  "resource": "string (required, min 3 chars, cannot be blank or whitespace only)",
  "description": "string (optional, max 255 chars)",
  "group_id": "integer (optional, permission group ID)"
}
```

> [!NOTE]
>
> - Fields `name`, `resource`, and `action` will be **automatically trimmed** of leading/trailing whitespace
> - Whitespace-only values (e.g., `"   "`) will be **rejected** with validation error
> - Permission name must be unique
> - Combination of `resource` + `action` must be unique

**Example Request:**

```json
{
  "name": "events.create",
  "resource": "events",
  "action": "create",
  "description": "Create new events",
  "group_id": 6
}
```

**Success Response (201):**

```json
{
  "message": "permission created successfully",
  "data": {
    "id": 23,
    "name": "events.create",
    "resource": "events",
    "action": "create",
    "description": "Create new events",
    "group_id": 6,
    "created_at": "2025-12-19T14:20:00Z"
  }
}
```

**Error Responses:**

- **400 Bad Request** - Blank/whitespace validation:

```json
{
  "error": "validation_error",
  "message": "permission name cannot be blank or contain only whitespace"
}
```

```json
{
  "error": "validation_error",
  "message": "action cannot be blank or contain only whitespace"
}
```

- **409 Conflict** - Duplicate permission name:

```json
{
  "error": "conflict",
  "message": "permission name already exists"
}
```

- **409 Conflict** - Duplicate resource+action:

```json
{
  "error": "conflict",
  "message": "permission for resource 'events' and action 'create' already exists"
}
```

---

## 24. Update Permission

| Method | Endpoint           | Access           |
| ------ | ------------------ | ---------------- |
| `PUT`  | `/permissions/:id` | Super Admin Only |

**Request:**

```json
{
  "name": "string (optional, min 3 chars, must be unique)",
  "resource": "string (optional, min 3 chars)",
  "action": "string (optional, min 3 chars)",
  "description": "string (optional, max 255 chars)",
  "group_id": "integer (optional, permission group ID or null)"
}
```

> [!NOTE]
>
> - All fields are optional - only provided fields will be updated
> - Fields are **automatically trimmed** of leading/trailing whitespace
> - `name` must be unique if provided
> - Combination of `resource` + `action` must be unique if either is updated
> - Partial updates supported

**Example Request:**

```json
{
  "name": "meetings.create",
  "resource": "meetings",
  "action": "create",
  "description": "Create new meetings",
  "group_id": 6
}
```

**Success Response (200):**

```json
{
  "message": "permission updated successfully",
  "data": {
    "id": 31,
    "name": "meetings.create",
    "resource": "meetings",
    "action": "create",
    "description": "Create new meetings",
    "group_id": 6,
    "created_at": "2025-12-19T07:43:39.688513Z"
  }
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "permission not found"
}
```

- **409 Conflict** - Duplicate name:

```json
{
  "error": "conflict",
  "message": "permission name already exists"
}
```

- **409 Conflict** - Duplicate resource+action:

```json
{
  "error": "conflict",
  "message": "permission for resource 'meetings' and action 'create' already exists"
}
```

---

## 25. Delete Permission (Protected)

| Method   | Endpoint           | Access           |
| -------- | ------------------ | ---------------- |
| `DELETE` | `/permissions/:id` | Super Admin Only |

**Description:** Delete a permission with **assignment protection**. Will fail if permission is assigned to any roles.

**Success Response (200):**

```json
{
  "message": "permission deleted successfully"
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "permission not found"
}
```

- **409 Conflict** - Permission is assigned:

```json
{
  "error": "conflict",
  "message": "cannot delete permission: assigned to 2 role(s) [super_admin, admin]. Use force delete to cascade",
  "hint": "use force delete endpoint: DELETE /permissions/{id}/force"
}
```

---

## 26. Force Delete Permission (Cascade)

| Method   | Endpoint                 | Access           |
| -------- | ------------------------ | ---------------- |
| `DELETE` | `/permissions/:id/force` | Super Admin Only |

**Description:** Force delete a permission with **cascade removal** - automatically removes all role assignments.

> [!WARNING]
> This will **permanently remove** the permission and **unassign it from all roles**. Use with caution!

**Success Response (200):**

```json
{
  "message": "permission force deleted successfully (cascade)",
  "affected_roles": ["super_admin", "admin"],
  "removed_assignments": 2
}
```

**Success Response (No assignments):**

```json
{
  "message": "permission force deleted successfully (cascade)"
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "permission not found"
}
```

### **Delete Permission Comparison:**

| Method             | Protection   | Behavior            | Use Case      |
| ------------------ | ------------ | ------------------- | ------------- |
| **Regular Delete** | ✅ Protected | Fails if assigned   | Safe deletion |
| **Force Delete**   | ❌ Cascade   | Removes assignments | Clean removal |

---

# Ticket Service (ms-ticket)

> [!NOTE] > **Access Control:**
>
> - **All Authenticated Users** can **VIEW** ticket categories
> - **Only Super Admin** can **CREATE, UPDATE, DELETE** ticket categories

## 27. List All Ticket Categories

| Method | Endpoint             | Access              |
| ------ | -------------------- | ------------------- |
| `GET`  | `/ticket-categories` | Authenticated Users |

**Success Response (200):**

```json
{
  "message": "ticket categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "Technical Issue",
      "description": "Technical issues and system errors",
      "is_active": true,
      "created_at": "2026-01-02T08:00:00Z",
      "updated_at": "2026-01-02T08:00:00Z"
    },
    {
      "id": 2,
      "name": "Account Access",
      "description": "Account access and login problems",
      "is_active": true,
      "created_at": "2026-01-02T08:00:00Z",
      "updated_at": "2026-01-02T08:00:00Z"
    }
  ]
}
```

---

## 28. Get Active Ticket Categories

| Method | Endpoint                    | Access              |
| ------ | --------------------------- | ------------------- |
| `GET`  | `/ticket-categories/active` | Authenticated Users |

**Description:** Get only active ticket categories (where `is_active = true`).

**Success Response (200):**

```json
{
  "message": "active ticket categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "Technical Issue",
      "description": "Technical issues and system errors",
      "is_active": true,
      "created_at": "2026-01-02T08:00:00Z",
      "updated_at": "2026-01-02T08:00:00Z"
    }
  ]
}
```

---

## 29. Get Ticket Category By ID

| Method | Endpoint                 | Access              |
| ------ | ------------------------ | ------------------- |
| `GET`  | `/ticket-categories/:id` | Authenticated Users |

**Success Response (200):**

```json
{
  "message": "ticket category retrieved successfully",
  "data": {
    "id": 1,
    "name": "Technical Issue",
    "description": "Technical issues and system errors",
    "is_active": true,
    "created_at": "2026-01-02T08:00:00Z",
    "updated_at": "2026-01-02T08:00:00Z"
  }
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "category not found"
}
```

---

## 30. Create Ticket Category

| Method | Endpoint             | Access           |
| ------ | -------------------- | ---------------- |
| `POST` | `/ticket-categories` | Super Admin Only |

**Request:**

```json
{
  "name": "string (required, min 3 chars, max 100 chars, must be unique)",
  "description": "string (optional, max 255 chars)",
  "is_active": "boolean (optional, default: true)"
}
```

**Example Request:**

```json
{
  "name": "Infrastructure",
  "description": "Infrastructure and deployment issues",
  "is_active": true
}
```

**Success Response (201):**

```json
{
  "message": "ticket category created successfully",
  "data": {
    "id": 8,
    "name": "Infrastructure",
    "description": "Infrastructure and deployment issues",
    "is_active": true,
    "created_at": "2026-01-02T15:00:00Z",
    "updated_at": "2026-01-02T15:00:00Z"
  }
}
```

**Error Responses:**

- **400 Bad Request** - Validation error:

```json
{
  "error": "validation_error",
  "message": "category name cannot be blank"
}
```

- **409 Conflict** - Duplicate name:

```json
{
  "error": "conflict",
  "message": "category name already exists"
}
```

- **403 Forbidden** - Not super admin:

```json
{
  "error": "forbidden",
  "message": "super admin role required (level 10)"
}
```

---

## 31. Update Ticket Category

| Method | Endpoint                 | Access           |
| ------ | ------------------------ | ---------------- |
| `PUT`  | `/ticket-categories/:id` | Super Admin Only |

**Request:**

```json
{
  "name": "string (optional, min 3 chars, max 100 chars, must be unique)",
  "description": "string (optional, max 255 chars)",
  "is_active": "boolean (optional)"
}
```

> [!NOTE]
>
> - All fields are optional - only provided fields will be updated
> - Fields are **automatically trimmed** of leading/trailing whitespace
> - `name` must be unique if provided

**Example Request:**

```json
{
  "name": "Infrastructure & DevOps",
  "description": "Infrastructure, deployment, and DevOps issues",
  "is_active": true
}
```

**Success Response (200):**

```json
{
  "message": "ticket category updated successfully",
  "data": {
    "id": 8,
    "name": "Infrastructure & DevOps",
    "description": "Infrastructure, deployment, and DevOps issues",
    "is_active": true,
    "created_at": "2026-01-02T15:00:00Z",
    "updated_at": "2026-01-02T15:30:00Z"
  }
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "category not found"
}
```

- **409 Conflict** - Duplicate name:

```json
{
  "error": "conflict",
  "message": "category name already exists"
}
```

---

## 32. Delete Ticket Category

| Method   | Endpoint                 | Access           |
| -------- | ------------------------ | ---------------- |
| `DELETE` | `/ticket-categories/:id` | Super Admin Only |

**Success Response (200):**

```json
{
  "message": "ticket category deleted successfully"
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "category not found"
}
```

- **403 Forbidden:**

```json
{
  "error": "forbidden",
  "message": "super admin role required (level 10)"
}
```

---

### **Default Ticket Categories:**

The following categories are automatically seeded on service startup:

| ID  | Name            | Description                        |
| --- | --------------- | ---------------------------------- |
| 1   | Technical Issue | Technical issues and system errors |
| 2   | Account Access  | Account access and login problems  |
| 3   | Billing         | Billing and payment related issues |
| 4   | Feature Request | Feature requests and suggestions   |
| 5   | General Support | General support and inquiries      |
| 6   | Bug Report      | Bug reports and error tracking     |
| 7   | Other           | Other miscellaneous issues         |

---

## Ticket Status ✨

> [!NOTE] > **Access Control:**
>
> - **All Authenticated Users** can **VIEW** ticket statuses
> - **Only Super Admin** can **CREATE, UPDATE, DELETE** ticket statuses
> - 5 default statuses are seeded on startup: Open, In Progress, Pending, Resolved, Closed

> [!TIP] > **Field `is_active` Function:**
>
> - Controls status visibility in frontend/dropdown
> - `true` = Status available for selection
> - `false` = Status hidden from users (soft delete)
> - Super admin can toggle without deleting data
> - Use `GET /ticket-statuses/active` to get only active statuses

### 33. List All Ticket Statuses

| Method | Endpoint           | Access              |
| ------ | ------------------ | ------------------- |
| `GET`  | `/ticket-statuses` | Authenticated Users |

**Description:** Get all available ticket statuses.

**Success Response (200):**

```json
{
  "message": "ticket statuses retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "open",
      "description": "Tiket baru dibuat",
      "is_final": false,
      "display_order": 1,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.922122Z",
      "updated_at": "2026-01-06T02:46:19.922122Z"
    },
    {
      "id": 2,
      "name": "in_progress",
      "description": "Tiket sedang ditangani",
      "is_final": false,
      "display_order": 2,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.924566Z",
      "updated_at": "2026-01-06T02:46:19.924566Z"
    },
    {
      "id": 5,
      "name": "closed",
      "description": "Tiket ditutup",
      "is_final": true,
      "display_order": 5,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.931153Z",
      "updated_at": "2026-01-06T02:46:19.931153Z"
    }
  ]
}
```

---

### 34. Get Active Ticket Statuses

| Method | Endpoint                  | Access              |
| ------ | ------------------------- | ------------------- |
| `GET`  | `/ticket-statuses/active` | Authenticated Users |

**Description:** Get only active ticket statuses (where `is_active = true`). Use this for frontend dropdowns.

**Success Response (200):**

```json
{
  "message": "active ticket statuses retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "open",
      "description": "Tiket baru dibuat",
      "is_final": false,
      "display_order": 1,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.922122Z",
      "updated_at": "2026-01-06T02:46:19.922122Z"
    }
  ]
}
```

---

### 35. Get Ticket Status By ID

| Method | Endpoint               | Access              |
| ------ | ---------------------- | ------------------- |
| `GET`  | `/ticket-statuses/:id` | Authenticated Users |

**Success Response (200):**

```json
{
  "message": "ticket status retrieved successfully",
  "data": {
    "id": 1,
    "name": "open",
    "description": "Tiket baru dibuat",
    "is_final": false,
    "display_order": 1,
    "is_active": true,
    "created_at": "2026-01-06T02:46:19.922122Z",
    "updated_at": "2026-01-06T02:46:19.922122Z"
  }
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "status not found"
}
```

---

### **Default Ticket Statuses:**

| ID  | Name        | IsFinal | Description             |
| --- | ----------- | ------- | ----------------------- |
| 1   | open        | false   | Tiket baru dibuat       |
| 2   | in_progress | false   | Tiket sedang ditangani  |
| 3   | pending     | false   | Menunggu informasi/aksi |
| 4   | resolved    | false   | Masalah sudah teratasi  |
| 5   | closed      | true    | Tiket ditutup           |

> [!NOTE]
>
> - `is_final`: Jika `true`, tiket dengan status ini tidak bisa diubah lagi (Closed)
> - `display_order`: Urutan tampilan di UI

---

### 36. Get Allowed Status Transitions

| Method | Endpoint                           | Access              |
| ------ | ---------------------------------- | ------------------- |
| `GET`  | `/ticket-statuses/:id/transitions` | Authenticated Users |

**Description:** Get allowed next statuses that a ticket can transition to from the current status.

**Example:** From status "open" (id=1), can transition to "in_progress" or "closed"

**Success Response (200):**

```json
{
  "message": "allowed transitions retrieved successfully",
  "data": [
    {
      "id": 2,
      "name": "in_progress",
      "description": "Tiket sedang ditangani",
      "is_final": false,
      "display_order": 2,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.924566Z",
      "updated_at": "2026-01-06T02:46:19.924566Z"
    },
    {
      "id": 5,
      "name": "closed",
      "description": "Tiket ditutup",
      "is_final": true,
      "display_order": 5,
      "is_active": true,
      "created_at": "2026-01-06T02:46:19.931153Z",
      "updated_at": "2026-01-06T02:46:19.931153Z"
    }
  ]
}
```

**Error Responses:**

- **404 Not Found:**

```json
{
  "error": "not_found",
  "message": "status not found"
}
```

---

### **Status Transition Flow:**

> [!TIP]
> Transitions are **dynamic** and stored in database. Super Admin can modify using `PUT /ticket-statuses/:id/transitions`.

**Default Flow:**

```
Open → In Progress → Pending → Resolved → Closed
         ↑              │           │
         └──────────────┴───────────┘ (Reopen)
```

| From        | Default Allowed Transitions   |
| ----------- | ----------------------------- |
| Open        | In Progress, Closed           |
| In Progress | Pending, Resolved, Closed     |
| Pending     | In Progress, Resolved, Closed |
| Resolved    | Closed, In Progress (Reopen)  |
| Closed      | - (Final, tidak bisa diubah)  |

---

### 37. Set Status Transitions (Super Admin) ✨

| Method | Endpoint                           | Access           |
| ------ | ---------------------------------- | ---------------- |
| `PUT`  | `/ticket-statuses/:id/transitions` | Super Admin Only |

**Description:** Set allowed transitions for a status. Replaces all existing transitions.

**Request:**

```json
{
  "allowed_to_ids": [2, 5]
}
```

**Success Response (200):**

```json
{
  "message": "transitions updated successfully",
  "data": [
    { "id": 2, "name": "in_progress", ... },
    { "id": 5, "name": "closed", ... }
  ]
}
```

**Error Responses:**

- **404 Not Found** - Status tidak ada:

```json
{ "error": "not_found", "message": "from status not found" }
```

- **400 Bad Request** - Target tidak valid:

```json
{ "error": "validation_error", "message": "target status not found: [99]" }
```

- **400 Bad Request** - Target tidak aktif:

```json
{
  "error": "validation_error",
  "message": "cannot transition to inactive status: [3]"
}
```

- **400 Bad Request** - Array kosong:

```json
{ "error": "validation_error", "message": "allowed_to_ids cannot be empty" }
```

- **400 Bad Request** - From status final:

```json
{
  "error": "validation_error",
  "message": "cannot add transition from final status"
}
```

- **400 Bad Request** - Self-transition:

```json
{ "error": "validation_error", "message": "cannot transition to same status" }
```

---

### 38. Delete Status Transitions (Super Admin) ✨ NEW

| Method   | Endpoint                           | Access           |
| -------- | ---------------------------------- | ---------------- |
| `DELETE` | `/ticket-statuses/:id/transitions` | Super Admin Only |

**Description:** Delete specific transitions from a status.

**Request:**

```json
{
  "to_ids": [2, 5]
}
```

**Success Response (200):**

```json
{
  "message": "transitions deleted successfully",
  "data": [...] // remaining transitions
}
```

**Error Responses:**

- **404 Not Found:**

```json
{ "error": "not_found", "message": "from status not found" }
```

- **400 Bad Request** - Array kosong:

```json
{ "error": "validation_error", "message": "to_ids cannot be empty" }
```

- **400 Bad Request** - From status final:

```json
{
  "error": "validation_error",
  "message": "cannot delete transitions from final status"
}
```

- **400 Bad Request** - Target tidak ada:

```json
{ "error": "validation_error", "message": "target status not found: [99]" }
```

- **400 Bad Request** - Transition tidak ada:

```json
{
  "error": "validation_error",
  "message": "transitions not found: from 1 to [5, 6]"
}
```

---

### 39. Create Ticket Status

| Method | Endpoint           | Access           |
| ------ | ------------------ | ---------------- |
| `POST` | `/ticket-statuses` | Super Admin Only |

**Request:**

```json
{
  "name": "string (required, min 3, max 50, lowercase)",
  "description": "string (optional, max 255)",
  "is_final": "boolean (optional, default: false)",
  "display_order": "integer (optional, default: 0)",
  "is_active": "boolean (optional, default: true)"
}
```

**Success Response (201):**

```json
{
  "message": "ticket status created successfully",
  "data": {
    "id": 6,
    "name": "on_hold",
    "description": "Tiket ditunda sementara",
    "is_final": false,
    "display_order": 6,
    "is_active": true,
    "created_at": "2026-01-05T10:00:00Z",
    "updated_at": "2026-01-05T10:00:00Z"
  }
}
```

**Error Responses:**

- **409 Conflict** - Name already exists:

```json
{
  "error": "conflict",
  "message": "status name already exists"
}
```

---

### 40. Update Ticket Status

| Method | Endpoint               | Access           |
| ------ | ---------------------- | ---------------- |
| `PUT`  | `/ticket-statuses/:id` | Super Admin Only |

**Request:**

```json
{
  "name": "string (optional)",
  "description": "string (optional)",
  "is_final": "boolean (optional)",
  "display_order": "integer (optional)",
  "is_active": "boolean (optional)"
}
```

**Success Response (200):**

```json
{
  "message": "ticket status updated successfully",
  "data": { ... }
}
```

**Error Responses:**

- **404 Not Found:**

```json
{ "error": "not_found", "message": "status not found" }
```

- **403 Forbidden** - System status protection:

```json
{ "error": "forbidden", "message": "cannot rename system status" }
{ "error": "forbidden", "message": "cannot deactivate system status" }
{ "error": "forbidden", "message": "only 'closed' status can be final" }
{ "error": "forbidden", "message": "'closed' status must remain final" }
```

- **409 Conflict** - Name duplicate:

```json
{ "error": "conflict", "message": "status name already exists" }
```

---

### 41. Delete Ticket Status (Soft Delete)

| Method   | Endpoint               | Access           |
| -------- | ---------------------- | ---------------- |
| `DELETE` | `/ticket-statuses/:id` | Super Admin Only |

**Description:** Soft delete a ticket status by setting `is_active = false`. The status will no longer appear in dropdowns but remains in database.

**Success Response (200):**

```json
{
  "message": "ticket status deactivated successfully"
}
```

**Error Responses:**

- **403 Forbidden** - Cannot delete system status:

```json
{ "error": "forbidden", "message": "cannot delete system status" }
```

- **404 Not Found:**

```json
{ "error": "not_found", "message": "status not found" }
```

---

### 42. Force Delete Ticket Status (Cascade) ✨ NEW

| Method   | Endpoint                     | Access           |
| -------- | ---------------------------- | ---------------- |
| `DELETE` | `/ticket-statuses/:id/force` | Super Admin Only |

**Description:** Permanently delete a ticket status with cascade removal of all associated transitions.

> [!WARNING]
> This will **permanently remove** the status and **delete all transitions** pointing to or from this status. Use with caution!

**Success Response (200):**

```json
{
  "message": "ticket status force deleted successfully (cascade)",
  "status_name": "on_hold",
  "removed_transitions": 3
}
```

**Success Response (No transitions):**

```json
{
  "message": "ticket status force deleted successfully (cascade)"
}
```

**Error Responses:**

- **403 Forbidden** - Cannot delete system status:

```json
{ "error": "forbidden", "message": "cannot delete system status" }
```

- **404 Not Found:**

```json
{ "error": "not_found", "message": "status not found" }
```

---

### **Ticket Status Field Explanations:**

| Field           | Type      | Description                                                                              |
| --------------- | --------- | ---------------------------------------------------------------------------------------- |
| `id`            | integer   | Unique identifier                                                                        |
| `name`          | string    | Internal identifier (lowercase, e.g., "open", "in_progress")                             |
| `display_name`  | string    | User-friendly name shown in UI (e.g., "Open", "In Progress")                             |
| `description`   | string    | Human-readable description of the status                                                 |
| `is_final`      | boolean   | If `true`, tickets cannot transition from this status (e.g., "closed")                   |
| `display_order` | integer   | Sorting order for UI display                                                             |
| `is_active`     | boolean   | **Controls visibility:** `true` = available in dropdowns, `false` = hidden (soft delete) |
| `created_at`    | timestamp | Record creation time                                                                     |
| `updated_at`    | timestamp | Last update time                                                                         |

> [!IMPORTANT] > **is_active Use Cases:**
>
> - **Frontend Dropdown:** Use `GET /ticket-statuses/active` to show only active statuses
> - **Soft Delete:** Super admin can deactivate instead of deleting
> - **Temporary Hide:** Disable statuses without losing historical data
> - **Data Integrity:** Existing tickets keep reference to inactive statuses

---

## Tickets (Main Entity) 🎫 NEW

> [!NOTE] > **Access Control:**
>
> - **All Authenticated Users** can **CREATE** tickets
> - **Customers** can only **VIEW** their own tickets
> - **Agent/Admin/Super Admin** can **VIEW ALL** tickets
> - **Agent** can **UPDATE** tickets assigned to them
> - **Admin/Super Admin** can **UPDATE** any ticket and **ASSIGN** agents
> - **Super Admin** can **DELETE** tickets

> [!IMPORTANT] > **SLA (Service Level Agreement) - Not Yet Implemented:**
>
> - Priority field exists but SLA logic (response time tracking) will be implemented in **next sprint**
> - Current implementation: Basic ticket management without automatic SLA calculations
> - Next sprint will add: Response time tracking, escalation, and SLA breach alerts

---

### 42. Create Ticket

| Method | Endpoint   | Access              |
| ------ | ---------- | ------------------- |
| `POST` | `/tickets` | Authenticated Users |

**Description:** Create a new support ticket. Available to all authenticated users (customer, agent, admin, super_admin). Due date is automatically calculated based on priority via SLA service.

**Request:**

```json
{
  "subject": "string (required, 5-200 chars)",
  "description": "string (required, min 10 chars)",
  "category_id": "integer (required)",
  "priority": "string (optional: low, medium, high, critical, default: medium)",
  "attachment": "string (optional, file URL from upload endpoint)"
}
```

**Success Response (201):**

```json
{
  "message": "ticket created successfully",
  "data": {
    "id": 1,
    "subject": "Cannot login to system",
    "description": "I forgot my password and cannot reset it",
    "category_id": 2,
    "status_id": 1,
    "priority": "high",
    "attachment": "/uploads/20260106112600_a1b2c3d4.pdf",
    "created_by": 10,
    "assigned_to": null,
    "due_date": "2026-01-06T19:30:00Z",
    "is_overdue": false,
    "category": {
      "id": 2,
      "name": "Account Access",
      "description": "Account access and login problems",
      "is_active": true
    },
    "status": {
      "id": 1,
      "name": "open",
      "description": "Tiket baru dibuat",
      "is_final": false,
      "display_order": 1,
      "is_active": true
    },
    "created_at": "2026-01-06T11:30:00Z",
    "updated_at": "2026-01-06T11:30:00Z"
  }
}
```

**SLA Due Date Calculation:**

| Priority | Resolution Time | Due Date Example (created 11:30) |
| -------- | --------------- | -------------------------------- |
| Low      | 72 hours (3d)   | 3 days later                     |
| Medium   | 24 hours        | Next day 11:30                   |
| High     | 8 hours         | Same day 19:30                   |
| Critical | 4 hours         | Same day 15:30                   |

**Business Rules:**

- `status_id` automatically set to "open" (id: 1)
- `created_by` automatically set from JWT token
- `assigned_to` automatically set to `null` (unassigned)
- Default `priority` is "medium" if not provided
- Category must exist and be active
- `due_date` automatically calculated from SLA based on priority
- `is_overdue` defaults to `false`, updated by SLA cron job
- If SLA service unavailable, ticket created without due_date (graceful fallback)

**Error Responses:**

- **400 Bad Request** - Validation error:

```json
{ "error": "validation_error", "message": "subject cannot be blank" }
{ "error": "validation_error", "message": "category is not active" }
{ "error": "validation_error", "message": "invalid priority value" }
```

- **404 Not Found** - Category not found:

```json
{ "error": "not_found", "message": "category not found" }
```

---

### 43. List All Tickets

| Method | Endpoint   | Access              |
| ------ | ---------- | ------------------- |
| `GET`  | `/tickets` | Authenticated Users |

**Description:** Get all tickets with filters and pagination.

- **Customer:** Only see own tickets (`created_by = user_id`)
- **Agent/Admin/Super Admin:** See all tickets

**Query Parameters:**

| Parameter          | Type    | Description                                                                                           |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------- |
| `status_id`        | integer | Filter by status ID                                                                                   |
| `category_id`      | integer | Filter by category ID                                                                                 |
| `priority`         | string  | Filter by priority (low, medium, high, critical)                                                      |
| `assigned_to`      | integer | Filter by assigned agent ID                                                                           |
| `is_assigned`      | boolean | Filter by assignment status (`true` = assigned, `false` = unassigned)                                 |
| `created_by`       | integer | Filter by creator user ID                                                                             |
| `is_overdue`       | boolean | Filter overdue tickets (`true` / `false`)                                                             |
| `response_delayed` | boolean | Filter response-delayed tickets (`true` = past response deadline without first response)              |
| `search`           | string  | Search in subject and description (case-insensitive, partial match)                                   |
| `sort_by`          | string  | Sort field: `created_at`, `updated_at`, `due_date`, `priority`, `status_id`, `category_id`, `subject` |
| `order`            | string  | Sort direction: `asc` or `desc` (default: `desc`)                                                     |
| `page`             | integer | Page number (default: 1)                                                                              |
| `limit`            | integer | Items per page (default: 10, max: 100)                                                                |

> [!NOTE]
>
> - **Default sort:** Without `sort_by`, tickets are sorted by response-delayed first (most delayed), then by `created_at DESC` (newest first)
> - **Custom sort:** When `sort_by` is provided, the delayed-first ordering is replaced by the specified sort field

**Example Request:**

```
GET /tickets?status_id=1&priority=high&page=1&limit=20
GET /tickets?assigned_to=5&category_id=2
GET /tickets?is_assigned=false                          ← Get unassigned tickets
GET /tickets?is_assigned=true&status_id=2               ← Get assigned tickets with status in_progress
GET /tickets?search=login                               ← Search "login" in subject & description
GET /tickets?search=password&priority=high              ← Search + filter combined
GET /tickets?sort_by=created_at&order=desc
GET /tickets?sort_by=due_date&order=asc
GET /tickets?sort_by=updated_at&order=desc&priority=high
GET /tickets?is_overdue=true&sort_by=due_date&order=asc
```

**Success Response (200):**

```json
{
  "message": "tickets retrieved successfully",
  "data": [
    {
      "id": 1,
      "subject": "Cannot login to system",
      "description": "I forgot my password",
      "priority": "high",
      "attachment": "/uploads/file.pdf",
      "created_by": 10,
      "assigned_to": 5,
      "category": {
        "id": 2,
        "name": "Account Access",
        "description": "Account access problems"
      },
      "status": {
        "id": 2,
        "name": "in_progress",
        "description": "Tiket sedang ditangani"
      },
      "created_at": "2026-01-06T11:30:00Z",
      "updated_at": "2026-01-06T11:35:00Z"
    }
  ],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 20
  }
}
```

---

### 44. Get Ticket By ID (with Comments) ✨ UPDATED

| Method | Endpoint       | Access              |
| ------ | -------------- | ------------------- |
| `GET`  | `/tickets/:id` | Authenticated Users |

**Description:** Get ticket details by ID with chat history (comments) from ms-chat service.

- **Customer:** Can only view own tickets
- **Agent/Admin/Super Admin:** Can view all tickets

> [!NOTE]
>
> - Comments are fetched from **ms-chat service** (port 8083)
> - If there are no comments, the `comments` field will not be included in the response
> - Comments include attachment URLs if available
> - Limited to 50 most recent comments

**Success Response (200):**

```json
{
  "message": "ticket retrieved successfully",
  "data": {
    "id": 1,
    "subject": "Cannot login to system",
    "description": "I forgot my password and cannot reset it",
    "category_id": 2,
    "status_id": 2,
    "priority": "high",
    "attachment": "/uploads/20260106112600_a1b2c3d4.pdf",
    "created_by": 10,
    "assigned_to": 5,
    "creator_info": {
      "id": 10,
      "name": "John Customer",
      "email": "customer@test.com",
      "firstname": "John"
    },
    "assignee_info": {
      "id": 5,
      "name": "Agent Smith",
      "email": "agent@test.com",
      "firstname": "Agent"
    },
    "category": { ... },
    "status": { ... },
    "created_at": "2026-01-06T11:30:00Z",
    "updated_at": "2026-01-06T11:35:00Z"
  },
  "comments": {
    "data": [
      {
        "id": 1,
        "ticket_id": 1,
        "user_id": 10,
        "user_name": "customer@test.com",
        "user_role": "customer",
        "content": "Halo, saya butuh bantuan",
        "attachment": "/uploads/screenshot.png",
        "created_at": "2026-01-06T11:31:00Z"
      },
      {
        "id": 2,
        "ticket_id": 1,
        "user_id": 5,
        "user_name": "agent@test.com",
        "user_role": "agent",
        "content": "Baik, saya akan bantu",
        "created_at": "2026-01-06T11:32:00Z"
      }
    ],
    "total": 2
  }
}
```

**Comment Fields:**

- `id`: Comment ID
- `ticket_id`: Ticket ID
- `user_id`: User who posted
- `user_name`: User email/username
- `user_role`: User role (customer, agent, admin)
- `content`: Comment text
- `attachment`: File URL (optional, only if file attached)
- `created_at`: Timestamp

**Error Responses:**

- **403 Forbidden** - Customer accessing other's ticket:

```json
{
  "error": "forbidden",
  "message": "access denied: you can only view your own tickets"
}
```

- **404 Not Found:**

```json
{ "error": "not_found", "message": "ticket not found" }
```

---

### 45. Get Tickets By Status

| Method | Endpoint                     | Access              |
| ------ | ---------------------------- | ------------------- |
| `GET`  | `/tickets/status/:status_id` | Authenticated Users |

**Description:** Get tickets filtered by specific status with pagination.

**Example:**

```
GET /tickets/status/1?page=1&limit=20
```

**Response:** Same as List All Tickets

---

### 46. Update Ticket

| Method | Endpoint       | Access           |
| ------ | -------------- | ---------------- |
| `PUT`  | `/tickets/:id` | Agent Level (≥5) |

**Description:** Update ticket information.

**Access Rules:**

- **Agent (level 5):** Can only update tickets assigned to them. Can re-assign to other agents (level ≥5).
- **Admin (level 7):** Can update any ticket and assign to agents.
- **Super Admin (level 10):** Full access.

**Assign Rules:**

| Role             | Can Assign? | Condition                                                 |
| ---------------- | ----------- | --------------------------------------------------------- |
| Agent (level 5)  | ✅          | Only tickets assigned to them, to other agents (level ≥5) |
| Admin (level 7+) | ✅          | Any ticket, to agents or higher                           |
| Customer (< 5)   | ❌          | Cannot assign                                             |

**Request:**

```json
{
  "subject": "string (optional, 5-200 chars)",
  "description": "string (optional, min 10 chars)",
  "category_id": "integer (optional)",
  "status_id": "integer (optional, must follow transition rules)",
  "priority": "string (optional: low, medium, high, critical)",
  "assigned_to": "integer (optional, agent can re-assign their tickets)",
  "attachment": "string (optional, file URL)"
}
```

**Example - Agent updates status:**

```json
{
  "status_id": 2,
  "priority": "critical"
}
```

**Example - Agent re-assigns to another agent:**

```json
{
  "assigned_to": 8
}
```

**Example - Admin assigns ticket:**

```json
{
  "assigned_to": 5,
  "status_id": 2
}
```

**Success Response (200):**

```json
{
  "message": "ticket updated successfully",
  "data": { ... }
}
```

**Error Responses:**

- **403 Forbidden** - Agent accessing unassigned ticket:

```json
{ "error": "forbidden", "message": "access denied: you can only update tickets assigned to you" }
{ "error": "forbidden", "message": "access denied: you can only re-assign tickets assigned to you" }
```

- **400 Bad Request** - Invalid assignee:

```json
{ "error": "validation_error", "message": "invalid assignee: user not found" }
{ "error": "validation_error", "message": "invalid assignee: user is inactive" }
{ "error": "validation_error", "message": "invalid assignee: user role level 1 is below minimum required level 5 (agent)" }
```

- **400 Bad Request** - Invalid transition:

```json
{ "error": "validation_error", "message": "cannot transition from 'open' to 'resolved'" }
{ "error": "validation_error", "message": "category is not active" }
{ "error": "validation_error", "message": "status is not active" }
```

---

### 47. Delete Ticket

| Method   | Endpoint       | Access           |
| -------- | -------------- | ---------------- |
| `DELETE` | `/tickets/:id` | Super Admin Only |

**Description:** Permanently delete a ticket (hard delete).

**Success Response (200):**

```json
{
  "message": "ticket deleted successfully"
}
```

**Error Responses:**

- **404 Not Found:**

```json
{ "error": "not_found", "message": "ticket not found" }
```

---

### 48. Upload File (Attachment) ⚠️ UPDATED

| Method | Endpoint  | Access              |
| ------ | --------- | ------------------- |
| `POST` | `/upload` | Authenticated Users |

**Description:** Upload file attachment for tickets. Files are tracked in database with ownership information for security.

**Request:**

- Content-Type: `multipart/form-data`
- Field name: `file`

**Allowed File Types:**

- Images: jpg, jpeg, png, gif
- Documents: pdf, doc, docx, txt
- Archives: zip

**File Size Limit:** 5 MB

> [!NOTE]
> For Nginx deployments, ensure `client_max_body_size 5M;` is configured.

**Example:**

```bash
curl -X POST http://localhost:8000/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@screenshot.png"
```

**Success Response (200):**

```json
{
  "message": "file uploaded successfully",
  "data": {
    "id": 1,
    "filename": "20260106112600_a1b2c3d4.png",
    "original_name": "screenshot.png",
    "size": 102400,
    "url": "/uploads/20260106112600_a1b2c3d4.png"
  }
}
```

**Usage in Ticket:**

```json
{
  "subject": "Bug report",
  "description": "See screenshot",
  "category_id": 6,
  "attachment": "/uploads/20260106112600_a1b2c3d4.png"
}
```

**Error Responses:**

- **400 Bad Request:**

```json
{ "error": "validation_error", "message": "file is required" }
{ "error": "validation_error", "message": "file size exceeds maximum limit of 5 MB" }
{ "error": "validation_error", "message": "file type not allowed. Allowed: jpg, jpeg, png, gif, pdf, doc, docx, txt, zip" }
```

- **500 Internal Server Error:**

```json
{ "error": "upload_failed", "message": "failed to save file" }
{ "error": "upload_failed", "message": "failed to save attachment record" }
```

---

### 49. Download File (Attachment) ⚠️ UPDATED - Security Enhanced

| Method | Endpoint             | Access                    |
| ------ | -------------------- | ------------------------- |
| `GET`  | `/uploads/:filename` | Authenticated + Ownership |

**Description:** Download/view uploaded file attachment with ownership validation.

> [!IMPORTANT]
> **Security Fix (Bug #Bug-CT-001):** File downloads now require ownership validation. Users can only download files they have permission to access.

**Access Control Rules:**

| Role       | Access Level                                               |
| ---------- | ---------------------------------------------------------- |
| Admin (5+) | Can access ALL files                                       |
| User (1-4) | Can access: own uploads OR files attached to their tickets |

**Detailed Access:**

- **Own uploads:** Files uploaded by the user (`uploaded_by = user_id`)
- **Ticket access:** Files attached to tickets where user is creator (`created_by`) or assignee (`assigned_to`)

**Example:**

```bash
curl -X GET http://localhost:8000/uploads/20260106112600_a1b2c3d4.png \
  -H "Authorization: Bearer $TOKEN" \
  --output downloaded_file.png
```

**Response:** File binary with appropriate Content-Type header

**Error Responses:**

- **400 Bad Request:**

```json
{ "error": "invalid_filename", "message": "invalid filename" }
```

- **401 Unauthorized:**

```json
{ "error": "unauthorized", "message": "user not authenticated" }
```

- **403 Forbidden:**

```json
{
  "error": "forbidden",
  "message": "you don't have permission to access this file"
}
```

- **404 Not Found:**

```json
{ "error": "not_found", "message": "file not found" }
```

---

### Attachment Database Model ✨ NEW

Attachments are now tracked in the database for security and audit purposes.

**Table: `attachments`**

| Column        | Type       | Description                   |
| ------------- | ---------- | ----------------------------- |
| id            | int        | Primary key, auto-increment   |
| filename      | string     | Unique generated filename     |
| original_name | string     | Original filename from upload |
| file_size     | int64      | File size in bytes            |
| mime_type     | string     | MIME type (e.g., image/png)   |
| uploaded_by   | int        | User ID who uploaded the file |
| ticket_id     | int (null) | Linked ticket ID (optional)   |
| created_at    | timestamp  | Upload timestamp              |

---

### **Ticket Priority Levels:**

| Priority   | Description                      | SLA Response Time (Next Sprint) |
| ---------- | -------------------------------- | ------------------------------- |
| `low`      | Non-urgent issues                | 3 days                          |
| `medium`   | Standard issues (default)        | 1 day                           |
| `high`     | Important issues affecting users | 4 hours                         |
| `critical` | System down, security issues     | 1 hour                          |

> [!WARNING] > **SLA Implementation Note:**
>
> - Priority field is functional and can be used for filtering
> - Automatic SLA tracking (response time, escalation) not yet implemented
> - Will be implemented in **next sprint** with:
>   - Response time calculation
>   - Automatic escalation on SLA breach
>   - Notification system for approaching deadlines

---

### **Ticket Workflow:**

```
Customer creates ticket (status: open, assigned_to: null)
         ↓
Admin/Agent assigns ticket (assigned_to: agent_id)
         ↓
Agent accepts & starts work (status: in_progress)
         ↓
Agent requests info (status: pending) ← Customer can respond
         ↓
Agent resolves issue (status: resolved)
         ↓
Customer confirms (status: closed) - FINAL
```

**Reopen Flow:**

```
Resolved → In Progress (if issue persists)
```

---

### **RBAC Summary for Tickets:**

| Action        | Customer               | Agent                  | Admin  | Super Admin |
| ------------- | ---------------------- | ---------------------- | ------ | ----------- |
| Create        | ✅ Own                 | ✅ Own                 | ✅ Own | ✅ Own      |
| List All      | ❌ Own only            | ✅ All                 | ✅ All | ✅ All      |
| Get By ID     | ✅ Own only            | ✅ All                 | ✅ All | ✅ All      |
| Update        | ❌                     | ✅ Assigned only       | ✅ All | ✅ All      |
| Update Status | ❌                     | ✅ Assigned only       | ✅ All | ✅ All      |
| Assign Agent  | ❌                     | ✅ Re-assign own       | ✅     | ✅          |
| Delete        | ❌                     | ❌                     | ❌     | ✅          |
| Upload File   | ✅                     | ✅                     | ✅     | ✅          |
| Download File | ✅ Own uploads/tickets | ✅ Own uploads/tickets | ✅ All | ✅ All      |

---

# Chat Service (ms-chat) ✨ NEW

> [!NOTE] > **Access Control:**
>
> - **All Authenticated Users** can read/write comments on their accessible tickets
> - **Customer:** Can comment on tickets they created
> - **Agent:** Can comment on tickets assigned to them
> - **Admin/Super Admin:** Can comment on all tickets

## 50. Get Ticket Comments (Chat History)

| Method | Endpoint                | Access              |
| ------ | ----------------------- | ------------------- |
| `GET`  | `/tickets/:id/comments` | Authenticated Users |

**Description:** Get all comments/chat messages for a ticket with pagination.

**Query Parameters:**

| Parameter | Type    | Description                            |
| --------- | ------- | -------------------------------------- |
| `page`    | integer | Page number (default: 1)               |
| `limit`   | integer | Items per page (default: 50, max: 100) |

**Example Request:**

```bash
curl -X GET "http://localhost:8083/tickets/1/comments?page=1&limit=50" \
  -H "Authorization: Bearer $TOKEN"
```

**Success Response (200):**

```json
{
  "message": "comments retrieved successfully",
  "data": [
    {
      "id": 1,
      "ticket_id": 1,
      "user_id": 5,
      "user_name": "customer@test.com",
      "firstname": "John",
      "user_role": "customer",
      "content": "Halo, saya butuh bantuan dengan masalah login",
      "created_at": "2026-01-20T09:00:00Z"
    },
    {
      "id": 2,
      "ticket_id": 1,
      "user_id": 10,
      "user_name": "agent@test.com",
      "firstname": "Agent",
      "user_role": "agent",
      "content": "Baik, saya akan bantu. Bisa jelaskan masalahnya?",
      "created_at": "2026-01-20T09:05:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 2
  }
}
```

---

## 51. Create Comment (REST API)

| Method | Endpoint                | Access              |
| ------ | ----------------------- | ------------------- |
| `POST` | `/tickets/:id/comments` | Authenticated Users |

**Description:** Create a new comment on a ticket via REST API.

**Request:**

```json
{
  "content": "string (required, min 1 char)"
}
```

**Example Request:**

```bash
curl -X POST http://localhost:8083/tickets/1/comments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "Halo, saya butuh bantuan dengan masalah login"}'
```

**Success Response (201):**

```json
{
  "message": "comment created successfully",
  "data": {
    "id": 1,
    "ticket_id": 1,
    "user_id": 5,
    "user_name": "customer@test.com",
    "user_role": "customer",
    "content": "Halo, saya butuh bantuan dengan masalah login",
    "created_at": "2026-01-20T09:00:00Z"
  }
}
```

**Error Responses:**

- **400 Bad Request** - Validation error:

```json
{ "error": "validation_error", "message": "content is required" }
```

---

## 52. Real-time Chat (WebSocket) ✨

| Protocol | Endpoint                      | Access              |
| -------- | ----------------------------- | ------------------- |
| `WS`     | `/ws/tickets/:id?token=<jwt>` | Authenticated Users |

**Description:** Connect to real-time chat for a ticket using WebSocket. Messages are automatically saved to database and broadcast to all connected clients in the same ticket room.

> [!IMPORTANT]
> WebSocket connections use JWT token via **query parameter** instead of Authorization header.

**Connection URL:**

```
ws://localhost:8083/ws/tickets/1?token=<your_jwt_token>
```

**Testing with wscat:**

```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c "ws://localhost:8083/ws/tickets/1?token=$TOKEN"
```

**Testing with Postman:**

1. Create new **WebSocket** request
2. Enter URL: `ws://localhost:8083/ws/tickets/1?token=<paste_token>`
3. Click **Connect**
4. Send messages in JSON format

**Send Message Format:**

```json
{
  "type": "message",
  "content": "Hello from WebSocket!"
}
```

**Receive Message Format (Broadcast):**

```json
{
  "id": 3,
  "ticket_id": 1,
  "user_id": 5,
  "user_name": "customer@test.com",
  "user_role": "customer",
  "content": "Hello from WebSocket!",
  "created_at": "2026-01-20T10:00:00Z"
}
```

**Connection Flow:**

```
1. Client connects with JWT token
2. Server validates token
3. Client joins ticket "room"
4. Client sends message
5. Server saves to database
6. Server broadcasts to all clients in room
7. All clients receive message in real-time
```

**Error Cases:**

- **401 Unauthorized** - Missing or invalid token
- **403 Forbidden** - User doesn't have access to ticket
- Connection closes if token expires

---

### **TicketComment Database Model:**

| Field        | Type      | Description                        |
| ------------ | --------- | ---------------------------------- |
| `id`         | int (PK)  | Auto-increment primary key         |
| `ticket_id`  | int       | Foreign key to ticket              |
| `user_id`    | int       | ID of user who sent message        |
| `user_name`  | string    | Display name (email)               |
| `user_role`  | string    | Role: customer, agent, admin, etc. |
| `content`    | text      | Message content                    |
| `created_at` | timestamp | When message was sent              |

---

### **RBAC Summary for Chat:**

| Action         | Customer       | Agent       | Admin  | Super Admin |
| -------------- | -------------- | ----------- | ------ | ----------- |
| Read Comments  | ✅ Own tickets | ✅ Assigned | ✅ All | ✅ All      |
| Write Comments | ✅ Own tickets | ✅ Assigned | ✅ All | ✅ All      |
| WebSocket Chat | ✅ Own tickets | ✅ Assigned | ✅ All | ✅ All      |

---

# Internal Endpoints

## 50. Create User (Internal)

| Method | Endpoint          | Access           |
| ------ | ----------------- | ---------------- |
| `POST` | `/internal/users` | X-Internal-Token |

> [!CAUTION]
> NOT exposed through gateway. Only accessible by ms-auth service.

**Request:**

```json
{
  "email": "string (required, email format)",
  "username": "string (required, min 3 chars)",
  "password": "string (required, min 8 chars)",
  "name": "string (required)",
  "last_name": "string (optional)",
  "role": "string (optional, any custom role name)",
  "role_id": "integer (optional, role ID)"
}
```

**Success Response (201):**

```json
{
  "data": {
    "id": 10,
    "email": "user@example.com",
    "username": "user123",
    "name": "John",
    "last_name": "Doe",
    "role_id": 4,
    "is_first_login": true
  }
}
```

**Error Responses:**

- **400 Bad Request** - Invalid role name:

```json
{
  "error": "invalid_role",
  "message": "role not found: the specified role name does not exist in the database",
  "hint": "please create the role first or use an existing role name"
}
```

- **409 Conflict** - Email/username exists:

```json
{
  "error": "conflict",
  "message": "email already exists"
}
```

---

## 51. Validate User (Internal)

| Method | Endpoint                   | Access           |
| ------ | -------------------------- | ---------------- |
| `POST` | `/internal/users/validate` | X-Internal-Token |

**Request:**

```json
{
  "identifier": "string (required, email or username)",
  "password": "string (required)"
}
```

---

# Common Specifications

## HTTP Status Codes

| Code | Description        |
| ---- | ------------------ |
| 200  | Request successful |
| 201  | Resource created   |
| 400  | Invalid request    |
| 401  | Unauthorized       |
| 403  | Forbidden          |
| 404  | Not found          |
| 500  | Server error       |

## Authentication

- **Format:** `Bearer <token>`
- **Header:** `Authorization`
- **Expiry:** 24 hours
- **Claims:** `user_id`, `email`, `role`, `exp`, `iat`

## Error Response Format

```json
{
  "error": "error_type",
  "message": "human readable message",
  "fields": {
    "field_name": "field error message"
  }
}
```

---

# Role Hierarchy

| Level | Role        | Description            |
| ----- | ----------- | ---------------------- |
| 1     | customer    | Regular user (default) |
| 5     | agent       | Support staff          |
| 8     | admin       | System administrator   |
| 10    | super_admin | Highest privilege      |

## User Creation Rights

```mermaid
graph TD
    SA[Super Admin] -->|can create| Admin
    SA -->|can create| Agent
    SA -->|can create| Customer

    Admin[Admin] -->|can create| AgentByAdmin[Agent]
    Admin -->|can create| CustomerByAdmin[Customer]

    SuperEndpoint["/auth/super"] -->|only creates| SuperAdmin[Super Admin]
```

---

# Environment Variables

## ms-auth (.env)

```env
APP_PORT=8080
JWT_SECRET=<64+ chars secret>
JWT_EXPIRES_IN=24h
INTERNAL_TOKEN=<32+ chars secret>
USER_SERVICE_URL=http://localhost:8081
SUPER_ADMIN_SECRET=<32+ chars secret>
```

## ms-user-management (.env)

```env
APP_PORT=8081
JWT_SECRET=<same as ms-auth>
INTERNAL_TOKEN=<same as ms-auth>
DATABASE_URL=postgres://user:pass@localhost:5432/dbname?sslmode=disable
```

## ms-gateway (.env)

```env
APP_PORT=8000
AUTH_SERVICE_URL=http://localhost:8080
USER_SERVICE_URL=http://localhost:8081
TICKET_SERVICE_URL=http://localhost:8082
CHAT_SERVICE_URL=http://localhost:8083
```

## ms-ticket (.env)

```env
APP_PORT=8082
JWT_SECRET=<same as ms-auth>
INTERNAL_TOKEN=<same as ms-auth>
DATABASE_URL=postgres://user:pass@localhost:5432/ticketing_db?sslmode=disable
UPLOAD_DIR=./uploads
```

**Notes:**

- `UPLOAD_DIR`: Directory for uploaded file attachments (default: `./uploads`)
- Directory will be created automatically on startup if not exists

## ms-chat (.env) ✨ NEW

```env
APP_PORT=8083
DATABASE_URL=postgres://user:pass@localhost:5432/chat_db?sslmode=disable
JWT_SECRET=<same as ms-auth>
INTERNAL_TOKEN=<same as ms-auth>
TICKET_SERVICE_URL=http://localhost:8082
```

**Notes:**

- Uses separate database `chat_db` for chat history
- `TICKET_SERVICE_URL`: For future ticket access validation

---

# Testing Examples

```bash
# 1. Create Super Admin
curl -X POST http://localhost:8080/auth/super \
  -H "Content-Type: application/json" \
  -H "X-Super-Admin-Secret: <secret>" \
  -d '{"email": "superadmin@test.com", "username": "superadmin", "password": "SuperPass123!", "name": "Super", "last_name": "Admin"}'

# 2. Login as Super Admin (returns access_token + refresh_token)
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier": "superadmin@test.com", "password": "SuperPass123!"}'
# Response: { "data": { "access_token": "eyJ...", "refresh_token": "uuid...", "expires_in": 900, "user": {...} } }

# 2b. Login with username
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier": "superadmin", "password": "SuperPass123!"}'

# 2c. Refresh Token (when access_token expires)
curl -X POST http://localhost:8080/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "609c1f38-a65a-4ba5-aa1c-f2e3c142915e"}'
# Response: { "data": { "access_token": "eyJ_NEW...", "expires_in": 900 } }

# 2d. Logout (blacklist access token + delete refresh token)
curl -X POST http://localhost:8080/auth/logout \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "609c1f38-a65a-4ba5-aa1c-f2e3c142915e"}'

# 3. Create Admin (as Super Admin)
curl -X POST http://localhost:8080/auth/register \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@test.com", "username": "admin", "password": "AdminPass123!", "name": "Admin", "last_name": "User", "role": "admin"}'

# 4. Create Customer (as Admin)
curl -X POST http://localhost:8080/auth/register \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "customer@test.com", "username": "customer1", "password": "Pass123!", "name": "Customer", "last_name": "One", "role": "customer"}'

# 5. Get My Profile
curl -X GET http://localhost:8081/users/me \
  -H "Authorization: Bearer $TOKEN"

# 6. List All Users
curl -X GET "http://localhost:8081/users?page=1&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# 7. Get User with Role Details
curl -X GET http://localhost:8081/users/1/with-role \
  -H "Authorization: Bearer $TOKEN"

# 8. List Roles
curl -X GET http://localhost:8081/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 9. List All Ticket Categories (any authenticated user)
curl -X GET http://localhost:8000/ticket-categories \
  -H "Authorization: Bearer $TOKEN"

# 10. Get Active Ticket Categories Only
curl -X GET http://localhost:8000/ticket-categories/active \
  -H "Authorization: Bearer $TOKEN"

# 11. Create Ticket Category (super admin only)
curl -X POST http://localhost:8000/ticket-categories \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Infrastructure", "description": "Infrastructure and deployment issues", "is_active": true}'

# 12. Update Ticket Category (super admin only)
curl -X PUT http://localhost:8000/ticket-categories/8 \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Infrastructure & DevOps", "description": "Infrastructure, deployment, and DevOps issues"}'

# 13. Delete Ticket Category (super admin only)
curl -X DELETE http://localhost:8000/ticket-categories/8 \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN"

# 14. Upload File Attachment (any authenticated user)
curl -X POST http://localhost:8000/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@screenshot.png"

# 15. Create Ticket (any authenticated user)
curl -X POST http://localhost:8000/tickets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Cannot login to system",
    "description": "I forgot my password and cannot reset it. Please help me access my account.",
    "category_id": 2,
    "priority": "high",
    "attachment": "/uploads/20260106112600_a1b2c3d4.png"
  }'

# 16. List All Tickets (customer sees own, agent+ sees all)
curl -X GET "http://localhost:8000/tickets?page=1&limit=20" \
  -H "Authorization: Bearer $TOKEN"

# 17. List Tickets with Filters
curl -X GET "http://localhost:8000/tickets?status_id=1&priority=high&page=1&limit=10" \
  -H "Authorization: Bearer $AGENT_TOKEN"

# 18. Get Ticket by ID
curl -X GET http://localhost:8000/tickets/1 \
  -H "Authorization: Bearer $TOKEN"

# 19. Get Tickets by Status
curl -X GET "http://localhost:8000/tickets/status/1?page=1&limit=20" \
  -H "Authorization: Bearer $AGENT_TOKEN"

# 20. Assign Ticket to Agent (admin/super admin only)
curl -X PUT http://localhost:8000/tickets/1 \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"assigned_to": 5}'

# 21. Update Ticket Status (agent can update assigned tickets)
curl -X PUT http://localhost:8000/tickets/1 \
  -H "Authorization: Bearer $AGENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status_id": 2,
    "priority": "critical"
  }'

# 22. Download Attachment
curl -X GET http://localhost:8000/uploads/20260106112600_a1b2c3d4.png \
  -H "Authorization: Bearer $TOKEN" \
  --output downloaded_file.png

# 23. Delete Ticket (super admin only)
curl -X DELETE http://localhost:8000/tickets/1 \
  -H "Authorization: Bearer $SUPERADMIN_TOKEN"

# ==================== CHAT SERVICE (ms-chat) ====================

# 24. Get Ticket Comments (Chat History)
curl -X GET "http://localhost:8083/tickets/1/comments?page=1&limit=50" \
  -H "Authorization: Bearer $TOKEN"

# 25. Create Comment via REST
curl -X POST http://localhost:8083/tickets/1/comments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"content": "Halo, saya butuh bantuan dengan masalah login"}'

# 26. WebSocket Chat (using wscat)
# Install: npm install -g wscat
wscat -c "ws://localhost:8083/ws/tickets/1?token=$TOKEN"
# Send message: {"type": "message", "content": "Hello via WebSocket!"}
```

---

# Changelog

## Version 2.8 (2026-01-20) - Chat Service ✨ NEW

- ✨ **New Microservice: ms-chat** - Dedicated chat service for ticket comments (port 8083)
- ✨ **WebSocket Real-time Chat** - Gorilla WebSocket for live messaging
- ✨ **REST API for Chat History** - GET/POST endpoints for comments
- ✨ **Room-based Messaging** - Each ticket is a separate chat room
- ✨ **Auto Message Persistence** - All WebSocket messages saved to database
- 🗄️ **Separate Database** - `chat_db` for chat history storage
- 🌐 **Gateway Integration** - Routes proxied via ms-gateway

**API Endpoints Added:**

- `GET /tickets/:id/comments` - Get chat history with pagination
- `POST /tickets/:id/comments` - Create comment via REST
- `WS /ws/tickets/:id?token=xxx` - Real-time WebSocket chat

**Database Model:**

| Field      | Type      | Description           |
| ---------- | --------- | --------------------- |
| id         | int       | Primary key           |
| ticket_id  | int       | Ticket ID             |
| user_id    | int       | User who sent message |
| user_name  | string    | Display name          |
| user_role  | string    | customer/agent/admin  |
| content    | text      | Message content       |
| created_at | timestamp | Sent time             |

## Version 2.7 (2026-01-06) - Agent Re-assign & Upload Limit

- ✨ **Agent Re-assign** - Agents can now re-assign tickets to other agents (level ≥5)
- 🔧 **Upload Limit** - Reduced file upload limit from 10MB to 5MB
- 🔧 **Assignee Validation** - HTTP call to ms-user-management for validating assignee
- 🔒 **Internal Endpoint** - `GET /internal/users/:id` for service-to-service validation
- 🐛 **Fix: IsActive** - GetUserWithRole now includes is_active field

**Assign Rules Updated:**
| Role | Can Assign? | Condition |
|------|-------------|-----------|
| Agent (level 5) | ✅ | Only tickets assigned to them, to other agents (level ≥5) |
| Admin (level 7+) | ✅ | Any ticket, to agents or higher |
| Customer (< 5) | ❌ | Cannot assign |

## Version 2.6 (2026-01-06) - Tickets CRUD & File Upload

- ✨ **Tickets CRUD** - Complete ticket management with filters & pagination
- ✨ **File Upload** - Attachment support for tickets (5MB limit, multiple file types)
- ✨ **Priority Levels** - Low, Medium, High, Critical with future SLA support
- ✨ **Dynamic Status Transitions** - Database-driven status workflow validation
- 🔒 **Advanced RBAC** - Customer (own tickets), Agent (assigned), Admin (all)
- 🔍 **Powerful Filters** - By status, category, priority, assigned_to, created_by
- 📄 **Pagination** - Page & limit support (max 100 per page)
- 🎯 **Auto-Assignment** - Tickets start unassigned, admins can assign to agents
- 📁 **File Management** - Upload endpoint returns secure file URL
- ⚠️ **SLA Note** - Priority field ready, SLA tracking implementation in **next sprint**

**API Endpoints Added:**

- `POST /tickets` - Create ticket (all users)
- `GET /tickets` - List tickets with filters
- `GET /tickets/:id` - Get ticket details
- `GET /tickets/status/:status_id` - Filter by status
- `PUT /tickets/:id` - Update ticket (agent+)
- `DELETE /tickets/:id` - Delete ticket (super admin)
- `POST /upload` - Upload file attachment
- `GET /uploads/:filename` - Download attachment

**Business Rules:**

- New tickets auto-set to "open" status
- Customers can only view/create own tickets
- Agents can update only assigned tickets
- Agents can re-assign their tickets to other agents
- Admins can assign tickets to agents
- Status transitions validated against database rules
- Category and status must be active

## Version 2.9 (2026-01-22) - Profile Picture Support ✨ NEW

- ✨ **Profile Picture Upload** - `POST /users/me/profile-picture` for uploading profile photos
- ✨ **Profile Picture Field** - User profile (`/users/me`) now includes `profile_picture` URL
- 🔒 **File Type Validation** - Allowed: jpg, jpeg, png (Images only)
- 🔒 **File Size Limit** - Max 2MB per file
- 📁 **Serve Files** - `GET /profile-pictures/:filename` to access uploaded photos

**New Endpoints (ms-user-management):**

| Method | Endpoint                      | Description                         |
| ------ | ----------------------------- | ----------------------------------- |
| `POST` | `/users/me/profile-picture`   | Upload profile photo (JWT required) |
| `GET`  | `/profile-pictures/:filename` | Serve profile photos                |

**Database Changes:**

```sql
ALTER TABLE users ADD COLUMN profile_picture VARCHAR(255);
```

---

## Version 2.10 (2026-01-26) - Block Chat on Closed Tickets ✨ NEW

- 🔒 **Closed Ticket Protection** - Chat disabled on tickets with `is_final` status (e.g., "closed")
- 🔒 **REST API Block** - `POST /tickets/:id/comments` returns `403 Forbidden` with `ticket_closed` error
- 🔒 **WebSocket Block** - Messages on closed tickets return error via WebSocket
- 🔒 **Upload Block** - `POST /tickets/:id/comments/upload` blocked on closed tickets

**Error Response (403 Forbidden):**

```json
{
  "error": "ticket_closed",
  "message": "cannot add comments to a closed ticket"
}
```

**WebSocket Error Message:**

```json
{
  "type": "error",
  "content": "Cannot send messages to a closed ticket"
}
```

**Note:** Reading comments (`GET /tickets/:id/comments`) and viewing chat history via WebSocket is still allowed on closed tickets.

---

- ✨ **Chat Attachment Upload** - `POST /tickets/:id/comments/upload` for uploading files in chat
- ✨ **Attachment Field** - Comments now support optional `attachment` field
- ✨ **Flexible Comments** - Comments can have content only, attachment only, or both
- ✨ **WebSocket Attachment** - Send attachments via WebSocket with `{"type": "message", "content": "...", "attachment": "..."}`
- 🔒 **Ticket Access Validation** - Upload requires valid ticket access (same as comments)
- 🔒 **File Type Validation** - Allowed: jpg, jpeg, png, gif, pdf, doc, docx, txt, zip
- 🔒 **File Size Limit** - Max 5MB per file
- 📁 **Serve Files** - `GET /chat-uploads/:filename` to access uploaded files

**New Endpoints (ms-chat):**

| Method | Endpoint                       | Description                      |
| ------ | ------------------------------ | -------------------------------- |
| `POST` | `/tickets/:id/comments/upload` | Upload attachment (JWT required) |
| `GET`  | `/chat-uploads/:filename`      | Serve uploaded files             |

**Request Example - Create Comment with Attachment:**

```json
{
  "content": "See attached screenshot",
  "attachment": "/chat-uploads/chat_1_20260121_abc123.png"
}
```

**WebSocket Message with Attachment:**

```json
{
  "type": "message",
  "content": "Check this file",
  "attachment": "/chat-uploads/chat_1_20260121_xyz789.pdf"
}
```

**Database Changes:**

```sql
ALTER TABLE ticket_comments ADD COLUMN attachment VARCHAR(255);
```

**Validation Rules:**

- Content and attachment are both optional
- At least one (content OR attachment) must be present
- Empty/whitespace-only content is rejected

**Frontend Integration Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│  1. User picks file                                             │
│     ↓                                                           │
│  2. POST /tickets/:id/comments/upload (multipart/form-data)     │
│     → Response: { "data": { "url": "/chat-uploads/xxx.pdf" }}   │
│     ↓                                                           │
│  3. Send via WebSocket with the URL                             │
│     { "type": "message", "content": "...", "attachment": "url" }│
└─────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> WebSocket cannot handle binary file uploads. Always upload file first via REST API, then send the returned URL via WebSocket.

---

## Version 2.11 (2026-01-27) - Internal Notes for Agents ✨ NEW

- ✨ **Internal Notes** - Agents can add private notes to tickets (not visible to customers)
- 🔒 **Agent-Only Access** - Only role level ≥ 2 can read/write internal notes
- 📋 **Use Case** - Handoff notes when ticket is reassigned to another agent

**New Endpoints (ms-ticket):**

| Method | Endpoint                      | Description                          |
| ------ | ----------------------------- | ------------------------------------ |
| `GET`  | `/tickets/:id/internal-notes` | Get all internal notes (agent+ only) |
| `POST` | `/tickets/:id/internal-notes` | Create internal note (agent+ only)   |

**Request Example - Create Internal Note:**

```json
POST /tickets/70/internal-notes
Authorization: Bearer <agent_token>

{
  "content": "Customer mengalami masalah login karena password expired. Sudah di-reset tapi masih gagal. Perlu eskalasi ke IT."
}
```

**Response (201 Created):**

```json
{
  "message": "internal note created successfully",
  "data": {
    "id": 1,
    "ticket_id": 70,
    "user_id": 5,
    "user_name": "agent@company.com",
    "firstname": "Agent",
    "content": "Customer mengalami masalah login...",
    "created_at": "2026-01-27T14:00:00Z"
  }
}
```

**Response - Get Internal Notes (200 OK):**

```json
{
  "message": "internal notes retrieved successfully",
  "data": [
    {
      "id": 1,
      "ticket_id": 70,
      "user_id": 5,
      "user_name": "agent@company.com",
      "firstname": "Agent",
      "content": "Customer mengalami masalah login...",
      "created_at": "2026-01-27T14:00:00Z"
    }
  ],
  "total": 1
}
```

**Error Response (403 Forbidden - Customer accessing):**

```json
{
  "error": "forbidden",
  "message": "internal notes are only accessible to agents and above"
}
```

**Access Control:**

| Role Level       | Can Read | Can Write |
| ---------------- | -------- | --------- |
| Customer (1)     | ❌       | ❌        |
| Agent (2+)       | ✅       | ✅        |
| Admin (5+)       | ✅       | ✅        |
| Super Admin (10) | ✅       | ✅        |

**Database Changes:**

```sql
CREATE TABLE ticket_internal_notes (
    id SERIAL PRIMARY KEY,
    ticket_id INT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id INT NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    firstname VARCHAR(100),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

> [!IMPORTANT]
> Internal notes cannot be edited or deleted after creation. They serve as an audit trail for ticket handling.

---

## Version 2.14 (2026-01-30) - WebSocket Profile Picture ✨ NEW

- 📸 **Real-time Profile Pictures** - WebSocket chat messages now include sender's `profile_picture`
- 🚀 **Profile Picture on Connect** - Fetched once when user connects to WebSocket
- 🔄 **Enriched Broadcast** - All chat messages in room receive profile picture

**WebSocket Message Format (Updated):**

```json
{
  "id": 1,
  "ticket_id": 112,
  "user_id": 56,
  "user_name": "agent@company.com",
  "firstname": "Goku",
  "profile_picture": "/profile-pictures/profile_56_xxx.jpg",
  "user_role": "agent",
  "content": "Hello!",
  "attachment": "",
  "created_at": "2026-01-30T11:00:00Z"
}
```

---

## Version 2.13 (2026-01-29) - Profile Picture in Responses ✨ NEW

- ✨ **Profile Picture Lookup** - Comments, internal notes, and ticket details now include user profile pictures
- 🔄 **Batch User Lookup** - New internal endpoint for efficient batch user info fetching
- 📸 **Enriched Responses** - `profile_picture` field added to comment, internal note, and ticket creator/assignee info

**New Internal Endpoint (ms-user-management):**

| Method | Endpoint                | Description                        |
| ------ | ----------------------- | ---------------------------------- |
| `GET`  | `/internal/users/batch` | Batch lookup user info with photos |

**Request:**

```
GET /internal/users/batch?ids=1,2,3
X-Internal-Token: <token>
```

**Updated Response - GET Comments:**

```json
{
  "data": [
    {
      "id": 1,
      "user_id": 5,
      "user_name": "agent@company.com",
      "firstname": "Agent",
      "profile_picture": "/profile-pictures/abc123.jpg",
      "content": "Hello!",
      "created_at": "2026-01-29T10:00:00Z"
    }
  ]
}
```

**Updated Response - GET Internal Notes:**

```json
{
  "data": [
    {
      "id": 1,
      "user_id": 5,
      "user_name": "agent@company.com",
      "profile_picture": "/profile-pictures/abc123.jpg",
      "content": "Internal handoff note",
      "created_at": "2026-01-29T10:00:00Z"
    }
  ]
}
```

**Updated Response - GET Ticket Details:**

```json
{
  "data": {
    "id": 70,
    "creator_info": {
      "id": 1,
      "name": "John",
      "profile_picture": "/profile-pictures/john.jpg"
    },
    "assignee_info": {
      "id": 5,
      "name": "Agent",
      "profile_picture": "/profile-pictures/agent.jpg"
    }
  }
}
```

---

## Version 2.12 (2026-01-29) - Profile Update & Phone Number ✨ NEW

- ✨ **Update Own Profile** - New `PUT /users/me` endpoint for all roles
- ✨ **Phone Number Field** - Added optional `phone_number` field to User model
- 📋 **Editable Fields** - Users can update: `name`, `last_name`, `phone_number`

**New Endpoint (ms-user-management):**

| Method | Endpoint    | Description                    |
| ------ | ----------- | ------------------------------ |
| `PUT`  | `/users/me` | Update own profile (all roles) |

**Request Example:**

```json
PUT /users/me
Authorization: Bearer <token>

{
  "name": "John",
  "last_name": "Doe",
  "phone_number": "+6281234567890"
}
```

**Response (200 OK):**

```json
{
  "message": "profile updated successfully",
  "data": {
    "id": 1,
    "email": "john@example.com",
    "username": "johndoe",
    "name": "John",
    "last_name": "Doe",
    "phone_number": "+6281234567890"
  }
}
```

**Notes:**

- All fields are **optional** - send only what you want to update
- `phone_number` max length: 20 characters
- Empty string for `last_name` or `phone_number` will clear the value
- Available to **all authenticated users** (customer, agent, admin, super_admin)

**Database Changes:**

```sql
ALTER TABLE users ADD COLUMN phone_number VARCHAR(20);
```

---

## Version 2.7 (2026-01-07) - Attachment Security Fix

- 🔒 **Security Fix (Bug #Bug-CT-001):** File download now requires ownership validation
- ✨ **Attachment Model** - New `attachments` table to track file ownership
- 🔒 **Access Control** - Users can only download files they uploaded or files attached to their tickets
- 🔒 **Admin Override** - Admin (level 5+) can access all files
- ✨ **Upload Response** - Now includes attachment `id` for tracking
- 🗄️ **Auto-migration** - `attachments` table created automatically on startup
- 📝 **Documentation** - Updated upload/download endpoints with security details

**Database Changes:**

- New table: `attachments` (id, filename, original_name, file_size, mime_type, uploaded_by, ticket_id, created_at)

**Security Rules:**

- File downloads require JWT authentication
- Users can access: own uploads OR files attached to tickets they created/assigned to
- Admin/Super Admin can access all files
- Directory traversal attacks prevented with filename validation

## Version 2.5 (2026-01-02) - Ticket Service & Category Management

- ✨ **New Microservice: ms-ticket** - Dedicated ticketing service (port 8082)
- ✨ **Ticket Category Management** - CRUD operations for ticket categories
- ✨ **Dynamic Categories** - Super admin can create/update/delete categories
- 🔒 **Access Control** - All authenticated users can view, only super admin can manage
- 🗄️ **Default Categories Seeded** - 7 pre-configured categories (Technical Issue, Account Access, Billing, Feature Request, General Support, Bug Report, Other)
- 🌐 **Gateway Integration** - `/ticket-categories/*` routes proxied to ms-ticket
- 📋 **Category Features:**
  - `GET /ticket-categories` - List all categories
  - `GET /ticket-categories/active` - Get active categories only
  - `GET /ticket-categories/:id` - Get category by ID
  - `POST /ticket-categories` - Create category (super admin)
  - `PUT /ticket-categories/:id` - Update category (super admin)
  - `DELETE /ticket-categories/:id` - Delete category (super admin)
- 🔧 **Validation** - Name uniqueness check, whitespace trimming
- 🔧 **Status Support** - Active/Inactive categories with `is_active` flag
- 🗄️ **Auto-migration** - `ticket_categories` table created automatically

---

## Dashboard Statistics ✨ UPDATED

### Get Dashboard Statistics

| Method | Endpoint           | Access        |
| ------ | ------------------ | ------------- |
| `GET`  | `/dashboard/stats` | Authenticated |

**Description:** Returns summary statistics of tickets for dashboard display. Uses **counter-based approach with O(1) query performance** for all user roles. Statistics are pre-computed and stored in the `ticket_stats` table, updated automatically during ticket CRUD operations.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Role-Based Filtering:**

| Role              | Level | Data Returned                              |
| ----------------- | ----- | ------------------------------------------ |
| Customer          | < 2   | Only tickets created by the user           |
| Agent             | 2     | Tickets created by OR assigned to the user |
| Admin/Super Admin | >= 5  | All tickets (global statistics)            |

**Success Response (200):**

```json
{
  "data": {
    "total_tickets": 150,
    "open_count": 20,
    "in_progress_count": 35,
    "pending_count": 15,
    "resolved_count": 50,
    "closed_count": 30,
    "overdue_count": 5,
    "low_count": 30,
    "medium_count": 65,
    "high_count": 40,
    "critical_count": 15
  }
}
```

| Field               | Type    | Description                                 |
| ------------------- | ------- | ------------------------------------------- |
| `total_tickets`     | integer | Total number of tickets (filtered by role)  |
| `open_count`        | integer | Number of tickets with status `open`        |
| `in_progress_count` | integer | Number of tickets with status `in_progress` |
| `pending_count`     | integer | Number of tickets with status `pending`     |
| `resolved_count`    | integer | Number of tickets with status `resolved`    |
| `closed_count`      | integer | Number of tickets with status `closed`      |
| `overdue_count`     | integer | Number of tickets with `is_overdue = true`  |
| `low_count`         | integer | Number of tickets with priority `low`       |
| `medium_count`      | integer | Number of tickets with priority `medium`    |
| `high_count`        | integer | Number of tickets with priority `high`      |
| `critical_count`    | integer | Number of tickets with priority `critical`  |

> [!NOTE]
> **Validation formulas:**
>
> - `total_tickets == open_count + in_progress_count + pending_count + resolved_count + closed_count`
> - `total_tickets == low_count + medium_count + high_count + critical_count`

**Error Responses:**

| Code | Error                    |
| ---- | ------------------------ |
| 401  | Invalid or missing token |
| 500  | Failed to get statistics |

---

### Recalculate Dashboard Counters

| Method | Endpoint                 | Access      |
| ------ | ------------------------ | ----------- |
| `POST` | `/dashboard/recalculate` | Super Admin |

**Description:** Recalculates all dashboard counters from actual ticket data. Used to fix counter drift if synchronization issues occur.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Success Response (200):**

```json
{
  "message": "counters recalculated successfully"
}
```

**Error Responses:**

| Code | Error                     |
| ---- | ------------------------- |
| 401  | Invalid or missing token  |
| 403  | Access denied (not admin) |
| 500  | Failed to recalculate     |

---

### Database Schema

**Table: `ticket_stats`** (Unified)

| Column              | Type        | Description                        |
| ------------------- | ----------- | ---------------------------------- |
| `id`                | SERIAL      | Primary key                        |
| `user_id`           | INT         | User ID (0 = global stats)         |
| `role_type`         | VARCHAR(20) | "global", "creator", or "assignee" |
| `total_tickets`     | INT         | Total ticket count                 |
| `open_count`        | INT         | Open status count                  |
| `in_progress_count` | INT         | In-progress status count           |
| `pending_count`     | INT         | Pending status count               |
| `resolved_count`    | INT         | Resolved status count              |
| `closed_count`      | INT         | Closed status count                |
| `overdue_count`     | INT         | Overdue ticket count               |
| `low_count`         | INT         | Low priority count                 |
| `medium_count`      | INT         | Medium priority count              |
| `high_count`        | INT         | High priority count                |
| `critical_count`    | INT         | Critical priority count            |
| `updated_at`        | TIMESTAMP   | Last update time                   |

**Index:** `idx_user_role` on `(user_id, role_type)` for O(1) lookups.

> [!NOTE]
>
> - Statistics use **O(1) query time** via pre-computed counters
> - Counters are synchronized automatically on ticket create/update/delete
> - Counters are recalculated on service startup to ensure accuracy
> - `overdue_count` is updated when ms-sla marks tickets as overdue
> - Priority counters are updated when ticket priority changes

---

## Report & Excel Export ✨ NEW

### Get Report Data

| Method | Endpoint   | Access            |
| ------ | ---------- | ----------------- |
| `GET`  | `/reports` | Admin/Super Admin |

**Authorization:** Bearer Token (Admin level ≥ 5)

**Description:** Mendapatkan data report dengan aggregasi dan filter. Mengembalikan summary statistik dan daftar tiket.

#### Query Parameters (Semua Optional)

| Parameter     | Type   | Format       | Description                                                          |
| ------------- | ------ | ------------ | -------------------------------------------------------------------- |
| `start_date`  | string | `YYYY-MM-DD` | Filter dari tanggal                                                  |
| `end_date`    | string | `YYYY-MM-DD` | Filter sampai tanggal                                                |
| `status_id`   | int    | -            | Filter berdasarkan status ID                                         |
| `agent_id`    | int    | -            | Filter berdasarkan agent (assigned_to)                               |
| `category_id` | int    | -            | Filter berdasarkan category ID                                       |
| `priority`    | string | -            | Filter berdasarkan priority (`low`/`medium`/`high`/`critical`)       |
| `page`        | int    | -            | Nomor halaman (default: 1, tidak boleh negatif)                      |
| `limit`       | int    | -            | Jumlah item per halaman (default: 20, max: 100, tidak boleh negatif) |

#### Parameter Validation

> [!NOTE]
>
> - Unknown query parameters akan ditolak dengan error
> - `start_date` dan `end_date` harus format `YYYY-MM-DD`
> - `start_date` tidak boleh setelah `end_date`
> - `priority` hanya menerima: `low`, `medium`, `high`, `critical`
> - `status_id`, `agent_id`, `category_id` harus berupa angka
> - `page` dan `limit` tidak boleh bernilai negatif (akan mengembalikan error 400)
> - Jika `page` tidak diisi atau `0`, default ke `1`
> - Jika `limit` tidak diisi atau `0`, default ke `20`; maksimum `100`

#### Contoh Request

```http
# Tanpa filter (semua data)
GET /reports
Authorization: Bearer <token>

# Filter berdasarkan date range
GET /reports?start_date=2026-01-01&end_date=2026-02-19
Authorization: Bearer <token>

# Filter kombinasi
GET /reports?start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=5&priority=high
Authorization: Bearer <token>

# Dengan pagination
GET /reports?page=2&limit=10
Authorization: Bearer <token>
```

#### Success Response (200 OK)

```json
{
  "data": {
    "summary": {
      "total_tickets": 150,
      "open_count": 25,
      "in_progress_count": 45,
      "pending_count": 10,
      "resolved_count": 40,
      "closed_count": 30,
      "overdue_count": 5,
      "sla_met_count": 65,
      "sla_breached_count": 5,
      "avg_resolution_hours": 24.5,
      "by_category": [
        { "category_id": 1, "category_name": "Technical Issue", "count": 50 },
        { "category_id": 2, "category_name": "Account Access", "count": 35 }
      ],
      "by_priority": [
        { "priority": "medium", "count": 60 },
        { "priority": "high", "count": 40 },
        { "priority": "low", "count": 30 },
        { "priority": "critical", "count": 20 }
      ],
      "by_agent": [
        { "agent_id": 5, "agent_name": "Agent One", "count": 45 },
        { "agent_id": 8, "agent_name": "Agent Two", "count": 38 }
      ]
    },
    "tickets": [
      {
        "ticket_id": 1,
        "subject": "Cannot login to system",
        "agent_id": 5,
        "agent_name": "Agent One",
        "status_name": "in_progress",
        "sla_status": "In Progress",
        "category_name": "Technical Issue",
        "priority": "high",
        "created_at": "2026-02-01T08:30:00Z",
        "closed_at": null
      },
      {
        "ticket_id": 2,
        "subject": "Billing discrepancy",
        "agent_id": 8,
        "agent_name": "Agent Two",
        "status_name": "closed",
        "sla_status": "Met",
        "category_name": "Billing",
        "priority": "medium",
        "created_at": "2026-01-15T10:00:00Z",
        "closed_at": "2026-01-16T14:30:00Z"
      },
      {
        "ticket_id": 3,
        "subject": "Feature request: dark mode",
        "agent_id": null,
        "agent_name": "Unassigned",
        "status_name": "open",
        "sla_status": "In Progress",
        "category_name": "Feature Request",
        "priority": "low",
        "created_at": "2026-02-10T09:15:00Z",
        "closed_at": null
      }
    ],
    "pagination": {
      "total": 150,
      "page": 1,
      "limit": 20,
      "total_pages": 8
    },
    "filters_applied": {
      "start_date": "2026-01-01",
      "end_date": "2026-02-19"
    }
  }
}
```

#### Response Fields — Summary

| Field                  | Type  | Description                                         |
| ---------------------- | ----- | --------------------------------------------------- |
| `total_tickets`        | int   | Total tiket sesuai filter                           |
| `open_count`           | int   | Jumlah tiket open                                   |
| `in_progress_count`    | int   | Jumlah tiket in_progress                            |
| `pending_count`        | int   | Jumlah tiket pending                                |
| `resolved_count`       | int   | Jumlah tiket resolved                               |
| `closed_count`         | int   | Jumlah tiket closed                                 |
| `overdue_count`        | int   | Jumlah tiket overdue                                |
| `sla_met_count`        | int   | Tiket selesai tanpa overdue                         |
| `sla_breached_count`   | int   | Tiket yang overdue                                  |
| `avg_resolution_hours` | float | Rata-rata waktu penyelesaian (jam)                  |
| `by_category`          | array | Breakdown jumlah tiket per kategori                 |
| `by_priority`          | array | Breakdown jumlah tiket per priority                 |
| `by_agent`             | array | Breakdown jumlah tiket per agent (assigned tickets) |

#### Response Fields — Tickets

| Field           | Type          | Description                                      |
| --------------- | ------------- | ------------------------------------------------ |
| `ticket_id`     | int           | ID tiket                                         |
| `subject`       | string        | Judul tiket                                      |
| `agent_id`      | int/null      | ID agent yang di-assign                          |
| `agent_name`    | string        | Nama agent (`"Unassigned"` jika belum di-assign) |
| `status_name`   | string        | Nama status tiket                                |
| `sla_status`    | string        | `"Met"`, `"Overdue"`, atau `"In Progress"`       |
| `category_name` | string        | Nama kategori tiket                              |
| `priority`      | string        | `low`/`medium`/`high`/`critical`                 |
| `created_at`    | datetime      | Waktu pembuatan tiket                            |
| `closed_at`     | datetime/null | Waktu penutupan (null jika belum ditutup)        |

#### Response Fields — Pagination

| Field         | Type | Description                       |
| ------------- | ---- | --------------------------------- |
| `total`       | int  | Total seluruh tiket sesuai filter |
| `page`        | int  | Halaman saat ini                  |
| `limit`       | int  | Jumlah item per halaman           |
| `total_pages` | int  | Total halaman yang tersedia       |

#### SLA Status Logic

| SLA Status    | Kondisi                                               |
| ------------- | ----------------------------------------------------- |
| `Overdue`     | `is_overdue = true`                                   |
| `Met`         | Status final (closed) atau resolved DAN tidak overdue |
| `In Progress` | Selain kondisi di atas (tiket masih aktif)            |

#### Error Responses

**Unknown Parameter (400):**

```json
{
  "error": "unknown query parameter(s): typo_param. Valid parameters: start_date, end_date, status_id, agent_id, category_id, priority",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high"
}
```

**Invalid Date Format (400):**

```json
{
  "error": "invalid start_date format 'not-a-date', expected YYYY-MM-DD",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high"
}
```

**Invalid Date Range (400):**

```json
{
  "error": "start_date '2026-03-01' cannot be after end_date '2026-01-01'",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high"
}
```

**Invalid Priority (400):**

```json
{
  "error": "invalid priority 'xyz', valid values: low, medium, high, critical",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high"
}
```

**Negative Page (400):**

```json
{
  "error": "page cannot be negative, got -1",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high&page=1&limit=20"
}
```

**Negative Limit (400):**

```json
{
  "error": "limit cannot be negative, got -5",
  "hint": "use format: start_date=2026-01-01&end_date=2026-02-19&status_id=1&agent_id=2&category_id=3&priority=high&page=1&limit=20"
}
```

---

### Export Report to Excel

| Method | Endpoint          | Access            |
| ------ | ----------------- | ----------------- |
| `GET`  | `/reports/export` | Admin/Super Admin |

**Authorization:** Bearer Token (Admin level ≥ 5)

**Description:** Generate dan download file Excel (.xlsx) berisi data report. Filter yang didukung sama dengan endpoint `/reports`.

**Query Parameters:** Sama dengan `GET /reports` (lihat tabel di atas).

#### Contoh Request

```http
# Export semua data
GET /reports/export
Authorization: Bearer <token>

# Export dengan filter date range
GET /reports/export?start_date=2026-01-01&end_date=2026-02-19
Authorization: Bearer <token>

# Export dengan filter kombinasi
GET /reports/export?start_date=2026-01-01&end_date=2026-02-19&agent_id=5&priority=high
Authorization: Bearer <token>
```

#### Success Response (200 OK)

**Headers:**

```
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename=ticket_report_2026-01-01_to_2026-02-19.xlsx
```

**Body:** Binary file (.xlsx)

#### Excel File Structure

File Excel berisi **2 sheet**:

**Sheet 1: Tickets**

| Ticket ID | Title                  | Agent      | Status      | SLA Status  | Category        | Priority | Created At          | Closed At           |
| --------- | ---------------------- | ---------- | ----------- | ----------- | --------------- | -------- | ------------------- | ------------------- |
| 1         | Cannot login to system | Agent One  | in_progress | In Progress | Technical Issue | high     | 2026-02-01 08:30:00 | -                   |
| 2         | Billing discrepancy    | Agent Two  | closed      | Met         | Billing         | medium   | 2026-01-15 10:00:00 | 2026-01-16 14:30:00 |
| 3         | Feature request        | Unassigned | open        | In Progress | Feature Request | low      | 2026-02-10 09:15:00 | -                   |

**Sheet 2: Summary**

| Label                  | Value |
| ---------------------- | ----- |
| Total Tickets          | 150   |
| Open                   | 25    |
| In Progress            | 45    |
| Pending                | 10    |
| Resolved               | 40    |
| Closed                 | 30    |
| Overdue                | 5     |
| SLA Met                | 65    |
| SLA Breached           | 5     |
| Avg Resolution (hours) | 24.5  |

#### Filename Convention

| Filter                                      | Filename                                      |
| ------------------------------------------- | --------------------------------------------- |
| Tanpa filter                                | `ticket_report.xlsx`                          |
| `start_date=2026-01-01`                     | `ticket_report_2026-01-01.xlsx`               |
| `start_date=2026-01-01&end_date=2026-02-19` | `ticket_report_2026-01-01_to_2026-02-19.xlsx` |

#### Error Responses

| Status Code | Error                 | Description                          |
| ----------- | --------------------- | ------------------------------------ |
| 400         | Bad Request           | Parameter tidak valid (lihat detail) |
| 401         | Unauthorized          | Token tidak valid atau expired       |
| 403         | Forbidden             | Role level kurang (butuh level ≥ 5)  |
| 500         | Internal Server Error | Gagal generate report/Excel          |

---

## Version 2.4 (2025-12-30) - Verify Reset Token

- ✨ **Verify Reset Token** - `POST /auth/verify-reset-token` to validate code before showing new password form
- 🔧 **3-Step Password Reset Flow** - forgot-password → verify-reset-token → reset-password
- 📝 **Documentation** - Added password reset flow diagram

## Version 2.3 (2025-12-17) - Password Management & Account Control

- ✨ **Account Status Control** - `PUT /users/:id/status` Super Admin can activate/deactivate accounts
- ✨ **Account Active/Inactive** - `is_active` field added to User model (default: true)
- 🔐 **Login Protection** - Inactive accounts are blocked from logging in with clear error message
- 🔐 **Security Fix: Role Assignment** - Admin can no longer assign roles equal/higher than their own level (Bug #SEC-001)
- 🐛 **Bug Fix: Clear Last Name** - `last_name` can now be cleared by sending empty string in update request (Bug #BUG-002)
- ✨ **Change Password Endpoint** - `PUT /users/me/change-password` for all authenticated users
- ✨ **Forgot Password** - `POST /auth/forgot-password` send 4-digit reset code via email
- ✨ **Reset Password** - `POST /auth/reset-password` reset password using 4-digit code
- ✨ **First Login Detection** - `is_first_login` field added to User model
- 🔐 **Security Enhancement** - Force password change on first login
- 🔐 **Email Service** - SMTP integration for password reset emails (Gmail)
- 🔐 **Password Minimum Length** - Increased from 6 to 8 characters
- 🔐 **RBAC Access Control Fix** - Admin can now view roles/permissions (Bug #Bug-RM-001)
- 🔐 **Same-Level Protection** - Users at same level cannot modify each other (Super Admin ↔ Super Admin)
- 🔐 **Super Admin Role Protection** - Cannot update/delete Super Admin role (level 10)
- ✨ **Custom Role Support** - All endpoints now accept any custom role name from database (removed hardcoded validation)
- ✨ **Update User by Role Name** - `PUT /users/:id` now supports updating role by name (not just role_id)
- 🐛 **Improved Error Messages** - Clear error responses for invalid role names with helpful hints
- 🔧 **LastName Optional** - `last_name` field is now optional in all registration endpoints
- 📧 **4-Digit Reset Code** - User-friendly code (1000-9999) with 1-hour expiration
- 🐛 **Status Code Fix** - Assign/Remove permissions now return 404 for role not found (Bug #Bug-RM-010, #Bug-RM-011)
- 🐛 **Status Code Fix** - Role CRUD operations return proper codes (404, 403, 409)
- 🔧 User responses now include `is_first_login` boolean flag
- 🔧 `is_first_login` automatically set to `false` after password change
- 🔧 New users created with `is_first_login = true` by default
- 🔧 JWT tokens now include `role_id` and `role_level` for RBAC middleware
- 🔧 Gateway middleware now sets `user_role_id` and `user_role_level` to context
- 🔧 Admin can VIEW roles/permissions, only Super Admin can MODIFY
- 🗄️ New table: `password_reset_tokens` for secure code storage
- 🐛 Fixed: "role level not found in context" error in production

## Version 2.2 (2025-12-10) - LastName Field & Authorization Fixes

- ✨ **LastName field** added to User model (required)
- 🔒 **Authorization fixes** - Prevent non-super_admin from viewing/modifying super_admin users
- 🔒 **Authorization fixes** - Prevent non-admin from modifying admin/super_admin users
- 🔒 **Authorization fixes** - Restrict list users to admin/super_admin only
- 🔧 All user requests now support `last_name` field
- 🔧 All user responses include `last_name`
- 🐛 Fixed error message exposure in token validation

## Version 2.1 (2025-12-09) - Username Login & Enhanced Endpoints

- ✨ **Username login support** - Login with email OR username
- ✨ **Username field** added to User model
- ✨ `GET /users` - List all users with pagination
- ✨ `GET /users/:id/with-role` - Get user with full role details
- ✨ `DELETE /users/:id` - Delete user endpoint
- 🔧 Login request now uses `identifier` field (email or username)
- 🔧 Register requires `username` field
- 🔧 All user responses include `username`

## Version 3.0 (2026-02-03) - SLA Edition

- ✨ **SLA Service (ms-sla)** - SLA management with automatic due date calculation
- ✨ **Notification Service (ms-notification)** - Email notifications via SMTP
- ✨ Tickets now include `due_date` and `is_overdue` fields
- ✨ SLA configurations per priority (CRUD via `/sla-configs`)
- ✨ Overdue checker cron job (every 5 minutes)
- ✨ Email notifications for overdue and warning alerts
- ✨ Filter tickets by `is_overdue` status
- 🔧 Ticket response includes SLA fields

## Version 2.0 (2025-12-08) - RBAC Edition

- ✨ JWT tokens include `role` claim
- ⚠️ `/auth/register` requires JWT authentication
- ✨ Complete RBAC (roles, permissions, role_permissions)
- ✨ Role management endpoints (CRUD)
- ✨ Permission management endpoints
- ✨ User profile endpoints (`/users/me`)
- ✨ Enhanced validation errors

## Version 1.0 (2025-12-05)

- Initial API specification
- Basic authentication endpoints
- String-based role support

---

# SLA Service (ms-sla)

## Get All SLA Configs

| Method | Endpoint       | Access |
| ------ | -------------- | ------ |
| `GET`  | `/sla-configs` | Public |

**Description:** Get all SLA configurations.

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "priority": "low",
      "response_time_min": 1440,
      "resolve_time_min": 4320,
      "warning_time_min": 60,
      "is_active": true
    },
    {
      "id": 2,
      "priority": "medium",
      "response_time_min": 240,
      "resolve_time_min": 1440,
      "warning_time_min": 30,
      "is_active": true
    },
    {
      "id": 3,
      "priority": "high",
      "response_time_min": 60,
      "resolve_time_min": 480,
      "warning_time_min": 30,
      "is_active": true
    },
    {
      "id": 4,
      "priority": "critical",
      "response_time_min": 15,
      "resolve_time_min": 240,
      "warning_time_min": 10,
      "is_active": true
    }
  ],
  "message": "SLA configs retrieved successfully"
}
```

---

## Get SLA Config by Priority

| Method | Endpoint                 | Access |
| ------ | ------------------------ | ------ |
| `GET`  | `/sla-configs/:priority` | Public |

**Path Parameters:**

- `priority` - `low`, `medium`, `high`, `critical`

**Success Response (200):**

```json
{
  "data": {
    "id": 4,
    "priority": "critical",
    "response_time_min": 15,
    "resolve_time_min": 240,
    "warning_time_min": 10,
    "is_active": true
  }
}
```

---

## Create SLA Config

| Method | Endpoint       | Access      |
| ------ | -------------- | ----------- |
| `POST` | `/sla-configs` | Super Admin |

**Request:**

```json
{
  "priority": "urgent",
  "response_time_min": 10,
  "resolve_time_min": 120,
  "warning_time_min": 5
}
```

---

## Update SLA Config

| Method | Endpoint           | Access      |
| ------ | ------------------ | ----------- |
| `PUT`  | `/sla-configs/:id` | Super Admin |

**Request:**

```json
{
  "response_time_min": 20,
  "resolve_time_min": 180,
  "warning_time_min": 10,
  "is_active": true
}
```

---

## Delete SLA Config

| Method   | Endpoint           | Access      |
| -------- | ------------------ | ----------- |
| `DELETE` | `/sla-configs/:id` | Super Admin |

---

## SLA Default Configuration

| Priority | Response Time | Resolution Time | Warning Before |
| -------- | ------------- | --------------- | -------------- |
| Low      | 24 hours      | 72 hours (3d)   | 60 min         |
| Medium   | 4 hours       | 24 hours        | 30 min         |
| High     | 1 hour        | 8 hours         | 30 min         |
| Critical | 15 min        | 4 hours         | 10 min         |

---

# Audit Log Service (ms-sla) ✨ NEW

The Audit Log service records important events related to SLA and ticket operations. All audit logs are stored in the `audit_logs` table within the ms-sla database.

## Event Types

| Event Type          | Description                     | Triggered By      |
| ------------------- | ------------------------------- | ----------------- |
| `sla_overdue`       | Ticket becomes overdue          | ms-sla scheduler  |
| `notification_sent` | Email notification sent         | ms-sla scheduler  |
| `status_change`     | Ticket status changed           | ms-ticket service |
| `ticket_assigned`   | Ticket assigned to agent        | ms-ticket service |
| `first_response`    | Agent's first response recorded | ms-ticket/ms-chat |

---

## Get All Audit Logs

| Method | Endpoint      | Access            |
| ------ | ------------- | ----------------- |
| `GET`  | `/audit-logs` | Admin/Super Admin |

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Query Parameters:**

| Parameter     | Type    | Description                            |
| ------------- | ------- | -------------------------------------- |
| `event_type`  | string  | Filter by event type                   |
| `entity_type` | string  | Filter by entity type (e.g., "ticket") |
| `entity_id`   | integer | Filter by entity ID (e.g., ticket_id)  |
| `page`        | integer | Page number (default: 1)               |
| `limit`       | integer | Items per page (default: 20, max: 100) |

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "event_type": "status_change",
      "entity_type": "ticket",
      "entity_id": 42,
      "description": "Ticket #42 status changed from 'open' to 'in_progress'",
      "metadata": "{\"old_status\":\"open\",\"new_status\":\"in_progress\",\"changed_by\":5,\"changed_at\":\"2026-02-04T10:30:00Z\"}",
      "created_by": 5,
      "created_at": "2026-02-04T10:30:00Z"
    },
    {
      "id": 2,
      "event_type": "sla_overdue",
      "entity_type": "ticket",
      "entity_id": 38,
      "description": "Ticket #38 is overdue by 2 hours",
      "metadata": "{\"overdue_by\":\"2h0m\",\"recipient_email\":\"agent@test.com\",\"detected_at\":\"2026-02-04T10:00:00Z\"}",
      "created_by": null,
      "created_at": "2026-02-04T10:00:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "limit": 20
}
```

**Error Responses:**

| Code | Error                      |
| ---- | -------------------------- |
| 400  | Unknown query parameter    |
| 400  | Page must be non-negative  |
| 400  | Limit must be non-negative |
| 401  | Invalid or missing token   |
| 403  | Admin access required      |

**Validation:**

> [!NOTE]
>
> - Unknown query parameters will be rejected with an error listing valid parameter names
> - `page` and `limit` must be non-negative numbers (>= 0)
> - `page=0` defaults to page 1, `limit=0` defaults to 20

**Example Error Response (typo in parameter):**

```json
{
  "error": "unknown query parameter(s): entitiy_id",
  "valid_params": ["event_type", "entity_type", "entity_id", "page", "limit"],
  "hint": "check for typos in parameter names"
}
```

**Example Error Response (negative page):**

```json
{
  "error": "page must be a non-negative number",
  "hint": "use page=1 for the first page, or page=0 for default"
}

---

## Get Audit Log by ID

| Method | Endpoint          | Access            |
| ------ | ----------------- | ----------------- |
| `GET`  | `/audit-logs/:id` | Admin/Super Admin |

**Headers:**

```

Authorization: Bearer <jwt_token>

````

**Success Response (200):**

```json
{
  "data": {
    "id": 1,
    "event_type": "ticket_assigned",
    "entity_type": "ticket",
    "entity_id": 42,
    "description": "Ticket #42 assigned to user #5",
    "metadata": "{\"assigned_to\":5,\"assigned_by\":10,\"assigned_at\":\"2026-02-04T09:00:00Z\"}",
    "created_by": 10,
    "created_at": "2026-02-04T09:00:00Z"
  }
}
````

**Error Responses:**

| Code | Error                |
| ---- | -------------------- |
| 400  | Invalid audit log ID |
| 404  | Audit log not found  |

---

## Get Audit Logs by Ticket ID

| Method | Endpoint                 | Access            |
| ------ | ------------------------ | ----------------- |
| `GET`  | `/audit-logs/ticket/:id` | Admin/Super Admin |

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Description:** Get all audit logs related to a specific ticket, useful for viewing ticket activity history.

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 5,
      "event_type": "status_change",
      "entity_type": "ticket",
      "entity_id": 42,
      "description": "Ticket #42 status changed from 'in_progress' to 'resolved'",
      "metadata": "{\"old_status\":\"in_progress\",\"new_status\":\"resolved\",\"changed_by\":5}",
      "created_by": 5,
      "created_at": "2026-02-04T14:00:00Z"
    },
    {
      "id": 3,
      "event_type": "notification_sent",
      "entity_type": "ticket",
      "entity_id": 42,
      "description": "Notification 'overdue' sent for ticket #42 to agent@test.com",
      "metadata": "{\"notification_type\":\"overdue\",\"recipient_email\":\"agent@test.com\"}",
      "created_by": null,
      "created_at": "2026-02-04T12:00:00Z"
    },
    {
      "id": 2,
      "event_type": "sla_overdue",
      "entity_type": "ticket",
      "entity_id": 42,
      "description": "Ticket #42 is overdue by 30 min",
      "metadata": "{\"overdue_by\":\"30m\",\"recipient_email\":\"agent@test.com\"}",
      "created_by": null,
      "created_at": "2026-02-04T12:00:00Z"
    },
    {
      "id": 1,
      "event_type": "ticket_assigned",
      "entity_type": "ticket",
      "entity_id": 42,
      "description": "Ticket #42 assigned to user #5",
      "metadata": "{\"assigned_to\":5,\"assigned_by\":10}",
      "created_by": 10,
      "created_at": "2026-02-04T09:00:00Z"
    }
  ],
  "ticket_id": 42,
  "total": 4
}
```

---

## Internal Endpoints

> [!NOTE]
> These endpoints are for service-to-service communication only and require the `X-Internal-Token` header.

### Log Status Change

| Method | Endpoint                             | Access   |
| ------ | ------------------------------------ | -------- |
| `POST` | `/internal/audit-logs/status-change` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Request:**

```json
{
  "ticket_id": 42,
  "old_status": "open",
  "new_status": "in_progress",
  "changed_by": 5
}
```

**Success Response (201):**

```json
{
  "message": "status change logged"
}
```

---

### Log Ticket Assignment

| Method | Endpoint                               | Access   |
| ------ | -------------------------------------- | -------- |
| `POST` | `/internal/audit-logs/ticket-assigned` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Request:**

```json
{
  "ticket_id": 42,
  "assigned_to": 5,
  "assigned_by": 10
}
```

**Success Response (201):**

```json
{
  "message": "ticket assignment logged"
}
```

---

### Log First Response

| Method | Endpoint                              | Access   |
| ------ | ------------------------------------- | -------- |
| `POST` | `/internal/audit-logs/first-response` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Request:**

```json
{
  "ticket_id": 42,
  "responded_by": 5
}
```

**Success Response (201):**

```json
{
  "message": "first response logged"
}
```

---

### Log Notification Sent

| Method | Endpoint                                 | Access   |
| ------ | ---------------------------------------- | -------- |
| `POST` | `/internal/audit-logs/notification-sent` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Request:**

```json
{
  "ticket_id": 42,
  "notification_type": "assignment",
  "recipient_email": "agent@test.com"
}
```

**Success Response (201):**

```json
{
  "message": "notification sent logged"
}
```

---

## Audit Log Database Schema

```sql
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,     -- sla_overdue, status_change, etc.
    entity_type VARCHAR(50) NOT NULL,    -- ticket, user
    entity_id INTEGER NOT NULL,          -- ticket_id
    description TEXT,
    metadata JSONB,                      -- Additional JSON data
    created_by INTEGER,                  -- User who triggered (if applicable)
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for query performance
CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
```

---

# Auto-Close Inactive Tickets Feature

## Overview

Fitur otomatis menutup ticket yang tidak direspon oleh user selama X hari (default: 3 hari). Konfigurasi disimpan di database `system_configs`.

## Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    AUTO-CLOSE FLOW                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Agent sends message (via WebSocket chat)                     │
│     └── Set waiting_for_user_since = NOW()                       │
│                                                                  │
│  2. User replies                                                 │
│     ├── Set last_user_reply_at = NOW()                           │
│     └── Clear waiting_for_user_since = NULL                      │
│                                                                  │
│  3. Cron job (every hour) checks:                                │
│     WHERE waiting_for_user_since IS NOT NULL                     │
│       AND waiting_for_user_since < NOW() - X days                │
│       AND status NOT IN ('closed', 'resolved')                   │
│     └── Auto-close ticket and send notification                  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Database Changes

### Ticket Table (ms-ticket)

New columns added:

| Column                   | Type      | Description                                       |
| ------------------------ | --------- | ------------------------------------------------- |
| `last_user_reply_at`     | TIMESTAMP | Waktu terakhir user membalas                      |
| `waiting_for_user_since` | TIMESTAMP | Waktu mulai menunggu reply (set saat agent reply) |

### System Config Table (ms-sla)

```sql
CREATE TABLE system_configs (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(50) UNIQUE NOT NULL,
    config_value VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Default config
INSERT INTO system_configs (config_key, config_value, description)
VALUES ('auto_close_inactive_days', '3', 'Days to wait before auto-closing inactive ticket');
```

---

## Internal API Endpoints (ms-ticket)

### Mark User Activity

Called by ms-chat when **user** sends a message.

| Method | Endpoint                              | Access   |
| ------ | ------------------------------------- | -------- |
| `PUT`  | `/internal/tickets/:id/user-activity` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Success Response (200):**

```json
{
  "message": "user activity recorded",
  "data": {
    "id": 123,
    "last_user_reply_at": "2026-02-05T10:00:00Z"
  }
}
```

---

### Mark Waiting for User

Called by ms-chat when **agent** sends a message.

| Method | Endpoint                                 | Access   |
| ------ | ---------------------------------------- | -------- |
| `PUT`  | `/internal/tickets/:id/waiting-for-user` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Success Response (200):**

```json
{
  "message": "waiting for user marked",
  "data": {
    "id": 123,
    "waiting_for_user_since": "2026-02-05T10:00:00Z"
  }
}
```

---

### Get Inactive Tickets

Called by ms-sla scheduler to get tickets waiting for user > X days.

| Method | Endpoint                            | Access   |
| ------ | ----------------------------------- | -------- |
| `GET`  | `/internal/tickets/inactive?days=3` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Query Parameters:**

| Parameter | Type | Required | Default | Description        |
| --------- | ---- | -------- | ------- | ------------------ |
| `days`    | int  | No       | 3       | Days of inactivity |

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 123,
      "subject": "Login Issue",
      "created_by": 5,
      "waiting_for_user_since": "2026-02-01T10:00:00Z"
    }
  ],
  "count": 1,
  "message": "inactive tickets retrieved"
}
```

---

### Auto-Close Ticket

Called by ms-sla scheduler to auto-close a ticket.

| Method | Endpoint                           | Access   |
| ------ | ---------------------------------- | -------- |
| `PUT`  | `/internal/tickets/:id/auto-close` | Internal |

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Success Response (200):**

```json
{
  "message": "ticket auto-closed due to inactivity",
  "data": {
    "id": 123,
    "old_status_id": 2,
    "new_status_id": 4
  }
}
```

---

## WebSocket Chat Integration

When messages are sent via WebSocket (ms-chat):

| Sender                  | Action                                             |
| ----------------------- | -------------------------------------------------- |
| Agent (role_level >= 2) | Calls `PUT /internal/tickets/:id/waiting-for-user` |
| User (role_level < 2)   | Calls `PUT /internal/tickets/:id/user-activity`    |

---

## Scheduler (ms-sla)

**InactiveChecker** runs every hour (`0 * * * *`):

1. Get `auto_close_inactive_days` from `system_configs` table
2. Fetch inactive tickets via `GET /internal/tickets/inactive?days=X`
3. For each ticket:
   - Call `PUT /internal/tickets/:id/auto-close`
   - Send email notification to user
   - Log audit event `ticket_auto_closed`

---

## Email Notification

When ticket is auto-closed, user receives email:

**Subject:** `[AUTO-CLOSED] Ticket #123 ditutup otomatis karena tidak ada respons`

**Template:** `ticket_auto_close`

```html
<h1>🔒 Ticket Ditutup Otomatis</h1>
<p>
  Ticket berikut telah ditutup secara otomatis karena tidak ada respons dalam 3
  hari:
</p>
<ul>
  <li><strong>Ticket ID:</strong> #123</li>
  <li><strong>Subject:</strong> Login Issue</li>
</ul>
<p>Jika Anda masih memerlukan bantuan, silakan buat ticket baru.</p>
```
