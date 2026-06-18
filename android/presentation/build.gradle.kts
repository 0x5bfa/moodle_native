plugins {
    id("com.android.library")
}

android {
    namespace = "dev.example.moodlenative.presentation"
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
    implementation(project(":core"))
    implementation(project(":features"))
    testImplementation("junit:junit:4.13.2")
}
