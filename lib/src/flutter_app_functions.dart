import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../flutter_app_functions_platform_interface.dart';
import 'exceptions.dart';
import 'models/app_function_context.dart';
import 'models/app_function_definition.dart';
import 'registry.dart';

/// The wire-format name of the [MethodChannel] used by the plugin.
const String kAppFunctionsChannelName = 'flutter_app_functions_channel';

/// The method invoked from Android when the agent calls a registered
/// function. Arguments: `{"functionId": String, "parametersJson": String}`.
const String _kMethodInvokeAppFunction = 'invokeAppFunction';

/// Fails fast with [AppFunctionPlatformNotSupportedException] when the
/// plugin is used on a platform other than Android. Local-only
/// operations (registry CRUD, channel handler installation) do not call
/// this; any public API that could touch native code does.
void _assertAndroid() {
  if (defaultTargetPlatform != TargetPlatform.android) {
    throw AppFunctionPlatformNotSupportedException(
      defaultTargetPlatform.name,
    );
  }
}

/// Public entry point of the Flutter App Functions plugin.
///
/// Mirrors the surface of `androidx.appfunctions` for Flutter apps:
///
/// * Register typed [AppFunctionDefinition]s in Dart that the agent can
///   invoke through the on-device AppFunctions system.
/// * Throwing one of the typed [AppFunctionException] subtypes from a
///   handler is mapped to the matching Android exception class on the
///   Kotlin side.
///
/// Typical lifecycle in `main()`:
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   FlutterAppFunctions.instance
///     ..register(AppFunctionDefinition(
///         id: 'createTask',
///         description: 'Creates a new task.',
///         parameters: [
///           AppFunctionParameter.string('title'),
///           AppFunctionParameter.optionalString('notes'),
///         ],
///         returnType: AppFunctionReturnType.string,
///         handler: (ctx, params) async {
///           return 'Created: ${params['title']}';
///         }))
///     ..register(/* ...more functions... */);
///
///   runApp(const MyApp());
/// }
/// ```
///
/// The plugin's `AndroidManifest.xml` already declares the
/// `appfunctions:APP_FUNCTION_SERVICE` permission, the `appfn:description`
/// attributes, and the `<property android:name="android.app.appfunctions.app_metadata">`
/// entry that the Android AppFunctions system reads at startup. To plug
/// the bridge into a host Android app, extend
/// [FlutterAppFunctionsApplication] (or implement
/// `AppFunctionConfiguration.Provider` directly) and set
/// `android:name=".MyApplication"` in the host's `AndroidManifest.xml`.
class FlutterAppFunctions {
  FlutterAppFunctions._();

  /// The global plugin instance.
  static final FlutterAppFunctions instance = FlutterAppFunctions._();

  final MethodChannel _channel = const MethodChannel(kAppFunctionsChannelName);
  final AppFunctionRegistry _registry = AppFunctionRegistry();

  bool _handlerInstalled = false;

  /// The set of [AppFunctionDefinition]s currently registered. The
  /// returned iterable is a live view in insertion order.
  Iterable<AppFunctionDefinition> get definitions => _registry.definitions;

  /// The IDs of every registered definition, in insertion order.
  Iterable<String> get registeredIds => _registry.ids;

  /// The number of registered definitions.
  int get length => _registry.length;

  /// Registers a single [definition]. If a definition with the same
  /// [AppFunctionDefinition.id] already exists it is replaced.
  ///
  /// Throws [AppFunctionPlatformNotSupportedException] on non-Android
  /// platforms.
  ///
  /// This method also implicitly calls [ensureInitialized] so that
  /// method-channel invocations from Kotlin are routed here as soon as
  /// possible after [runApp].
  void register(AppFunctionDefinition definition) {
    _assertAndroid();
    ensureInitialized();
    _registry.register(definition);
  }

  /// Registers every definition in [definitions]. See [register].
  void registerAll(Iterable<AppFunctionDefinition> definitions) {
    for (final d in definitions) {
      register(d);
    }
  }

  /// Unregisters the definition with the given [id], if any.
  void unregister(String id) {
    _registry.unregister(id);
  }

  /// Unregisters every definition. Useful in tests.
  void unregisterAll() {
    _registry.clear();
  }

