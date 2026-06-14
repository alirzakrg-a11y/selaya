import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imza bilgileri: android/key.properties (GITIGNORE'lu — gizli, repoya
// GİRMEZ). Dosya yoksa (CI / başka geliştirici) release, debug imzaya düşer ki
// `flutter run --release` yine çalışsın. Play'e .aab İÇİN bu dosya gerekli.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.selaya.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.selaya.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Target Android 13 (33), not the toolchain's latest, on purpose: a
        // prayer-alarm app needs reliable background alarms + a persistent
        // notification. Targeting 34+ pulls in Android 14's dismissible-FGS
        // notifications and stricter foreground/background limits; 33 keeps the
        // ongoing notification non-dismissible and the alarms dependable, while
        // still requiring the runtime notification permission. (compileSdk stays
        // latest, so API 34+ symbols still build.)
        targetSdk = 33
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // İMZA: key.properties varsa release keystore (Play .aab için);
            // yoksa debug (lokal `flutter run --release` çalışsın).
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // Do NOT shrink resources: the adhan sounds in res/raw are referenced
            // only by name (RawResourceAndroidNotificationSound → getIdentifier),
            // so the resource shrinker can't see they're used and strips them —
            // which made every prayer notification fail with "invalid_sound" and
            // silently schedule nothing. Keep minify+shrink off so res/raw ships.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
