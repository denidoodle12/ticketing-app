# ms-knowledge API Documentation

## Overview

`ms-knowledge` adalah microservice khusus untuk manajemen artikel knowledge base yang **tenant-isolated**. Setiap tenant memiliki artikel dan kategori knowledge base sendiri yang sepenuhnya terisolasi dari tenant lain.

Admin masing-masing tenant dapat membuat kategori custom sesuai kebutuhan, lalu membuat artikel yang dikategorikan ke dalam kategori tersebut. Artikel bisa dilihat oleh semua user yang terautentikasi sesuai level akses masing-masing.

Service ini juga dilengkapi **AI Assistant** berbasis Gemini/OpenRouter yang menjawab pertanyaan user berdasarkan artikel yang sudah ada, dengan filter visibility sesuai role masing-masing dan isolasi penuh per tenant. AI menggunakan **pgvector semantic search** (cosine similarity) untuk menemukan artikel yang paling relevan dengan pertanyaan user.

**Service Port:** `8087`  
**Database:** Shared PostgreSQL (tabel `knowledge_categories` + `knowledge_articles`)  
**Dependensi Tambahan:** pgvector extension untuk PostgreSQL

---

## Base URL

Semua endpoint diakses melalui ms-gateway:

```
http://localhost:8000
```

---

## Authentication

Semua endpoint memerlukan JWT token.

```
Authorization: Bearer <jwt_token>
```

`tenant_id` **selalu diambil otomatis dari JWT** — tidak bisa dimanipulasi dari request body.

---

## Tenant Isolation

| Aturan | Detail |
|--------|--------|
| Data tenant A tidak pernah bisa diakses tenant B | `WHERE tenant_id = ?` di setiap query |
| `tenant_id` diinjeksi dari JWT, bukan request body | Tidak bisa di-spoof dari client |
| Super Admin diblok dari operasi CUD | Knowledge & Category adalah aset per-tenant |
| Delete & Update selalu validasi `tenant_id` match | Tidak bisa hapus data tenant lain |
| Category divalidasi milik tenant saat create/update artikel | Tidak bisa pakai category tenant lain |

---

## Role & Access Control

### Kategori

| Role | Level | GET List | POST | PUT | DELETE |
|------|-------|----------|------|-----|--------|
| Customer | 1 | ✅ (active only) | ❌ | ❌ | ❌ |
| Agent | 2 | ✅ (active only) | ❌ | ❌ | ❌ |
| Admin | 5 | ✅ (semua, aktif + nonaktif) | ✅ | ✅ | ✅ (jika tidak dipakai) |
| Super Admin | 10 | ❌ (tenant-scoped) | ❌ | ❌ | ❌ |

### Artikel

| Role | Level | GET List | GET Detail | POST | PUT | DELETE | AI Ask |
|------|-------|----------|------------|------|-----|--------|--------|
| Customer | 1 | ✅ (published + visibility=all) | ✅ | ❌ | ❌ | ❌ | ✅ (hanya artikel `all`) |
| Agent | 2 | ✅ (published + visibility ≠ admin_only) | ✅ | ❌ | ❌ | ❌ | ✅ (`all` + `agent_only`) |
| Admin | 5 | ✅ (semua status & visibility) | ✅ | ✅ | ✅ | ✅ | ✅ (semua visibility) |
| Super Admin | 10 | ❌ (tenant-scoped) | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## Data Models

### KnowledgeCategory

```json
{
  "id": 1,
  "tenant_id": 3,
  "name": "FAQ",
  "is_active": true,
  "created_at": "2026-04-15T10:00:00Z",
  "updated_at": "2026-04-15T10:00:00Z"
}
```

### KnowledgeArticle

