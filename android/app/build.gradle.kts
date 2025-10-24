plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.jejak_cerita_rakyat"

    // Compile against Android 16 (API 36)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.jejak_cerita_rakyat"

        // Keep minSdk compatible with Flutter; ensure it's at least 21
        minSdk = maxOf(21, flutter.minSdkVersion)

        // Align target to API 36
        targetSdk = 36

        // Read from pubspec.yaml via Flutter plugin
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true

        ndk {
            // If you use TFLite delegates later, these ABIs are common
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
            // TEMP: use debug signing so `flutter run --release` works out of the box
            // Replace with your real release signing config when ready.
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    // Java/Kotlin toolchains
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    // Prefer toolchain declaration (AGP 8.x)
    kotlin { jvmToolchain(17) }

    // Packaging options
    packaging {
        resources {
            // Keep this conservative exclude; avoids license duplicate warnings
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Required so Flutter knows where the module root is
flutter {
    source = "../.."
}
