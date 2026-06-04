import 'flutter_app_functions_platform_interface.dart';
import 'package:flutter/services.dart';

typedef ToolHandler =
    Future<String> Function(String toolName, String parametersJson);

class FlutterAppFunctions {
  // Private constructor
  FlutterAppFunctions._internal() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<String?> getPlatformVersion() {
    return FlutterAppFunctionsPlatform.instance.getPlatformVersion();
  }

  factory FlutterAppFunctions() {
    return instance;
  }

  // Singleton Instance
  static final FlutterAppFunctions instance = FlutterAppFunctions._internal();

  final MethodChannel _channel = const MethodChannel(
    'flutter_app_functions_channel',
  );
  ToolHandler? _registeredHandler;

  /// Registers the main processing handler to intercept agent tool executions.
  void registerToolHandler(ToolHandler handler) {
    _registeredHandler = handler;
  }

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'onInvokeAgentTool':
        final Map<dynamic, dynamic> arguments =
            call.arguments as Map<dynamic, dynamic>;
        final String toolName = arguments['toolName'] as String;
        final String parametersJson = arguments['parametersJson'] as String;

        if (_registeredHandler != null) {
          try {
            return await _registeredHandler!(toolName, parametersJson);
          } catch (e) {
            return 'Dart Exception: ${e.toString()}';
          }
        }
        return 'Error: No Dart Tool Handlers registered.';
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'flutter_app_functions: Method ${call.method} not implemented.',
        );
    }
  }
}
