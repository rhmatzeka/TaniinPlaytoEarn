import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localEnv = Properties().apply {
    listOf(
        rootProject.file("../../.env"),
        rootProject.file("../.env"),
        rootProject.file(".env")
    ).firstOrNull { it.exists() }?.inputStream()?.use { load(it) }
}

fun envValue(name: String, fallback: String = ""): String {
    return (System.getenv(name) ?: localEnv.getProperty(name) ?: fallback).trim()
}

fun escapedBuildConfig(value: String): String {
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
}

android {
    namespace = "id.rahmat.taniin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.rahmat.taniin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        buildConfigField("String", "SEPOLIA_RPC_URL", escapedBuildConfig(envValue("SEPOLIA_RPC_URL", "https://ethereum-sepolia-rpc.publicnode.com")))
        buildConfigField("String", "TANIIN_COIN_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_COIN_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_ITEMS_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_ITEMS_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_LAND_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_LAND_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_GAME_API_URL", escapedBuildConfig(envValue("TANIIN_GAME_API_URL")))
        buildConfigField("String", "TANIIN_MULTIPLAYER_URL", escapedBuildConfig(envValue("TANIIN_MULTIPLAYER_URL")))
    }

    buildFeatures {
        buildConfig = true
    }

    // CI writes the fixed release key here so every APK update installs over
    // the previous one; local builds without it fall back to the debug key.
    val releaseKeystore = file("taniin.keystore")
    val releaseKeystorePassword = envValue("TANIIN_KEYSTORE_PASSWORD")
    signingConfigs {
        create("tetap") {
            storeFile = releaseKeystore
            storeType = "pkcs12"
            storePassword = releaseKeystorePassword
            keyAlias = "taniin"
            keyPassword = releaseKeystorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystore.exists() && releaseKeystorePassword.isNotEmpty()) {
                signingConfigs.getByName("tetap")
            } else {
                signingConfigs.getByName("debug")
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
