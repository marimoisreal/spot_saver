// android/build.gradle.kts (root)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Actual versions as required(2026)
extra["compileSdkVersion"] = 35
extra["compileSdk"] = 35
extra["targetSdkVersion"] = 35
extra["targetSdk"] = 35
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
    
    // Force SDK 35
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(35)
        }
    }
    
    evaluationDependsOn(":app")
}

// Настроить уже существующую задачу clean (не регистрировать заново)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}