```json
{
  "id": 1,
  "tenant_id": 3,
  "category_id": 1,
  "category": {
    "id": 1,
    "tenant_id": 3,
    "name": "FAQ",
    "is_active": true,
    "created_at": "2026-04-15T10:00:00Z",
    "updated_at": "2026-04-15T10:00:00Z"
  },
  "title": "Cara Reset Password Aplikasi",
  "content": "## Langkah Reset Password\n\n1. Buka halaman login\n2. Klik 'Lupa Password'...",
  "tags": ["password", "login", "akun"],
  "visibility": "all",
  "status": "published",
  "created_by": 12,
  "created_at": "2026-04-15T10:00:00Z",
  "updated_at": "2026-04-15T10:00:00Z"
}
```

### Article Field Reference

| Field | Type | Keterangan |
|-------|------|-----------|
| `id` | int | Auto-increment primary key |
| `tenant_id` | int | Injected dari JWT |
| `category_id` | int | FK ke `knowledge_categories.id` milik tenant yang sama |
| `category` | object | Data kategori (preloaded, hanya di GET response) |
| `title` | string | Judul artikel (3–200 karakter, unik per tenant) |
| `content` | string | Isi lengkap artikel, mendukung Markdown (min 10 karakter) |
| `tags` | []string | Array tag untuk pencarian |
| `visibility` | string | `all`, `agent_only`, `admin_only` |
| `status` | string | `draft`, `published` |
| `created_by` | int | `user_id` admin yang membuat, injected dari JWT |

### Valid Visibility

| Value | Bisa dilihat oleh |
|-------|------------------|
| `all` | Semua user (Customer, Agent, Admin) |
| `agent_only` | Agent dan Admin saja |
| `admin_only` | Admin saja |

---

## Endpoints — Kategori

---

### 1. List Kategori

**`GET /knowledge-categories`**

**Access:** Semua authenticated user
- Admin (L5+): semua kategori (aktif + nonaktif)
- Non-admin: hanya kategori `is_active = true`

**Response (200 OK):**
```json
{
  "message": "knowledge categories retrieved successfully",
  "data": [
    {
      "id": 1,
      "tenant_id": 3,
      "name": "FAQ",
      "is_active": true,
      "created_at": "2026-04-15T10:00:00Z",
      "updated_at": "2026-04-15T10:00:00Z"
    },
    {
      "id": 2,
      "tenant_id": 3,
      "name": "SOP Internal",
      "is_active": false,
      "created_at": "2026-04-15T10:00:00Z",
      "updated_at": "2026-04-15T10:30:00Z"
    }
  ]
}
```

**Contoh Request:**
```bash
curl -X GET "http://localhost:8000/knowledge-categories" \
  -H "Authorization: Bearer <jwt_token>"
```

---

### 2. Create Kategori

**`POST /knowledge-categories`**

**Access:** Admin (level 5+) — Super Admin diblok

**Request Body:**

| Field | Type | Wajib | Validasi |
|-------|------|-------|---------|
| `name` | string | **Ya** | min=2, max=100 karakter, unik per tenant |
| `is_active` | bool | Tidak | Default: `true` |

**Contoh Request Body:**
```json
{
  "name": "Troubleshooting Jaringan",
  "is_active": true
}
```

**Response (201 Created):**
```json
{
  "message": "knowledge category created successfully",
  "data": {
    "id": 3,
    "tenant_id": 3,
    "name": "Troubleshooting Jaringan",
    "is_active": true,
    "created_at": "2026-04-15T11:00:00Z",
    "updated_at": "2026-04-15T11:00:00Z"
  }
}
```

**Error Responses:**

**409 Conflict — Nama sudah ada:**
```json
{
  "error": "conflict",
  "message": "category name already exists"
}
```

**403 Forbidden — Super Admin:**
```json
{
  "error": "forbidden",
  "message": "super admin cannot create knowledge categories (tenant-scoped operation)"
}
```

**Contoh Request:**
```bash
curl -X POST "http://localhost:8000/knowledge-categories" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"name": "Troubleshooting Jaringan", "is_active": true}'
```

---

### 3. Update Kategori

**`PUT /knowledge-categories/:id`**

**Access:** Admin (level 5+) — Super Admin diblok

**Path Parameters:**

