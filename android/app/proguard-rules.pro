# Flutter and the Android Gradle plugin provide the core release rules.
# Keep annotations and generic signatures used by JSON/plugin reflection.
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,Signature

# Supabase realtime uses the Java-WebSocket implementation.
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
