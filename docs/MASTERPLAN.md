# MASTER PLAN - ENTERPRISE TICKETING SYSTEM

## Informasi Project

| Item | Detail |
|------|--------|
| **Nama Project** | Enterprise Ticketing System |
| **Durasi** | 24 November 2024 - Mei 2025 (6 Bulan) |
| **Metodologi** | Agile Scrum |
| **Architecture** | Microservices (Polyrepo) |
| **Organisasi** | ENIGMACAMP x Kementerian Ketenagakerjaan RI |

---

## I. Tech Stack & Architecture

### Backend
- **Language:** Golang 1.22+
- **Framework:** Gin
- **Database:** PostgreSQL (Per-Service Schema)
- **Cache/Session:** Redis

### Frontend Web
- **Framework:** React.js (Vite)
- **Language:** TypeScript
- **Styling:** Tailwind CSS, Shadcn UI

### Mobile App
- **Framework:** Flutter
- **Target:** Android & iOS
- **Fokus:** Aplikasi End-User (Pelapor)

### Infrastructure
- **Gateway:** Nginx
- **Container:** Docker Compose
- **API Style:** RESTful API
- **Repository Strategy:** Polyrepo (1 Service = 1 Git Repository)

---

## II. Komposisi Tim (9 Orang)

### Backend Team (3 Orang) - "The Engine"
| Nama | Role | Fokus |
|------|------|-------|
| Damar | Infra & Core | Gateway, Docker Environment, Service Tiket Utama |
| Abiel | Auth & Security | Auth Service (Login/Register), Security Middleware |
| Arifin | User & Automation | User Service, Service Notifikasi/SLA |

### Web Team (3 Orang) - "The Dashboard"
| Nama | Role | Fokus |
|------|------|-------|
| Riski | Web Lead | Arsitektur Frontend, Axios Interceptor, Auth Context, Code Review |
| Fikri | Admin Module | Halaman Admin, Master Data, Reporting |
| Satrio | Agent Module | Interaksi Tiket (Chat, Detail), Workspace Agent |

### Mobile Team (1 Orang) - "The User Interface"
| Nama | Role | Fokus |
|------|------|-------|
| **Deny** | Mobile Developer | **Aplikasi Pelapor (End-User) Android/iOS** |

### Support Team (2 Orang)
| Nama | Role | Fokus |
|------|------|-------|
| Riana | Admin & Tech Writer | Scrum Master, Dokumentasi API Contract, Notulen |
| Bagas | SQA | API Automation Testing (Postman), Functional Testing |

---

## III. Requirement Fitur

### A. Modul User (Mobile & Web) ⭐ FOKUS UTAMA MOBILE

#### Authentication
- Login
- Register
- Lupa Password
- Edit Profil

#### Create Ticket
- Form input: Subject, Kategori, Deskripsi
- Upload Foto (dari Galeri/Kamera)

#### My Tickets
- List tiket yang pernah dibuat
- Status tiket (Open/In Progress/Resolved/Done)
- Filter & Search

#### Interaction
- Chat dengan Agent di dalam tiket
- Beri Rating setelah tiket closed

---

### B. Modul Agent (Web Only)
- Workspace: Inbox ticket (Queue), Filter, Search
- Ticket Action: Ambil Tiket, Lempar Tiket, Ubah Status, Ubah Prioritas
- Communication: Reply ke User, Internal Note

### C. Modul Admin/Manager (Web Only)
- Master Data: Manage Users, Categories, Departments, Priorities
- SLA Config: Setting jam kerja & target waktu penyelesaian
- Reporting: Dashboard Statistik, Export Excel

### D. System Logic (Backend)
- API Gateway: Routing & validasi token
- SLA Engine: Kalkulasi Due Date otomatis
- Auto-Rules: Auto-close tiket jika user tidak merespon > 3 hari
- Notifications: Email & Push Notification (Async)

---

## IV. Sprint Roadmap - MOBILE FLUTTER

### FASE 1: FONDASI & IDENTITAS (Bulan 1)

#### Sprint 1
- [x] Setup Project Flutter
- [x] Setup Network Layer (Dio)
- [ ] Login Screen
- [ ] Splash Screen

#### Sprint 2
- [ ] Integrasi API Login
- [ ] Simpan Token (Secure Storage)
- [ ] Halaman Profile

---

### FASE 2: ALUR UTAMA / MVP (Bulan 2)

#### Sprint 3
- [ ] Integrasi API Create Ticket
- [ ] List Tiket User (History)
- [ ] Form Create Ticket

#### Sprint 4
- [ ] Detail Tiket View
- [ ] Fitur Chat User
- [ ] Upload Foto dari Galeri/Kamera

---

### FASE 3: KECERDASAN SISTEM / SLA (Bulan 3)

#### Sprint 5
- [ ] Push Notification Integration (Firebase)

#### Sprint 6
- [ ] Handling Notifikasi masuk (Deep link)

---

### FASE 4: REPORTING & OPTIMASI (Bulan 4)

#### Sprint 7
- [ ] Filter Pencarian Lanjutan

#### Sprint 8
- [ ] Offline Mode support (Cache lokal)

---

### FASE 5: POLISHING & KEAMANAN (Bulan 5)

#### Sprint 9
- [ ] Fitur Beri Bintang (Rating)

#### Sprint 10
- [ ] Bug Fixing & UI Polish

---

### FASE 6: TESTING & LAUNCH (Bulan 6)

#### Sprint 11-12
- [ ] UAT (User Acceptance Test)
- [ ] Upload Play Store (jika perlu)

---

## V. Standar API Response

### Single Object Response
```json
{
  "success": true,
  "message": "Data retrieved successfully",
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "ticket_number": "TIK-202411-001",
    "subject": "Printer Lantai 2 Macet",
    "status": "OPEN",
    "priority": "HIGH",
    "created_at": "2024-11-25T14:30:00Z"
  }
}
```

### Pagination Response
```json
{
  "success": true,
  "message": "Ticket list retrieved successfully",
  "data": {
    "items": [...],
    "meta": {
      "current_page": 1,
      "total_pages": 5,
      "total_items": 45,
      "limit": 10,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

### Auth Response (Login)
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "dGhpcyBpcyBhIHJlZnJl...",
    "expires_in": 3600,
    "user": {
      "id": "u-123",
      "full_name": "Budi Santoso",
      "role": "USER",
      "avatar_url": "https://cdn.example.com/avatar.jpg"
    }
  }
}
```

### Auth Response (Register)
```json
{
  "success": true,
  "message": "Registration successful. Please login.",
  "data": {
    "user_id": "u-123",
    "email": "budi@example.com",
    "created_at": "2024-11-26T09:00:00Z"
  }
}
```

### Error Response
```json
{
  "success": false,
  "message": "Invalid email or password",
  "data": null
}
```

### Validation Error Response (422)
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
        "message": "Password must be at least 8 characters"
      }
    ]
  }
}
```

---

## VI. Catatan Penting

1. **API Contract First**: Backend menyediakan draft JSON Response sebelum coding, Frontend/Mobile bisa kerja paralel dengan Mock Data
2. **Polyrepo Discipline**: Tidak import code antar-repo, komunikasi via HTTP API
3. **Git Flow**:
   - `main`: Production-ready
   - `develop`: Integration branch
   - `feature/nama-fitur`: Branch kerja developer

---

*Dokumen ini dapat berubah sesuai kesepakatan bersama*
