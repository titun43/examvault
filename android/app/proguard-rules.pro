# =============================================================================
# ExamVault - ProGuard Rules
# =============================================================================

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# AdMob
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Model classes
-keep class com.examvault.education.models.** { *; }
