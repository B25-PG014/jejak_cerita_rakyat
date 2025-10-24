// android/settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Locate your Flutter SDK to load Flutter's Gradle plugin
    val props = java.util.Properties()
    file("local.properties").inputStream().use { props.load(it) }
    val flutterSdk = props.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in local.properties")
    includeBuild("$flutterSdk/packages/flutter_tools/gradle")
}

// Loader in settings + toolchain versions available to modules
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"      // apply = true
    id("com.android.application") version "8.12.0" apply false   // AGP for API 36
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// (Optional, but good practice) centralize repos for all modules
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "jejak_cerita_rakyat"
include(":app")
