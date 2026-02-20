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

| Parameter      | Type   | Default        | Description                                            |
| -------------- | ------ | -------------- | ------------------------------------------------------ |
| `include`      | string | -              | Comma-separated: `trend`, `distribution`, `comparison` |
| `trend_period` | string | `weekly`       | `weekly` (minggu ini) atau `monthly` (per bulan)       |
| `trend_month`  | string | bulan sekarang | Bulan target untuk monthly trend (format: `YYYY-MM`)   |

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
> - `trend_month` format: `YYYY-MM` (e.g., `2026-02`). Defaults to current month if not specified
> - `trend_month` hanya berlaku jika `trend_period=monthly`

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

**Error Response - Invalid `trend_month` Format (400):**

```json
{
  "error": "invalid trend_month format: 2026-13",
  "format": "YYYY-MM",
  "example": "2026-02",
  "hint": "trend_month defaults to current month if not specified"
}
```

---

## Parameter Guide

### Parameter: `include`

Menentukan data tambahan yang ingin ditampilkan. Bisa dikombinasikan dengan koma.

| Value          | Kegunaan                         | UI Component        |
| -------------- | -------------------------------- | ------------------- |
| `trend`        | Data trend tiket per hari        | 📊 Bar Chart        |
| `distribution` | Breakdown status & priority      | 🥧 Pie Chart        |
| `comparison`   | Perbandingan hari ini vs kemarin | 📈 Trend Indicators |

**Contoh kombinasi:**

```http
# Hanya trend (bar chart)
GET /dashboard/stats?include=trend

# Hanya distribution (pie chart)
GET /dashboard/stats?include=distribution

# Trend + distribution
GET /dashboard/stats?include=trend,distribution

# Semua data
GET /dashboard/stats?include=trend,distribution,comparison
```

---

### Parameter: `trend_period`

Menentukan rentang waktu data trend untuk bar chart. Hanya berlaku jika `include` mengandung `trend`.

| Value     | Rentang Waktu                    | Data Points           | Label Format          |
| --------- | -------------------------------- | --------------------- | --------------------- |
| `weekly`  | Minggu s/d Sabtu (selalu 7 hari) | 7 item (per hari)     | `Sun`, `Mon`, …       |
| `monthly` | 1 bulan kalender (1–28/31)       | 4–6 item (per minggu) | `Week 1`, `Week 2`, … |

> [!NOTE]
>
> - Default: `weekly` (jika tidak diisi atau `include` mengandung `trend`)
> - `weekly` selalu mengembalikan **7 item** (Minggu–Sabtu). Hari tanpa data diisi nilai 0
> - `monthly` selalu mengembalikan **semua minggu** dalam bulan tersebut (4-6 item). Minggu tanpa data diisi nilai 0
> - Minggu dimulai dari hari **Minggu (Sunday)**
> - Parameter ini **diabaikan** jika `include` tidak mengandung `trend`

**Contoh penggunaan:**

```http
# Weekly trend (default) — Minggu s/d Sabtu (selalu 7 hari)
GET /dashboard/stats?include=trend
GET /dashboard/stats?include=trend&trend_period=weekly

# Monthly trend — bulan ini (default)
GET /dashboard/stats?include=trend&trend_period=monthly

# Monthly trend — bulan Januari 2026
GET /dashboard/stats?include=trend&trend_period=monthly&trend_month=2026-01

# Monthly trend + distribution — bulan Desember 2025
GET /dashboard/stats?include=trend,distribution&trend_period=monthly&trend_month=2025-12
```

---

### Trend Response Fields

Setiap item dalam `trend.items` berisi data agregat:

- **Weekly**: data per hari, `date` = tanggal, `label` = nama hari (`Sun`, `Mon`, …). Selalu 7 item, hari kosong = 0
- **Monthly**: data per minggu (Minggu–Sabtu), `date` = tanggal Minggu minggu tersebut, `label` = `Week 1`, `Week 2`, …

| Field         | Type   | Description                        |
| ------------- | ------ | ---------------------------------- |
| `date`        | string | Tanggal (format: `YYYY-MM-DD`)     |
| `label`       | string | Label singkat hari (`Mon`, `Tue`)  |
| `created`     | int    | Jumlah tiket dibuat pada hari itu  |
| `open`        | int    | Jumlah tiket berstatus open        |
| `in_progress` | int    | Jumlah tiket berstatus in_progress |
| `pending`     | int    | Jumlah tiket berstatus pending     |
| `resolved`    | int    | Jumlah tiket berstatus resolved    |
| `closed`      | int    | Jumlah tiket berstatus closed      |
| `overdue`     | int    | Jumlah tiket overdue               |
| `low`         | int    | Jumlah tiket priority low          |
| `medium`      | int    | Jumlah tiket priority medium       |
| `high`        | int    | Jumlah tiket priority high         |
| `critical`    | int    | Jumlah tiket priority critical     |

---

### Weekly vs Monthly — Response Comparison

**Weekly** (`trend_period=weekly`) — contoh jika hari ini Rabu 11 Feb (selalu 7 item):

