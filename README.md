# ExamVault — Flutter + Firebase Android App

India's #1 MCQ Mock Test platform for Railway, SSC, UPSC, Banking, ADRE & State Exams.

> **Package:** `com.examvault.education`
> **Owner:** lkstudeoandcomputering@gmail.com
> **Firebase Project:** examvault-7fba8

---

## 📱 App Features

### User App
- **Authentication** — Mobile OTP, Email/Password, Google Sign-In
- **Home** — Categories, popular subjects, current affairs, premium banner
- **Test Series** — Mock tests, previous year papers, daily quizzes
- **Take Test** — Timer, question palette, negative marking
- **Results** — Detailed analysis, solutions, explanations
- **Leaderboard** — Weekly, Monthly, All-time rankings
- **Premium** — Razorpay payment (Monthly / Quarterly / Yearly)
- **Profile** — Stats, test history, bookmarks, settings
- **Current Affairs** — Daily updates with PDF
- **Notifications** — Push notifications for tests, results
- **Dark Mode** — Full dark theme support
- **AdMob Ads** — Banner, Interstitial, Rewarded, Native

### Admin Panel
- **Dashboard** — Statistics overview
- **Categories / Subjects / Tests / Questions** — CRUD operations
- **Users** — View, block / unblock
- **Payments** — View all transactions
- **Analytics** — Charts and graphs

---

## 🛠️ Tech Stack

| Area        | Choice                                       |
|-------------|----------------------------------------------|
| Framework   | Flutter 3.x (stable)                         |
| Language    | Dart 3.x                                     |
| Backend     | Firebase (Auth, Firestore, Storage, Messaging, Crashlytics) |
| Payments    | Razorpay (Live: `rzp_live_T2FtqmiTmWAWRW`)   |
| Ads         | Google AdMob                                 |
| State       | Provider                                     |
| Charts      | fl_chart                                     |
| Theme       | Material Design 3 — Blue + White, dark mode  |

---

## 🚀 Quick Start

> Prerequisites: Flutter 3.x, Dart 3.x, JDK 17, Android SDK 34.

```bash
git clone <your-repo-url> examvault-flutter
cd examvault-flutter
flutter pub get
```

### 1. Add `google-services.json`
- Go to <https://console.firebase.google.com> → project `examvault-7fba8`
- Project Settings → Your apps → Add Android app
- Package name: **`com.examvault.education`**
- Download `google-services.json` and place it at `android/app/google-services.json`
- Add your keystore SHA-1 to the Firebase Android app:
  ```bash
  keytool -list -v -keystore examvault-release.keystore -alias examvault -storepass ExamVault2026!
  ```

### 2. Add the keystore
Place `examvault-release.keystore` at `android/app/examvault-release.keystore`.
`android/key.properties` is already configured with the correct passwords.

### 3. Run
```bash
flutter run                   # debug
flutter build apk --release   # release APK
flutter build appbundle       # Play Store AAB
```

---

## 🔑 Configuration

All real values are in **`lib/config/app_config.dart`**:

| Key                       | Value (already set)                                              |
|---------------------------|------------------------------------------------------------------|
| `appName`                 | `ExamVault`                                                      |
| `packageName`             | `com.examvault.education`                                        |
| `firebaseProjectId`       | `examvault-7fba8`                                                |
| `firebaseApiKey`          | `AIzaSyDumulPADTU0YigQ_w96-shb5i2ch6w8FY`                        |
| `admobAppId`              | `ca-app-pub-1742730064755213~7890219994`                         |
| `bannerAdUnitId`          | `ca-app-pub-1742730064755213/4499859652`                         |
| `interstitialAdUnitId`    | `ca-app-pub-1742730064755213/5520307609`                         |
| `razorpayLiveKeyId`       | `rzp_live_T2FtqmiTmWAWRW`                                        |
| `razorpayTestMode`        | `false` (live)                                                   |
| `admobTestMode`           | `false` (real ads)                                               |

---

## 📦 Build & Sign

Local release APK build:
```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Or build a Play Store bundle:
```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

### CI / GitHub Actions
A workflow is provided at `.github/workflows/build.yml`. On every push to
`main`, it builds a signed APK + AAB and uploads them as artifacts.

**Required GitHub Secrets** (already configured by owner):
- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD` = `ExamVault2026!`
- `KEY_ALIAS` = `examvault`
- `KEY_PASSWORD` = `ExamVault2026!`
- `GOOGLE_SERVICES_JSON` = (full content of google-services.json)

---

## 🔑 Default Admin Credentials

- **Email:** `admin@examvault.com`
- **Password:** `Admin@123`
- ⚠️ Change these after first login!

---

## 📁 Project Structure

```
examvault-flutter/
├── android/                  Android configuration
│   ├── app/
│   │   ├── build.gradle      App-level Gradle config
│   │   ├── google-services.json.placeholder  (rename to google-services.json)
│   │   ├── key.properties    Keystore signing config (REAL)
│   │   ├── proguard-rules.pro
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/examvault/education/MainActivity.kt
│   │       └── res/          Android resources
│   └── build.gradle          Project-level Gradle config
├── lib/                      Flutter source code
│   ├── main.dart             Entry point
│   ├── config/app_config.dart  ← ALL API KEYS HERE (REAL)
│   ├── theme/app_theme.dart    Material Design 3 theme
│   ├── models/               Data models (12 files)
│   ├── services/             Firebase / Auth / AdMob / Razorpay / Notifications
│   ├── providers/            State management
│   ├── screens/              User-facing screens
│   ├── admin/                Admin Panel
│   ├── widgets/              Reusable widgets
│   └── utils/firestore_seed.dart  Initial data seed
├── assets/                   Images, icons, fonts
├── .github/workflows/build.yml  CI to build signed APK/AAB
├── firestore.rules           Firestore security rules
├── firestore.indexes.json    Composite indexes
├── docs/DEPLOYMENT_GUIDE.md  Complete deployment guide
├── pubspec.yaml              Dependencies
└── README.md                 This file
```

---

## 🆘 Support

- Email: **lkstudeoandcomputering@gmail.com**
- See `docs/DEPLOYMENT_GUIDE.md` for full step-by-step deployment & troubleshooting

---

## 📄 License

Proprietary — All rights reserved © ExamVault.
