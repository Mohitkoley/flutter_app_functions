/// Typed exceptions that mirror the `androidx.appfunctions` exception
/// hierarchy. When a Dart handler throws one of these, the Flutter
/// AppFunctions bridge translates the error into the matching Android
/// exception type on the Kotlin side.
///
/// The class names match the corresponding
/// `androidx.appfunctions.AppFunction*Exception` classes
/// 1:1 so a developer can search either codebase for the same
/// error.
///
/// See: <https://developer.android.com/ai/appfunctions#errors>
library;

/// Base type for all AppFunction errors raised from a Dart handler.
///
/// The Android bridge maps each concrete subtype to the matching
/// `androidx.appfunctions` exception class.
abstract class AppFunctionException implements Exception {
  /// Human-readable error message describing the failure.
  final String message;

  const AppFunctionException(this.message);

  /// Stable error code shared with the Android bridge. Subclasses return
  /// the corresponding `AppFunction*Exception` simple name (matching the
  /// Kotlin class name minus the `Exception` suffix).
  String get code;

  @override
  String toString() => '$code: $message';
}

/// Thrown when one or more arguments passed to a function are invalid.
///
/// Maps to `androidx.appfunctions.AppFunctionInvalidArgumentException`.
class AppFunctionInvalidArgumentException extends AppFunctionException {
  const AppFunctionInvalidArgumentException(super.message);

  @override
  String get code => 'AppFunctionInvalidArgument';
}

/// Thrown when a referenced element does not exist.
///
/// Maps to `androidx.appfunctions.AppFunctionElementNotFoundException`.
class AppFunctionElementNotFoundException extends AppFunctionException {
  const AppFunctionElementNotFoundException(super.message);

  @override
  String get code => 'AppFunctionElementNotFound';
}

/// Thrown when the agent requests a function that has not been registered
/// on the Dart side.
///
/// Maps to `androidx.appfunctions.AppFunctionFunctionNotFoundException`.
class AppFunctionFunctionNotFoundException extends AppFunctionException {
  /// The function ID that could not be resolved.
  final String functionId;

  const AppFunctionFunctionNotFoundException(this.functionId)
      : super('App function not registered: $functionId');

  @override
  String get code => 'AppFunctionFunctionNotFound';
}

/// Thrown when the requested operation is not supported by the underlying
/// app or platform.
///
/// Maps to `androidx.appfunctions.AppFunctionNotSupportedException`.
class AppFunctionNotSupportedException extends AppFunctionException {
  const AppFunctionNotSupportedException(super.message);

  @override
  String get code => 'AppFunctionNotSupported';
}

/// Thrown when the calling user or app does not have the permission
/// required to invoke the function.
///
/// Maps to `androidx.appfunctions.AppFunctionPermissionRequiredException`.
class AppFunctionPermissionRequiredException extends AppFunctionException {
  const AppFunctionPermissionRequiredException(super.message);

  @override
  String get code => 'AppFunctionPermissionRequired';
}

/// Thrown when the AppFunctions system is disabled, unavailable, or has
/// no usable bridge to the Flutter engine.
///
/// Maps to `androidx.appfunctions.AppFunctionDisabledException` on the
/// Kotlin side.
class AppFunctionDisabledException extends AppFunctionException {
  const AppFunctionDisabledException(super.message);

  @override
  String get code => 'AppFunctionDisabled';
}

/// Catch-all for any other internal failure that occurs inside a Dart
/// handler.
///
/// Maps to `androidx.appfunctions.AppFunctionAppUnknownException`.
class AppFunctionAppUnknownException extends AppFunctionException {
  /// Optional underlying cause for diagnostic purposes.
  final Object? cause;

  const AppFunctionAppUnknownException(super.message, {this.cause});

  @override
  String get code => 'AppFunctionAppUnknown';

  @override
  String toString() =>
      cause == null ? super.toString() : '$code: $message (caused by: $cause)';
}
