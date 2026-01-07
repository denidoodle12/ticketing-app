# API Contract Specification

**Golang Clean Architecture Microservices - Version 2.0 (RBAC Edition)**

---

## Base URLs

| Service                | URL                     |
| ---------------------- | ----------------------- |
| **Gateway**            | `http://localhost:8000` |
| **ms-auth**            | `http://localhost:8080` |
| **ms-user-management** | `http://localhost:8081` |

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
      "created_at": "2025-12-08T10:00:00Z",
      "updated_at": "2025-12-08T10:00:00Z"
    }
  }
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
  "password": "string (required, min 6 chars)",
  "name": "string (required)",
  "role": "string (required: customer|agent|admin)"
}
```

**Authorization Rules:**

| Role           | Can Create             |
| -------------- | ---------------------- |
| Admin          | customer, agent        |
| Super Admin    | customer, agent, admin |
| Customer/Agent | ❌ Cannot create       |

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
  "password": "string (required, min 6 chars)",
  "name": "string (required)"
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
      "role": "super_admin"
    }
  }
}
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
    "role": {
      "id": 1,
      "name": "customer",
      "description": "Regular customer",
      "level": 1
    },
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
    "role": "customer",
    "role_id": 1,
    "created_at": "2025-12-08T10:00:00Z",
    "updated_at": "2025-12-08T10:00:00Z"
  }
}
```

---

## 8. Get User With Role Details ✨ NEW

| Method | Endpoint              | Access        |
| ------ | --------------------- | ------------- |
| `GET`  | `/users/:id/with-role` | Authenticated |

**Success Response (200):**

```json
{
  "data": {
    "id": 1,
    "email": "user@test.com",
    "username": "user1",
    "name": "User One",
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
  "email": "string (optional, email format)"
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

> [!NOTE]
> Cannot delete super_admin users

---

## 11. Change User Role ✨ NEW

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

## 12. List All Roles

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
      "name": "agent",
      "description": "Support agent",
      "level": 5,
      "is_system_role": true
    },
    {
      "id": 3,
      "name": "admin",
      "description": "System administrator",
      "level": 8,
      "is_system_role": true
    },
    {
      "id": 4,
      "name": "super_admin",
      "description": "Super administrator",
      "level": 10,
      "is_system_role": true
    }
  ]
}
```

---

## 13. Get Role By ID

| Method | Endpoint     | Access            |
| ------ | ------------ | ----------------- |
| `GET`  | `/roles/:id` | Admin/Super Admin |

---

## 14. Create Role

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

---

## 15. Update Role

| Method | Endpoint     | Access           |
| ------ | ------------ | ---------------- |
| `PUT`  | `/roles/:id` | Super Admin Only |

> [!NOTE]
> Cannot update system roles (customer, agent, admin, super_admin)

---

## 16. Delete Role

| Method   | Endpoint     | Access           |
| -------- | ------------ | ---------------- |
| `DELETE` | `/roles/:id` | Super Admin Only |

> [!NOTE]
> Cannot delete system roles or roles with assigned users

---

## 17. Get Role Permissions

| Method | Endpoint                 | Access            |
| ------ | ------------------------ | ----------------- |
| `GET`  | `/roles/:id/permissions` | Admin/Super Admin |

---

## 18. Assign Permissions to Role

| Method | Endpoint                 | Access           |
| ------ | ------------------------ | ---------------- |
| `POST` | `/roles/:id/permissions` | Super Admin Only |

**Request:**

```json
{
  "permission_ids": [1, 2, 5, 8]
}
```

---

## 19. Remove Permissions from Role

| Method   | Endpoint                 | Access           |
| -------- | ------------------------ | ---------------- |
| `DELETE` | `/roles/:id/permissions` | Super Admin Only |

**Request:**

```json
{
  "permission_ids": [1, 2]
}
```

---

# Permission Management ✨ NEW

## 20. List All Permissions

| Method | Endpoint       | Access            |
| ------ | -------------- | ----------------- |
| `GET`  | `/permissions` | Admin/Super Admin |

**Query Parameters:**

- `action`: Filter by action (view, create, update, delete)
- `resource`: Filter by resource (users, tickets, roles, etc)

---

## 21. Create Permission

| Method | Endpoint       | Access           |
| ------ | -------------- | ---------------- |
| `POST` | `/permissions` | Super Admin Only |

**Request:**

```json
{
  "name": "string (required)",
  "action": "string (required: view|create|update|delete|manage)",
  "resource": "string (required)",
  "description": "string (required)"
}
```

---

# Internal Endpoints

## 22. Create User (Internal)

| Method | Endpoint          | Access           |
| ------ | ----------------- | ---------------- |
| `POST` | `/internal/users` | X-Internal-Token |

> [!CAUTION]
> NOT exposed through gateway. Only accessible by ms-auth service.

---

## 23. Validate User (Internal)

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
```

---

# Testing Examples

```bash
# 1. Create Super Admin
curl -X POST http://localhost:8080/auth/super \
  -H "Content-Type: application/json" \
  -H "X-Super-Admin-Secret: <secret>" \
  -d '{"email": "superadmin@test.com", "password": "SuperPass123!", "name": "Super Admin"}'

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
  -d '{"email": "admin@test.com", "username": "admin", "password": "AdminPass123!", "name": "Admin", "role": "admin"}'

# 4. Create Customer (as Admin)
curl -X POST http://localhost:8080/auth/register \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "customer@test.com", "username": "customer1", "password": "Pass123!", "name": "Customer", "role": "customer"}'

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
```

---

# Changelog

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
