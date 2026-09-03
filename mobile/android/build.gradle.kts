allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/bkey-inc/package-distribution")
            credentials {
                username = providers.gradleProperty("bkey.gpr.user").orNull
                    ?: System.getenv("USERNAME")
                    ?: System.getenv("GITHUB_ACTOR")
                password = providers.gradleProperty("bkey.gpr.key").orNull
                    ?: System.getenv("TOKEN")
                    ?: System.getenv("GITHUB_TOKEN")
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
