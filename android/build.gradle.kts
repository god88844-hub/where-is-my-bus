allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Gradle outputs out of OneDrive on Windows so generated files stay regular files.
val buildDirPath =
    System.getenv("LOCALAPPDATA")?.let { "$it\\vizag_bus_v2\\build" }
        ?: "../../build"

val newBuildDir: Directory =
    rootProject.layout.projectDirectory
        .dir(buildDirPath)
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
