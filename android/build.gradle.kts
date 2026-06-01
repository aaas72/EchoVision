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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val injectNamespace = Action<AppliedPlugin> {
        if (project.name == "vosk_flutter_2") {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "org.vosk.vosk_flutter")
                    println("EchoVision Build: Dynamically injected matching namespace into ${project.name}")
                } catch (e: Exception) {
                    println("EchoVision Build Warning: Failed to set namespace: $e")
                }
            }
        }
    }
    project.pluginManager.withPlugin("com.android.library", injectNamespace)
    project.pluginManager.withPlugin("com.android.application", injectNamespace)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
