# flutter_app_functions

Flutter plugin for exposing Android App Functions that can call back into Dart
tool handlers through a method channel.

The Android side registers an App Function named `executeDartTool`. When the
function is invoked on-device, the plugin forwards the requested tool name and
JSON parameters to Dart. Your app registers one Dart handler and returns a
string result.

## Platform support

- Android only
- Minimum Android SDK: 24
- Android compile SDK: 36
- AndroidX AppFunctions: 1.0.0-alpha08
- Flutter SDK with Dart 3.12.0 or newer

## Installation

Add the package to your app:

```yaml
dependencies:
  flutter_app_functions: ^0.0.1
```

For local development, use a path dependency that points to this package.

## Usage

Initialize Flutter bindings before registering handlers, then register a tool
handler early in app startup:

```dart
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterAppFunctions.instance.registerToolHandler((
    String toolName,
    String parametersJson,
  ) async {
    if (toolName == 'create_task') {
      final data = jsonDecode(parametersJson) as Map<String, dynamic>;
      final title = data['title'] as String? ?? 'Untitled Task';
      return 'Created task: $title';
    }

    return 'Unknown tool: $toolName';
  });

  runApp(const MyApp());
}
```

You can still call the generated platform-version method:

```dart
final version = await FlutterAppFunctions().getPlatformVersion();
```

## Android App Function

The native Android implementation exposes:

```kotlin
suspend fun executeDartTool(
    context: AppFunctionContext,
    toolName: String,
    parametersJson: String
): String
```

`parametersJson` should be a JSON object string. The Dart handler is responsible
for parsing and validating the data.

## Example

Run the bundled example app from the `example` directory:

```sh
cd example
flutter run
```

The example registers a `create_task` handler and displays a listener status
screen while waiting for on-device App Function calls.

## Testing

Run package analysis and tests from the package root:

```sh
flutter analyze
flutter test
```

Run Android unit tests through the example app Gradle project:

```sh
cd example/android
./gradlew testDebugUnitTest
```
