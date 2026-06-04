import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_app_functions_platform_interface.dart';

/// An implementation of [FlutterAppFunctionsPlatform] that uses method channels.
class MethodChannelFlutterAppFunctions extends FlutterAppFunctionsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_app_functions_channel');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
