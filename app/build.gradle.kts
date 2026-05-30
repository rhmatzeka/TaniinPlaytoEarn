import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

val localEnv = Properties().apply {
    val envFile = rootProject.file(".env")
    if (envFile.exists()) {
        envFile.inputStream().use { load(it) }
    }
}

fun envValue(name: String, fallback: String = ""): String {
    return (System.getenv(name) ?: localEnv.getProperty(name) ?: fallback).trim()
}

fun escapedBuildConfig(value: String): String {
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
}

android {
    namespace = "id.rahmat.taniin"
    compileSdk = 36

    defaultConfig {
        applicationId = "id.rahmat.taniin"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("String", "SEPOLIA_RPC_URL", escapedBuildConfig(envValue("SEPOLIA_RPC_URL", "https://ethereum-sepolia-rpc.publicnode.com")))
        buildConfigField("String", "TANIIN_COIN_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_COIN_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_ITEMS_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_ITEMS_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_LAND_CONTRACT_ADDRESS", escapedBuildConfig(envValue("TANIIN_LAND_CONTRACT_ADDRESS")))
        buildConfigField("String", "TANIIN_GAME_API_URL", escapedBuildConfig(envValue("TANIIN_GAME_API_URL")))
        buildConfigField("String", "TANIIN_DEFAULT_WALLET_ADDRESS", escapedBuildConfig(envValue("TANIIN_DEFAULT_WALLET_ADDRESS")))
        buildConfigField("String", "TANIIN_ETH_WEI_PER_COIN", escapedBuildConfig(envValue("TANIIN_ETH_WEI_PER_COIN", "10000000000")))
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}
