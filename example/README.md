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
registered AppFunctions through Android and executes the Kotlin bridge. The
bridge forwards the call to the same Dart handlers shown in
[`lib/main.dart`](lib/main.dart).

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
final store = DemoProductivityStore();
registerProductivityAppFunctions(store);
runApp(MyApp(store: store));
```

2. Create an Android `Application` class in your app module:

```kotlin
package com.example.myapp

import com.mohitkoley.flutter_app_functions.FlutterAppFunctionsApplication

class MyApplication : FlutterAppFunctionsApplication()
```

3. Point the host app manifest at it and add AppFunctions descriptions:

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

4. Add the strings in `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="appfn_description">com.example.myapp</string>
    <string name="appfn_display_description">My app exposes productivity tools to Android agents.</string>
</resources>
```

## Run

```sh
flutter run
```

On a supported Android device, verify registration with the Android
AppFunctions command-line tools described in the Android documentation:

https://developer.android.com/ai/appfunctions
