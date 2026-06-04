pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id("com.android.library") version "9.0.1"
        id("org.jetbrains.kotlin.android") version "2.3.20"
        id("com.google.devtools.ksp") version "2.3.7"
    }
}

rootProject.name = "flutter_app_functions"
