plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "app.lockin"
    // ⚠️ UNVERIFIED: compileSdk/targetSdk 36 is Android 16. Bump to whatever is current
    // when you first build — Play requires targeting the latest-1 API within a year of
    // its release, and this app has no reason to lag.
    compileSdk = 36

    defaultConfig {
        // The published identity, and permanent: Play binds it to the listing on first
        // upload and it can never be changed. `app.lockin` was taken by somebody else, so
        // this follows the iOS bundle id's owner instead. The *namespace* above stays
        // app.lockin -- that is the code's package, nobody outside sees it, and renaming
        // it would move every source file for no gain.
        applicationId = "com.r00tlab.nagg"
        minSdk = 26
        targetSdk = 36
        // Play refuses an upload whose versionCode it has seen before, and says so only
        // after the bundle is built, signed and sent. CI passes the run number; a local
        // build falls back to 1, which never reaches Play.
        versionCode = (System.getenv("ANDROID_VERSION_CODE") ?: "1").toInt()
        // Matches iOS. Two stores showing different numbers for the same release is a
        // support question nobody should have to answer.
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // The upload key. Google holds the real app signing key under Play App Signing; this
    // one only proves the bundle came from us. Absent locally, which is why the config is
    // built conditionally rather than declared and left half-empty: a signingConfig
    // pointing at a keystore that is not there fails every local build, including the
    // debug one nobody was trying to sign.
    val keystore = rootProject.file("upload.jks")
    val keystorePassword = System.getenv("KEYSTORE_PASSWORD")

    signingConfigs {
        if (keystore.exists() && keystorePassword != null) {
            create("upload") {
                storeFile = keystore
                storePassword = keystorePassword
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            isMinifyEnabled = false
        }
        release {
            // Unsigned when the keystore is absent. `gradle bundleRelease` then still
            // succeeds locally and produces something Play will reject -- which is the
            // right trade: the alternative is a build file that cannot be run at all
            // without a secret, and nobody can check their work.
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    lint {
        // lintVitalRelease fails the release build and prints only that it failed; the
        // issues themselves go to a report file nobody on CI ever opens. Printing them to
        // stdout is the difference between one round trip and four.
        textReport = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    val composeBom = platform(libs.androidx.compose.bom)
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    // Only three icons are used (PhotoCamera / Timer / QrCodeScanner). R8 strips the
    // rest in release; in debug this adds a few MB to the APK and nothing else.
    implementation(libs.androidx.compose.material.icons.extended)

    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.mlkit.barcode.scanning)
    implementation(libs.zxing.core)

    implementation(libs.revenuecat.purchases)

    testImplementation(libs.junit)

    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
