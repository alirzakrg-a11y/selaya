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
        // google_mobile_ads 5.x en az API 23 ister; flutter varsayılanı daha
        // düşükse 23'e yükselt (Android 6.0 — kullanıcı kaybı ihmal edilebilir).
        minSdk = maxOf(23, flutter.minSdkVersion)
        // Google Play, 31 Ağu 2025'ten beri yeni uygulama/güncellemeler için
        // targetSdk >= 35 (Android 15) şart koşuyor; 36 (Android 16) ise
        // Flutter 3.44'ün önerdiği en son stabil ve compileSdk de zaten 36.
        // Geleceğe-dönük olması için 36'ya çekildi.
        // NOT (cihazda doğrula): Android 15/16 KENAR-A-KENAR (edge-to-edge)
        // çizimi zorunlu kılar → SafeArea/sistem çubukları altına taşma kontrol
        // edilmeli. Devam-eden (FGS) namaz bildirimi kaydırılıp kapatılabilir;
        // alarmlar USE_EXACT_ALARM ile çalışır. FGS türleri manifeste tanımlı
        // (specialUse / mediaPlayback). Alarm + ongoing + tam-ekran alarm test.
        targetSdk = 36
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