| Parameter | Type | Keterangan |
|-----------|------|-----------|
| `id` | int | ID kategori |

**Request Body (semua opsional):**
```json
{
  "name": "Troubleshooting & Jaringan",
  "is_active": false
}
```

> **Catatan:** Set `is_active: false` untuk menonaktifkan kategori. Kategori nonaktif tidak muncul di list artikel untuk non-admin, tetapi artikel yang sudah menggunakan kategori ini TIDAK terpengaruh.

**Response (200 OK):**
```json
{
  "message": "knowledge category updated successfully",
  "data": {
    "id": 3,
    "tenant_id": 3,
    "name": "Troubleshooting & Jaringan",
    "is_active": false,
    "created_at": "2026-04-15T11:00:00Z",
    "updated_at": "2026-04-15T12:00:00Z"
  }
}
```

**Contoh Request:**
```bash
curl -X PUT "http://localhost:8000/knowledge-categories/3" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"is_active": false}'
```

---

### 4. Delete Kategori

**`DELETE /knowledge-categories/:id`**

**Access:** Admin (level 5+) — Super Admin diblok

**Deskripsi:** Menghapus kategori. **Diblok** jika masih ada artikel yang menggunakan kategori ini.

**Response (200 OK):**
```json
{
  "message": "knowledge category deleted successfully"
}
```

**409 Conflict — Masih ada artikel yang pakai:**
```json
{
  "error": "conflict",
  "message": "cannot delete category: it is still used by one or more articles"
}
```

**404 Not Found:**
```json
{
  "error": "not_found",
  "message": "category not found"
}
```

**Contoh Request:**
```bash
curl -X DELETE "http://localhost:8000/knowledge-categories/3" \
  -H "Authorization: Bearer <admin_jwt>"
```

---

## Endpoints — Artikel

---

### 5. List Artikel

**`GET /knowledge`**

**Access:** Semua authenticated user  
Visibility dan status difilter otomatis berdasarkan role.

**Query Parameters:**

| Parameter | Type | Wajib | Keterangan |
|-----------|------|-------|-----------|
| `category_id` | int | Tidak | Filter by category ID |
| `visibility` | string | Tidak | `all`, `agent_only`, `admin_only` |
| `status` | string | Tidak | `draft`, `published` (non-admin selalu published) |
| `search` | string | Tidak | Full-text search pada `title` dan `content` (case-insensitive) |
| `tag` | string | Tidak | Filter exact by tag (case-insensitive). Artikel yang `tags` array-nya mengandung tag ini |
| `sort_by` | string | Tidak | `created_at`, `updated_at`, `title` |
| `order` | string | Tidak | `ASC` atau `DESC` (default: `DESC`) |
| `page` | int | Tidak | Nomor halaman (default: 1) |
| `limit` | int | Tidak | Jumlah per halaman (default: 10, max: 100) |

**Response (200 OK):**
```json
{
  "message": "knowledge articles retrieved successfully",
  "data": [
    {
      "id": 1,
      "tenant_id": 3,
      "category_id": 1,
      "category": {
        "id": 1,
        "tenant_id": 3,
        "name": "FAQ",
        "is_active": true,
        "created_at": "2026-04-15T10:00:00Z",
        "updated_at": "2026-04-15T10:00:00Z"
      },
      "title": "Cara Reset Password Aplikasi",
      "content": "## Langkah Reset Password...",
      "tags": ["password", "login"],
      "visibility": "all",
      "status": "published",
      "created_by": 12,
      "created_at": "2026-04-15T10:00:00Z",
      "updated_at": "2026-04-15T10:00:00Z"
    }
  ],
  "pagination": {
    "total": 25,
    "page": 1,
    "limit": 10
  }
}
```

