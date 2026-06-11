## 0.0.9

* I have updated alpha 0.0.9 in kotlin.

## 0.0.7

* Example: replaced the toy sample with a realistic productivity app that
  exposes AppFunctions as on-device MCP-style tools (`createTask`,
  `addItemsToShoppingList`, `completeTask`, and `summarizeToday`).
* Example: added a local AI caller simulation that turns prompts into function
  ids and JSON parameters, then invokes the same Dart handlers that Android
  AppFunctions callers use through the bridge.
* Example README: documented that real apps expose local AppFunctions to Android
  and do not connect directly to Gemini just to make tools discoverable.

## 0.0.6

* README: removed hard-coded package version snippets and switched install
  instructions to `flutter pub add flutter_app_functions`, so future releases
  do not leave stale README version text behind.
* README: clarified that each host app must create its own Android
  `MyApplication` class extending `FlutterAppFunctionsApplication` and point
  `<application android:name>` at it.

## 0.0.5

* Fixed real-app integration failure where Gradle could not resolve the
  `com.google.devtools.ksp` plugin from the published package. The plugin's
  Android module now applies KSP with an explicit `2.3.7` version.
* Fixed host app compilation when extending `FlutterAppFunctionsApplication` by
  exposing the AndroidX AppFunctions API artifacts transitively.
* Added a Kotlin unit test that installs a coroutine test main dispatcher and
  verifies `AppFunctionsBridge.executeAppFunction` dispatches to the Flutter
  method channel successfully.
* README: updated install/version text and clarified that host apps do not need
  to declare KSP solely to consume `flutter_app_functions`.

## 0.0.4

* Added `.github/workflows/publish.yml` — pushing a `vX.Y.Z` tag now auto-publishes the package to pub.dev via OpenID Connect (no `PUB_CREDENTIALS` secret is required). The workflow runs `flutter analyze` and `flutter test` before publishing; Kotlin tests are skipped because they need an Android SDK and the alpha08 KSP processor only completes inside a real build.
* README: added a maintainer-only "Publishing releases" section that documents the one-time pub.dev OIDC setup, the version-bump-and-tag flow, and how to re-publish by deleting and re-pushing the tag. The pub.dev form's tag pattern uses `{{version}}` substitution (not a regex), so the form field is `v{{version}}` — the matching GitHub-side regex in the workflow's `on.push.tags` is independent.

## 0.0.3

* Added `AppFunctionPlatformNotSupportedException` (extends `UnsupportedError`). The plugin now fails fast on iOS, macOS, Linux, Windows, and Web before any native code is touched.
* `FlutterAppFunctions.register`, `registerAll`, `invoke`, and `getPlatformVersion` now throw `AppFunctionPlatformNotSupportedException` when `defaultTargetPlatform != android`. Local-only operations (`unregister`, `unregisterAll`, `ensureInitialized`, registry getters) remain no-ops on any platform.
* The exception's `platform` field carries the offending platform name (e.g. `"iOS"`); the message links to `developer.android.com/ai/appfunctions`.
* README: added the new exception to the Errors table and made the "Android only" limitation explicit.

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
