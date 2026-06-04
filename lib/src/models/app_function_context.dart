/// The context in which an [AppFunctionDefinition] handler is invoked.
///
/// Mirrors the contract of `androidx.appfunctions.AppFunctionContext` on
/// the Android side. Only the parts that are meaningful across the
/// Dart↔Kotlin bridge are exposed: the function ID and the underlying
/// raw parameter map.
class AppFunctionContext {
  /// The unique identifier of the function being invoked.
  final String functionId;

  /// The raw `AppFunctionData` payload sent by the agent, converted to a
  /// `Map<String, dynamic>` by the bridge.
  ///
  /// Handlers should normally rely on the typed [parameters] argument
  /// that the [AppFunctionDefinition] receives; this field is provided
  /// for advanced access (e.g. when a function accepts arbitrary keys).
  final Map<String, dynamic> rawParameters;

  const AppFunctionContext({
    required this.functionId,
    required this.rawParameters,
  });

  @override
  String toString() =>
      'AppFunctionContext(functionId: $functionId, params: ${rawParameters.keys.toList()})';
}
