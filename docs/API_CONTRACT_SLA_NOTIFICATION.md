# API Contract Specification - SLA & Notification Services

**Sprint 5 - Version 3.0**

---

## Base URLs

| Service               | URL                     | Description                    |
| --------------------- | ----------------------- | ------------------------------ |
| **ms-gateway**        | `http://localhost:8000` | API Gateway (all routes)       |
| **ms-sla**            | `http://localhost:8084` | SLA Management Service         |
| **ms-notification**   | `http://localhost:8085` | Email Notification Service     |

---

## New Features in V3.0

- **SLA Configuration** - CRUD untuk konfigurasi SLA per priority
- **Due Date Calculation** - Otomatis hitung due date saat ticket dibuat
- **Overdue Checker** - Cron job setiap 5 menit untuk cek ticket overdue
- **Email Notifications** - Kirim email overdue & warning via SMTP
- **Ticket SLA Fields** - Fields baru: `due_date`, `is_overdue` di ticket

---

# SLA Service (ms-sla)

## Environment Configuration

```env
APP_PORT=8084
DATABASE_URL=postgres://root:damar@localhost:5432/sla_db?sslmode=disable
JWT_SECRET=your-jwt-secret
INTERNAL_TOKEN=internal-secret-token-change-this
TICKET_SERVICE_URL=http://localhost:8082
NOTIFICATION_SERVICE_URL=http://localhost:8085
CRON_INTERVAL=*/5 * * * *
```

---

## 1. Get All SLA Configs

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
      "is_active": true,
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    },
    {
      "id": 2,
      "priority": "medium",
      "response_time_min": 240,
      "resolve_time_min": 1440,
      "warning_time_min": 30,
      "is_active": true,
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    },
    {
      "id": 3,
      "priority": "high",
      "response_time_min": 60,
      "resolve_time_min": 480,
      "warning_time_min": 30,
      "is_active": true,
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    },
    {
      "id": 4,
      "priority": "critical",
      "response_time_min": 15,
      "resolve_time_min": 240,
      "warning_time_min": 10,
      "is_active": true,
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    }
  ],
  "message": "SLA configs retrieved successfully"
}
```

---

## 2. Get SLA Config by Priority

| Method | Endpoint                 | Access |
| ------ | ------------------------ | ------ |
| `GET`  | `/sla-configs/:priority` | Public |

**Description:** Get SLA config by priority name.

**Path Parameters:**
- `priority` - Priority name: `low`, `medium`, `high`, `critical`

**Success Response (200):**

```json
{
  "data": {
    "id": 4,
    "priority": "critical",
    "response_time_min": 15,
    "resolve_time_min": 240,
    "warning_time_min": 10,
    "is_active": true,
    "created_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-03T10:00:00Z"
  },
  "message": "SLA config retrieved successfully"
}
```

**Error Response (404):**

```json
{
  "error": "SLA config not found"
}
```

---

## 3. Update SLA Config

| Method | Endpoint           | Access      |
| ------ | ------------------ | ----------- |
| `PUT`  | `/sla-configs/:id` | Super Admin |

**Description:** Update SLA configuration by ID. This is the **only** modification endpoint available.

> [!IMPORTANT]
>
> - **Create** and **Delete** endpoints have been **removed**
> - SLA configs are pre-seeded with 4 fixed priorities: `low`, `medium`, `high`, `critical`
> - Only **Update** is allowed to maintain data integrity
> - Updated values are **persisted** and will NOT reset on server restart

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**Request (all fields optional):**

```json
{
  "response_time_min": 20,
  "resolve_time_min": 180,
  "warning_time_min": 10,
  "is_active": true
}
```

**Success Response (200):**

```json
{
  "data": {
    "id": 4,
    "priority": "critical",
    "response_time_min": 20,
    "resolve_time_min": 180,
    "warning_time_min": 10,
    "is_active": true,
    "created_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-03T11:30:00Z"
  },
  "message": "SLA config updated successfully"
}
```

**Error Responses:**

| Code | Error                  |
| ---- | ---------------------- |
| 400  | Invalid request        |
| 401  | Unauthorized           |
| 403  | Super Admin required   |
| 404  | SLA config not found   |

---

## 4. System Configs (NEW)

System configs allow super admins to manage system-wide settings without restarting the service.

### Get All System Configs

| Method | Endpoint          | Access      |
| ------ | ----------------- | ----------- |
| `GET`  | `/system-configs` | Super Admin |

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "config_key": "auto_close_inactive_days",
      "config_value": "3",
      "description": "Number of days to wait before auto-closing inactive ticket",
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    },
    {
      "id": 2,
      "config_key": "cron_interval",
      "config_value": "*/5 * * * *",
      "description": "Cron expression for overdue/warning checker (default: every 5 minutes)",
      "created_at": "2026-02-03T10:00:00Z",
      "updated_at": "2026-02-03T10:00:00Z"
    }
  ],
  "message": "system configs retrieved successfully"
}
```

