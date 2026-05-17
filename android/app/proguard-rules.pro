# ─────────────────────────────────────────────────────────────
# ProGuard / R8 Rules for Ticketing App
# ─────────────────────────────────────────────────────────────

# Flutter defaults — keep Flutter engine and framework
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native SSE JNI bindings (libcurl-based native SSE)
-keep class com.enigma.ticketing_app.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Gson / JSON serialization (if used by plugins)
-keepattributes Signature
-keepattributes *Annotation*

# OkHttp / Retrofit (used by some Flutter plugins)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# flutter_background_service
-keep class id.flutter.flutter_background_service.** { *; }

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums (used in various places)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
