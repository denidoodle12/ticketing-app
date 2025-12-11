# ERD - Enterprise Ticketing System

## Overview Diagram

Database menggunakan **PostgreSQL** dengan arsitektur per-service schema. Semua ID menggunakan **UUID** untuk konsistensi antar microservices.

---

## Entitas & Relasi

### 1. auth_accounts
Tabel untuk menyimpan kredensial autentikasi user.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `email` | varchar | UNIQUE, NOT NULL | Email untuk login |
| `password_hash` | varchar | NOT NULL | Password yang di-hash |
| `is_login_allowed` | boolean | DEFAULT true | Status akun aktif/tidak |
| `last_login_at` | timestamp | | Waktu login terakhir |
| `created_at` | timestamp | NOT NULL | Waktu pembuatan akun |

**Relasi:** One-to-One dengan `user_profiles`

---

### 2. user_profiles
Tabel untuk menyimpan data profil lengkap user.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `auth_account_id` | uuid | FK → auth_accounts.id | Relasi ke auth |
| `full_name` | varchar | NOT NULL | Nama lengkap |
| `phone_number` | varchar | | Nomor telepon |
| `avatar_url` | varchar | | URL foto profil |
| `department_id` | uuid | FK → departments.id | Departemen user |
| `role` | enum_role | NOT NULL | Role: customer, agent, admin, super_admin |
| `deleted_at` | timestamp | | Soft delete marker |
| `stat_tickets_created_count` | integer | DEFAULT 0 | Statistik tiket dibuat |
| `stat_tickets_resolved_count` | integer | DEFAULT 0 | Statistik tiket resolved |
| `updated_at` | timestamp | | Waktu update terakhir |

**Enum `role`:** `customer`, `agent`, `admin`, `super_admin`

**Relasi:**
- Many-to-One dengan `departments`
- One-to-Many dengan `tickets` (sebagai creator)
- One-to-Many dengan `tickets` (sebagai assignee)
- One-to-Many dengan `comments`

---

### 3. account_moderations
Tabel untuk audit log moderasi akun (ban/unban/etc).

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `user_profile_id` | uuid | FK → user_profiles.id | User yang dimoderasi |
| `executor_profile_id` | uuid | FK → user_profiles.id | Admin yang melakukan aksi |
| `action` | enum_moderation_action | NOT NULL | Jenis aksi moderasi |
| `reason` | text | | Alasan moderasi |
| `created_at` | timestamp | NOT NULL | Waktu aksi |
| `expired_at` | timestamp | | Waktu expired (untuk ban sementara) |

**Enum `moderation_action`:** `ban`, `unban`, `suspend`, `warn`

---

### 4. ticket_categories
Master data kategori tiket.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `name` | varchar | UNIQUE, NOT NULL | Nama kategori |

**Contoh data:** `Jaringan`, `Hardware`, `Software`, `Akun & Password`, `Lainnya`

---

### 5. tickets ⭐ (Core Entity)
Tabel utama untuk menyimpan data tiket.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `ticket_number` | varchar | UNIQUE, NOT NULL | Nomor tiket (TIK-YYYYMM-XXX) |
| `subject` | varchar | NOT NULL | Judul tiket |
| `description` | text | NOT NULL | Deskripsi masalah |
| `status` | enum_ticket_status | NOT NULL | Status tiket |
| `priority` | enum_ticket_priority | NOT NULL | Prioritas tiket |
| `created_at` | timestamp | NOT NULL | Waktu dibuat |
| `resolved_at` | timestamp | | Waktu resolved |
| `duration_minutes` | integer | | Durasi penyelesaian (menit) |
| `category_id` | uuid | FK → ticket_categories.id | Kategori tiket |
| `creator_profile_id` | uuid | FK → user_profiles.id | User yang membuat |
| `assignee_profile_id` | uuid | FK → user_profiles.id | Agent yang handle |
| `updated_at` | timestamp | | Waktu update terakhir |

**Enum `ticket_status`:** `OPEN`, `IN_PROGRESS`, `RESOLVED`, `CLOSED`, `CANCELLED`

**Enum `ticket_priority`:** `LOW`, `MEDIUM`, `HIGH`, `URGENT`

**Relasi:**
- Many-to-One dengan `ticket_categories`
- Many-to-One dengan `user_profiles` (creator)
- Many-to-One dengan `user_profiles` (assignee)
- One-to-Many dengan `comments`
- One-to-Many dengan `ticket_attachments`
- One-to-Many dengan `ticket_history`

