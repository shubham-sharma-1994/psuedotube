import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists().also { exists ->
    if (exists) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }
}

android {
    namespace = "com.anand.noize"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.anand.noize"
        multiDexEnabled = true
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Named "release" but also used for debug when key.properties is present,
        // so local debug installs and CI APKs share one signature and can upgrade
        // in place without uninstalling.
        create("release") {
            if (hasReleaseKeystore) {
                val storeFilePath: String? = keystoreProperties.getProperty("storeFile")
                val storePassword: String? = keystoreProperties.getProperty("storePassword")
                val keyAlias: String? = keystoreProperties.getProperty("keyAlias")
                val keyPassword: String? = keystoreProperties.getProperty("keyPassword")

                storeFilePath?.let { storeFile = rootProject.file(it) }
                storePassword?.let { this.storePassword = it }
                keyAlias?.let { this.keyAlias = it }
                keyPassword?.let { this.keyPassword = it }
            }
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }

    buildTypes {
        debug {
            // Prefer the same keystore as release so sideloaded debug/CI builds
            // update over each other. Falls back to the default debug keystore
            // when key.properties is missing (e.g. fresh clone without secrets).
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            // If no keystore is configured, Gradle still produces an unsigned
            // or debug-signed artifact depending on AGP defaults — CI always
            // injects key.properties so release builds are signed there.

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.guava:guava-bom:33.0.0-android"))
    implementation("com.google.guava:guava")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter {
    source = "../.."
}