**Contoh Request:**
```bash
# Filter by category_id
curl -X GET "http://localhost:8000/knowledge?category_id=1&page=1&limit=10" \
  -H "Authorization: Bearer <jwt_token>"

# Search artikel
curl -X GET "http://localhost:8000/knowledge?search=vpn&sort_by=created_at&order=DESC" \
  -H "Authorization: Bearer <jwt_token>"

# Filter by tag
curl -X GET "http://localhost:8000/knowledge?tag=password" \
  -H "Authorization: Bearer <jwt_token>"

# Kombinasi: tag + category + pagination
curl -X GET "http://localhost:8000/knowledge?tag=ticket&category_id=2&page=1&limit=5" \
  -H "Authorization: Bearer <jwt_token>"

# Admin: lihat semua draft
curl -X GET "http://localhost:8000/knowledge?status=draft" \
  -H "Authorization: Bearer <admin_jwt>"
```

---

### 6. Get Artikel by ID

**`GET /knowledge/:id`**

**Access:** Semua authenticated user

**Response (200 OK):**
```json
{
  "message": "knowledge article retrieved successfully",
  "data": {
    "id": 1,
    "tenant_id": 3,
    "category_id": 1,
    "category": {
      "id": 1,
      "tenant_id": 3,
      "name": "FAQ",
      "is_active": true,
      "created_at": "2026-04-15T10:00:00Z",
      "updated_at": "2026-04-15T10:00:00Z"
    },
    "title": "Cara Reset Password Aplikasi",
    "content": "## Langkah Reset Password\n\n1. Buka halaman login\n2. Klik 'Lupa Password'\n3. Masukkan email yang terdaftar\n4. Cek email untuk link reset",
    "tags": ["password", "login", "akun"],
    "visibility": "all",
    "status": "published",
    "created_by": 12,
    "created_at": "2026-04-15T10:00:00Z",
    "updated_at": "2026-04-15T10:00:00Z"
  }
}
```

**404 Not Found:**
```json
{
  "error": "not_found",
  "message": "article not found"
}
```

---

### 7. Create Artikel

**`POST /knowledge`**

**Access:** Admin (level 5+) — Super Admin diblok

**Request Body:**

| Field | Type | Wajib | Validasi |
|-------|------|-------|---------|
| `title` | string | **Ya** | min=3, max=200, unik per tenant |
| `content` | string | **Ya** | min=10 karakter, mendukung Markdown |
| `category_id` | int | **Ya** | Harus milik tenant yang sama (min=1) |
| `tags` | []string | Tidak | Array of string |
| `visibility` | string | Tidak | `all`, `agent_only`, `admin_only` (default: `all`) |
| `status` | string | Tidak | `draft`, `published` (default: `draft`) |

**Contoh Request Body:**
```json
{
  "title": "Cara Reset Password Aplikasi",
  "content": "## Langkah Reset Password\n\n1. Buka halaman login\n2. Klik 'Lupa Password'\n3. Masukkan email\n4. Cek email\n5. Set password baru",
  "category_id": 1,
  "tags": ["password", "login", "reset"],
  "visibility": "all",
  "status": "published"
}
```

**Response (201 Created):**
```json
{
  "message": "knowledge article created successfully",
  "data": {
    "id": 5,
    "tenant_id": 3,
    "category_id": 1,
    "category": null,
    "title": "Cara Reset Password Aplikasi",
    "content": "## Langkah Reset Password...",
    "tags": ["password", "login", "reset"],
    "visibility": "all",
    "status": "published",
    "created_by": 12,
    "created_at": "2026-04-15T10:00:00Z",
    "updated_at": "2026-04-15T10:00:00Z"
  }
}
```

> **Catatan:** Field `category` di response create adalah `null` — fetch ulang dengan GET untuk mendapat nested category object.

**Error Responses:**

**400 Bad Request — category_id invalid:**
```json
{
  "error": "validation_error",
  "message": "Key: 'CreateKnowledgeRequest.CategoryID' Error:Field validation for 'CategoryID' failed on the 'min' tag"
}
```

**404-style error — category tidak ditemukan di tenant:**
```json
{
  "error": "internal_error",
  "message": "category not found or does not belong to this tenant"
}
```

