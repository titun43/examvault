# ExamVault - BUILD FIX v3 (Read This First!)

## The Problem
Your `flutter build apk --release` failed with:
```
settings.gradle: 1: Unexpected input: '{' @ line 1, column 18.
   pluginManagement {
                    ^
```

## Root Cause
**Notepad added a BOM (Byte Order Mark)** — an invisible 3-byte character (`EF BB BF`) at the start of `settings.gradle` when you opened/saved it. Gradle's Groovy parser sees the BOM, can't recognize `pluginManagement` as a valid identifier, and throws "Unexpected input: '{'".

## The Fix — Use PowerShell Script (RECOMMENDED, 30 seconds)

### Step 1: Download the new ZIP
Download `examvault-flutter.zip` from the green banner.

### Step 2: Extract ONLY the `fix-android.ps1` file
From the ZIP, extract just `fix-android.ps1` to:
```
D:\ALL APS\examvault-flutter\examvault-flutter\fix-android.ps1
```

### Step 3: Run the fix script in PowerShell
1. Open **PowerShell** (NOT Git Bash, NOT cmd)
   - Press `Win + R`, type `powershell`, press Enter
2. Navigate to your project:
   ```powershell
   cd "D:\ALL APS\examvault-flutter\examvault-flutter"
   ```
3. Run the script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File fix-android.ps1
   ```

This writes all 4 Android config files with **UTF-8 No BOM** encoding — guaranteed correct, no Notepad corruption possible.

### Step 4: Build the APK
In Git Bash or PowerShell:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## Alternative Fix — Regenerate Android with Flutter (if script fails)

If the PowerShell script doesn't work, regenerate a clean Android folder:

### Step 1: Back up 3 files FIRST
Copy these somewhere safe:
- `android/key.properties`
- `android/app/examvault-release.keystore`
- `android/app/google-services.json`

### Step 2: Delete android folder & regenerate
In Git Bash:
```bash
cd "D:/ALL APS/examvault-flutter/examvault-flutter"
rm -rf android
flutter create . --platforms=android --project-name examvault
```

### Step 3: Restore the 3 backed-up files
- `key.properties` → `android/`
- `examvault-release.keystore` → `android/app/`
- `google-services.json` → `android/app/`

### Step 4: Run the fix script (to add AdMob/signing config)
```powershell
powershell -ExecutionPolicy Bypass -File fix-android.ps1
```

### Step 5: Build
```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## After Successful Build

Your APK will be at:
```
D:\ALL APS\examvault-flutter\examvault-flutter\build\app\outputs\flutter-apk\app-release.apk
```

## IMPORTANT — Never open these files in Notepad!
Notepad adds BOM characters that break Gradle. If you need to edit any `.gradle` file:
- Use **VS Code** (it preserves encoding)
- Or use **Notepad++** (set Encoding → UTF-8 without BOM)
- Or use the PowerShell script approach above
