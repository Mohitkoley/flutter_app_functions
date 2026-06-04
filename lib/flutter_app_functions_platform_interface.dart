import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_app_functions_method_channel.dart';

abstract class FlutterAppFunctionsPlatform extends PlatformInterface {
  /// Constructs a FlutterAppFunctionsPlatform.
  FlutterAppFunctionsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAppFunctionsPlatform _instance =
      MethodChannelFlutterAppFunctions();

  /// The default instance of [FlutterAppFunctionsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAppFunctions].
  static FlutterAppFunctionsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAppFunctionsPlatform] when
  /// they register themselves.
  static set instance(FlutterAppFunctionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
