import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('flutter_app_functions_channel');

  setUp(() {
    FlutterAppFunctions.instance.unregisterAll();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    FlutterAppFunctions.instance.unregisterAll();
  });

  test('getPlatformVersion round-trips through the channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getPlatformVersion') return '42';
      return null;
    });

    expect(await FlutterAppFunctions.instance.getPlatformVersion(), '42');
  });

  test('invokeAppFunction dispatches to a registered handler', () async {
    FlutterAppFunctions.instance.register(
      AppFunctionDefinition(
        id: 'echo',
        description: 'Echoes its input back.',
        parameters: [AppFunctionParameter.string('message')],
        returnType: AppFunctionReturnType.string,
        handler: (context, params) async => params['message'] as String,
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'invokeAppFunction') {
        final args = (call.arguments as Map).cast<String, dynamic>();
        return await FlutterAppFunctions.instance.invoke(
          args['functionId'] as String,
          (jsonDecode(args['parametersJson'] as String) as Map)
              .cast<String, dynamic>(),
        );
      }
      return null;
    });

    final result = await channel.invokeMethod<String>(
      'invokeAppFunction',
      <String, dynamic>{
        'functionId': 'echo',
        'parametersJson': jsonEncode(<String, dynamic>{'message': 'hello'}),
      },
    );
    expect(result, 'hello');
  });

  test('invokeAppFunction surfaces typed error codes as PlatformException',
      () async {
    FlutterAppFunctions.instance.register(
      AppFunctionDefinition(
        id: 'fail',
        description: 'Always fails.',
        returnType: AppFunctionReturnType.voidType,
        handler: (context, params) async {
          throw AppFunctionPermissionRequiredException('nope');
        },
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'invokeAppFunction') {
        final args = (call.arguments as Map).cast<String, dynamic>();
        try {
          return await FlutterAppFunctions.instance.invoke(
            args['functionId'] as String,
            (jsonDecode(args['parametersJson'] as String) as Map)
                .cast<String, dynamic>(),
          );
        } on AppFunctionException catch (e) {
          throw PlatformException(code: e.code, message: e.message);
        }
      }
      return null;
    });

    await expectLater(
      channel.invokeMethod<Object?>(
        'invokeAppFunction',
        <String, dynamic>{
          'functionId': 'fail',
          'parametersJson': '{}',
        },
      ),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'AppFunctionPermissionRequired')
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
  });
}
