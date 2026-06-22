plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