### Get System Config by Key

| Method | Endpoint               | Access      |
| ------ | ---------------------- | ----------- |
| `GET`  | `/system-configs/:key` | Super Admin |

**Example:** `GET /system-configs/cron_interval`

**Success Response (200):**

```json
{
  "data": {
    "id": 2,
    "config_key": "cron_interval",
    "config_value": "*/5 * * * *",
    "description": "Cron expression for overdue/warning checker",
    "created_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-03T10:00:00Z"
  },
  "message": "system config retrieved successfully"
}
```

### Update System Config

| Method | Endpoint               | Access      |
| ------ | ---------------------- | ----------- |
| `PUT`  | `/system-configs/:key` | Super Admin |

> [!IMPORTANT]
> When updating `cron_interval`, the scheduler will **automatically restart** with the new interval. No need to restart the service.

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Request:**

```json
{
  "config_value": "*/1 * * * *"
}
```

**Success Response (200):**

```json
{
  "data": {
    "id": 2,
    "config_key": "cron_interval",
    "config_value": "*/1 * * * *",
    "description": "Cron expression for overdue/warning checker",
    "created_at": "2026-02-03T10:00:00Z",
    "updated_at": "2026-02-06T15:10:00Z"
  },
  "message": "system config updated successfully"
}
```

### Available Config Keys

| Key                       | Default          | Description                              |
| ------------------------- | ---------------- | ---------------------------------------- |
| `auto_close_inactive_days`| `3`              | Days before auto-close inactive ticket   |
| `cron_interval`           | `*/5 * * * *`    | Cron expression for overdue/warning check|

### Cron Expression Examples

| Expression     | Meaning              |
| -------------- | -------------------- |
| `*/1 * * * *`  | Every 1 minute       |
| `*/5 * * * *`  | Every 5 minutes      |
| `*/10 * * * *` | Every 10 minutes     |
| `0 * * * *`    | Every hour           |
| `0 */2 * * *`  | Every 2 hours        |

---

## 5. Warning Notifications (NEW)

Warning notifications are sent **before** a ticket becomes overdue, based on the `warning_time_min` in SLA config.

### How It Works

1. Scheduler runs every X minutes (configurable via `cron_interval`)
2. Fetches tickets approaching due date within 60 minutes
3. For each ticket:
   - Get `warning_time_min` from SLA config based on priority
   - If `now >= (due_date - warning_time_min)` AND ticket not yet overdue
   - Send warning email to assigned agent (or creator if unassigned)
   - Mark `warning_notified = true` to prevent duplicate notifications

### Warning Times per Priority

| Priority | warning_time_min | Example                          |
| -------- | ---------------- | -------------------------------- |
| low      | 60 min           | Warning 1 hour before due        |
| medium   | 30 min           | Warning 30 min before due        |
| high     | 30 min           | Warning 30 min before due        |
| critical | 10 min           | Warning 10 min before due        |

### Notification Flow

```
Ticket Created (priority: critical)
   ↓
Due Date: 15:00
   ↓
14:50 → Warning email sent (10 min before due)
   ↓
15:00 → Overdue email sent
```

### Email Templates

Warning email includes:
- Ticket ID and Subject
- Priority
- Due Date
- Time remaining until due

---

## Internal Endpoints (Service-to-Service)

### Calculate Due Date

| Method | Endpoint                       | Access   |
| ------ | ------------------------------ | -------- |
| `POST` | `/internal/calculate-due-date` | Internal |

**Description:** Calculate due date for a ticket (called by ms-ticket).

