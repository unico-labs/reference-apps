allprojects {
    repositories {
        google()
        mavenCentral()
        // No Unico repository here: unico_check adds it. Declaring it here puts it ahead of Flutter's engine
        // repository, and Unico's answers HTTP 200 with a JSON error for an artifact it doesn't have (ITD-2725).
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
