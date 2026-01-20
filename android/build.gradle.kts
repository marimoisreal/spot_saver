// android/build.gradle.kts (root)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

extra["compileSdkVersion"] = 33
extra["compileSdk"] = 33
extra["targetSdkVersion"] = 33
extra["targetSdk"] = 33
extra["minSdkVersion"] = 21
extra["minSdk"] = 21

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    evaluationDependsOn(":app")
}

tasks.named("clean", Delete::class).configure {
    delete(rootProject.layout.buildDirectory)
}