**Headers:**
```
X-Internal-Token: internal-secret-token
```

**Request:**

```json
{
  "priority": "high",
  "created_at": "2026-02-03T10:00:00Z"
}
```

**Success Response (200):**

```json
{
  "data": {
    "due_date": "2026-02-03T18:00:00Z",
    "warning_time": "2026-02-03T17:30:00Z"
  },
  "message": "Due date calculated successfully"
}
```

---

# Notification Service (ms-notification)

## Environment Configuration

```env
APP_PORT=8085
JWT_SECRET=your-jwt-secret
INTERNAL_TOKEN=internal-secret-token-change-this
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_EMAIL=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FRONTEND_URL=http://localhost:5173
```

---

## Internal Endpoints (Service-to-Service)

### 1. Send Generic Email

| Method | Endpoint               | Access   |
| ------ | ---------------------- | -------- |
| `POST` | `/internal/send-email` | Internal |

**Headers:**
```
X-Internal-Token: internal-secret-token
```

**Request:**

```json
{
  "to": "user@example.com",
  "subject": "Email Subject",
  "template": "ticket_overdue",
  "data": {
    "TicketID": 123,
    "Subject": "Bug pada login",
    "Priority": "high",
    "DueDate": "2026-02-03T18:00:00Z",
    "OverdueBy": "2 hours"
  }
}
```

**Success Response (200):**

```json
{
  "message": "email sent successfully",
  "data": {
    "to": "user@example.com",
    "subject": "Email Subject",
    "template": "ticket_overdue"
  }
}
```

---

### 2. Send Overdue Notification

| Method | Endpoint                    | Access   |
| ------ | --------------------------- | -------- |
| `POST` | `/internal/notify/overdue`  | Internal |

**Headers:**
```
X-Internal-Token: internal-secret-token
```

**Request:**

```json
{
  "to": "agent@example.com",
  "data": {
    "ticket_id": 123,
    "subject": "Bug pada login",
    "priority": "high",
    "due_date": "2026-02-03T18:00:00Z",
    "overdue_by": "2 hours"
  }
}
```

---

### 3. Send Warning Notification

| Method | Endpoint                    | Access   |
| ------ | --------------------------- | -------- |
| `POST` | `/internal/notify/warning`  | Internal |

**Headers:**
```
X-Internal-Token: internal-secret-token
```

**Request:**

```json
{
  "to": "agent@example.com",
  "data": {
    "ticket_id": 123,
    "subject": "Bug pada login",
    "priority": "high",
    "due_date": "2026-02-03T18:00:00Z",
    "time_left": "30 minutes"
  }
}
```

---

# MS-Ticket Changes (V3.0)

## New Ticket Fields

Ticket model sekarang memiliki field SLA dan Response Tracking:

```json
{
  "id": 123,
  "subject": "Bug pada login",
  "description": "...",
  "priority": "high",
  "due_date": "2026-02-03T18:00:00Z",
  "is_overdue": false,
  "assigned_at": "2026-02-03T10:30:00Z",
  "first_response_at": null,
  "response_deadline": "2026-02-03T11:30:00Z",
  "response_delay": "Response delay (15 min)",
  "response_delay_min": 15,
  "status": {...},
  "category": {...},
  "created_at": "2026-02-03T10:00:00Z",
  "updated_at": "2026-02-03T10:00:00Z"
}
```

### Response Tracking Fields

| Field | Description |
|-------|-------------|
| `assigned_at` | Waktu ticket di-assign ke agent |
| `first_response_at` | Waktu respons pertama dari agent (via chat) |
| `response_deadline` | Deadline respons = `assigned_at + response_time_min` |
| `response_delay` | Label delay jika belum respons, e.g. "Response delay (15 min)" |
| `response_delay_min` | Delay dalam menit (untuk sorting) |

### Response Tracking Flow

```
1. Ticket dibuat
   → due_date = created_at + resolve_time_min

2. Ticket di-assign ke agent
   → assigned_at = now
   → response_deadline = now + response_time_min

3. Agent mengirim pesan pertama (WebSocket chat)
   → ms-chat panggil PUT /internal/tickets/:id/first-response
   → first_response_at = now
   → response_delay = null (tidak ada delay)

4. Jika agent belum respons dan now > response_deadline
   → response_delay = "Response delay (X min)"
   → Ticket tampil di atas list dengan label delay
```

