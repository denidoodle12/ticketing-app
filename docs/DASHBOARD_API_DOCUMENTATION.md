# Dashboard Statistics API Documentation

## Overview

Dashboard Statistics API menyediakan endpoint untuk mendapatkan ringkasan statistik tiket. Implementasi menggunakan **counter-based approach** dengan **single unified table** yang menghasilkan query time O(1) untuk semua role.

**New Features:**

- ✨ `closed_count` pada basic stats
- ✨ Optional `distribution` data for pie charts
- ✨ Optional `trend` data for bar charts
- ✨ Optional `comparison` data for trend indicators

---

## Database Schema

### Table: `ticket_stats` (Unified)

Menyimpan semua counter dalam satu tabel.

| Column            | Type        | Description                          |
| ----------------- | ----------- | ------------------------------------ |
| id                | SERIAL      | Primary key                          |
| user_id           | INT         | User ID (0 = global stats)           |
| role_type         | VARCHAR(20) | "global", "creator", atau "assignee" |
| total_tickets     | INT         | Total tiket                          |
| open_count        | INT         | Tiket open                           |
| in_progress_count | INT         | Tiket in_progress                    |
| resolved_count    | INT         | Tiket resolved                       |
| closed_count      | INT         | Tiket closed ✨ NEW                  |
| overdue_count     | INT         | Tiket overdue                        |
| updated_at        | TIMESTAMP   | Last update time                     |

**Index:** `idx_user_role` on `(user_id, role_type)`

---

## API Endpoints

### 1. Get Dashboard Statistics

**Endpoint:** `GET /dashboard/stats`

**Authorization:** Bearer Token (All authenticated users)

**Description:** Mendapatkan statistik tiket berdasarkan role user.

#### Query Parameters (Optional)

| Parameter      | Type   | Default  | Description                                            |
| -------------- | ------ | -------- | ------------------------------------------------------ |
| `include`      | string | -        | Comma-separated: `trend`, `distribution`, `comparison` |
| `trend_period` | string | `weekly` | `weekly` (7 days) atau `monthly` (28 days)             |

**Role-Based Response:**

| Role     | Level | Data                     |
| -------- | ----- | ------------------------ |
| Customer | < 2   | Tiket dibuat sendiri     |
| Agent    | 2     | Tiket dibuat + di-assign |
| Admin    | >= 5  | Semua tiket              |

#### Parameter Validation

> [!NOTE]
>
> - Unknown query parameters will be rejected with an error
> - `include` only accepts: `trend`, `distribution`, `comparison` (comma-separated)
> - `trend_period` only accepts: `weekly`, `monthly`

**Error Response - Unknown Parameter (400):**

```json
{
  "error": "unknown query parameter(s): typo_param",
  "valid_params": ["include", "trend_period"],
  "hint": "check for typos in parameter names"
}
```

**Error Response - Invalid `include` Value (400):**

```json
{
  "error": "invalid include value(s): invalid_value",
  "valid_values": ["trend", "distribution", "comparison"],
  "hint": "use comma-separated values like: include=trend,distribution"
}
```

**Error Response - Invalid `trend_period` Value (400):**

```json
{
  "error": "invalid trend_period: daily",
  "valid_values": ["weekly", "monthly"],
  "hint": "trend_period defaults to 'weekly' if not specified"
}
```

---

### Basic Request (Backward Compatible)

```http
GET /dashboard/stats
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "data": {
    "total_tickets": 150,
    "open_count": 25,
    "in_progress_count": 45,
    "resolved_count": 80,
    "closed_count": 40,
    "overdue_count": 5
  }
}
```

---

### Extended Request with All Data

```http
GET /dashboard/stats?include=trend,distribution,comparison&trend_period=weekly
Authorization: Bearer <token>
```

**Response (200 OK):**

