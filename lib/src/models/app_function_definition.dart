import 'app_function_context.dart';
import 'app_function_parameter.dart';
import 'app_function_return_type.dart';

/// Signature implemented by every Flutter-side app function handler.
///
/// The [parameters] map is the validated, type-coerced view of the
/// `AppFunctionData` payload that the agent sent. The return value must
/// match the [AppFunctionDefinition.returnType] contract.
typedef AppFunctionHandler = Future<dynamic> Function(
  AppFunctionContext context,
  Map<String, dynamic> parameters,
);

/// Declarative description of a single Dart-registered app function.
///
/// Each instance corresponds to one function exposed to the Android
/// AppFunctions ecosystem. The bridge holds a single `@AppFunction` that
/// dispatches by `id` to the Dart handler in [handler].
///
/// All fields except [parameters] and [returnType] are required. The
/// [description] and per-parameter [AppFunctionParameter.description]
/// strings are surfaced to the agent, so they should be KDoc-style
/// documentation of the behaviour, parameters, and constraints.
class AppFunctionDefinition {
  /// The unique identifier of the function. Must match the ID the agent
  /// uses when calling the function (e.g. `createTask`).
  final String id;

  /// KDoc-style description of the function, surfaced to the agent.
  final String description;

  /// The function's parameter list, in declaration order. May be empty
  /// for parameter-less functions.
  final List<AppFunctionParameter> parameters;

  /// The function's return type. Defaults to [AppFunctionReturnType.void]
  /// for action-style functions.
  final AppFunctionReturnType returnType;

  /// The Dart handler invoked when the function is called.
  final AppFunctionHandler handler;

  const AppFunctionDefinition({
    required this.id,
    required this.description,
    this.parameters = const [],
    this.returnType = AppFunctionReturnType.voidType,
    required this.handler,
  });

  /// Serialises this definition to a JSON-compatible map for the
  /// Dart↔Kotlin protocol.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'description': description,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'returnType': returnType.toJson(),
      };

  @override
  String toString() =>
      'AppFunctionDefinition(id: $id, parameters: ${parameters.length}, returnType: $returnType)';
}
