import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';
import 'package:flutter_app_functions/flutter_app_functions_platform_interface.dart';
import 'package:flutter_app_functions/flutter_app_functions_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAppFunctionsPlatform
    with MockPlatformInterfaceMixin
    implements FlutterAppFunctionsPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final FlutterAppFunctionsPlatform initialPlatform =
      FlutterAppFunctionsPlatform.instance;

  test('$MethodChannelFlutterAppFunctions is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAppFunctions>());
  });

  test('getPlatformVersion', () async {
    FlutterAppFunctions flutterAppFunctionsPlugin = FlutterAppFunctions();
    MockFlutterAppFunctionsPlatform fakePlatform =
        MockFlutterAppFunctionsPlatform();
    FlutterAppFunctionsPlatform.instance = fakePlatform;

    expect(await flutterAppFunctionsPlugin.getPlatformVersion(), '42');
  });
}
