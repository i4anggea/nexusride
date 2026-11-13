import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefines: Map<String, String> = if (project.hasProperty("dart-defines")) {
    project.property("dart-defines")
        .toString()
        .split(",")
        .associate { entry ->
            val decoded = String(Base64.getDecoder().decode(entry), Charsets.UTF_8)
            val pair    = decoded.split("=", limit = 2)
            pair[0] to if (pair.size > 1) pair[1] else ""
        }
} else {
    emptyMap()
}

val releaseSigningProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) propertiesFile.inputStream().use(::load)
}
val releaseStoreFile = releaseSigningProperties.getProperty("storeFile")
val releaseStorePassword = releaseSigningProperties.getProperty("storePassword")
val releaseKeyAlias = releaseSigningProperties.getProperty("keyAlias")
val releaseKeyPassword = releaseSigningProperties.getProperty("keyPassword")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val requestedTasks = gradle.startParameter.taskNames
val requestsRelease = requestedTasks.any { it.contains("release", ignoreCase = true) }
if (requestsRelease && !hasReleaseSigning) {
    throw GradleException(
        "Android release requiere android/key.properties con storeFile, " +
            "storePassword, keyAlias y keyPassword. Consulta README.md."
    )
}

android {
    namespace    = "com.iangea.nexusride2025"
    compileSdk   = flutter.compileSdkVersion
    ndkVersion   = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.iangea.nexusride2025"
        minSdk        = flutter.minSdkVersion
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_KEY_ANDROID"] =
            dartDefines["GOOGLE_MAPS_KEY_ANDROID"] ?: ""
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