**409 Conflict — Title sudah ada:**
```json
{
  "error": "conflict",
  "message": "article with this title already exists"
}
```

**Contoh Request:**
```bash
curl -X POST "http://localhost:8000/knowledge" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Cara Reset Password",
    "content": "Langkah-langkah reset password...",
    "category_id": 1,
    "tags": ["password"],
    "visibility": "all",
    "status": "published"
  }'
```

---

### 8. Update Artikel

**`PUT /knowledge/:id`**

**Access:** Admin (level 5+) — Super Admin diblok

**Request Body (semua opsional):**
```json
{
  "title": "Cara Reset Password (Diperbarui)",
  "content": "## Versi baru...",
  "category_id": 2,
  "tags": ["password", "update"],
  "visibility": "all",
  "status": "published"
}
```

**Response (200 OK):**
```json
{
  "message": "knowledge article updated successfully",
  "data": { ... }
}
```

**Contoh — Publish draft:**
```bash
curl -X PUT "http://localhost:8000/knowledge/1" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"status": "published"}'
```

**Contoh — Pindah ke kategori lain:**
```bash
curl -X PUT "http://localhost:8000/knowledge/1" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"category_id": 2}'
```

---

### 9. Delete Artikel

**`DELETE /knowledge/:id`**

**Access:** Admin (level 5+) — Super Admin diblok

**Response (200 OK):**
```json
{
  "message": "knowledge article deleted successfully"
}
```

---

## Alur Penggunaan

```
1. Admin buat kategori dulu
   POST /knowledge-categories → { "name": "FAQ" }

2. Admin buat artikel dengan category_id dari langkah 1
   POST /knowledge → { "category_id": 1, "title": ..., "content": ... }

3. User/Agent list artikel
   GET /knowledge?category_id=1

4. Admin hapus artikel dulu sebelum hapus kategori
   DELETE /knowledge/1
   DELETE /knowledge-categories/1  ← baru bisa dihapus
```

---

## Use Case Scenarios

### Skenario 1: Setup awal tenant baru

```bash
# 1. Buat kategori-kategori
curl -X POST "http://localhost:8000/knowledge-categories" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"name": "FAQ"}'
# → id: 1

curl -X POST "http://localhost:8000/knowledge-categories" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"name": "SOP Internal", "is_active": true}'
# → id: 2

# 2. Buat artikel pertama
curl -X POST "http://localhost:8000/knowledge" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Cara Buat Tiket Support",
    "content": "## Panduan membuat tiket...",
    "category_id": 1,
    "visibility": "all",
    "status": "published"
  }'
```

### Skenario 2: Nonaktifkan kategori (tanpa hapus artikel)

```bash
curl -X PUT "http://localhost:8000/knowledge-categories/2" \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"is_active": false}'
# Kategori nonaktif → tidak muncul di list untuk non-admin
# Artikel yang sudah pakai kategori ini tetap ada
```

### Skenario 3: Agent cari artikel troubleshooting

```bash
curl -X GET "http://localhost:8000/knowledge?category_id=3&search=vpn" \
  -H "Authorization: Bearer <agent_jwt>"
# Hasilnya: published only, visibility IN (all, agent_only)
```

### Skenario 4: Tenant isolation test

```bash
# Admin Tenant A coba pakai category_id milik Tenant B saat buat artikel
curl -X POST "http://localhost:8000/knowledge" \
  -H "Authorization: Bearer <tenant_a_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"category_id": 99, ...}'
# → Error: "category not found or does not belong to this tenant"
```

---

## Database Schema

