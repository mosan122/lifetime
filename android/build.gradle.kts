allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force a consistent compileSdk across all Android subprojects/plugins.
// Some plugins (e.g. isar_flutter_libs) reference Android 12+ attributes like
// `android:attr/lStar`, which require compiling against a modern SDK.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                val compileSdkField = ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                compileSdkField.invoke(ext, 36)
            } catch (_: Throwable) {
                // Ignore: not an Android project or different DSL.
            }
        }
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
