import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Eigene Release-Signatur aus android/key.properties (steht in .gitignore).
// Ohne gleichbleibende Signatur lassen sich Updates nicht über die alte APK installieren.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    throw GradleException(
        "android/key.properties fehlt – Release-APK kann nicht signiert werden. Siehe README.",
    )
}

android {
    namespace = "at.todoliste.todo_liste"
    // flutter_local_notifications braucht mindestens SDK 37 zum Kompilieren.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Für geplante Erinnerungen (java.time auf älteren Android-Versionen)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Eindeutige App-ID – nach der ersten Installation nicht mehr ändern,
        // sonst gilt die App auf dem Handy als neue App.
        applicationId = "at.todoliste.todo_liste"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Versionsnummer und -name kommen aus pubspec.yaml (`version: 1.0.0+1`).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            // Eigene App-ID („Todo-Liste Test“): Die Debug-Version lässt sich neben der echten
            // App installieren und hat eigene Daten – zum gefahrlosen Ausprobieren.
            applicationIdSuffix = ".debug"
        }
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
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
