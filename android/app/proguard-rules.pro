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
# Preserve Firebase custom token / claims model fields
-keepclassmembers class * {
    @com.google.firebase.* <fields>;
}

# --------- Razorpay ---------
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keep class com.razorpay.PaymentDataProvider { *; }
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

# --------- Hive (NoSQL DB) — model classes are reflected at runtime ---------
-keep class **.hive.** { *; }
-keep class **_HiveAdapter { *; }
-keepclassmembers class * {
    @ HiveType <fields>;
}
-keep @org.hive2.TypeAdapters class *
-keep class org.hive2.** { *; }
-dontwarn org.hive2.**

# --------- Freezed / JsonSerializable / model annotations ---------
-keep class **_freezed.** { *; }
-keep class **.freezed.** { *; }
-keepclassmembers class * {
    @freezed.<fields>;
}
-keep class freezed.** { *; }
-dontwarn freezed.**

# --------- Model classes (in case any are written in Kotlin/Java) ---------
-keep class com.examvault.education.models.** { *; }
-keep class com.examvault.education.** { *; }
-keepclassmembers class com.examvault.education.** {
    public <methods>;
    public <fields>;
}

# --------- Riverpod (Dart-only, but keep classes referenced via reflection) ---------
# Riverpod runs entirely in Dart, no native ProGuard impact — kept for safety.
-keep class riverpod.** { *; }
-dontwarn riverpod.**

# --------- Annotation processors (JsonAnnotation, Freezed, etc.) ---------
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations,RuntimeVisibleTypeAnnotations
-keepattributes AnnotationDefault
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*

# --------- OkHttp / Retrofit / Dio (networking libs may transitively pull these) ---------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# --------- Kotlin coroutines (used by many Android libs) ---------
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# --------- WebView / ChromeClient (flutter_html, webview_flutter) ---------
-keep class android.webkit.** { *; }
-keep class com.tencent.smtt.** { *; }
-dontwarn android.webkit.**

# --------- Common: keep enum values (often used in models) ---------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --------- Strip logging for smaller release builds (optional, keep verbose) ---------
# -assumenosideeffects class android.util.Log {
#     public static *** v(...);
#     public static *** d(...);
#     public static *** i(...);
# }
