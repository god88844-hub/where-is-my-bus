allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Gradle outputs stay out of OneDrive via a directory junction at the
// project root: <project>\build -> %LOCALAPPDATA%\vizag_bus_v2\build
// (created once with: cmd /c mklink /J build "%LOCALAPPDATA%\vizag_bus_v2\build").
// Pointing Gradle at ../build resolves THROUGH the junction — regular files
// on disk, no OneDrive sync — while the Flutter tool still finds APKs under
// <project>\build\app\outputs\flutter-apk (a Gradle-level env-var redirect
// breaks `flutter run`/`install` because the tool cannot see it).
val rootBuildDir: Directory =
    rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(rootBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = rootBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
