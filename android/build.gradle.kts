// android/build.gradle.kts (root) — uses layout.buildDirectory (Gradle 7+/8+ safe)

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Set the root build output dir to ../build (one level above android/)
rootProject.layout.buildDirectory.set(file("../build"))

// Each subproject writes to ../build/<module-name>
subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
}

// Clean task
tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
