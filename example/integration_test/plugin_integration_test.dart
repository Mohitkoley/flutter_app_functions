// Integration test for the flutter_app_functions plugin.
//
// Boots the plugin, registers two sample functions, exercises the method
// channel from the host side, and verifies that typed error codes round-trip
// back to the host.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('flutter_app_functions_channel');

  setUp(() {
    FlutterAppFunctions.instance.unregisterAll();
  });

  tearDown(() {
    FlutterAppFunctions.instance.unregisterAll();
  });

  testWidgets('getPlatformVersion', (WidgetTester tester) async {
    final String? version = await FlutterAppFunctions.instance.getPlatformVersion();
    expect(version?.isNotEmpty, true);
  });

  testWidgets('invokeAppFunction echoes a string parameter', (WidgetTester tester) async {
    FlutterAppFunctions.instance.register(
      AppFunctionDefinition(
        id: 'echo',
        description: 'Echoes its input back.',
        parameters: [AppFunctionParameter.string('message')],
        returnType: AppFunctionReturnType.string,
        handler: (context, params) async => params['message'] as String,
      ),
    );

    final result = await channel.invokeMethod<String>(
      'invokeAppFunction',
      <String, dynamic>{
        'functionId': 'echo',
        'parametersJson': jsonEncode(<String, dynamic>{'message': 'integration'}),
      },
    );
    expect(result, 'integration');
  });

  testWidgets('invokeAppFunction surfaces a typed error code', (WidgetTester tester) async {
    FlutterAppFunctions.instance.register(
      AppFunctionDefinition(
        id: 'forbidden',
        description: 'Always throws a permission-required error.',
        returnType: AppFunctionReturnType.voidType,
        handler: (context, params) async {
          throw AppFunctionPermissionRequiredException('blocked');
        },
      ),
    );

    await expectLater(
      channel.invokeMethod<Object?>(
        'invokeAppFunction',
        <String, dynamic>{
          'functionId': 'forbidden',
          'parametersJson': '{}',
        },
      ),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'AppFunctionPermissionRequired')
            .having((e) => e.message, 'message', 'blocked'),
      ),
    );
  });
}