```sql
-- Dibuat SEBELUM knowledge_articles (FK dependency)
CREATE TABLE knowledge_categories (
    id         SERIAL PRIMARY KEY,
    tenant_id  INT NOT NULL,
    name       VARCHAR(100) NOT NULL,
    is_active  BOOL NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_knowledge_categories_tenant ON knowledge_categories(tenant_id);

CREATE TABLE knowledge_articles (
    id          SERIAL PRIMARY KEY,
    tenant_id   INT NOT NULL,
    category_id INT NOT NULL REFERENCES knowledge_categories(id),
    title       VARCHAR(200) NOT NULL,
    content     TEXT NOT NULL,
    tags        TEXT[] DEFAULT '{}',
    visibility  VARCHAR(20) NOT NULL DEFAULT 'all',
    status      VARCHAR(20) NOT NULL DEFAULT 'draft',
    created_by  INT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_knowledge_tenant_id ON knowledge_articles(tenant_id);
```

> **Catatan:** Kedua tabel dibuat otomatis saat `ms-knowledge` pertama kali dijalankan via `AutoMigrate`.

---

## Environment Variables

| Variable | Wajib | Default | Keterangan |
|----------|-------|---------|-----------|
| `APP_PORT` | Tidak | `8087` | Port service |
| `HOST` | Tidak | `0.0.0.0` | Bind address |
| `DATABASE_URL` | **Ya** | — | PostgreSQL connection string |
| `JWT_SECRET` | **Ya** | — | Harus sama persis dengan service lain |
| `GEMINI_API_KEY` | **Ya** (AI) | — | API key dari Google AI Studio — jika kosong, endpoint `/knowledge/ask` return 503 |
| `GEMINI_MODEL` | Tidak | `gemini-2.0-flash` | Model Gemini yang digunakan |

---

## Error Reference

| HTTP Code | Error Key | Penyebab |
|-----------|-----------|---------|
| `400` | `validation_error` | Field tidak valid |
| `400` | `invalid_content_type` | Header bukan `application/json` |
| `400` | `invalid_id` | `:id` bukan angka valid |
| `401` | `unauthorized` | JWT tidak ada atau tidak valid |
| `403` | `forbidden` | Role tidak cukup atau Super Admin coba CUD |
| `404` | `not_found` | Data tidak ditemukan (atau milik tenant lain) |
| `409` | `conflict` | Nama/title duplikat, atau hapus category yang masih dipakai |
| `500` | *(error message)* | Internal server error |
| `503` | `ai_error` | GEMINI_API_KEY tidak dikonfigurasi atau Gemini API tidak bisa dihubungi |

---

## Endpoints — AI Assistant

---

### `POST /knowledge/ask` — Tanya AI

**Access:** Semua authenticated user (Customer, Agent, Admin) — Super Admin diblok

AI menjawab pertanyaan berdasarkan artikel knowledge base tenant yang sedang login. Artikel yang dikirim ke Gemini disesuaikan dengan visibility yang boleh dilihat oleh role user:

| Role | Artikel yang dilihat AI |
|------|------------------------|
| Customer (L1) | `visibility=all` saja |
| Agent (L2-4) | `all` + `agent_only` |
| Admin (L5+) | `all` + `agent_only` + `admin_only` |

> **Multi-tenant isolation:** Gemini **hanya menerima** artikel milik tenant user yang login. Data tenant lain tidak pernah masuk ke prompt.

**Request Body:**

| Field | Type | Wajib | Validasi |
|-------|------|-------|---------|
| `question` | string | **Ya** | min 3, max 500 karakter |

```json
{
  "question": "Bagaimana cara membuat tiket baru?"
}
```

**Response (200 OK) — Ada artikel relevan:**
```json
{
  "message": "ok",
  "answer": "Untuk membuat tiket baru, kamu bisa mengakses menu Tickets lalu klik tombol 'New Ticket'...",
  "source_count": 2,
  "search_mode": "semantic",
  "sources": [
    { "id": 12, "title": "Cara Buat Tiket", "tags": ["tiket", "support"] },
    { "id": 7,  "title": "Panduan Helpdesk", "tags": ["helpdesk"] }
  ]
}
```

**Response (200 OK) — Tidak ada artikel relevan:**
```json
{
  "message": "ok",
  "answer": "Maaf, sepertinya informasi terkait pertanyaan Anda belum tersedia di knowledge base ini.",
  "source_count": 0,
  "search_mode": "fallback",
  "sources": []
}
```

