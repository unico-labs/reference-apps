pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        google()
        mavenCentral()
        // Unico's own Maven repository: https://developer.unico.io/developers/sdks-and-tools/android/installation
        maven("https://maven-sdk.unico.run/sdk-mobile")
    }
}

rootProject.name = "unico-reference-android"
