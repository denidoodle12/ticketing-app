# Credentials Handover Checklist

> **Audience:** the new developer receiving this project. This document lists **every secret / off-repo file** you must receive from the outgoing team, plus how to recover each one if it is lost.

> [!CAUTION]
> The files in this document **must NOT** live in Git, **and links pointing to them must NOT live in Git either**. They are all already excluded by [.gitignore](../.gitignore). When transferring them between developers, use the channels listed in [Distribution Channels](#distribution-channels) below.

---

## Table of Contents

1. [Quick Checklist](#quick-checklist)
2. [Distribution Channels](#distribution-channels)
3. [File-by-File Detail](#file-by-file-detail)
4. [Recovery — When Files Are Lost](#recovery--when-files-are-lost)
5. [After All Files Are Collected](#after-all-files-are-collected)

---

## Quick Checklist

Confirm the new developer has received:

### Signing & Release
- [ ] `android/key.properties` (~200 bytes, 4-5 lines)
- [ ] `android/app/Enigma.p12` (already in repo, **but confirm the password is still valid**)

### Firebase
- [ ] `android/app/google-services.json` (~700 bytes)
- [ ] `lib/firebase_options.dart` (~3-5 KB)

### Local Machine Config
- [ ] `android/local.properties` (per-machine template, must be created locally)

### Native Build
- [ ] Folder `android/app/src/main/jni/curl/` (prebuilt libcurl + OpenSSL static, ~hundreds of MB)
- [ ] Folder `android/app/src/main/jni/rapidjson/` (header-only)
- [ ] File `assets/certs/cacert.pem` (already in repo, but verify it is not corrupted)

### Accounts & Access
- [ ] Firebase Console access (project `ticketing-app-7affc`)
- [ ] GitLab `enigma` remote access
- [ ] Backend API docs access (Swagger / Postman)
- [ ] New developer email added to the `enigma-ticketing-app` tester group

---

## Distribution Channels

The credential files in this document must travel **out of band** — never through Git, never through links checked into Git, never through public chat. Pick **one** of the channels below, in order of preference.

### What NOT To Do

> [!CAUTION]
> All three of these are unsafe and must be avoided:
>
> - ❌ **Committing the files to Git** (even to a private company repo). Once they enter Git history, every present and future person with repo access — plus every clone, mirror, and CI log — gets a copy. Removing them later does not erase the history.
> - ❌ **Putting a Drive / Dropbox / shared link in this Markdown file or anywhere else in the repo.** The link itself is sensitive metadata; it is just as bad as the file content. A future contributor scrolling through docs should not be able to bootstrap themselves into production secrets.
> - ❌ **Sending passwords through Slack / Discord / WhatsApp group chats / regular email.** These channels persist in chat history, get backed up, and are accessible to admins.

### Preferred: Team Password Manager

If the company already uses one (1Password Business, Bitwarden Teams, Keeper, etc.):

1. Create a shared vault named `tixcora-mobile-credentials` (or similar).
2. Upload every file in the [Quick Checklist](#quick-checklist) as a vault attachment, or store passwords as items.
3. Grant the new developer access by **email** (not a public link).
4. The new developer copies each file out of the vault into the project's correct path.
5. Audit log shows who accessed what and when. Access can be revoked instantly.

**This is the right answer for a recurring handover scenario.** Ask IT if a vault is available before falling back to other options.

### Acceptable: Restricted Google Drive Folder (company workspace)

If no password manager is available:

1. Create a folder inside the **company Google Workspace** (not a personal Gmail).
2. Sharing setting: **"Restricted"** → add the new developer's company email explicitly. **DO NOT** use "Anyone with the link".
3. Upload all credential files into the folder.
4. Communicate the folder location during the handover meeting (verbal or via 1Password note) — **never** by pasting the link in this Markdown.
5. After the new developer downloads everything and confirms the project builds, **revoke the previous developer's access** to the folder.

> [!IMPORTANT]
> If you must record the folder location somewhere written, put it in the company password manager or a confidential ticketing-system entry — not in a Git-tracked file.

### Acceptable: Encrypted Archive + Out-of-Band Password

For one-time delivery:

```bash
# Create an AES-encrypted 7z archive
7z a -p"<strong-password>" -mhe=on tixcora-creds.7z key.properties google-services.json local.properties firebase_options.dart jni-prebuilts.zip
```

1. Send the `.7z` file via company email or Drive (the file alone is useless without the password).
2. Send the password through a **different** channel: in person, phone call, signed direct message, or password-manager note.
3. The new developer extracts and stores everything in their own vault.

### Last Resort: Physical USB

When company infrastructure is limited or paranoia is high:

1. Copy credentials to a fresh USB stick.
2. Hand-deliver to the new developer in person.
3. Once they confirm a successful release build, **format the USB** (full overwrite, not a quick format).

### Post-Handover Hygiene

Regardless of which channel was used:

- [ ] Outgoing developer's access to Firebase / Drive / GitLab is revoked or downgraded
- [ ] If the keystore password was shared verbally and the team has any concern about leakage, **rotate the keystore** before the next release (see [HANDOVER.md Section 7](../HANDOVER.md#7-signature-checker--maintenance-critical))
- [ ] Any chat messages used during emergency transfer are deleted from both sides
- [ ] The new developer changes their personal copy storage (e.g. Downloads folder) to a vault entry, then wipes the loose copies


---

## File-by-File Detail

### 1. `android/key.properties`

**Location:** `android/key.properties`

**Contents (template):**
```properties
storePassword=<KEYSTORE_PASSWORD>
keyPassword=<KEY_ALIAS_PASSWORD>
keyAlias=<ALIAS_NAME>
storeFile=Enigma.p12
storeType=pkcs12
```

**Where the values come from:**
- `storePassword` and `keyPassword` → the passwords used when the keystore was created. Get them from the outgoing developer.
- `keyAlias` → typically `enigma` or `key0`. Check with:
  ```bash
  keytool -list -v -keystore android/app/Enigma.p12 -storetype PKCS12
  # Look for the "Alias name:" line
  ```
- `storeFile=Enigma.p12` → relative path from `android/app/`.
- `storeType=pkcs12` → because the keystore is `.p12`.

**Verify the password works:**
```bash
keytool -list -v -keystore android/app/Enigma.p12 -storetype PKCS12 -storepass <PASSWORD>
# If it runs without an error → the password is valid
```

---

### 2. `android/app/Enigma.p12`

**Location:** `android/app/Enigma.p12`
**Status:** Already committed to Git (~2.5 KB).

**What to verify:**
- The password in `key.properties` still matches.
- The certificate's SHA-256 hash **must match** the one embedded in `libjavaloader.so` (signature checker). See [HANDOVER.md Section 7](../HANDOVER.md#7-signature-checker--maintenance-critical).

**Get the certificate SHA-256:**
```bash
keytool -list -v -keystore android/app/Enigma.p12 -storetype PKCS12 -alias <ALIAS>
# Look for "Certificate fingerprints" → "SHA256: XX:XX:..."
```

---

### 3. `android/app/google-services.json`

**Location:** `android/app/google-services.json`
**Size:** ~700 bytes

**Where it comes from:**
1. Open https://console.firebase.google.com
2. Project: `ticketing-app-7affc`
3. Project Settings → General → Your apps → Android app `com.enigma.ticketing_app`
4. Click "Download `google-services.json`"
5. Place it at `android/app/google-services.json`

**Verify:**
```json
{
  "project_info": {
    "project_id": "ticketing-app-7affc",
    ...
  },
  "client": [
    {
      "client_info": {
        "android_client_info": {
          "package_name": "com.enigma.ticketing_app"
        }
      },
      ...
    }
  ]
}
```

---

### 4. `lib/firebase_options.dart`

**Location:** `lib/firebase_options.dart`
**Size:** ~3-5 KB

**Where it comes from:** Auto-generated by `flutterfire configure`.

**How to regenerate:**
```bash
# Install the FlutterFire CLI once
dart pub global activate flutterfire_cli

# Login to Firebase (will open a browser)
firebase login

# Generate (run from the project root)
flutterfire configure
# Pick project: ticketing-app-7affc
# Pick platforms: android (minimum), ios (if needed)
```

The output is a generated `lib/firebase_options.dart`.

> [!NOTE]
> This file is **not strictly secret** — its contents (appId, projectId, etc.) are also in `google-services.json`. It is gitignored only because it is auto-generated and should always be regenerated fresh from the Firebase CLI.

---

### 5. `android/local.properties`

**Location:** `android/local.properties`
**Size:** ~5 lines

**Contents (Windows template):**
```properties
sdk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\flutter
ndk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk\\ndk\\27.0.12077973
flutter.buildMode=debug
flutter.versionName=0.16.0
```

**Format notes:**
- Windows uses **double backslashes** (`\\`).
- Linux/macOS uses forward slashes (`/`).
- Paths must be absolute.

**How to find each path:**
- `sdk.dir` → Android Studio → Settings → System Settings → Android SDK → Android SDK Location.
- `flutter.sdk` → `where flutter` (Windows) or `which flutter` (Linux/macOS).
- `ndk.dir` → Android Studio → SDK Manager → SDK Tools → NDK (Side by side). The path is `<sdk.dir>/ndk/<version>`.

> [!IMPORTANT]
> The NDK version **must** be `27.0.12077973` (matches `android/app/build.gradle.kts` `ndkVersion`). Install it via SDK Manager if it is missing.

---

### 6. Folder `android/app/src/main/jni/curl/`

**Location:** `android/app/src/main/jni/curl/`
**Size:** several hundred MB total

**Contents (per architecture):**
```
jni/curl/
├── curl-android-arm64-v8a/
│   ├── include/curl/...
│   └── lib/libcurl.a
├── curl-android-x86_64/
├── openssl-android-arm64-v8a/
│   ├── include/openssl/...
│   └── lib/
│       ├── libssl.a
│       └── libcrypto.a
└── openssl-android-x86_64/
```

**Where it comes from:** prebuilt static libraries — ideally request directly from the outgoing developer (ZIP / shared drive).

**If lost, rebuild:**
- libcurl official: https://curl.se/download.html — compile static for Android NDK.
- OpenSSL official: https://www.openssl.org/source/ — compile static for Android NDK.
- Or use prebuilts from https://github.com/leenjewel/openssl_for_ios_and_android.

> [!WARNING]
> The build must be **compatible with NDK 27** and **C++17**. Older prebuilts can produce `__sync_add_and_fetch_4` undefined errors. See [docs/NATIVE_SSE_SETUP.md](./NATIVE_SSE_SETUP.md) for details.

---

### 7. Folder `android/app/src/main/jni/rapidjson/`

**Location:** `android/app/src/main/jni/rapidjson/`
**Size:** ~5 MB (header-only)

**Where it comes from:** https://github.com/Tencent/rapidjson — clone the repo, copy `include/rapidjson/` into `jni/rapidjson/`.

```bash
git clone https://github.com/Tencent/rapidjson.git /tmp/rapidjson
cp -r /tmp/rapidjson/include/rapidjson android/app/src/main/jni/rapidjson
```

---

### 8. `assets/certs/cacert.pem`

**Location:** `assets/certs/cacert.pem`
**Status:** Already committed to Git.

**Verify it is not corrupted:**
```bash
openssl x509 -in assets/certs/cacert.pem -text -noout | head
# Should print a parsed valid certificate
```

**Update when needed:** download the latest version from https://curl.se/ca/cacert.pem (Mozilla CA bundle, refreshed monthly).

---

## Recovery — When Files Are Lost

### Scenario 1: `key.properties` Is Lost, Password Unknown
**Risk level:** 🔴 High.

**Consequence:** You cannot build a release APK signed with the original keystore → **the new APK cannot update an APK already installed on user devices** (Android refuses installs with mismatched signatures).

**Solution:**
- **Option A (recommended):** try every password the team might have used (check 1Password / team vault for the pattern).
- **Option B (last resort):** generate a new keystore → update the signature checker hash → users **must uninstall and reinstall** (no in-place update). This is disruptive for every tester / user.

### Scenario 2: `Enigma.p12` Is Lost
**Risk level:** 🔴 Very high.

**Consequence:** same as scenario 1.

**Solution:**
- Check every team backup (Google Drive, 1Password, USB drives).
- Check `git log android/app/Enigma.p12` — the file has been committed before, so `git checkout <hash> android/app/Enigma.p12` can recover it.
- Last resort: regenerate the keystore + update the signature hash + force a reinstall.

### Scenario 3: `google-services.json` Is Lost
**Risk level:** 🟢 Low.

**Solution:** re-download from Firebase Console (see file #3 above).

### Scenario 4: `firebase_options.dart` Is Lost
**Risk level:** 🟢 Low.

**Solution:** run `flutterfire configure` (see file #4 above).

### Scenario 5: `jni/curl/` Folder Is Lost
**Risk level:** 🟡 Moderate — recoverable but slow.

**Solution:**
- Check the outgoing developer's backup.
- Or rebuild libcurl + OpenSSL static (1-2 days of work).
- Or use prebuilts from a trusted source like `openssl_for_ios_and_android`.

---

## After All Files Are Collected

### Final Verification
```bash
# 1. Check key.properties is valid
keytool -list -v -keystore android/app/Enigma.p12 -storetype PKCS12 \
  -storepass $(grep storePassword android/key.properties | cut -d= -f2)

# 2. Check the native libs build
flutter clean
flutter pub get
cd android
.\gradlew :app:ndkBuildNative
cd ..
ls android/app/src/main/jniLibs/arm64-v8a/libjavaloader.so
# The file must exist and be > 1 MB

# 3. Build a release APK
flutter build apk --release

# 4. Verify the APK is signed with the correct keystore
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# The SHA-256 must match Enigma.p12

# 5. Install on a test device
adb install build/app/outputs/flutter-apk/app-release.apk

# 6. Open the app — it must NOT show SecurityErrorScreen
```

If every step above is green → **the credential handover is complete**.

---

## Security Notes

- **Do NOT** commit any of the files in this list to Git, **even to a private repo**. `.gitignore` is set up, but always double-check `git status` before a large commit.
- **Do NOT** put a Drive / Dropbox / file-sharing link to credentials inside this repo (Markdown, code comment, anywhere). The link is as sensitive as the file itself.
- **Do NOT** send passwords over Slack/Discord/regular email/group chat. Use a team password manager, an out-of-band password (separate channel from the file), or a physical USB stick.
- **Do NOT** put passwords or secret values in source code (`api_config.dart`, `app_constants.dart`, etc.).
- **DO** rotate any password you can after handover (Firebase Service Account credentials, the keystore password if the team is unsure who has seen it, etc.).
- **DO** revoke the outgoing developer's access to Firebase, GitLab, and the credentials Drive folder once the new developer confirms the project builds and deploys end-to-end.

---

**Update this document when:** new credentials are introduced, file paths change, or a better recovery procedure is found.
