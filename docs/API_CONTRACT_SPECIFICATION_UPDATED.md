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
- User profile endpoints (`/users/me`)
- **NEW:** Ticket Service (ms-ticket) with:
  - Ticket Categories CRUD
  - Ticket Status CRUD with dynamic transitions
  - **Tickets CRUD** (main entity) with filters & pagination
  - File upload for attachments (10MB limit)
  - Priority levels (low, medium, high, critical)
  - **Note:** SLA tracking will be implemented in next sprint

---

# Authentication Service (ms-auth)

## 1. Login User

| Method | Endpoint      | Access |
| ------ | ------------- | ------ |
| `POST` | `/auth/login` | Public |

**Description:** Authenticate user with email/username and password, returns JWT token with role.

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
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "admin@test.com",
      "username": "admin",
      "name": "Admin User",
      "role": "admin",
      "is_active": true,
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    }
  }
}
```

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

**JWT Token Claims:**

```json
{
  "user_id": 1,
  "email": "admin@test.com",
  "role": "admin",
  "exp": 1702122000,
  "iat": 1702035600
}
```

**Errors:**
| Code | Error |
|------|-------|
| 400 | Validation failed |
| 500 | Invalid credentials |

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

## 4. Get My Profile ✨ NEW

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
    "role": {
      "id": 1,
      "name": "customer",
      "description": "Regular customer",
      "level": 1
    },
    "is_first_login": true,
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2025-12-08T10:00:00Z"
  }
}
```

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

## 6. List All Users ✨ NEW

| Method | Endpoint | Access        |
| ------ | -------- | ------------- |
| `GET`  | `/users` | Authenticated |

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

**Description:** Create a new support ticket. Available to all authenticated users (customer, agent, admin, super_admin).

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

**Business Rules:**

- `status_id` automatically set to "open" (id: 1)
- `created_by` automatically set from JWT token
- `assigned_to` automatically set to `null` (unassigned)
- Default `priority` is "medium" if not provided
- Category must exist and be active

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

| Parameter     | Type    | Description                                      |
| ------------- | ------- | ------------------------------------------------ |
| `status_id`   | integer | Filter by status ID                              |
| `category_id` | integer | Filter by category ID                            |
| `priority`    | string  | Filter by priority (low, medium, high, critical) |
| `assigned_to` | integer | Filter by assigned agent ID                      |
| `created_by`  | integer | Filter by creator user ID                        |
| `page`        | integer | Page number (default: 1)                         |
| `limit`       | integer | Items per page (default: 10, max: 100)           |

**Example Request:**

```
GET /tickets?status_id=1&priority=high&page=1&limit=20
GET /tickets?assigned_to=5&category_id=2
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

### 44. Get Ticket By ID

| Method | Endpoint       | Access              |
| ------ | -------------- | ------------------- |
| `GET`  | `/tickets/:id` | Authenticated Users |

**Description:** Get ticket details by ID.

- **Customer:** Can only view own tickets
- **Agent/Admin/Super Admin:** Can view all tickets

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
    "category": { ... },
    "status": { ... },
    "created_at": "2026-01-06T11:30:00Z",
    "updated_at": "2026-01-06T11:35:00Z"
  }
}
```

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

| Role | Can Assign? | Condition |
|------|-------------|-----------|
| Agent (level 5) | ✅ | Only tickets assigned to them, to other agents (level ≥5) |
| Admin (level 7+) | ✅ | Any ticket, to agents or higher |
| Customer (< 5) | ❌ | Cannot assign |

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

| Role        | Access Level                                                  |
| ----------- | ------------------------------------------------------------- |
| Admin (5+)  | Can access ALL files                                          |
| User (1-4)  | Can access: own uploads OR files attached to their tickets    |

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
{ "error": "forbidden", "message": "you don't have permission to access this file" }
```

- **404 Not Found:**

```json
{ "error": "not_found", "message": "file not found" }
```

---

### Attachment Database Model ✨ NEW

Attachments are now tracked in the database for security and audit purposes.

**Table: `attachments`**

| Column        | Type      | Description                          |
| ------------- | --------- | ------------------------------------ |
| id            | int       | Primary key, auto-increment          |
| filename      | string    | Unique generated filename            |
| original_name | string    | Original filename from upload        |
| file_size     | int64     | File size in bytes                   |
| mime_type     | string    | MIME type (e.g., image/png)          |
| uploaded_by   | int       | User ID who uploaded the file        |
| ticket_id     | int (null)| Linked ticket ID (optional)          |
| created_at    | timestamp | Upload timestamp                     |

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

| Action        | Customer       | Agent            | Admin  | Super Admin |
| ------------- | -------------- | ---------------- | ------ | ----------- |
| Create        | ✅ Own         | ✅ Own           | ✅ Own | ✅ Own      |
| List All      | ❌ Own only    | ✅ All           | ✅ All | ✅ All      |
| Get By ID     | ✅ Own only    | ✅ All           | ✅ All | ✅ All      |
| Update        | ❌             | ✅ Assigned only | ✅ All | ✅ All      |
| Update Status | ❌             | ✅ Assigned only | ✅ All | ✅ All      |
| Assign Agent  | ❌             | ✅ Re-assign own | ✅     | ✅          |
| Delete        | ❌             | ❌               | ❌     | ✅          |
| Upload File   | ✅             | ✅               | ✅     | ✅          |
| Download File | ✅ Own uploads/tickets | ✅ Own uploads/tickets | ✅ All | ✅ All |

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

---

# Testing Examples

```bash
# 1. Create Super Admin
curl -X POST http://localhost:8080/auth/super \
  -H "Content-Type: application/json" \
  -H "X-Super-Admin-Secret: <secret>" \
  -d '{"email": "superadmin@test.com", "username": "superadmin", "password": "SuperPass123!", "name": "Super", "last_name": "Admin"}'

# 2. Login as Super Admin (with email)
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier": "superadmin@test.com", "password": "SuperPass123!"}'

# 2b. Login with username
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier": "superadmin", "password": "SuperPass123!"}'

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
```

---

# Changelog

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
