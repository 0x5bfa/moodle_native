plugins {
    id("com.android.library")
}

android {
    namespace = "dev.example.moodlenative.runtime"
    buildToolsVersion = "37.0.0"

    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}

dependencies {
    api(project(":core"))
    api(project(":features"))
    api(project(":presentation"))
    api(project(":storage"))
    implementation(project(":data"))
    implementation(platform("androidx.compose:compose-bom:2026.05.01"))
    implementation("androidx.compose.runtime:runtime")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
    testImplementation("junit:junit:4.13.2")
}
