import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

val devServerHost = providers.gradleProperty("devServerHost").get()
val devServerPort = providers.gradleProperty("devServerPort").get()
val prodServerHost = providers.gradleProperty("prodServerHost").get()

// Release signing key, kept outside the repo. The properties file holds
// storeFile, storePassword, keyAlias and keyPassword. Without it, release
// builds come out unsigned. Override the location with -PreleaseSigning=…
// A value starting with op:// is a 1Password secret reference, read with the
// 1Password CLI (`op read`) when a release build is configured.
val releaseSigning = Properties().apply {
    val path = providers.gradleProperty("releaseSigning").orNull
        ?: "${System.getProperty("user.home")}/.portermills/android-release.properties"
    file(path).takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

fun signingValue(key: String): String {
    val value: String = releaseSigning.getProperty(key) ?: error("$key missing from release signing properties")
    if (!value.startsWith("op://")) return value
    return providers.exec { commandLine("op", "read", "--no-newline", value) }
        .standardOutput.asText.get()
}

android {
    namespace = "app.portermills"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.portermills"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // Only release tasks need the key, so debug builds never prompt 1Password.
    val buildingRelease = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

    signingConfigs {
        if (buildingRelease && !releaseSigning.isEmpty) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = signingValue("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", "\"http://$devServerHost:$devServerPort/api\"")
            buildConfigField("String", "SOCKET_URL", "\"ws://$devServerHost:$devServerPort/socket/websocket\"")
        }
        release {
            isMinifyEnabled = true
            signingConfig = signingConfigs.findByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "API_BASE_URL", "\"https://$prodServerHost/api\"")
            buildConfigField("String", "SOCKET_URL", "\"wss://$prodServerHost/socket/websocket\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi",
        )
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.datastore.preferences)
    debugImplementation(libs.androidx.ui.tooling)
}