## New Filter Parameters

```
GET /tickets?is_overdue=true
GET /tickets?response_delayed=true
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `is_overdue` | boolean | Filter tickets yang sudah overdue (due_date lewat) |
| `response_delayed` | boolean | Filter tickets yang response delay (agent belum respon) |

### Sorting Behavior

Ticket list otomatis di-sort dengan **delayed tickets di atas**:
```sql
ORDER BY 
  CASE WHEN response_delayed THEN delay_minutes ELSE 0 END DESC,
  created_at DESC
```

## Internal Endpoints (for ms-sla & ms-chat)

| Method | Endpoint                              | Description                    |
| ------ | ------------------------------------- | ------------------------------ |
| `GET`  | `/internal/tickets/check-overdue`     | Get tickets near/past due date |
| `PUT`  | `/internal/tickets/:id/overdue`       | Mark ticket as overdue         |
| `PUT`  | `/internal/tickets/:id/due-date`      | Set due date for ticket        |
| `PUT`  | `/internal/tickets/:id/first-response`| Mark first response time       |

---

# Default SLA Configuration

| Priority | Response Time | Resolution Time | Warning Before |
|----------|---------------|-----------------|----------------|
| Low      | 24 hours      | 72 hours (3d)   | 60 min         |
| Medium   | 4 hours       | 24 hours        | 30 min         |
| High     | 1 hour        | 8 hours         | 30 min         |
| Critical | 15 min        | 4 hours         | 10 min         |

---

# Tutorial: Running the Services

## 1. Setup Database

```bash
# Create sla_db database
psql -U root -c "CREATE DATABASE sla_db;"
```

## 2. Configure Environment

```bash
# ms-sla/.env
APP_PORT=8084
DATABASE_URL=postgres://root:damar@localhost:5432/sla_db?sslmode=disable
JWT_SECRET=your-jwt-secret
INTERNAL_TOKEN=internal-secret-token-change-this
TICKET_SERVICE_URL=http://localhost:8082
NOTIFICATION_SERVICE_URL=http://localhost:8085
CRON_INTERVAL=*/5 * * * *

# ms-notification/.env
APP_PORT=8085
JWT_SECRET=your-jwt-secret
INTERNAL_TOKEN=internal-secret-token-change-this
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_EMAIL=your-email@gmail.com
SMTP_PASSWORD=your-app-password
FRONTEND_URL=http://localhost:5173
```

## 3. Run Services

```bash
# Terminal 1 - ms-sla
cd ms-sla
go mod tidy
go run cmd/server/main.go

# Terminal 2 - ms-notification
cd ms-notification
go mod tidy
go run cmd/server/main.go
```

## 4. Verify Services

```bash
# Check health
curl http://localhost:8084/health
curl http://localhost:8085/health

# Get SLA configs
curl http://localhost:8084/sla-configs
```

## 5. Test Calculate Due Date

```bash
curl -X POST http://localhost:8084/internal/calculate-due-date \
  -H "X-Internal-Token: internal-secret-token-change-this" \
  -H "Content-Type: application/json" \
  -d '{"priority": "high", "created_at": "2026-02-03T10:00:00Z"}'
```

---

# Architecture Flow

```
   ┌──────────────┐
   │   Frontend   │
   └──────┬───────┘
          │
          ▼
   ┌──────────────┐
   │  ms-gateway  │
   └──────┬───────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌─────────┐ ┌─────────┐
│ms-ticket│ │ ms-sla  │──┐
└────┬────┘ └────┬────┘  │
     │           │       │ Cron: Check Overdue
     │◄──────────┘       │
     │  Calculate        │
     │  Due Date         ▼
     │            ┌──────────────┐
     └───────────►│ms-notification│
                  │   (Email)    │
                  └──────────────┘
