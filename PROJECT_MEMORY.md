# 🧠 ExamVault Project Memory — READ THIS FIRST

> **পরের session-এ আমি (AI) এই file-টা অবশ্যই প্রথমে পড়ব।**
> এখানে পুরো project-এর context, গুরুত্বপূর্ণ decision, সব সমস্যা ও সমাধান লেখা আছে।
> এটা পড়েই আমি বুঝব কী হয়েছে, কী করতে হবে, আর কোন ভুল আগে হয়েছে — সেগুলো যেন আর না করি।

---

## 📌 PROJECT OVERVIEW

- **Project Name**: ExamVault
- **Type**: Flutter app (Android only, no iOS setup)
- **Package name**: `com.examvault.education`
- **Current version**: `1.18.0+22` (in `pubspec.yaml`)
- **Location**: `/home/z/examvault-work/`
- **Purpose**: India's MCQ Mock Test platform (Railway, SSC, UPSC, Banking, ADRE & State Exams)
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging, Analytics, Crashlytics)
- **Payments**: Razorpay
- **Ads**: AdMob (App ID: `ca-app-pub-1742730064755213~7890219994`)
- **Build target**: Android (minSdk 21, targetSdk 35, compileSdk 35)

---

## 👤 USER CONTEXT (খুব গুরুত্বপূর্ণ)

- **ভাষা**: ইউজার বাংলায় কথা বলেন (Banglish / মিক্সড)। আমি reply-তে বাংলায় বলব, কোডে ইংরেজি।
- **প্রকৃতি**: ইউজার সরাসরি কথা বলেন, প্রশ্ন স্পষ্ট। আমি যত্নসহকারে শুনব, ভুল বুঝলে সরি বলে ঠিক করব।
- **যোগাযোগ**: ইউজার তার পরিবারের লোকজনকেও এই app ব্যবহার করান (চাচা, অন্যান্য)।

### ⚠️ আগে আমি যে ভুলগুলো করেছিলাম — এগুলো আর করব না:
1. **"chacha" ভুল বোঝা**: ইউজার বলেছিল "anar mobile" — আমি ভেবেছিলাম চাচার ফোন। কিন্তু ইউজার বোঝাচ্ছিলেন নিজের ফোনে conflict হচ্ছে। **শিক্ষা**: পরিষ্কার না বুঝলে একবার নিশ্চিত করে নেব, তারপর solution দেব।
2. **Random keystore bug**: আগের workflow-এ `KEYSTORE_BASE64` secret না থাকলে random keystore বানানোর fallback ছিল — যার ফলে প্রতি build আলাদা key দিয়ে sign হতো → মোবাইলে `package conflicts with an existing package` error। **এটা এখন fix করা হয়েছে** (নিচে দেখুন)।

---

## 🔑 SIGNING / KEYSTORE — LIFETIME CRITICAL

### Official Keystore Details
- **File**: `android/app/examvault-release.keystore`
- **Backup**: `examvault-release.keystore.BACKUP` (project root)
- **Base64 (for GitHub Secret)**: `KEYSTORE_BASE64.txt` (project root, `.gitignore`-এ রয়েছে)
- **key.properties**: `android/key.properties`
  - `storePassword=ExamVault2026!`
  - `keyPassword=ExamVault2026!`
  - `keyAlias=examvault`
  - `storeFile=examvault-release.keystore`
- **SHA1 fingerprint**: `BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E`
- **SHA256 fingerprint**: `59:4E:C2:7E:67:22:2B:D4:9D:1D:3F:46:EE:1B:4B:75:6F:64:9B:8D:14:5E:3D:1D:1F:3E:AA:5F:A1:88:9F:84`
- **Creation date**: Jul 1, 2026
- **Validity**: 10000 days (until Nov 16, 2053)

### 🚨 LIFETIME RULES (কখনো ভঙ্গ করব না):
1. **এই keystore কখনো delete করব না, regenerate করব না, replace করব না।**
2. একবার হারিয়ে গেলে আর recover করা যাবে না — সব existing user-কে uninstall করে নতুন install করতে হবে।
3. ভবিষ্যতে কোনো build এই একই keystore দিয়ে sign হবে — তাইই হবে "update" কাজ করার গ্যারান্টি।
4. যদি কখনো ইউজার keystore পাল্টাতে চান, আমি **সতর্ক করব** যে এতে সব existing install break হবে — যতক্ষণ না ইউজার জোর দিয়ে বলছেন ততক্ষণ করব না।

