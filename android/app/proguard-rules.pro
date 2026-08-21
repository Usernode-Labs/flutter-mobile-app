# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Generate mapping.txt file for crash symbolication
-printmapping mapping.txt

# Keep attributes needed for crash symbolication
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Keep exception classes for better crash reports
-keep public class * extends java.lang.Exception

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# JNI uses conventional symbol lookup, so the declaring class and native
# method names must remain stable in minified builds.
-keepclasseswithmembernames class com.usernode_labs.usernode.session.SessionAuthorityNative {
    native <methods>;
}

# Ignore missing Play Core classes (not used in this app)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
