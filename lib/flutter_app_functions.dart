/// Public entry point for the Flutter App Functions plugin.
///
/// This package is a 1:1 Flutter wrapper of the Android
/// [AppFunctions](https://developer.android.com/ai/appfunctions) API.
/// It exposes the same concepts (typed parameters, typed return values,
/// typed exceptions) from Dart, and dispatches calls from the agent
/// (e.g. Gemini) to handlers registered in your Flutter app.
///
/// ## Quick start
///
/// ```dart
/// import 'package:flutter/widgets.dart';
/// import 'package:flutter_app_functions/flutter_app_functions.dart';
///
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   FlutterAppFunctions.instance
///     ..register(AppFunctionDefinition(
///       id: 'createTask',
///       description: 'Creates a new task in the user's task list.',
///       parameters: [
///         AppFunctionParameter.string('title'),
///         AppFunctionParameter.optionalString('notes'),
///       ],
///       returnType: AppFunctionReturnType.string,
///       handler: (ctx, params) async {
///         return 'Created task: ${params['title']}';
///       },
///     ));
///
///   runApp(const MyApp());
/// }
/// ```
///
/// Then, in `AndroidManifest.xml` (no Kotlin required):
///
/// ```xml
/// <application
///     appfn:description="@string/appfn_description"
///     appfn:displayDescription="@string/appfn_display_description">
/// ```
library;

export 'src/exceptions.dart';
export 'src/models/app_function_context.dart';
export 'src/models/app_function_definition.dart';
export 'src/models/app_function_parameter.dart';
export 'src/models/app_function_return_type.dart';
export 'src/flutter_app_functions.dart';