```

---

# SSE Push Notifications (ms-notification)

## Overview

Server-Sent Events (SSE) untuk real-time push notification ke user. User akan menerima notifikasi saat status ticket berubah.

## Environment Configuration (ms-notification)

```env
DATABASE_URL=postgres://root:damar@localhost:5432/notification_db?sslmode=disable
JWT_SECRET=your-jwt-secret
INTERNAL_TOKEN=internal-secret-token-change-this
```

---

## SSE Stream Endpoint

| Method | Endpoint               | Access           |
| ------ | ---------------------- | ---------------- |
| `GET`  | `/notifications/stream`| JWT (All Users)  |

**Description:** Buka koneksi SSE untuk menerima notifikasi real-time.

**Headers:**

```
Authorization: Bearer <jwt_token>
```

**SSE Events:**

```
event: connected
data: {"message":"connected","user_id":5}

event: notification
data: {"id":1,"type":"status_change","title":"Status Tiket #42 Diperbarui","message":"Status tiket berubah dari open ke in_progress","metadata":{"ticket_id":42,"old_status":"open","new_status":"in_progress"},"is_read":false,"created_at":"2026-02-05T10:00:00Z"}
```

**Frontend Example:**

```javascript
const eventSource = new EventSource('/notifications/stream', {
  headers: { 'Authorization': 'Bearer ' + token }
});

eventSource.addEventListener('notification', (e) => {
  const data = JSON.parse(e.data);
  showToast(data.title, data.message);
});
```

---

## Get Notification History

| Method | Endpoint             | Access           |
| ------ | -------------------- | ---------------- |
| `GET`  | `/notifications`     | JWT (All Users)  |

**Query Parameters:**

| Parameter | Type | Default | Description     |
| --------- | ---- | ------- | --------------- |
| `page`    | int  | 1       | Page number     |
| `limit`   | int  | 20      | Items per page  |

**Success Response (200):**

```json
{
  "data": [
    {
      "id": 1,
      "type": "status_change",
      "title": "Status Tiket #42 Diperbarui",
      "message": "Status tiket berubah dari open ke in_progress",
      "metadata": {"ticket_id": 42, "old_status": "open", "new_status": "in_progress"},
      "is_read": false,
      "created_at": "2026-02-05T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 5
  }
}
```

---

## Get Unread Count

| Method | Endpoint                       | Access           |
| ------ | ------------------------------ | ---------------- |
| `GET`  | `/notifications/unread-count`  | JWT (All Users)  |

**Success Response (200):**

```json
{
  "data": {
    "count": 3
  }
}
```

---

## Mark Notification as Read

| Method | Endpoint                  | Access           |
| ------ | ------------------------- | ---------------- |
| `PUT`  | `/notifications/:id/read` | JWT (All Users)  |

**Success Response (200):**

```json
{
  "message": "notification marked as read"
}
```

---

## Mark All as Read

| Method | Endpoint                  | Access           |
| ------ | ------------------------- | ---------------- |
| `PUT`  | `/notifications/read-all` | JWT (All Users)  |

**Success Response (200):**

```json
{
  "message": "all notifications marked as read"
}
```

---

## Internal Push Endpoint

| Method | Endpoint               | Access   |
| ------ | ---------------------- | -------- |
| `POST` | `/internal/notify/push`| Internal |

**Description:** Kirim push notification ke user (dipanggil oleh ms-ticket saat status berubah).

**Headers:**

```
X-Internal-Token: <internal_token>
```

**Request:**

```json
{
  "user_id": 5,
  "type": "status_change",
  "title": "Status Tiket #42 Diperbarui",
  "message": "Status tiket berubah dari open ke in_progress",
  "metadata": {
    "ticket_id": 42,
    "old_status": "open",
    "new_status": "in_progress"
  }
}
```

**Success Response (201):**

```json
{
  "message": "notification sent",
  "data": {
    "id": 1,
    "user_id": 5,
    "type": "status_change"
  }
}
```

---

## Notification Types

| Type           | Description                          |
| -------------- | ------------------------------------ |
| `status_change`| Status ticket berubah                |
| `assignment`   | Ticket di-assign ke agent            |
| `overdue`      | Ticket melebihi batas waktu SLA      |
| `warning`      | Warning sebelum overdue              |
| `auto_close`   | Ticket ditutup otomatis              |

---

# Gmail SMTP Setup

1. Enable 2-Factor Authentication di Google Account
2. Generate App Password: Google Account → Security → App Passwords
3. Use App Password sebagai `SMTP_PASSWORD`

