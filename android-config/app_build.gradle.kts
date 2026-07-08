plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ibrahimshoshaa.workshop_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ibrahimshoshaa.workshop_manager"
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // توقيع مؤقت بمفتاح الـ debug عشان تقدر تجرّب الـ APK على موبايلك بسرعة.
            // قبل أي نشر فعلي على المتجر، لازم تعمل keystore حقيقي وتوقّع بيه.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// إعداد إصدار الـ JVM لـ Kotlin بالطريقة الحديثة (kotlinOptions القديمة بقت
// تتعامل كخطأ مع AGP 9+، فاستخدمنا compilerOptions بدلها)
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
