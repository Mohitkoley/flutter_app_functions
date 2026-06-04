import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_app_functions_platform_interface.dart';
import 'src/flutter_app_functions.dart' show kAppFunctionsChannelName;

/// The [MethodChannel]-backed implementation of
/// [FlutterAppFunctionsPlatform].
class MethodChannelFlutterAppFunctions extends FlutterAppFunctionsPlatform {
  /// The [MethodChannel] used to communicate with the native side.
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel(kAppFunctionsChannelName);

  @override
  Future<String?> getPlatformVersion() async {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
