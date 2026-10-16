# The native SDK can't be obfuscated:
# https://developer.unico.io/developers/sdks-and-tools/flutter/installation/specific-setup
-keep class kotlin.coroutines.**
-keep class kotlinx.coroutines.**
-keep class com.acesso.acessobio_android.** { *; }
-keep class io.unico.** { *; }
-keep class br.com.makrosystems.haven.** { *; }
-keep class HavenSDK.** { *; }
-keep class HavenSDK** { *; }
