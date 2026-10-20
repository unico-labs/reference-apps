allprojects {
    repositories {
        google()
        mavenCentral()
        // Where io.unico:capture, the Android SDK behind unico_check, is published, plus one of its dependencies.
        // The plugin adds both too; they're declared here so the build doesn't depend on that.
        // Unico's repository answers a missing artifact with HTTP 200 and a JSON error instead of a 404, and Gradle
        // would cache that as Flutter's engine. So it never serves io.flutter, and Gradle goes on to Flutter's own.
        // Not yet in https://developer.unico.io/developers/sdks-and-tools/flutter/installation (tracked in ITD-2725)
        maven {
            url = uri("https://maven-sdk.unico.run/sdk-mobile")
            content { excludeGroup("io.flutter") }
        }
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
