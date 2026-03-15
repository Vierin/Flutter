plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Собственный debug-ключ для стабильного SHA-1 (Google OAuth).
    // Создать: см. GOOGLE_OAUTH_ANDROID.md или ключ henzo-debug.keystore в android/app/
    val henzoDebugKeystore = rootProject.file("app/henzo-debug.keystore")
    if (henzoDebugKeystore.exists()) {
        signingConfigs {
            create("henzoDebug") {
                storeFile = henzoDebugKeystore
                storePassword = "henzo-debug"
                keyAlias = "henzo-debug"
                keyPassword = "henzo-debug"
            }
            getByName("debug") {
                storeFile = henzoDebugKeystore
                storePassword = "henzo-debug"
                keyAlias = "henzo-debug"
                keyPassword = "henzo-debug"
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}
