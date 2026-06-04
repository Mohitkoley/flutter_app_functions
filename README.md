# flutter_app_functions

[![pub package](https://img.shields.io/pub/v/flutter_app_functions.svg)](https://pub.dev/packages/flutter_app_functions)

A Flutter plugin that mirrors the
[Android App Functions](https://developer.android.com/ai/appfunctions) API.
Register typed Dart functions once, and any on-device agent that talks to the
Android App Functions runtime (Gemini and friends) can discover, parameterise,
invoke, and react to typed errors from those functions — all without leaving
your existing Flutter app.

The plugin speaks the same wire protocol, the same `AppFunction*Exception`
types, and the same manifest shape as the official Android library, so the
documentation at `developer.android.com/ai/appfunctions` applies almost
verbatim.

| | |
| --- | --- |
| Android only | Minimum SDK 24, compile SDK 36 |
| AndroidX `appfunctions` | `1.0.0-alpha08` |
| Flutter | Flutter 3.x with Dart 3.12.0+ |
| Version | [`0.0.3`](https://pub.dev/packages/flutter_app_functions) |

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
* **Bridge** — the Kotlin side of the plugin. It exposes a single
  `@AppFunction` to the Android App Functions runtime and dispatches calls
  to the Dart registry.
* **Base application** — `FlutterAppFunctionsApplication`, the
  `Application` subclass your host app extends to register the bridge with
  the AppFunctions system.

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
works on `androidx.appfunctions:1.0.0-alpha08`):

```
Gemini agent
    ↓ "call createTask(title='Buy milk')"
Android AppFunctionManager
    ↓ looks up @AppFunction executeAppFunction
AppFunctionsBridge.executeAppFunction()           ← Kotlin (1 function, fixed)
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

Because the handler is plain Dart, your UI state, your state-management
objects, and your `ChangeNotifier`s / Riverpod providers / Bloc stores are
all directly accessible — the agent can mutate the same state the user sees
on screen, and the UI rebuilds through the normal `notifyListeners` /
`setState` / `ref.invalidate` flow.

---

## Installation

Add the package to your Flutter app from
[pub.dev/packages/flutter_app_functions](https://pub.dev/packages/flutter_app_functions):

```yaml
dependencies:
  flutter_app_functions: ^0.0.3
```

Then run:

```sh
flutter pub get
```

For local development, use a path dependency:

```yaml
dependencies:
  flutter_app_functions:
    path: ../flutter_app_functions
```

The plugin's Android manifest already contributes the
`appfunctions:APP_FUNCTION_SERVICE` permission, the
`<service>` declaration, and the `res/xml/app_metadata.xml` entry. The host
app's manifest only needs to opt in (see
[Wiring up the Android host app](#wiring-up-the-android-host-app)).

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
        android:name=".MyApplication"
        appfn:description="@string/appfn_description"
        appfn:displayDescription="@string/appfn_display_description">
        ...
    </application>
</manifest>
```

In `android/app/src/main/kotlin/.../MyApplication.kt`:

```kotlin
package com.example.myapp

import com.mohitkoley.flutter_app_functions.FlutterAppFunctionsApplication

class MyApplication : FlutterAppFunctionsApplication()
```

In `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="appfn_description">com.example.myapp</string>
    <string name="appfn_display_description">My App — lets the agent do useful things.</string>
</resources>
```

Build, install, and the function shows up in
`adb shell cmd appfunctions list-app-functions`.

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
2. Set `android:name=".MyApplication"` (or your equivalent) on
   `<application>`.
3. Provide `appfn:description` and `appfn:displayDescription` attributes
   on `<application>`.
4. Override the `appfn_description` / `appfn_display_description` strings
   in your `res/values/strings.xml` (the plugin ships sensible defaults
   so step 4 is optional).

Then point your custom `Application` class at
`FlutterAppFunctionsApplication`:

```kotlin
class MyApplication : FlutterAppFunctionsApplication()
```

That's the only Kotlin code you need to write. `FlutterAppFunctionsApplication`
implements `AppFunctionConfiguration.Provider` and registers the
`AppFunctionsBridge` with the AppFunctions runtime.

### Gradle

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
adb shell cmd appfunctions list-app-functions

# Invoke a function by id:
adb shell cmd appfunctions execute-app-function \
    --uri appfunctions://com.mohitkoley.flutter_app_functions/executeAppFunction \
    --function-id createTask \
    --params '{"title":"Buy milk","notes":"2L semi-skimmed"}'
```

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
./gradlew testDebugUnitTest
```

The Kotlin unit tests cover the plugin's lifecycle (`getPlatformVersion`).
The suspend `executeAppFunction` entry point is covered indirectly by
the integration test because it requires a real Flutter engine channel,
and the alpha08 `AppFunction*Exception` subclasses cannot be
constructed in plain JVM tests (their constructors touch
`android.os.Bundle.EMPTY`, which is only initialised inside a real
Android runtime).

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
* The plugin targets `androidx.appfunctions:1.0.0-alpha08`, which is an
  alpha release of the AppFunctions library.
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
     package's version, so this accepts tags like `v0.0.3`,
     `v1.2.3`, and `v0.0.4-rc.1`)
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
git commit -m "Release 0.0.4"
git push origin main

# 3. Tag and push the tag — this triggers the workflow
git tag v0.0.4
git push origin v0.0.4
```

The GitHub Actions run takes ~30 seconds, after which pub.dev lists the
new version. Re-publish by deleting and re-pushing the tag — there is
**no** `workflow_dispatch` trigger, because pub.dev's OIDC check
rejects branch-typed refs.

### Re-running a failed publish

```sh
# Delete the tag locally and remotely
git tag -d v0.0.4
git push origin :refs/tags/v0.0.4

# Fix the issue, then re-tag
git tag v0.0.4
git push origin v0.0.4
```

---

## References

* [Overview of App Functions](https://developer.android.com/ai/appfunctions)
* [`androidx.appfunctions` release notes](https://developer.android.com/jetpack/androidx/releases/appfunctions)
* [App Functions sample app](https://github.com/android/appfunctions-sample)
* [flutter_app_functions on pub.dev](https://pub.dev/packages/flutter_app_functions)
* [flutter_app_functions on GitHub](https://github.com/Mohitkoley/flutter_app_functions)
