plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Paste this entire block into your android/app/build.gradle.kts file

android {
    namespace = "com.example.token_manager"
    // It's best practice to use a recent compileSdk. 34 is current.
    compileSdk = 35

    // FIX #1: Set the specific NDK version required by Firebase.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Sticking to Java 1.8 is often safer for broader library compatibility.
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.token_manager"
        // FIX #2: Increase minSdk to 23 as required by firebase-auth.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
