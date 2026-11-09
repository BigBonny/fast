import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (FCM) — applied only once google-services.json is dropped into
// this folder, so builds stay green before the Firebase project exists.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.fast.resto.fast_resto_bigbonney"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (java.time usage)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fast.resto.fast_resto_bigbonney"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 26 is the floor imposed by sentry_flutter (Android 8.0, ~99% of devices).
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "FAST"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            manifestPlaceholders["appLabel"] = "FAST Dev"
        }
        release {
            // Signed with the release keystore when android/key.properties
            // is present (locally + Codemagic). Without it the build falls
            // back to debug keys, which only the guard below allows
            // (FAST_ALLOW_DEBUG_SIGNING=true) for quick local release runs.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")

            // Keep native shrinking off for APK releases; Flutter/Play Core optional
            // classes can otherwise fail R8 when deferred components are unused.
            // For Dart-level obfuscation, build with:
            //   flutter build apk --obfuscate --split-debug-info=debug-info/
            // This renames Dart symbols in the native binary (libapp.so)
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// A debug-signed "release" APK/AAB can't update installed builds, breaks
// Google Sign-In (SHA mismatch) and is rejected by Play. Fail packaging
// release artifacts without the release keystore, unless explicitly allowed.
val allowDebugSigning = System.getenv("FAST_ALLOW_DEBUG_SIGNING") == "true"
tasks.configureEach {
    if (!keystorePropertiesFile.exists() && !allowDebugSigning &&
        name.matches(Regex("(assemble|bundle|package)Release"))
    ) {
        doFirst {
            throw GradleException(
                "Release build without android/key.properties: it would be " +
                    "debug-signed. Add the release keystore, or set " +
                    "FAST_ALLOW_DEBUG_SIGNING=true for a local test build."
            )
        }
    }
}
