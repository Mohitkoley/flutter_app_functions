import java.util.Properties

group = "com.mohitkoley.flutter_app_functions"
version = "1.0-SNAPSHOT"

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterSdkPath: String? = localProperties.getProperty("flutter.sdk")
val flutterEngineVersion: String = flutterSdkPath
    ?.let { file("$it/bin/internal/engine.version") }
    ?.takeIf { it.exists() }
    ?.readText()
    ?.trim()
    .orEmpty()

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://storage.googleapis.com/download.flutter.io")
    }
}

plugins {
    id("com.android.library")
    id("com.google.devtools.ksp") version "2.3.7"
}

android {
    namespace = "com.mohitkoley.flutter_app_functions"

    compileSdk = 37
    compileSdkMinor = 0

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
    api("androidx.appfunctions:appfunctions:1.0.0-alpha10")
    ksp("androidx.appfunctions:appfunctions-compiler:1.0.0-alpha10")

    // Modern Flutter SDKs no longer ship engine/android-x64/flutter.jar; the
    // embedding classes come from the Maven artifact instead. Fall back to the
    // legacy jar only when it is actually present.
    val legacyFlutterJar = flutterSdkPath
        ?.let { file("$it/bin/cache/artifacts/engine/android-x64/flutter.jar") }
        ?.takeIf { it.exists() }
    if (legacyFlutterJar != null) {
        compileOnly(files(legacyFlutterJar))
        testImplementation(files(legacyFlutterJar))
    } else {
        compileOnly("io.flutter:flutter_embedding_debug:1.0.0-$flutterEngineVersion")
        testImplementation("io.flutter:flutter_embedding_debug:1.0.0-$flutterEngineVersion")
    }

    // Coroutines dependency for UI thread switching
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
