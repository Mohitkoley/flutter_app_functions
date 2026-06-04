## 0.0.2

* Rewrote the plugin as a faithful wrapper of the [Android App Functions](https://developer.android.com/ai/appfunctions) API.
* The Kotlin side now exposes a single `@AppFunction executeAppFunction` entry point that dispatches by `functionId` to a Dart-registered handler.
* Replaced the single `registerToolHandler` Dart API with a typed, multi-function API:
  * `FlutterAppFunctions.instance.register(AppFunctionDefinition(...))` / `unregister` / `unregisterAll`
  * `AppFunctionParameter` (string / int64 / double / bool / stringList, optional, enum-constrained)
  * `AppFunctionReturnType` (voidType / string / int64 / double / boolean / stringList)
  * `AppFunctionContext` (per-call `functionId` + validated `parameters`)
* Added a typed exception hierarchy mirroring `androidx.appfunctions.AppFunction*Exception` 1:1:
  * `AppFunctionException`, `AppFunctionInvalidArgumentException`,
    `AppFunctionElementNotFoundException`, `AppFunctionFunctionNotFoundException`,
    `AppFunctionNotSupportedException`, `AppFunctionPermissionRequiredException`,
    `AppFunctionDisabledException`, `AppFunctionAppUnknownException`.
  * The Kotlin bridge now dispatches by `functionId` over a single
    `parametersJson: String` / result `String` wire channel; typed
    exceptions are wrapped as `PlatformException` on the way out and
    mapped back to their `androidx.appfunctions` subclass on the way in.
* Added a `FlutterAppFunctionsApplication` base class that host apps extend to register the bridge with the AppFunctions runtime.
* Plugin manifest now contributes the `appfunctions` `<service>`, the `xmlns:appfn` namespace, and a `res/xml/app_metadata.xml` entry that points at user-overridable strings.
* Gradle: added `ksp { arg("appfunctions:aggregateAppFunctions", "true") }` so the KSP processor aggregates this module's `@AppFunction`s with the host app's.
* Tests: expanded the Dart `flutter_app_functions_test.dart` and `flutter_app_functions_method_channel_test.dart` suites, and updated the example integration test. The Kotlin bridge's exception mapping is exercised end-to-end by the integration test (alpha08 `AppFunction*Exception` subclasses cannot be constructed in plain JVM unit tests because their constructors touch `android.os.Bundle.EMPTY`).
* Example: registered four sample functions (`createTask`, `countActiveTasks`, `searchContacts`, `markAllTasksDone`) demonstrating typed parameters, typed returns, optional parameters, and a typed error.
* README: rewrote to mirror `developer.android.com/ai/appfunctions` structure.

## 0.0.1

* Initial release with Android App Functions support.
* Added a Dart tool-handler bridge through `MethodChannel`.
* Included an example app and Android unit tests.
