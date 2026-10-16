allprojects {
    repositories {
        google()
        mavenCentral()
        // Where io.unico:capture, the Android SDK behind unico_check, is published, plus one of its dependencies.
        // The plugin adds both too; they're declared here so the build doesn't depend on that.
        maven { url = uri("https://maven-sdk.unico.run/sdk-mobile") }
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
