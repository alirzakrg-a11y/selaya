import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imza bilgileri android/key.properties'ten (git'e GİRMEZ).
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
        // Google Play yeni uygulama/güncelleme için targetSdk 34 (Android 14)
        // şart. NOT: Android 14'te devam-eden (FGS) namaz bildirimi artık
        // kaydırılıp kapatılabilir hale gelir; alarmlar USE_EXACT_ALARM ile
        // çalışmaya devam eder. FGS türleri manifeste tanımlı (special_use /
        // mediaPlayback). Cihazda alarm + ongoing davranışı doğrulanmalı.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // key.properties varsa release upload keystore'uyla imzala (Play),
            // yoksa debug'a düş (yerel `flutter run --release` için).
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
    // Camide otomatik sessize alma — geofence (GeofencingClient). geolocator bunu
    // içeride kullanıyor ama app modülüne açmıyor → açıkça ekliyoruz.
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