---

### 6. ticket_attachments
Tabel untuk menyimpan file lampiran tiket.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `ticket_id` | uuid | FK → tickets.id | Relasi ke tiket |
| `uploader_profile_id` | uuid | FK → user_profiles.id | User yang upload |
| `file_name` | varchar | NOT NULL | Nama file asli |
| `file_url` | varchar | NOT NULL | URL file di storage |
| `file_type` | varchar | NOT NULL | MIME type (image/png, etc) |
| `file_size_kb` | integer | NOT NULL | Ukuran file dalam KB |
| `created_at` | timestamp | NOT NULL | Waktu upload |

---

### 7. comments
Tabel untuk menyimpan chat/komentar di dalam tiket.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `ticket_id` | uuid | FK → tickets.id | Relasi ke tiket |
| `user_profile_id` | uuid | FK → user_profiles.id | User yang komentar |
| `content` | text | NOT NULL | Isi komentar |
| `is_internal` | boolean | DEFAULT false | Internal note (hanya agent) |
| `created_at` | timestamp | NOT NULL | Waktu dibuat |

**Note:** `is_internal = true` untuk catatan internal antar agent, tidak terlihat oleh customer.

---

### 8. ticket_history
Tabel audit log untuk perubahan status/data tiket.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `id` | uuid | PK | Primary key |
| `ticket_id` | uuid | FK → tickets.id | Relasi ke tiket |
| `actor_profile_id` | uuid | FK → user_profiles.id | User yang melakukan aksi |
| `action` | enum_history_action | NOT NULL | Jenis aksi |
| `old_value` | text | | Nilai sebelum |
| `new_value` | text | | Nilai sesudah |
| `created_at` | timestamp | NOT NULL | Waktu aksi |

**Enum `history_action`:** `CREATED`, `STATUS_CHANGED`, `PRIORITY_CHANGED`, `ASSIGNED`, `REASSIGNED`, `COMMENTED`, `ATTACHMENT_ADDED`

---

### 9. sla_rules
Tabel konfigurasi SLA berdasarkan prioritas.

| Column | Type | Constraint | Description |
|--------|------|------------|-------------|
| `priority` | enum_ticket_priority | PK | Prioritas (sebagai key) |
| `response_time_limit_minutes` | integer | NOT NULL | Batas waktu response (menit) |
| `resolution_time_limit_minutes` | integer | NOT NULL | Batas waktu penyelesaian (menit) |

**Contoh data:**
| Priority | Response Time | Resolution Time |
|----------|---------------|-----------------|
| URGENT | 30 menit | 4 jam (240 menit) |
| HIGH | 1 jam | 8 jam (480 menit) |
| MEDIUM | 4 jam | 24 jam (1440 menit) |
| LOW | 8 jam | 72 jam (4320 menit) |

---

## Relasi Diagram (Simplified)

```
auth_accounts (1) ──────── (1) user_profiles
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
                    ▼               ▼               ▼
              tickets (creator) tickets (assignee) comments
                    │
        ┌───────────┼───────────┬───────────┐
        │           │           │           │
        ▼           ▼           ▼           ▼
  ticket_      ticket_      comments   ticket_
  categories   attachments             history
```

---

## Model Flutter (Preview)

Berdasarkan ERD di atas, berikut entity yang perlu dibuat di Flutter untuk **End-User Mobile App**:

### Models yang Dibutuhkan:

```dart
// Core Models
- User (dari user_profiles)
- Ticket
- TicketCategory
- Comment
- TicketAttachment

// Enum
- TicketStatus (OPEN, IN_PROGRESS, RESOLVED, CLOSED, CANCELLED)
- TicketPriority (LOW, MEDIUM, HIGH, URGENT)
- UserRole (customer, agent, admin, super_admin)
```

### Models yang TIDAK Dibutuhkan di Mobile End-User:
- auth_accounts (handled by backend)
- account_moderations (admin only)
- ticket_history (agent/admin only)
- sla_rules (system config)

---

## Catatan Penting

1. **UUID Format:** Semua ID menggunakan UUID v4, bukan auto-increment integer
2. **Soft Delete:** User menggunakan `deleted_at` untuk soft delete
3. **Timestamps:** Semua timestamp dalam format ISO 8601 (UTC)
4. **File Storage:** Attachment disimpan di cloud storage, database hanya menyimpan URL
5. **Internal Notes:** Field `is_internal` pada comments untuk membedakan chat publik vs catatan internal agent
