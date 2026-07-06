plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hlth.hlth_app"
    compileSdk = flutter.compileSdkVersion
    // permission_handler / sqflite / shared_preferences need 27.0.x
    ndkVersion = "27.0.12077973"

    compileOptions {
        // flutter_local_notifications uses java.time APIs and requires
        // core-library desugaring to run on minSdk 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hlth.hlth_app"
        // QRing SDK requires minSdk 26 (Android 8.0)
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(files("libs/qring_sdk_1.0.0.17.aar"))
    // Background-sync watchdog (SyncWatchdogWorker): revives the headless
    // sync engine after process kills; schedule survives reboots.
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}

flutter {
    source = "../.."
}
