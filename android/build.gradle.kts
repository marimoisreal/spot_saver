plugins {
    id("com.android.application")
    id("kotlin-android")
}


extra["compileSdkVersion"] = 35
extra["compileSdk"] = 35
extra["targetSdkVersion"] = 35
extra["targetSdk"] = 35
extra["minSdkVersion"] = 21
extra["minSdk"] = 21

allprojects {
    repositories {
        google()
        mavenCentral()
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
    evaluationDependsOn(":app")
}

if (tasks.findByName("clean") == null) {
    tasks.register<Delete>("clean") {
        delete(rootProject.layout.buildDirectory)
    }
} else {
    tasks.named("clean", Delete::class).configure {
        delete(rootProject.layout.buildDirectory)
    }
}
