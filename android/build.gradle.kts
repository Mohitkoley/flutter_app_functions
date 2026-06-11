import java.util.Properties

group = "com.mohitkoley.flutter_app_functions"
version = "1.0-SNAPSHOT"

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterSdkPath: String? = localProperties.getProperty("flutter.sdk")

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("com.google.devtools.ksp") version "2.3.7"
}

android {
    namespace = "com.mohitkoley.flutter_app_functions"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

ksp {
    arg("appfunctions:aggregateAppFunctions", "true")
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5:2.3.20")
    testImplementation("org.mockito:mockito-core:5.0.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    implementation "androidx.appfunctions:appfunctions:1.0.0-alpha09"
    implementation "androidx.appfunctions:appfunctions-service:1.0.0-alpha09"
    // Use Kotlin Symbol Processing (KSP) for the appfunctions compiler plugin.
    // See KSP Quickstart to add KSP to your build
    ksp "androidx.appfunctions:appfunctions-compiler:1.0.0-alpha09"

    if (flutterSdkPath != null) {
        compileOnly(files("$flutterSdkPath/bin/cache/artifacts/engine/android-x64/flutter.jar"))
        testImplementation(files("$flutterSdkPath/bin/cache/artifacts/engine/android-x64/flutter.jar"))
    }

    // Coroutines dependency for UI thread switching
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
