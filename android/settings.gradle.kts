// Fix for AGP AndroidLocationsException when both ANDROID_PREFS_ROOT and ANDROID_USER_HOME are set
try {
    val unsafeField = sun.misc.Unsafe::class.java.getDeclaredField("theUnsafe")
    unsafeField.isAccessible = true
    val unsafe = unsafeField.get(null) as sun.misc.Unsafe

    val peClass = Class.forName("java.lang.ProcessEnvironment")

    val envField = peClass.getDeclaredField("theEnvironment")
    val envOffset = unsafe.staticFieldOffset(envField)
    @Suppress("UNCHECKED_CAST")
    val envMap = unsafe.getObject(peClass, envOffset) as MutableMap<Any, Any>

    val ciField = peClass.getDeclaredField("theCaseInsensitiveEnvironment")
    val ciOffset = unsafe.staticFieldOffset(ciField)
    @Suppress("UNCHECKED_CAST")
    val ciMap = unsafe.getObject(peClass, ciOffset) as MutableMap<Any, Any>

    val keysToRemove = envMap.keys.filter { it.toString().equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
    for (k in keysToRemove) {
        envMap.remove(k)
        ciMap.remove(k)
    }
} catch (_: Throwable) {
}

rootProject.name = "android"

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
