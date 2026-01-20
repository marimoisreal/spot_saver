// android/build.gradle.kts (root)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

extra["compileSdkVersion"] = 34
extra["compileSdk"] = 34
extra["targetSdkVersion"] = 34
extra["targetSdk"] = 34
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

// Настроить уже существующую задачу clean (не регистрировать заново)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}