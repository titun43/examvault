# 🚀 ExamVault — Complete Deployment Guide

> All your real keys, IDs, and signing info are already saved in
> `lib/config/app_config.dart`, `android/key.properties`,
> `android/app/build.gradle`, and `android/app/src/main/AndroidManifest.xml`.
> This guide walks you through the **remaining** steps to ship the APK / AAB.

---

## ✅ What's Already Done For You

| Item                          | Status | Value                                                            |
|-------------------------------|--------|------------------------------------------------------------------|
| App name                      | ✅ Set | `ExamVault`                                                      |
| Package name                  | ✅ Set | `com.examvault.education`                                        |
| Firebase (Web config)         | ✅ Set | project `examvault-7fba8`, apiKey, senderId, appId, etc.         |
| AdMob App ID                  | ✅ Set | `ca-app-pub-1742730064755213~7890219994`                         |
| Banner Ad Unit ID             | ✅ Set | `ca-app-pub-1742730064755213/4499859652`                         |
| Interstitial Ad Unit ID       | ✅ Set | `ca-app-pub-1742730064755213/5520307609`                         |
| Razorpay Live Key ID          | ✅ Set | `rzp_live_T2FtqmiTmWAWRW`                                        |
| Razorpay Live Key Secret      | ✅ Set | `bm7ZbG2UEIRmQzoKcJXRWG2i`                                       |
| Razorpay mode                 | ✅ Live| `razorpayTestMode = false`                                       |
| AdMob mode                    | ✅ Live| `admobTestMode = false`                                          |
| Keystore password             | ✅ Set | `ExamVault2026!`                                                 |
| Key alias                     | ✅ Set | `examvault`                                                      |
| GitHub Actions workflow       | ✅ Set | `.github/workflows/build.yml`                                    |

---

## 📦 STEP 1: Local Machine Setup (one-time)

```bash
# 1) Install Flutter SDK (https://docs.flutter.dev/get-started/install)
flutter --version        # should be 3.x stable
flutter doctor           # make sure Android toolchain is green

# 2) Install JDK 17 (required for Android Gradle Plugin 8)
java -version            # should say 17.x
```

---

## 🔥 STEP 2: Finish Firebase Android App Registration

You've already provided the **Web** Firebase config, but for an Android app
you need the **Android** `google-services.json`.

1. Go to <https://console.firebase.google.com> → project **`examvault-7fba8`**.
2. **Project Settings → Your apps → Add app → Android**.
3. Android package name: **`com.examvault.education`** (must match exactly).
4. App nickname: `ExamVault`.
5. SHA-1 certificate fingerprint — get it from your keystore:
   ```bash
   keytool -list -v \
     -keystore examvault-release.keystore \
     -alias examvault \
     -storepass ExamVault2026!
   ```
   Copy the `SHA1:` line and paste it into Firebase.
6. **Download `google-services.json`** and place it at:
   ```
   examvault-flutter/android/app/google-services.json
   ```
   (a placeholder file already exists there — overwrite it).
7. In Firebase Console, enable these services:
   - **Authentication** → Sign-in methods → enable **Phone**, **Email/Password**, **Google**
   - **Firestore Database** → Create (production mode, `asia-south1` Mumbai)
   - **Storage** → Get started (`asia-south1`)
   - **Cloud Messaging** → enable
   - Paste the contents of `firestore.rules` into Firestore → Rules tab
   - Apply `firestore.indexes.json` (Firestore → Indexes → Composite → Import)

---

## 🔑 STEP 3: Place the Keystore

You already have `examvault-release.keystore`. Put it here:

```
examvault-flutter/android/app/examvault-release.keystore
```

`android/key.properties` is already configured with the right passwords — no
changes needed.

> ⚠️ The keystore file is git-ignored. **NEVER** commit it. If you lose it you
> cannot update the app on Play Store under the same package name.

---

## 💰 STEP 4: Razorpay (Already Live)

Your live key `rzp_live_T2FtqmiTmWAWRW` is wired up in
`lib/config/app_config.dart`. For **subscriptions**, create the 3 plans in
Razorpay Dashboard → Subscriptions → Plans and replace these in `app_config.dart`
if you want recurring auto-charge:

```dart
static const String monthlyPlanId   = 'plan_XXXXXXXX';  // ₹99
static const String quarterlyPlanId = 'plan_XXXXXXXX';  // ₹249
static const String yearlyPlanId    = 'plan_XXXXXXXX';  // ₹799
```

