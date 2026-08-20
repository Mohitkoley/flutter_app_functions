# flutter_app_functions example

This example shows the app-side code you write when your Flutter app wants to
behave like an on-device MCP tool provider through Android AppFunctions.

The app is a small productivity app. It registers Dart handlers for:

* `createTask`
* `addItemsToShoppingList`
* `completeTask`
* `summarizeToday`

Those functions mutate normal Flutter state in `DemoProductivityStore`. A real
caller such as Gemini or another permitted Android agent discovers the
registered AppFunctions through Android and binds the plugin's
`FlutterAppFunctionsService`, which forwards the call to the same Dart handlers
shown in [`lib/main.dart`](lib/main.dart).

## Important model

Your app does not connect directly to Gemini to expose tools. Your app exposes
AppFunctions locally. Android acts as the registry and execution layer. A caller
with the Android `EXECUTE_APP_FUNCTIONS` permission, such as an eligible system
agent, chooses a function id and parameters, then invokes your app.

The screen includes a local "AI caller simulation" so you can see the shape of
that call before you have access to a real AppFunctions caller. It turns a user
prompt into:

```json
{
  "functionId": "createTask",
  "parametersJson": "{\"title\":\"Pick up package\",\"dueDateTime\":\"today 5 PM\"}"
}
```

Then it calls `FlutterAppFunctions.instance.invoke(...)`, which runs the same
registered Dart handler that the Android bridge calls in production.

## Code to copy into a real app

1. Register app functions early in `main()`:

```dart
final demoStore = DemoProductivityStore();
registerProductivityAppFunctions(demoStore);
runApp(MyApp(store: demoStore));
```

2. Add the AppFunctions descriptions to the host app manifest. There is no
   Kotlin to write — the plugin declares its own KSP-generated
   `FlutterAppFunctionsService` and Android binds to it directly:

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

3. Add the strings in `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="appfn_description">com.example.myapp</string>
    <string name="appfn_display_description">My app exposes productivity tools to Android agents.</string>
</resources>
```

4. Set the toolchain floor that `androidx.appfunctions:1.0.0-alpha10`
   requires, in `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 37
    compileSdkMinor = 0
}
```

   Your project also needs Android Gradle plugin `9.1.0`+ and Gradle
   `9.3.1`+. Flutter's default `flutter.compileSdkVersion` is still 36, and
   API 37 ships only as minor-versioned platforms, so both lines above are
   required — see this example's
   [`android/app/build.gradle.kts`](android/app/build.gradle.kts) and
   [`android/settings.gradle.kts`](android/settings.gradle.kts).

> **Upgrading from 0.0.9 or earlier?** Earlier versions needed an
> `Application` subclass extending `FlutterAppFunctionsApplication`, pointed at
> by `<application android:name>`. Both are obsolete — delete them. This
> example no longer contains either.

## Run

```sh
flutter run
```

The AI caller simulation works on any device, including an emulator, because
it calls the Dart handlers in-process.

Real AppFunctions registration needs **Android 16 (API 36) or newer** — below
that the plugin's service is disabled, so the app runs normally but nothing can
discover its functions. On a supported device, verify registration with the
Android AppFunctions command-line tools described in the Android
documentation:

https://developer.android.com/ai/appfunctions

Note that having a real agent invoke your app is gated separately: callers need
the `EXECUTE_APP_FUNCTIONS` permission, and Gemini's AppFunctions integration
is still a private preview for trusted testers. Exposing the functions works
today; being called by the system agent in production requires onboarding
through Google's Early Access Program.
