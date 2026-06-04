import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_app_functions_method_channel.dart';

/// The platform interface for the Flutter App Functions plugin.
///
/// Concrete platform implementations (e.g. the bundled
/// [MethodChannelFlutterAppFunctions]) extend this class and register
/// themselves as the [FlutterAppFunctionsPlatform.instance].
abstract class FlutterAppFunctionsPlatform extends PlatformInterface {
  /// Constructs a [FlutterAppFunctionsPlatform].
  FlutterAppFunctionsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAppFunctionsPlatform _instance =
      MethodChannelFlutterAppFunctions();

  /// The default instance of [FlutterAppFunctionsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAppFunctions].
  static FlutterAppFunctionsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAppFunctionsPlatform]
  /// when they register themselves.
  static set instance(FlutterAppFunctionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the Android version string, or `null` on non-Android
  /// platforms.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
