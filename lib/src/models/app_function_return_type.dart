import 'app_function_parameter.dart';

/// Describes the return shape of an [AppFunctionDefinition].
///
/// A return type of [AppFunctionReturnType.void] signals that the function
/// performs an action but returns no data to the agent. All other return
/// types correspond to scalar values in
/// `androidx.appfunctions.AppFunctionData`.
class AppFunctionReturnType {
  /// The wire-format name of the underlying scalar type, or `null` for
  /// the special `void` return.
  final String? _type;

  const AppFunctionReturnType._(this._type);

  /// The function returns no value.
  static const AppFunctionReturnType voidType = AppFunctionReturnType._(null);

  /// The function returns a UTF-8 string.
  static const AppFunctionReturnType string =
      AppFunctionReturnType._('string');

  /// The function returns a 64-bit signed integer.
  static const AppFunctionReturnType int64 = AppFunctionReturnType._('int64');

  /// The function returns a 64-bit IEEE-754 double.
  static const AppFunctionReturnType double =
      AppFunctionReturnType._('double');

  /// The function returns a boolean.
  static const AppFunctionReturnType boolean =
      AppFunctionReturnType._('bool');

  /// The function returns a list of UTF-8 strings.
  static const AppFunctionReturnType stringList =
      AppFunctionReturnType._('stringList');

  /// `true` if this return type is [voidType].
  bool get isVoid => _type == null;

  /// The corresponding [AppFunctionDataType] for non-void return types.
  AppFunctionDataType? get dataType => AppFunctionDataType.fromWireName(_type);

  /// Serialises this return type to a JSON-compatible map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': _type ?? 'void',
      };

  @override
  String toString() => isVoid
      ? 'AppFunctionReturnType.void'
      : 'AppFunctionReturnType($_type)';
}
