package com.mohitkoley.flutter_app_functions

import android.app.Application

/**
 * Base [Application] class that host apps used to extend in order to
 * register the plugin's app function with the App Functions runtime.
 *
 * This is no longer necessary. Since `androidx.appfunctions` 1.0.0-alpha10
 * the plugin's `@AppFunction` lives on [BaseFlutterAppFunctionsService], and
 * the KSP-generated `FlutterAppFunctionsService` that the plugin declares in
 * its manifest constructs and dispatches to it directly. There is nothing
 * left for an `Application` subclass to provide.
 *
 * The class is kept so existing host apps still compile. To drop it, delete
 * your `Application` subclass and remove `android:name` from the
 * `<application>` element of your `AndroidManifest.xml`.
 */
@Deprecated(
    message =
        "No longer required. The plugin's KSP-generated FlutterAppFunctionsService " +
            "registers the app function directly. Delete your Application subclass " +
            "and remove android:name from <application>.",
)
abstract class FlutterAppFunctionsApplication : Application()