```json
{
  "trend": {
    "period": "weekly",
    "start_date": "2026-02-08",
    "end_date": "2026-02-14",
    "items": [
      {
        "date": "2026-02-08",
        "label": "Sun",
        "created": 3,
        "open": 1,
        "in_progress": 2,
        "pending": 0,
        "resolved": 1,
        "closed": 0,
        "overdue": 0,
        "low": 1,
        "medium": 1,
        "high": 1,
        "critical": 0
      },
      {
        "date": "2026-02-09",
        "label": "Mon",
        "created": 8,
        "open": 3,
        "in_progress": 4,
        "pending": 1,
        "resolved": 6,
        "closed": 2,
        "overdue": 1,
        "low": 2,
        "medium": 3,
        "high": 2,
        "critical": 1
      },
      {
        "date": "2026-02-10",
        "label": "Tue",
        "created": 5,
        "open": 2,
        "in_progress": 3,
        "pending": 0,
        "resolved": 4,
        "closed": 1,
        "overdue": 0,
        "low": 1,
        "medium": 2,
        "high": 1,
        "critical": 1
      },
      {
        "date": "2026-02-11",
        "label": "Wed",
        "created": 2,
        "open": 1,
        "in_progress": 1,
        "pending": 0,
        "resolved": 2,
        "closed": 0,
        "overdue": 0,
        "low": 1,
        "medium": 1,
        "high": 0,
        "critical": 0
      },
      {
        "date": "2026-02-12",
        "label": "Thu",
        "created": 0,
        "open": 0,
        "in_progress": 0,
        "pending": 0,
        "resolved": 0,
        "closed": 0,
        "overdue": 0,
        "low": 0,
        "medium": 0,
        "high": 0,
        "critical": 0
      },
      {
        "date": "2026-02-13",
        "label": "Fri",
        "created": 0,
        "open": 0,
        "in_progress": 0,
        "pending": 0,
        "resolved": 0,
        "closed": 0,
        "overdue": 0,
        "low": 0,
        "medium": 0,
        "high": 0,
        "critical": 0
      },
      {
        "date": "2026-02-14",
        "label": "Sat",
        "created": 0,
        "open": 0,
        "in_progress": 0,
        "pending": 0,
        "resolved": 0,
        "closed": 0,
        "overdue": 0,
        "low": 0,
        "medium": 0,
        "high": 0,
        "critical": 0
      }
    ]
  }
}
```

**Monthly** (`trend_period=monthly`) — Februari 2026, data per minggu (selalu semua minggu, minggu tanpa data = 0):

```json
{
  "trend": {
    "period": "monthly",
    "start_date": "2026-02-01",
    "end_date": "2026-02-28",
    "items": [
      {
        "date": "2026-02-01",
        "label": "Week 1",
        "created": 35,
        "open": 12,
        "in_progress": 18,
        "pending": 5,
        "resolved": 28,
        "closed": 8,
        "overdue": 3,
        "low": 8,
        "medium": 12,
        "high": 10,
        "critical": 5
      },
      {
        "date": "2026-02-08",
        "label": "Week 2",
        "created": 28,
        "open": 10,
        "in_progress": 15,
        "pending": 3,
        "resolved": 22,
        "closed": 6,
        "overdue": 1,
        "low": 7,
        "medium": 10,
        "high": 8,
        "critical": 3
      },
      {
        "date": "2026-02-15",
        "label": "Week 3",
        "created": 30,
        "open": 11,
        "in_progress": 16,
        "pending": 4,
        "resolved": 25,
        "closed": 7,
        "overdue": 2,
        "low": 8,
        "medium": 11,
        "high": 7,
        "critical": 4
      },
      {
        "date": "2026-02-22",
        "label": "Week 4",
        "created": 22,
        "open": 8,
        "in_progress": 12,
        "pending": 2,
        "resolved": 18,
        "closed": 5,
        "overdue": 1,
        "low": 5,
        "medium": 8,
        "high": 6,
        "critical": 3
      }
    ]
  }
}
```

> [!TIP]
>
> - Gunakan `weekly` untuk overview minggu ini (selalu 7 data points, Minggu–Sabtu). Hari tanpa tiket diisi 0
> - Gunakan `monthly` untuk analisis per minggu (selalu semua minggu dalam bulan). Minggu tanpa tiket diisi 0
> - Minggu dimulai dari hari **Minggu (Sunday)**
> - Monthly: `date` menunjukkan hari Minggu (Sunday) dari minggu tersebut

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
      "start_date": "2026-02-08",
      "end_date": "2026-02-14",
      "items": [
        {
          "date": "2026-02-08",
          "label": "Sun",
          "created": 3,
          "open": 1,
          "in_progress": 2,
          "pending": 0,
          "resolved": 1,
          "closed": 0,
          "overdue": 0,
          "low": 1,
          "medium": 1,
          "high": 1,
          "critical": 0
        },
        {
          "date": "2026-02-09",
          "label": "Mon",
          "created": 12,
          "open": 5,
          "in_progress": 8,
          "pending": 2,
          "resolved": 10,
          "closed": 3,
          "overdue": 1,
          "low": 3,
          "medium": 4,
          "high": 3,
          "critical": 2
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
