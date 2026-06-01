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
        buildConfigField("String", "TANIIN_DEFAULT_WALLET_ADDRESS", escapedBuildConfig(envValue("TANIIN_DEFAULT_WALLET_ADDRESS")))
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