---

## 🔄 GITHUB ACTIONS WORKFLOW (`.github/workflows/build.yml`)

### Trigger
- `push` to `main` / `master`
- Manual `workflow_dispatch`

### Required GitHub Secrets (ইউজার একবার বসাবেন, lifetime):
| Secret Name | Value |
|-------------|-------|
| `KEYSTORE_BASE64` | `KEYSTORE_BASE64.txt` file-এর পুরো content |
| `KEYSTORE_PASSWORD` | `ExamVault2026!` |
| `KEY_PASSWORD` | `ExamVault2026!` |
| `KEY_ALIAS` | `examvault` |
| `EXPECTED_SHA1` | `BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E` |

### Optional Secret:
- `GOOGLE_SERVICES_JSON` (যদি repo-তে commit না করা থাকে; এখন repo-তে committed)

### ৫-স্তরের সুরক্ষা (workflow-এ):
1. **Mandatory keystore** — `KEYSTORE_BASE64` না থাকলে build fail (random fallback নেই)
2. **SHA1 fingerprint verify** — ভুল key বসলে fail
3. **Secret-based passwords** — hardcoded password নেই
4. **Built APK signature verify** — `apksigner verify` দিয়ে final check
5. **Build summary** — version + SHA1 + SHA256 লেখা

### Build Artifacts:
- `examvault-apk-{version}` — signed APK + checksum (৯০ দিন retain)
- `examvault-aab-{version}` — Play Store bundle (৯০ দিন retain)

---

## 📂 IMPORTANT FILE LOCATIONS

```
/home/z/examvault-work/
├── pubspec.yaml                                  # App version, dependencies
├── android/
│   ├── app/
│   │   ├── build.gradle                          # applicationId, signing config
│   │   ├── examvault-release.keystore            # 🔑 OFFICIAL KEYSTORE — never delete
│   │   ├── google-services.json                 # Firebase (committed in repo)
│   │   └── proguard-rules.pro
│   ├── key.properties                            # Keystore passwords (gitignored)
│   └── build.gradle
├── .github/
│   └── workflows/
│       └── build.yml                             # ✅ FIXED workflow (5-layer protection)
├── lib/                                          # Flutter Dart source
├── assets/                                       # App assets
├── examvault-release.keystore.BACKUP             # 💾 Keystore backup
├── KEYSTORE_BASE64.txt                           # Base64 for GitHub Secret (gitignored)
├── SETUP_SECRETS.md                              # 📖 Setup guide (বাংলায়)
├── BUILD_FIX_INSTRUCTIONS.md                     # Old build fix doc
├── README.md                                     # Project README
└── PROJECT_MEMORY.md                             # 👈 এই file টা
```

---

## 🗂️ PENDING TASKS — All Completed ✅ (Jul 1, 2026)

পূর্ববর্তী session-এ ইউজার এই ৩টা কাজ চেয়েছিলেন — **সব হয়ে গেছে**:

1. ✅ **Admin panel: input field editable না** — FIX: `tests.tsx` ও `previous-papers.tsx`-এ disabled fields-এ helper text + `disabled:opacity-60 disabled:cursor-not-allowed` যোগ। Audit-এ দেখা গেছে ৩টা disabled field-ই intentional UX (negative marks gating, Daily Quiz locked type) — break করিনি, শুধু clarify করেছি।
2. ✅ **Admin panel: Bulk uploader-এ CSV template download** — FIX: ৭টা bulk uploader-এ (announcements, categories, current-affairs, questions, subjects, tests, upcoming-exams) "Download CSV" button যোগ। `src/lib/download.ts`-এ `downloadCsv` ও `parseCsv` function যোগ। এখন JSON ও CSV দুটোই upload করা যায়।
3. ✅ **Flutter user app: Splash screen-এ loading spinner + book logo animation** — FIX: `lib/screens/splash_screen.dart`-এ book logo এর ZoomIn animation (1s) + নিচে white CircularProgressIndicator (1s delay এ fade in) যোগ। Total splash = 2s minimum।

