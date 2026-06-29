# =============================================================================
# ExamVault - Android Build Fix Script (PowerShell)
# =============================================================================
# This script writes the 4 Android config files with CORRECT encoding
# (UTF-8 No BOM) to fix the "Unexpected input: '{'" Gradle parse error.
#
# USAGE:
#   1. Open PowerShell (NOT Git Bash, NOT cmd)
#   2. cd "D:\ALL APS\examvault-flutter\examvault-flutter"
#   3. Run: powershell -ExecutionPolicy Bypass -File fix-android.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$androidDir = Join-Path $PSScriptRoot "android"
$appDir = Join-Path $androidDir "app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ExamVault Android Build Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. settings.gradle ---
$settingsGradle = @'
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.2.2" apply false
    id "org.jetbrains.kotlin.android" version "1.9.22" apply false
    id "com.google.gms.google-services" version "4.4.0" apply false
    id "com.google.firebase.crashlytics" version "2.9.9" apply false
}

include ":app"
'@

# --- 2. build.gradle (project level) ---
$buildGradle = @'
// ExamVault - Android build.gradle (project level)
// All plugins are declared in settings.gradle (new Flutter style).

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
'@

# --- 3. app/build.gradle ---
$appBuildGradle = @'
// EXAMVAULT - Android build.gradle (app level)
// Package: com.examvault.education

plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.google.gms.google-services"
    id "com.google.firebase.crashlytics"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode') ?: '1'
def flutterVersionName = localProperties.getProperty('flutter.versionName') ?: '1.0.0'

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.examvault.education"
    compileSdk 35
    ndkVersion "25.1.8937393"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.examvault.education"
        minSdk 21
        targetSdk 35
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'

            manifestPlaceholders = [
                admobAppId: "ca-app-pub-1742730064755213~7890219994"
            ]
        }
        debug {
            manifestPlaceholders = [
                admobAppId: "ca-app-pub-3940256099942544~3347511713"
            ]
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'

    // Core library desugaring (required by flutter_local_notifications 17.x)
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'

    implementation platform('com.google.firebase:firebase-bom:32.7.1')
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.firebase:firebase-firestore'
    implementation 'com.google.firebase:firebase-storage'
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'com.google.firebase:firebase-crashlytics'

    implementation 'com.google.android.gms:play-services-auth:20.7.0'
    implementation 'com.razorpay:checkout:1.6.33'
    implementation 'com.google.android.gms:play-services-ads:23.0.0'
}
'@

# --- 4. gradle.properties ---
$gradleProperties = @'
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configureondemand=false
android.suppressUnsupportedCompileSdk=34
'@

# --- Write files with UTF-8 No BOM encoding ---
function Write-FileNoBom {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "  WROTE: $Path" -ForegroundColor Green
}

Write-Host "Writing Android config files (UTF-8 No BOM)..." -ForegroundColor Yellow
Write-FileNoBom -Path (Join-Path $androidDir "settings.gradle") -Content $settingsGradle
Write-FileNoBom -Path (Join-Path $androidDir "build.gradle") -Content $buildGradle
Write-FileNoBom -Path (Join-Path $appDir "build.gradle") -Content $appBuildGradle
Write-FileNoBom -Path (Join-Path $androidDir "gradle.properties") -Content $gradleProperties

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  All 4 files written successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. flutter clean"
Write-Host "  2. flutter pub get"
Write-Host "  3. flutter build apk --release"
Write-Host ""
Write-Host "If you still see errors, run:" -ForegroundColor Yellow
Write-Host '  flutter create . --platforms=android --project-name examvault'
Write-Host "  (then re-run this script)"
Write-Host ""
