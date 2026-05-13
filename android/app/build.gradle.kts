plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// NDK-build: read ndk.dir from local.properties
// ---------------------------------------------------------------------------
import java.util.Properties

val localProps = Properties()
rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use {
    localProps.load(it)
}
val ndkDirProp: String? = localProps.getProperty("ndk.dir")

val jniSrcDir  = file("src/main/jni")
val jniLibsDir = file("src/main/jniLibs")

android {
    namespace = "com.enigma.ticketing_app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.enigma.ticketing_app"
        minSdk = flutter.minSdkVersion  // Android 5.0
        targetSdk = 36  // Latest stable
        versionCode = flutter.versionCode  // from pubspec.yaml
        versionName = flutter.versionName  // from pubspec.yaml

        // Required for flutter_local_notifications
        multiDexEnabled = true

        // Only build for these ABIs (matches Application.mk)
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Tell Gradle where ndk-build outputs .so files
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

// ---------------------------------------------------------------------------
// ndk-build task: builds libjavaloader.so from jni/Android.mk
// Uses manual Exec task instead of externalNativeBuild to avoid CXX1400
// conflicts with Flutter plugins.
// ---------------------------------------------------------------------------
val ndkBuildNative = tasks.register<Exec>("ndkBuildNative") {
    group = "build"
    description = "Builds libjavaloader.so via ndk-build (Android.mk)"

    val ndkDir = ndkDirProp
        ?: System.getenv("ANDROID_NDK_HOME")
        ?: System.getenv("ANDROID_NDK_ROOT")
    require(ndkDir != null) { "ndk.dir is not set in local.properties and ANDROID_NDK_HOME/ANDROID_NDK_ROOT env vars are not set" }

    val isWindows = org.gradle.internal.os.OperatingSystem.current().isWindows
    val ndkBuildName = if (isWindows) "ndk-build.cmd" else "ndk-build"
    val ndkBuildFile = file("$ndkDir/$ndkBuildName")

    inputs.dir(jniSrcDir)
    outputs.dir(jniLibsDir)

    commandLine(
        ndkBuildFile.absolutePath,
        "NDK_PROJECT_PATH=${projectDir}",
        "APP_BUILD_SCRIPT=${file("$jniSrcDir/Android.mk").absolutePath}",
        "NDK_APPLICATION_MK=${file("$jniSrcDir/Application.mk").absolutePath}",
        "NDK_LIBS_OUT=${jniLibsDir.absolutePath}",
        "NDK_OUT=${layout.buildDirectory.dir("intermediates/ndkBuild/obj").get().asFile.absolutePath}",
        "V=1"
    )
}

afterEvaluate {
    tasks.named("preBuild") { dependsOn(ndkBuildNative) }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