> পরের session-এ এগুলো নিয়ে আর কাজ করতে হবে না। নতুন কাজ থাকলে শুধু বলবেন।

---

## ✅ WHAT WAS DONE IN LAST SESSION (Jul 1, 2026)

### Problem
ইউজার তার মোবাইলে নতুন APK install করতে গিয়ে `package conflicts with an existing package` error পাচ্ছিলেন।

### Root Cause
আগের `build.yml`-এ random keystore fallback ছিল — `KEYSTORE_BASE64` secret না থাকলে প্রতি build-এ নতুন random keystore বানাত। ফলে প্রতিটা build আলাদা signature দিয়ে হতো → Android update করতে দিত না।

### Solution (implemented)
1. **Rewrote `.github/workflows/build.yml`**:
   - Removed random keystore fallback
   - Added mandatory `KEYSTORE_BASE64` check
   - Added SHA1 fingerprint verification (safety net)
   - Added `apksigner verify` on built APK
   - Added version-aware artifact naming
   - Added build summary with SHA1/SHA256

2. **Created `KEYSTORE_BASE64.txt`**: base64-encoded keystore for GitHub Secret (gitignored)

3. **Created `SETUP_SECRETS.md`**: Complete setup guide in বাংলা

4. **Updated `.gitignore`**: Added `KEYSTORE_BASE64.txt`

5. **Created keystore backup**: `examvault-release.keystore.BACKUP`

### ইউজারকে বলা হয়েছে যে কাজ বাকি:
- GitHub repo-তে ৫টা secret বসাতে হবে (detail `SETUP_SECRETS.md`-এ)
- মোবাইলে পুরোনো ExamVault uninstall করে নতুন APK install করতে হবে (একবার)
- এরপর থেকে সব update smoothly হবে

---

## 🎯 HOW TO BEHAVE IN NEXT SESSION

### শুরুতে যা করব:
1. **এই file-টা (`PROJECT_MEMORY.md`) পড়ব প্রথমে** — পুরো context বোঝার জন্য
2. `pubspec.yaml` থেকে current version চেক করব
3. `android/app/build.gradle` থেকে applicationId চেক করব
4. যদি কোনো build কাজ থাকে, keystore intact আছে কিনা verify করব
5. ইউজারের pending tasks (উপরে) চেক করব

### কথা বলার নিয়ম:
- বাংলায় উত্তর দেব (কোডে ইংরেজি)
- সরি বলতে দ্বিধা করব না ভুল হলে
- পরিষ্কার না বুঝলে নিশ্চিত করে নেব
- গুরুত্বপূর্ণ decision-এ ইউজারকে জানাব

### কোড পরিবর্তনের নিয়ম:
- Keystore বা `key.properties` কখনো change করব না ইউজারের স্পষ্ট permission ছাড়া
- `applicationId` (`com.examvault.education`) কখনো change করব না
- `build.yml`-এ random fallback কখনো ফিরিয়ে আনব না
- কোনো secret/password hardcoded করব না

### Environment note:
- Flutter SDK এই sandbox environment-এ install নেই — তাই local এ APK build করতে পারি না
- ইউজারকে তার নিজের মেশিনে `flutter build apk --release` চালাতে বলতে হবে
- অথবা GitHub Actions workflow চালাতে হবে (recommended)

---

## 📞 QUICK REFERENCE

### Build APK locally (user's machine):
```bash
cd examvault-work
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Bump version:
- Edit `pubspec.yaml`: `version: 1.19.0+23` (versionName+versionCode)
- Commit & push → GitHub Actions auto-build করবে

### Verify keystore fingerprint:
```bash
keytool -list -v -keystore android/app/examvault-release.keystore -storepass 'ExamVault2026!'
# Should show: SHA1: BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E
```

---

## 📝 VERSION HISTORY / SESSION LOG

| Date | Session | What happened |
|------|---------|---------------|
| Jul 1, 2026 (earlier) | 1 | Project setup, keystore created, initial workflow |
| Jul 1, 2026 (this session) | 2 | Diagnosed package conflict, rewrote workflow, created setup guide, created this memory file |

---

**Last updated**: Jul 1, 2026
**Maintained by**: AI assistant (Z.ai Code)
**Purpose**: Persistent memory across sessions — যাতে আমি ভুল না করি, উল্টাপাল্টা না করি।
