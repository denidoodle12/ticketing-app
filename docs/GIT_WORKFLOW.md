# Git Workflow Guidelines

Dokumen ini berisi aturan dan best practices untuk commit, push, dan merge pada project ini.

---

## Branch Strategy

### Branch Utama
| Branch | Fungsi |
|--------|--------|
| `master` | Production-ready code |
| `dev` | Development/integration branch |

### Feature Branch
- **Format:** `feature/<nama-fitur>`
- **Contoh:** `feature/toast`, `feature/login-api-integration`, `feature/home`
- **Dibuat dari:** `dev`
- **Merge ke:** `dev`

### Bugfix Branch (jika diperlukan)
- **Format:** `bugfix/<nama-bug>`
- **Contoh:** `bugfix/login-validation`, `bugfix/token-refresh`

---

## Commit Message Convention

### Format
```
<type>: <subject>

<body (optional)>
```

### Types
| Type | Penggunaan |
|------|------------|
| `feat` | Fitur baru |
| `fix` | Bug fix |
| `refactor` | Refactoring code tanpa mengubah fungsionalitas |
| `style` | Formatting, styling (tidak mengubah logic) |
| `docs` | Dokumentasi |
| `chore` | Maintenance tasks (dependencies, config) |
| `test` | Menambah atau memperbaiki tests |

### Contoh Commit Message
```
feat: add toast notification and no internet dialog

- Replace snackbar with toastification minimal style
- Add no internet connection dialog with WiFi settings
- Add connectivity service for network monitoring
```

```
fix: resolve token refresh loop issue

- Add flag to prevent multiple refresh calls
- Clear token on 401 response
```

```
refactor: simplify auth provider logic
```

### Rules
- Subject menggunakan lowercase
- Tidak diakhiri titik
- Maksimal 50 karakter untuk subject
- Gunakan bahasa Inggris
- Body menjelaskan "what" dan "why", bukan "how"

---

## Workflow: Menyelesaikan Fitur

### Step-by-Step

```
1. DEVELOP
   └── Kerjakan fitur di feature branch

2. COMMIT
   └── git add -A
   └── git commit -m "feat: <deskripsi fitur>"

3. PUSH FEATURE BRANCH
   └── git push origin feature/<nama>
   └── git push enigma feature/<nama>

4. MERGE KE DEV
   └── git checkout dev
   └── git pull enigma dev (sync dulu)
   └── git merge feature/<nama>

5. PUSH DEV
   └── git push enigma dev

6. (OPTIONAL) CLEANUP
   └── git branch -d feature/<nama>  (delete local)
```

### Diagram
```
feature/toast ──commit──► push origin & enigma
                                │
                                ▼
                    dev ◄──merge──┘
                     │
                     ▼
              push enigma dev
```

---

## Remote Repositories

| Remote | URL | Fungsi |
|--------|-----|--------|
| `origin` | GitHub (personal) | Backup pribadi |
| `enigma` | GitLab Enigma | Repository tim/kantor |

### Push Priority
1. **Wajib:** `enigma` (repository utama tim)
2. **Optional:** `origin` (backup pribadi)

---

## Checklist Sebelum Merge

- [ ] Fitur sudah di-test dan berjalan dengan baik
- [ ] Tidak ada error/warning saat `flutter analyze`
- [ ] Commit message sudah sesuai convention
- [ ] Feature branch sudah di-push ke remote
- [ ] Dev branch sudah di-sync (pull) sebelum merge

---

## Quick Commands Reference

### Setelah Menyelesaikan Fitur
```bash
# 1. Stage dan commit
git add -A
git commit -m "feat: <deskripsi>"

# 2. Push feature branch ke kedua remote
git push origin feature/<nama>
git push enigma feature/<nama>

# 3. Merge ke dev
git checkout dev
git pull enigma dev
git merge feature/<nama>

# 4. Push dev
git push enigma dev

# 5. Kembali ke feature branch (jika lanjut develop)
git checkout feature/<nama>
```

### Membuat Feature Branch Baru
```bash
git checkout dev
git pull enigma dev
git checkout -b feature/<nama-fitur>
```

---

## Catatan Penting

1. **JANGAN** force push ke `dev` atau `master`
2. **JANGAN** commit langsung ke `dev` atau `master`
3. **SELALU** sync dev sebelum merge untuk menghindari conflict
4. **SELALU** test fitur sebelum commit
5. **JANGAN** include file `.env` atau credentials dalam commit

---

## Reminder untuk Claude

Ketika user menyelesaikan sebuah fitur, ingatkan untuk:
1. Commit dengan message yang sesuai convention
2. Push feature branch ke `origin` dan `enigma`
3. Merge ke `dev`
4. Push `dev` ke `enigma`
