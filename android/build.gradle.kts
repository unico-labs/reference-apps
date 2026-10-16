// One module, rooted here, so the source folders match the layout shared by every app in this repo
// (settings/, flows/, journey/native-sdk/, result/, api/). app/ holds the activity and navigation glue.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "io.unico.reference"
    // The current androidx navigation and core releases require compile SDK 37.
    compileSdk = 37

    defaultConfig {
        // The native SDK only opens for the application ID that Unico linked to your SDK key:
        // https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup
        // Change it to yours before running.
        applicationId = "io.unico.reference"
        minSdk = 26
        // The SDK's activities opt out of a resizability rule that stops working at target 37 (see its manifest).
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            manifest.srcFile("app/AndroidManifest.xml")
            // AGP 9's built-in Kotlin compiles only kotlin.srcDirs; java.srcDirs alone leaves every .kt out of the APK.
            kotlin.srcDirs("app", "settings", "flows", "journey/native-sdk", "result", "api")
            assets.srcDirs("flows/assets")
        }
        getByName("test") {
            kotlin.srcDirs("test")
        }
    }
}

dependencies {
    // https://developer.unico.io/developers/sdks-and-tools/android/installation (step 3)
    implementation(libs.unico.capture)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.serialization.json)
    implementation(libs.coroutines.android)

    testImplementation(libs.junit)
}
