package com.mohitkoley.flutter_app_functions

import android.app.Application
import androidx.appfunctions.AppFunctionConfiguration

/**
 * Base [Application] class that registers the plugin's [AppFunctionsBridge]
 * with the App Functions runtime.
 *
 * Extend this class from your own `Application` subclass and reference it
 * via `android:name=".YourApplication"` in your `AndroidManifest.xml`:
 *
 * ```kotlin
 * class MyApplication : FlutterAppFunctionsApplication()
 * ```
 *
 * The base class also requires the `xmlns:appfn` namespace on your
 * `<application>` element along with the `appfn:description` and
 * `appfn:displayDescription` attributes (see the README for the full
 * manifest snippet).
 */
abstract class FlutterAppFunctionsApplication :
    Application(), AppFunctionConfiguration.Provider {
    override val appFunctionConfiguration: AppFunctionConfiguration
        get() = AppFunctionConfiguration.Builder()
            .addEnclosingClassFactory(AppFunctionsBridge::class.java) {
                AppFunctionsBridge()
            }
            .build()
}