```json
{
  "data": {
    "total_tickets": 150,
    "open_count": 25,
    "in_progress_count": 45,
    "resolved_count": 80,
    "closed_count": 40,
    "overdue_count": 5,

    "distribution": {
      "by_status": [
        {
          "status": "open",
          "display_name": "Open",
          "count": 25,
          "percentage": 16.67,
          "color": "#3B82F6"
        },
        {
          "status": "in_progress",
          "display_name": "In Progress",
          "count": 45,
          "percentage": 30.0,
          "color": "#F59E0B"
        },
        {
          "status": "resolved",
          "display_name": "Resolved",
          "count": 80,
          "percentage": 53.33,
          "color": "#22C55E"
        }
      ],
      "by_priority": [
        { "priority": "low", "count": 40, "color": "#94A3B8" },
        { "priority": "medium", "count": 60, "color": "#3B82F6" },
        { "priority": "high", "count": 35, "color": "#F59E0B" },
        { "priority": "critical", "count": 15, "color": "#EF4444" }
      ]
    },

    "trend": {
      "period": "weekly",
      "start_date": "2026-01-29",
      "end_date": "2026-02-05",
      "items": [
        {
          "date": "2026-01-29",
          "label": "Wed",
          "created": 12,
          "open": 5,
          "in_progress": 8,
          "resolved": 10,
          "closed": 3,
          "overdue": 1
        }
      ]
    },

    "comparison": {
      "period": "yesterday",
      "changes": {
        "total_tickets": {
          "current": 12,
          "previous": 10,
          "change": 2,
          "change_percent": 20.0
        },
        "open_count": {
          "current": 5,
          "previous": 4,
          "change": 1,
          "change_percent": 25.0
        },
        "in_progress_count": {
          "current": 3,
          "previous": 4,
          "change": -1,
          "change_percent": -25.0
        },
        "resolved_count": {
          "current": 4,
          "previous": 2,
          "change": 2,
          "change_percent": 100.0
        },
        "closed_count": {
          "current": 2,
          "previous": 1,
          "change": 1,
          "change_percent": 100.0
        },
        "overdue_count": {
          "current": 0,
          "previous": 1,
          "change": -1,
          "change_percent": -100.0
        }
      }
    }
  }
}
```

---

### 2. Recalculate Counters

**Endpoint:** `POST /dashboard/recalculate`

**Authorization:** Bearer Token (Super Admin only)

**Description:** Menghitung ulang semua counter dari data tiket aktual.

**Request:**

```http
POST /dashboard/recalculate
Authorization: Bearer <super_admin_token>
```

**Response (200 OK):**

```json
{
  "message": "counters recalculated successfully"
}
```

---

## Architecture

### Counter Sync Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         STARTUP                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. AutoMigrate ticket_stats table                              │
│  2. SeedGlobalStats() - Create global row if not exist          │
│  3. RecalculateAll() - Sync all stats from ticket data          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 BACKGROUND SCHEDULER (1 min)                     │
├─────────────────────────────────────────────────────────────────┤
│  RecalculateOverdue() - Real-time overdue counter sync          │
│    ├── Count tickets where due_date < NOW()                     │
│    ├── Update global overdue count                              │
│    ├── Update is_overdue flag on tickets                        │
│    └── Update per-user overdue counts                           │
└─────────────────────────────────────────────────────────────────┘
```

### Query Performance

| Role     | Query                              | Time Complexity |
| -------- | ---------------------------------- | --------------- |
| Admin    | Read single row (global)           | O(1)            |
| Customer | Read single row (creator)          | O(1)            |
| Agent    | SUM of 2 rows (creator + assignee) | O(1)            |

---

## Files Structure

```
ms-ticket/
├── internal/
│   ├── model/
│   │   ├── ticket_stats.go      # Unified stats model
│   │   └── dashboard.go         # DashboardStats + Extended models
│   │
│   ├── repository/
│   │   └── stats_repository.go  # All stats operations + analytics
│   │
│   ├── service/
│   │   └── dashboard_service.go # Role-based stats + extended stats
│   │
│   └── handler/
│       ├── dashboard_handler.go # API endpoints + query params
│       └── internal_handler.go  # Overdue sync (ms-sla)
│
└── cmd/server/main.go           # Initialization & wiring
```

---

## Error Responses

| Status Code | Error                 | Description                    |
| ----------- | --------------------- | ------------------------------ |
| 401         | Unauthorized          | Token tidak valid atau expired |
| 403         | Forbidden             | Role tidak memiliki akses      |
| 500         | Internal Server Error | Database error                 |