For one-time payments (default), no plan IDs are needed — Razorpay checkout
will just charge the user once.

> Security tip: for production-grade payment verification, host a tiny Cloud
> Function that verifies the signature using `razorpayLiveKeySecret`. The app
> currently does local verification only.

---

## 📱 STEP 5: Build the APK / AAB Locally

```bash
cd examvault-flutter
flutter pub get

# Debug build (for testing on your phone)
flutter run

# Release APK (for direct install / sharing)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Release AAB (for Play Store upload)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Install APK on a connected phone:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 🤖 STEP 6: Build via GitHub Actions (automatic)

A workflow is included at `.github/workflows/build.yml`. On every push to
`main`/`master`, it builds a signed APK + AAB.

Required GitHub Secrets (already configured by owner per your message):

| Secret                | Value                                                |
|-----------------------|------------------------------------------------------|
| `KEYSTORE_BASE64`     | base64-encoded `examvault-release.keystore`          |
| `KEYSTORE_PASSWORD`   | `ExamVault2026!`                                     |
| `KEY_ALIAS`           | `examvault`                                          |
| `KEY_PASSWORD`        | `ExamVault2026!`                                     |
| `GOOGLE_SERVICES_JSON`| full content of `google-services.json`               |

To get `KEYSTORE_BASE64`:
```bash
base64 -w 0 examvault-release.keystore   # Linux
# or
base64 -i examvault-release.keystore     # macOS
```

Artifacts are uploaded to the Actions run page and kept for 30 days.

---

## 🛒 STEP 7: Publish to Play Store (replacing existing app)

> ⚠️ Your existing Play Store app already uses package `com.examvault.education`.
> Replacing it with this Flutter build requires the **same signing key** that
> was used for the original app — which you've kept (`examvault-release.keystore`).

1. Go to <https://play.google.com/console> → your app.
2. **Release → Production → Create new release**.
3. Upload `app-release.aab` from `build/app/outputs/bundle/release/`.
4. Update store listing (screenshots, description, etc.) if needed.
5. If Play App Signing is on, you'll be asked to upload an upload key — use
   the same keystore. If the previous app was signed with the same key, the
   update will be accepted.
6. Submit for review.

---

## 🧪 STEP 8: Verify After Build

After installing the APK:

- ✅ Splash screen shows **ExamVault** logo
- ✅ Login screen — try Email/Password and Google
- ✅ Home loads categories from Firestore
- ✅ Open a test → answers get saved → result screen shows score
- ✅ Open Premium → Razorpay checkout opens (live mode — ₹99 will be charged)
- ✅ Banner ad shows at the bottom of Home
- ✅ Interstitial ad shows after submitting a test (non-premium users)
- ✅ Dark mode toggle in Profile → Settings works
- ✅ Notifications arrive (subscribe to topic `all_users` in FCM)
- ✅ Admin login: `admin@examvault.com` / `Admin@123`

---

## 🧯 Troubleshooting

### `google-services.json` not found
Make sure the file is at `android/app/google-services.json` (NOT in `android/`).
Run `flutter clean && flutter pub get` after placing it.

### Build fails with `MIN_SDK_VERSION`
Open `android/app/build.gradle` and ensure `minSdkVersion 21`.

### AdMob ads not showing
- Real ads take 1–2 days to start serving after a new app is created in AdMob.
- For development, flip `admobTestMode = true` in `app_config.dart` to use
  Google's test ad IDs.
- Make sure your AdMob account is fully approved (KYC + tax info).

### Razorpay: `invalid key`
- Check that `razorpayTestMode = false` in `app_config.dart`.
- Make sure you're using the **Live** key, not the Test key.
- Live keys activate only after KYC is complete in Razorpay dashboard.

### Play Store: `Your APK is signed with a different key`
This means the previous Play Store app was signed with a *different* keystore.
Solutions:
1. Use the **original** keystore (if you still have it).
2. If lost, contact Play Console support → request a keystore reset
   (one-time, requires identity verification).

### App crashes on launch
Check `flutter logs` for the crash trace. Most common cause: missing
`google-services.json` or SHA-1 not added to Firebase.

---

## 🆘 Support

- **Email:** lkstudeoandcomputering@gmail.com
- See `README.md` for project overview
- See `lib/config/app_config.dart` for all configuration values