> **Catatan:** Jawaban saat "tidak ditemukan" bersifat natural dari LLM — tidak hardcoded.

**Response (503) — AI tidak tersedia:**
```json
{
  "error": "ai_error",
  "message": "AI assistant is currently unavailable, please try again later"
}
```

**Response (400) — Validasi gagal:**
```json
{
  "error": "validation_error",
  "message": "Key: 'question' Error:Field validation for 'question' failed on the 'min' tag"
}
```

**Contoh Request:**
```bash
curl -X POST "http://localhost:8000/knowledge/ask" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"question": "Bagaimana cara reset password?"}'
```

**Catatan Teknis:**
- AI menggunakan **RAG + pgvector Semantic Search:**
  1. Pertanyaan user di-embed menjadi vector 3072 dimensi via **Gemini `gemini-embedding-001`**
  2. pgvector cosine similarity mencari **top 5 artikel paling relevan** dari knowledge base tenant
  3. Artikel tersebut dikirim ke LLM sebagai konteks untuk menghasilkan jawaban
  4. **Fallback:** Jika embedding belum tersedia (kolom `embedding` NULL), sistem otomatis ambil artikel terbaru
- `search_mode`: `"semantic"` = pgvector cosine search berhasil, `"fallback"` = embedding tidak tersedia
- `sources`: array artikel yang dijadikan konteks LLM — ID, title, dan tags (selalu array, tidak pernah `null`)
- `source_count` = jumlah artikel yang dikirim ke AI sebagai konteks (max 5 via semantic search)
- Konten artikel dipotong maksimum **800 karakter** per artikel
- AI Provider: dikonfigurasi via `AI_PROVIDER` env (`nim`, `gemini`, atau `openrouter`)
- Timeout request ke LLM: **115 detik**
- Timeout request ke Embedding API: **15 detik**
- Jika tidak ada AI key yang dikonfigurasi, endpoint ini selalu return `503`


---

### `POST /knowledge/reembed` — Generate/Refresh Semua Embedding *(Admin Only)*

**Access:** Admin (L5+) saja — Customer & Agent diblok

Men-generate atau memperbarui embedding pgvector untuk **seluruh artikel published** milik tenant yang sedang login. Harus dijalankan **satu kali setelah pertama kali deploy** atau setelah API key embedding diganti.

Setelah endpoint ini berhasil, artikel baru yang dibuat/diupdate akan otomatis di-embed di background (tidak perlu panggil endpoint ini lagi untuk artikel baru).

**Request Body:** *(kosong)*

**Response (200 OK):**
```json
{
  "message": "reembed completed",
  "processed": 15,
  "failed": 0,
  "total": 15
}
```

| Field | Keterangan |
|-------|------------|
| `processed` | Jumlah artikel yang berhasil di-embed |
| `failed` | Jumlah artikel yang gagal (API error, timeout, dsb) |
| `total` | Total artikel yang diproses |

**Response (503) — Embedding tidak dikonfigurasi:**
```json
{
  "error": "embedding_not_configured",
  "message": "EMBEDDING_API_KEY is not set"
}
```

**Contoh Request:**
```bash
curl -X POST "http://localhost:8000/knowledge/reembed" \
  -H "Authorization: Bearer <admin_jwt_token>"
```

> **Kapan perlu dijalankan:**
> - Setelah pertama kali deploy service
> - Setelah mengganti `EMBEDDING_API_KEY` (key lama limit/expired)
> - **Tidak perlu** dijalankan ulang untuk artikel baru — embedding dibuat otomatis

---

## Setup pgvector

pgvector adalah PostgreSQL extension untuk vector similarity search. Harus diinstall sebelum service dijalankan pertama kali.

### Langkah 1 — Install Extension

