pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "taqlyn-flutter-android-host"

include(":bridge")
include(":taqlyn-sdk")
project(":taqlyn-sdk").projectDir =
    file("../../sdk-android/taqlyn-sdk")
