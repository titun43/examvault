# =============================================================================
# ExamVault - ProGuard / R8 Rules
# =============================================================================
# Generated mapping.txt will be at:
#   build/app/outputs/mapping/release/mapping.txt
# Upload this to Play Console → App Bundle Explorer → Downloads → Deobfuscation
# =============================================================================

# --------- Flutter ---------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --------- Firebase ---------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.crashlytics.** { *; }

# --------- Razorpay ---------
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclassmembers class com.razorpay.** {
    public <methods>;
}

# --------- AdMob / Google Mobile Ads ---------
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep public class com.google.android.gms.common.internal.** { *; }

# --------- Google Sign-In ---------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }

# --------- smart_auth plugin references (resolved at runtime via play-services-auth) ---------
-dontwarn com.google.android.gms.auth.api.credentials.**
-keep class com.google.android.gms.auth.api.credentials.** { *; }

# --------- Play Core (SplitCompatApplication — referenced by Flutter) ---------
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# --------- App's own Java/Kotlin classes (if any) ---------
-keep class com.examvault.education.** { *; }
-keepclassmembers class com.examvault.education.** {
    public <methods>;
    public <fields>;
}

# --------- Kotlin coroutines ---------
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# --------- Common: keep enum values ---------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --------- Keep annotations & signatures ---------
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,RuntimeVisibleTypeAnnotations
-keepattributes AnnotationDefault
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*

# --------- Suppress warnings for transitively-referenced libs ---------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn android.webkit.**
