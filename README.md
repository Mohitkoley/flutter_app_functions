# flutter_app_functions

[![pub package](https://img.shields.io/pub/v/flutter_app_functions.svg)](https://pub.dev/packages/flutter_app_functions)

A Flutter plugin that mirrors the
[Android App Functions](https://developer.android.com/ai/appfunctions) API.
Register typed Dart functions once, and any on-device agent that talks to the
Android App Functions runtime (Gemini and friends) can discover, parameterise,
invoke, and react to typed errors from those functions — all without leaving
your existing Flutter app.

The plugin speaks the same wire protocol and the same
`AppFunction*Exception` types as the official Android library, and declares
the same kind of `AppFunctionService` the library expects, so the
documentation at `developer.android.com/ai/appfunctions` applies almost
verbatim.

<!-- VERSIONS -->
| | |
| --- | --- |
| Android only | Minimum SDK 24, compile SDK 37 |
| AndroidX `appfunctions` | `1.0.0-alpha10` |
| Android Gradle plugin | `9.1.0` or higher |
| Flutter | Flutter 3.44.0+ with Dart 3.12.0+ |
| Latest release | See the pub.dev badge above |
<!-- /VERSIONS -->

---

## Table of contents

1. [Concepts](#concepts)
2. [How it works](#how-it-works)
3. [Installation](#installation)
4. [Quick start](#quick-start)
5. [Declaring an app function](#declaring-an-app-function)
   * [Parameters](#parameters)
   * [Return types](#return-types)
6. [Errors](#errors)
7. [Wiring up the Android host app](#wiring-up-the-android-host-app)
8. [Calling a function from an agent](#calling-a-function-from-an-agent)
9. [Testing your app functions](#testing-your-app-functions)
10. [Limitations](#limitations)
11. [Publishing releases](#publishing-releases) *(maintainers)*
12. [References](#references)

---

## Concepts

* **App function** — a single capability the agent can call on behalf of the
  user, e.g. *create a task*, *search contacts*, *send a message*.
* **Definition** — the schema (id, description, parameters, return type) you
  register on the Dart side.
* **Handler** — the Dart async function that runs when the agent calls the
  function.
* **Bridge** — the Kotlin side of the plugin. It dispatches calls from the
  Android App Functions runtime to the Dart registry.
* **Entry point** — `BaseFlutterAppFunctionsService`, the abstract
  `AppFunctionService` annotated with `@AppFunctionServiceEntryPoint` that
  carries the plugin's single `@AppFunction`. The KSP processor generates the
  concrete `FlutterAppFunctionsService` from it, and the plugin's manifest
  declares that generated service. Host apps do not write any Kotlin.

The plugin lives at one level of indirection on purpose: you write the
function **once** in Dart, and the Kotlin side dynamically forwards every
parameter and return value through the same single `@AppFunction`. This means
adding or removing a function does not require a Gradle rebuild.

---

## How it works

A single `@AppFunction` entry point in Kotlin accepts every call from the
agent, forwards it to the Dart registry over a `MethodChannel`, and returns
the result. The Kotlin side never contains user logic — it is a fixed
dispatcher. All parameters, return values, and errors flow over a JSON wire
format (KSP forbids `AppFunctionData` as a parameter type on
`@AppFunction`, so JSON strings are the only cross-language contract that
works on `androidx.appfunctions:1.0.0-alpha10`):

```
Gemini agent
    ↓ "call createTask(title='Buy milk')"
Android AppFunctionManager
    ↓ binds the service declared for the
      android.app.appfunctions.AppFunctionService action
FlutterAppFunctionsService.onExecuteFunction()     ← Kotlin (KSP-generated)
    ↓ dispatches on the function id
BaseFlutterAppFunctionsService.executeAppFunction() ← Kotlin (the @AppFunction)
    ↓ delegates
AppFunctionsBridge.executeAppFunction()            ← Kotlin (1 function, fixed)
    ↓ MethodChannel.invokeMethod("invokeAppFunction", {functionId, parametersJson})
FlutterAppFunctions._onMethodCall()                ← Dart
    ↓ JSON-decode parameters, look up registry
Your handler: (context, params) async { ... }       ← Dart (your logic)
    ↓ returns String
FlutterAppFunctions._encodeResultJson()
    ↓ MethodChannel Result.success("...")
AppFunctionsBridge.executeAppFunction() returns
    ↓
Android AppFunctionManager returns to agent
```

All three Kotlin frames are plugin code — generated or fixed — and you never
edit them. Your code starts at the handler.

Because the handler is plain Dart, your UI state, your state-management
objects, and your `ChangeNotifier`s / Riverpod providers / Bloc stores are
all directly accessible — the agent can mutate the same state the user sees
on screen, and the UI rebuilds through the normal `notifyListeners` /
`setState` / `ref.invalidate` flow.

---

## Installation

Add the package to your Flutter app from
[pub.dev/packages/flutter_app_functions](https://pub.dev/packages/flutter_app_functions):

```sh
flutter pub add flutter_app_functions
```

For local development, use a path dependency:

```yaml
dependencies:
  flutter_app_functions:
    path: ../flutter_app_functions
```

The plugin's Android manifest already contributes the
`FlutterAppFunctionsService` declaration (guarded by
`android.permission.BIND_APP_FUNCTION_SERVICE`, bound through the
`android.app.appfunctions.AppFunctionService` action, and enabled only on
API 36+ via a `values-v36` resource) plus the `res/xml/app_metadata.xml`
entry. The host app's manifest only needs to opt in (see
[Wiring up the Android host app](#wiring-up-the-android-host-app)).

Up to alpha09 the `<service>` entry came from the `appfunctions-service`
library's own manifest and was merged in automatically. That artifact no
longer exists, so the plugin declares its own generated service instead.

The package applies the KSP Gradle plugin with an explicit version in its own
Android module. Host apps do not need to declare `com.google.devtools.ksp`
just to consume this plugin.

---

## Quick start

In `lib/main.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterAppFunctions.instance.register(
    AppFunctionDefinition(
      id: 'createTask',
      description: 'Creates a new task in the user\'s task list.',
      parameters: [
        AppFunctionParameter.string('title'),
        AppFunctionParameter.optionalString('notes'),
      ],
      returnType: AppFunctionReturnType.string,
      handler: (context, params) async {
        final title = params['title'] as String;
        final notes = params['notes'] as String?;
        return 'Created task "$title"';
      },
    ),
  );

  runApp(const MyApp());
}
```

In `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:appfn="http://schemas.android.com/apk/androidx.appfunctions">

    <application
        appfn:description="@string/appfn_description"
        appfn:displayDescription="@string/appfn_display_description">
        ...
    </application>
</manifest>
```

That is the whole Android-side setup — no `Application` subclass and no
Kotlin in your app module. The plugin declares its own KSP-generated
`FlutterAppFunctionsService` and Android binds to it directly.

In `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="appfn_description">com.example.myapp</string>
    <string name="appfn_display_description">My App — lets the agent do useful things.</string>
</resources>
```

Build, install, and the function shows up in
`adb shell cmd app_function list-app-functions`.

For a more realistic flow, see [`example/lib/main.dart`](example/lib/main.dart).
It registers multiple productivity functions, mutates normal Flutter app state,
and includes a local AI caller simulation that sends the same function id and
JSON parameter shape that an Android AppFunctions caller would send.

---

## Declaring an app function

A function is a value of `AppFunctionDefinition` passed to
`FlutterAppFunctions.instance.register(...)`:

```dart
AppFunctionDefinition(
  id: 'createTask',                     // required
  description: '...',                   // required, surfaced to the agent
  parameters: [ ... ],                  // optional, defaults to []
  returnType: AppFunctionReturnType.string, // optional, defaults to void
  handler: (context, params) async { ... }, // required
)
```

* `id` must be unique within the registry. Re-registering with the same id
  replaces the existing definition.
* `description` is KDoc-style documentation of the function. It is exposed to
  the agent verbatim, so write it the way you would write a public API
  docstring.
* `parameters` is the ordered list of accepted parameters (see below).
* `returnType` defaults to `AppFunctionReturnType.voidType`. Set it explicitly
  for any function that returns data.
* `handler` is the async Dart function executed when the agent calls the
  function. It receives:
  * `context` — an `AppFunctionContext` with the `functionId` and the
    validated, type-coerced parameter map.
  * `parameters` — the same validated map, for convenience.
  It should return the declared return value, or `null` for void returns.

### Parameters

Each parameter is an `AppFunctionParameter`. The supported scalar types map
1:1 to `androidx.appfunctions.AppFunctionData`:

| Dart factory | Wire type | Description |
| --- | --- | --- |
| `AppFunctionParameter.string(name, ...)` | `String` | UTF-8 string. |
| `AppFunctionParameter.optionalString(name, ...)` | `String?` | Optional string. |
| `AppFunctionParameter.int(name, ...)` | `int64` | 64-bit signed integer. |
| `AppFunctionParameter.double(name, ...)` | `double` | IEEE-754 double. |
| `AppFunctionParameter.bool(name, ...)` | `bool` | Boolean. |
| `AppFunctionParameter.stringList(name, ...)` | `List<String>` | Ordered list of strings. |

Optional parameters default to `required: true`; pass `required: false` to
mark a string as optional:

```dart
AppFunctionParameter.string('filter', required: false)
```

String parameters can be restricted to an enum-like set:

```dart
AppFunctionParameter.string(
  'filterType',
  description: 'Either "INDIVIDUAL" or "GROUP".',
  enumValues: ['INDIVIDUAL', 'GROUP'],
)
```

Enum violations, missing required values, wrong types, and unknown keys all
raise `AppFunctionInvalidArgumentException` and are surfaced to the agent as
a typed `androidx.appfunctions.AppFunctionInvalidArgumentException`.

### Return types

`AppFunctionReturnType` mirrors the same scalar set plus a void marker:

```dart
AppFunctionReturnType.voidType    // handler returns null/void
AppFunctionReturnType.string      // handler returns String
AppFunctionReturnType.int64       // handler returns int
AppFunctionReturnType.double      // handler returns double
AppFunctionReturnType.boolean     // handler returns bool
AppFunctionReturnType.stringList  // handler returns List<String>
```

Handlers that return a different type throw
`AppFunctionAppUnknownException` and the agent sees the same typed error
it would from a native App Function.

---

## Errors

The Dart exception hierarchy maps 1:1 to `androidx.appfunctions`:

| Dart exception | Kotlin exception | Error code |
| --- | --- | --- |
| `AppFunctionInvalidArgumentException` | `AppFunctionInvalidArgumentException` | `AppFunctionInvalidArgument` |
| `AppFunctionElementNotFoundException` | `AppFunctionElementNotFoundException` | `AppFunctionElementNotFound` |
| `AppFunctionFunctionNotFoundException` | `AppFunctionFunctionNotFoundException` | `AppFunctionFunctionNotFound` |
| `AppFunctionNotSupportedException` | `AppFunctionNotSupportedException` | `AppFunctionNotSupported` |
| `AppFunctionPermissionRequiredException` | `AppFunctionPermissionRequiredException` | `AppFunctionPermissionRequired` |
| `AppFunctionDisabledException` | `AppFunctionDisabledException` | `AppFunctionDisabled` |
| `AppFunctionAppUnknownException` | `AppFunctionAppUnknownException` | `AppFunctionAppUnknown` |
| `AppFunctionPlatformNotSupportedException` *(extends `UnsupportedError`)* | n/a — fired on iOS/macOS/Linux/Windows/Web before native code is touched | n/a |

Throw any of these from your handler and the agent sees the matching typed
exception on the Kotlin side:

```dart
handler: (context, params) async {
  if (!userHasAccess) {
    throw AppFunctionPermissionRequiredException('User has not granted access.');
  }
  ...
}
```

Handlers that throw any other error are wrapped as
`AppFunctionAppUnknownException`.

---

## Wiring up the Android host app

The plugin takes care of every manifest entry *inside* the
`<application>` element, so the host app's manifest only needs to:

1. Declare the `xmlns:appfn` namespace.
2. Provide `appfn:description` and `appfn:displayDescription` attributes
   on `<application>`.
3. Override the `appfn_description` / `appfn_display_description` strings
   in your `res/values/strings.xml` (the plugin ships sensible defaults
   so this step is optional).

There is no step involving Kotlin. The plugin's `@AppFunction` lives on
`BaseFlutterAppFunctionsService`, an abstract `AppFunctionService` annotated
with `@AppFunctionServiceEntryPoint`; the appfunctions KSP processor generates
the concrete `FlutterAppFunctionsService` and the plugin's manifest declares
it. Android binds to that service directly.

> **Migrating from 0.0.9 or earlier.** Previous versions required a host-app
> `Application` subclass extending `FlutterAppFunctionsApplication`, pointed at
> by `<application android:name>`. That is obsolete: delete the class and
> remove the `android:name` attribute. `FlutterAppFunctionsApplication` is kept
> as a deprecated no-op so existing apps still compile.
>
> The function id also changed, since it is derived from the declaring class:
>
> ```
> before: com.mohitkoley.flutter_app_functions.AppFunctionsBridge#executeAppFunction
> after:  com.mohitkoley.flutter_app_functions.BaseFlutterAppFunctionsService#executeAppFunction
> ```
>
> This is the id of the plugin's single dispatch entry point, not of your own
> Dart functions, so it only matters if you referenced it directly.

### Gradle

`androidx.appfunctions:1.0.0-alpha10` raises the toolchain floor for every
host app, not just this plugin. Your app must build with **at least**:

| | |
| --- | --- |
| `compileSdk` | `37` (plus `compileSdkMinor`) |
| Android Gradle plugin | `9.1.0` |
| Gradle | `9.3.1` (required by AGP 9.1.0) |

If any of these is lower, the build fails while checking AAR metadata with
`Dependency 'androidx.appfunctions:appfunctions:1.0.0-alpha10' requires ...`
before your code is compiled.

Two things to watch for in your `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 37
    compileSdkMinor = 0
}
```

* Flutter's default `flutter.compileSdkVersion` is still 36, so `compileSdk`
  must be set explicitly rather than left to the Flutter Gradle plugin.
* API 37 ships only as minor-versioned platforms (`android-37.0`,
  `android-37.1`). Without `compileSdkMinor`, AGP looks for a plain
  `android-37` target and fails with `Failed to find target with hash string
  'android-37'`. `compileSdkMinor` requires AGP 9.1.0 or newer.

If your app's own modules declare their own `@AppFunction`s, add the
following to your **app-level** `android/app/build.gradle.kts` so the KSP
processor aggregates them all into a single metadata file:

```kotlin
ksp {
    arg("appfunctions:aggregateAppFunctions", "true")
}
```

(For pure plugin users, this block is already added to the plugin's
`android/build.gradle.kts`.)

---

## Calling a function from an agent

The agent interacts with the Kotlin bridge; the plugin takes care of the
Dart round-trip. Once your app is installed:

```sh
# List every function the bridge exposes:
adb shell cmd app_function list-app-functions

# Invoke a function by id:
adb shell cmd app_function execute-app-function \
    --uri app_function://<your.app.applicationId>/com.mohitkoley.flutter_app_functions.BaseFlutterAppFunctionsService%23executeAppFunction \
    --function-id createTask \
    --params '{"title":"Buy milk","notes":"2L semi-skimmed"}'
```

Two things that are easy to get wrong here:

* The package in the URI is **your host app's `applicationId`** — the app that
  bundles the plugin — not the plugin's Kotlin namespace.
* The AppFunctions id is the plugin's single dispatch entry point,
  `…BaseFlutterAppFunctionsService#executeAppFunction` (the `#` needs escaping
  in a URI). Your own function id — `createTask` — is what goes in
  `--function-id`, because the plugin dispatches on it in Dart.

The shell surface is experimental and has changed between alpha releases, so
treat the exact flags as a starting point and confirm with
`adb shell cmd app_function help`. Both commands need a device on Android 16
or newer.

The agent (e.g. Gemini) sees the function descriptions and parameters as
ordinary Android AppFunctions and calls them through the standard
`AppFunctionManager` flow.

---

## Testing your app functions

### Dart

```sh
flutter test
```

The suite covers the registry, the type-coercion validator, the
exception-hierarchy mapping, and the round-trip through the method
channel. The method channel is mocked via
`TestDefaultBinaryMessengerBinding.setMockMethodCallHandler`.

### Kotlin

```sh
cd example/android
./gradlew :flutter_app_functions:testDebugUnitTest
```

Two suites run:

* `FlutterAppFunctionsPluginTest` — the plugin's lifecycle
  (`getPlatformVersion`).
* `AppFunctionsBridgeDispatcherTest` — the suspend `executeAppFunction`
  dispatch, driven through a fake `BinaryMessenger` so no real Flutter engine
  is needed.

The typed error mapping in `AppFunctionsBridge.mapErrorCodeToException` is
*not* covered here: the `AppFunction*Exception` constructors touch
`android.os.Bundle.EMPTY`, which is only initialised inside a real Android
runtime, so it needs an instrumentation test rather than a plain JVM one.

### Integration

```sh
cd example
flutter test integration_test
```

Drives the example app's plugin, registering sample functions and
exercising the method channel from the host side.

---

## Limitations

* **Android only.** `androidx.appfunctions` has no iOS, macOS, Linux,
  Windows, or Web counterpart. `FlutterAppFunctions.register`,
  `registerAll`, `invoke`, and `getPlatformVersion` throw
  `AppFunctionPlatformNotSupportedException` on any non-Android
  `defaultTargetPlatform` before the registry is mutated or any method
  channel traffic is generated. The exception's `platform` field
  reports the offending runtime (e.g. `"iOS"`). If you want to share
  your function definitions between an Android build and an iOS / Web
  build of the same codebase, gate the `register` call on
  `defaultTargetPlatform == TargetPlatform.android`.
* **Functions are only discoverable on Android 16 (API 36) or newer.** The
  plugin's `minSdk` is 24 so your app still installs and runs on older
  devices, but the generated `FlutterAppFunctionsService` is disabled below
  API 36 (via a `values-v36` resource) because the platform
  `AppFunctionService` it extends does not exist there. Registering functions
  in Dart on such a device is harmless — nothing will ever call them.
* **Being invoked by a real agent is gated by Google, not by this plugin.**
  Callers need the `android.permission.EXECUTE_APP_FUNCTIONS` permission, and
  per Google's documentation AppFunctions is *"in an experimental preview"*
  with Gemini integration *"in a private preview with trusted testers"* and
  *"only a limited number of apps and system agents"* able to access the full
  pipeline. Exposing functions works today; having the system Gemini call
  them in production requires onboarding through Google's Early Access
  Program. If you want a working agent loop before then, host the model
  yourself and route its tool calls into the same Dart handlers.
* The plugin targets `androidx.appfunctions:1.0.0-alpha10`, which is an
  alpha release of the AppFunctions library. The API has broken between alpha
  releases (alpha10 dropped the `appfunctions-service` artifact and moved
  `@AppFunction` onto `@AppFunctionServiceEntryPoint`), so expect further
  churn.
* Nested object and array-of-object parameters are not supported — only
  the scalar types listed above. The `AppFunctionData` wire format
  supports richer shapes; the plugin exposes the common subset to keep
  the Dart surface ergonomic.
* Boolean and double are exposed as `boolean` / `double` in the return
  type, matching the official App Functions API.

---

## Publishing releases

*Maintainer-only — skip if you are consuming the package.*

Publishing is automated by
[`.github/workflows/publish.yml`](.github/workflows/publish.yml) using
**OpenID Connect** — no long-lived secret is stored in the repo. The
official guide is at
[dart.dev/tools/pub/automated-publishing](https://dart.dev/tools/pub/automated-publishing).

### One-time setup (do this once on pub.dev)

1. Sign in to pub.dev with the Google account that owns the package.
2. Open the package's admin page:
   [`pub.dev/packages/flutter_app_functions/admin/automated-publishing`](https://pub.dev/packages/flutter_app_functions/admin/automated-publishing).
3. Click **Enable publishing from GitHub Actions** and fill in:
   * **Tag pattern**: `v{{version}}`
     (the form's `{{version}}` placeholder is substituted with the
     package's version, so it accepts tags like `v1.2.3` and
     `v1.2.3-rc.1`)
4. Tick the form's checkboxes as follows:
   * **Enable publishing from push events** — ✅ on
     *(required; this workflow is triggered by `push: tags:`)*
   * **Enable publishing from workflow_dispatch events** — ❌ off
     *(pub.dev's OIDC check rejects branch-typed refs, so a manually
     triggered run would always fail with a confusing server error)*
   * **Require GitHub Actions environment** — ❌ off
     *(only relevant if you use GitHub Environments for approval gates
     or env-scoped secrets; unnecessary for solo publishing)*
5. Save. The next job triggered by a matching tag will be trusted.

> **Two patterns, two syntaxes.** This README's
> [`publish.yml`](.github/workflows/publish.yml) uses a GitHub regex
> (`'v[0-9]+.[0-9]+.[0-9]+*'`) to decide *when* the job fires; the
> pub.dev form's `v{{version}}` decides *which tags it will trust*.
> Both must be satisfied for a tag to result in a publish.

> **Why no `PUB_CREDENTIALS` secret?** OIDC exchanges a short-lived
> GitHub-issued token for a pub.dev OAuth token at runtime, so the
> repo never has to hold a credential that could leak. See the
> [GitHub Actions OIDC docs](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect).

### Cutting a release

```sh
# 1. Bump the version and update the changelog
$EDITOR pubspec.yaml   # bump `version:`
$EDITOR CHANGELOG.md   # add a new entry on top

# 2. Commit and push to main
git add pubspec.yaml CHANGELOG.md
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
git commit -m "Release ${VERSION}"
git push origin main

# 3. Tag and push the tag — this triggers the workflow
git tag "v${VERSION}"
git push origin "v${VERSION}"
```

The GitHub Actions run takes ~30 seconds, after which pub.dev lists the
new version. Re-publish by deleting and re-pushing the tag — there is
**no** `workflow_dispatch` trigger, because pub.dev's OIDC check
rejects branch-typed refs.

### Re-running a failed publish

```sh
# Delete the tag locally and remotely
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
git tag -d "v${VERSION}"
git push origin ":refs/tags/v${VERSION}"

# Fix the issue, then re-tag
git tag "v${VERSION}"
git push origin "v${VERSION}"
```

---

## References

* [Overview of App Functions](https://developer.android.com/ai/appfunctions)
* [`androidx.appfunctions` release notes](https://developer.android.com/jetpack/androidx/releases/appfunctions)
* [App Functions sample app](https://github.com/android/appfunctions-sample)
* [flutter_app_functions on pub.dev](https://pub.dev/packages/flutter_app_functions)
* [flutter_app_functions on GitHub](https://github.com/Mohitkoley/flutter_app_functions)
