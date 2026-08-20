# flutter_app_functions example

This example shows the app-side code you write when your Flutter app wants to
behave like an on-device MCP tool provider through Android AppFunctions.

It contains **two demos**, on separate tabs, because they teach different
things.

### 1. Productivity — one prompt, one function

Registers `createTask`, `addItemsToShoppingList`, `completeTask` and
`summarizeToday`. Each prompt maps to a single app function. This is the
simplest shape and the one most people picture first.

### 2. Shop — one prompt, a *chain* of functions

Registers small e-commerce primitives: `searchProducts`, `addToCart`,
`viewCart`, `removeFromCart`, `listAddresses`, `setDeliveryAddress`,
`applyCoupon`, `placeOrder`.

There is deliberately **no** `doCheckout()` mega-function. Ask it:

> Order 2 bags of dark roast coffee and send it to my office

and the agent composes five calls, feeding ids from each result into the next:

```
searchProducts(query: "coffee")        -> [{productId: sku_coffee_dark, ...}]
addToCart(productId: sku_coffee_dark, quantity: 2)
listAddresses()                        -> [{addressId: addr_work, label: Office}]
setDeliveryAddress(addressId: addr_work)
placeOrder()                           -> Order ord_1001 placed
```

Nobody wrote that sequence. It is composed at run time from the intent. That
is the whole reason to expose many small primitives instead of one big one:
the agent can also answer "what's in my cart?" with a single `viewCart`, and
can recover when a step fails.

Two more things the Shop tab demonstrates:

* **Registration is dynamic, not a compile-time list.** `placeOrder` is not
  registered at all until the cart is non-empty *and* an address is set, and
  signing out withdraws every mutating function. The "Registered right now"
  panel updates live — toggle the sign-in switch and watch it change. See
  `attachShopAppFunctions` in [`lib/shop_demo.dart`](lib/shop_demo.dart).
* **The agent never spends money unattended.** `placeOrder` shows a real
  confirmation sheet; declining raises
  `AppFunctionPermissionRequiredException`, which the agent sees as a typed
  failure rather than a crash.

The agent loop itself is about twenty lines in
[`lib/shop_agent.dart`](lib/shop_agent.dart): ask the brain what to call,
invoke it, feed the result back, repeat. `RuleBasedBrain` keeps the demo
runnable with no API key; `LlmBrain` in the same file is the seam where a real
model plugs in — `AppFunctionDefinition.toJson()` already emits the tool-schema
shape that tool-calling APIs expect, so the loop itself does not change.

Both demos mutate ordinary Flutter state through `ChangeNotifier`, so the UI
updates the moment the agent changes something. A real caller such as Gemini
or another permitted Android agent discovers the registered AppFunctions
through Android and binds the plugin's `FlutterAppFunctionsService`, which
forwards the call to these same Dart handlers.

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