  /// Installs the [MethodChannel] handler. Idempotent: subsequent calls
  /// are no-ops.
  ///
  /// [register] calls this implicitly, so most apps never need to invoke
  /// it directly. It is exposed for advanced setups where the host wants
  /// to wire the channel before any definition is registered (for
  /// example, to surface registration calls back from native code).
  ///
  /// This is a local-only operation and does not throw on non-Android
  /// platforms; the [register] / [invoke] / [getPlatformVersion] entry
  /// points are the ones that fail fast.
  void ensureInitialized() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler(_onMethodCall);
  }

  /// Returns the underlying [MethodChannel]. Exposed primarily for tests
  /// that need to install mock handlers without going through
  /// [ensureInitialized].
  @visibleForTesting
  MethodChannel get channel => _channel;

  /// Asks the platform for the Android version string. Kept for
  /// backwards-compat with the previous `getPlatformVersion` API.
  ///
  /// Throws [AppFunctionPlatformNotSupportedException] on non-Android
  /// platforms.
  Future<String?> getPlatformVersion() {
    _assertAndroid();
    return FlutterAppFunctionsPlatform.instance.getPlatformVersion();
  }

  /// Invokes a registered function by [id], bypassing the method
  /// channel. Primarily useful for tests and for in-process calls from
  /// other Dart code. Typed [AppFunctionException]s thrown by the handler
  /// propagate to the caller unchanged; the [PlatformException] wrapping
  /// only happens on the MethodChannel path.
  ///
  /// Throws [AppFunctionPlatformNotSupportedException] on non-Android
  /// platforms before the registry is consulted.
  Future<dynamic> invoke(
    String id, [
    Map<String, dynamic> parameters = const <String, dynamic>{},
  ]) async {
    _assertAndroid();
    try {
      return await _invokeInProcess(id, parameters);
    } on AppFunctionException {
      rethrow;
    } catch (e) {
      throw AppFunctionAppUnknownException(e.toString(), cause: e);
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case _kMethodInvokeAppFunction:
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final id = args['functionId'] as String?;
        final parametersJson = args['parametersJson'] as String? ?? '{}';
        if (id == null || id.isEmpty) {
          throw PlatformException(
            code: 'AppFunctionInvalidArgument',
            message: 'Missing "functionId" argument.',
          );
        }
        try {
          final result = await _invokeInProcess(
            id,
            _decodeParametersJson(parametersJson),
          );
          return _encodeResultJson(result);
        } on AppFunctionException catch (e) {
          throw PlatformException(code: e.code, message: e.message);
        } catch (e, st) {
          throw PlatformException(
            code: 'AppFunctionAppUnknown',
            message: e.toString(),
            details: st.toString(),
          );
        }
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'flutter_app_functions: Method ${call.method} not implemented.',
        );
    }
  }

  Map<String, dynamic> _decodeParametersJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw AppFunctionInvalidArgumentException(
          'parametersJson must decode to a JSON object, got ${decoded.runtimeType}.',
        );
      }
      return decoded.cast<String, dynamic>();
    } on FormatException catch (e) {
      throw AppFunctionInvalidArgumentException(
        'parametersJson is not valid JSON: ${e.message}',
      );
    }
  }

  String _encodeResultJson(Object? result) {
    if (result == null) return 'null';
    if (result is String ||
        result is num ||
        result is bool ||
        result is List ||
        result is Map) {
      return jsonEncode(result);
    }
    throw AppFunctionAppUnknownException(
      'Return value of type ${result.runtimeType} cannot be JSON-encoded. '
      'Supported: String, num, bool, List, Map, null.',
    );
  }

  Future<dynamic> _invokeInProcess(
    String id,
    Map<String, dynamic> rawParameters,
  ) async {
    final definition = _registry.find(id);
    if (definition == null) {
      throw AppFunctionFunctionNotFoundException(
        'No app function registered with id: $id',
      );
    }
    final parameters =
        AppFunctionRegistry.validateAndCoerce(definition, rawParameters);
    final context = AppFunctionContext(
      functionId: id,
      rawParameters: parameters,
    );
    return await definition.handler(context, parameters);
  }
}
