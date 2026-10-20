# The SDK cannot be obfuscated. Rules copied from
# https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup
# Reference only: this app leaves minification off. Add these rules to your app if you turn it on.
-keep class kotlin.coroutines.**
-keep class kotlinx.coroutines.**
-keep class com.acesso.acessobio_android.** { *; }
-keep class io.unico.** { *; }
-keep class br.com.makrosystems.haven.** { *; }
-keep class HavenSDK.** { *; }
-keep class HavenSDK** { *; }