#### Ubuntu/Debian — PostgreSQL 14, 15, 16
```bash
# Install paket pgvector sesuai versi PostgreSQL
apt install postgresql-14-pgvector   # untuk PG 14
apt install postgresql-15-pgvector   # untuk PG 15
apt install postgresql-16-pgvector   # untuk PG 16
apt install postgresql-17-pgvector   # untuk PG 17 (jika tersedia di repo)
```

#### Ubuntu — PostgreSQL 17 (dari PGDG repo)
```bash
# Jika menggunakan PGDG apt repo
apt install postgresql-17-pgvector

# Atau build dari source jika paket belum tersedia
apt install postgresql-server-dev-17 build-essential git
cd /tmp && git clone https://github.com/pgvector/pgvector.git
cd pgvector && make && make install
```

#### Amazon Linux / RHEL / CentOS
```bash
yum install pgvector_15   # ganti 15 sesuai versi PostgreSQL
# atau
dnf install pgvector_16
```

#### macOS (Homebrew)
```bash
brew install pgvector
```

#### Docker
```bash
# Gunakan image pgvector yang sudah include extension
docker pull pgvector/pgvector:pg16
# atau
docker pull pgvector/pgvector:pg17
```

#### Cek Versi PostgreSQL
```bash
psql -U postgres -c "SELECT version();"
```

### Langkah 2 — Aktifkan Extension & Buat Kolom

```sql
-- Jalankan sebagai superuser di database yang digunakan
CREATE EXTENSION IF NOT EXISTS vector;

-- Tambah kolom embedding (3072 dims untuk gemini-embedding-001)
ALTER TABLE knowledge_articles
  ADD COLUMN IF NOT EXISTS embedding vector(3072);
```

> **Catatan Dimensi:**
> - `gemini-embedding-001` menghasilkan **3072 dimensi** (default)
> - pgvector membatasi indexing maksimum **2000 dimensi** untuk `ivfflat` dan `hnsw`
> - Untuk 3072 dims, **tidak perlu membuat index** — pgvector tetap bisa melakukan cosine search via sequential scan
> - Untuk knowledge base < 1000 artikel, sequential scan tidak terasa bedanya

### Langkah 3 — Konfigurasi `.env`

```env
# AI Provider
AI_PROVIDER=openrouter             # atau 'gemini'
GEMINI_API_KEY=AIza...             # Google AI Studio API key
GEMINI_MODEL=gemini-2.0-flash
OPENROUTER_API_KEY=sk-or-v1-...   # OpenRouter API key
OPENROUTER_MODEL=google/gemini-2.0-flash:free

# Embedding (pgvector semantic search)
# Kosongkan untuk reuse GEMINI_API_KEY secara otomatis
EMBEDDING_API_KEY=
```

### Langkah 4 — Jalankan Reembed (Sekali Saja)

Setelah service pertama kali berjalan dan artikel sudah ada di database:

```bash
curl -X POST "https://<your-domain>/knowledge/reembed" \
  -H "Authorization: Bearer <admin_jwt_token>"
```

Pastikan response `processed > 0`. Jika `processed = 0` dan `failed > 0`:  
→ Cek log server untuk error detail (kemungkinan API key limit atau salah konfigurasi).

### Troubleshooting pgvector

| Error | Penyebab | Solusi |
|-------|----------|--------|
| `extension "vector" does not exist` | pgvector belum diinstall | Install sesuai langkah di atas |
| `column cannot have more than 2000 dimensions for ivfflat index` | Mencoba membuat index untuk 3072 dims | Jangan buat index — sequential scan sudah cukup |
| `models/gemini-embedding-001 is not found` | URL API salah (`v1` vs `v1beta`) | Pastikan URL menggunakan `v1beta` |
| `processed=0, failed=N` saat reembed | API key embedding limit/invalid | Ganti key, restart, jalankan reembed ulang |

---

## Related Documentation

- [ms-gateway Routing](ms-gateway/cmd/server/main.go)
- [System Configs API](SYSTEM_CONFIGS_API_DOCUMENTATION.md)
- [Dashboard & Report API](DASHBOARD&REPORT_API_DOCUMENTATION.md)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
