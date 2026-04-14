plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.lorendb.tayra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.lorendb.tayra"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit GenAI (Gemini Nano) requires minSdk 26 (Android 8.0).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing configuration for release builds. This expects a key.properties
    // file at the project root with storeFile, storePassword, keyAlias, keyPassword.
    signingConfigs {
        // Use the existing debug signing config as-is for local debug builds.
        create("release") {
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                val keyProps = java.util.Properties()
                keyPropsFile.inputStream().use { keyProps.load(it) }
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config if provided; otherwise fall back to debug
            // to preserve the current developer workflow. Do NOT commit key.properties.
            signingConfig = try {
                signingConfigs.getByName("release")
            } catch (e: Exception) {
                signingConfigs.getByName("debug")
            }
            // Ensure release builds are not debuggable
            isDebuggable = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta2")
}
