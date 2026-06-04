import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';
import 'package:flutter_app_functions/flutter_app_functions_method_channel.dart';
import 'package:flutter_app_functions/flutter_app_functions_platform_interface.dart';
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

  setUp(() {
    FlutterAppFunctions.instance.unregisterAll();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    FlutterAppFunctions.instance.unregisterAll();
  });

  test('$MethodChannelFlutterAppFunctions is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAppFunctions>());
  });

  test('getPlatformVersion uses the platform interface', () async {
    final fakePlatform = MockFlutterAppFunctionsPlatform();
    FlutterAppFunctionsPlatform.instance = fakePlatform;
    expect(await FlutterAppFunctions.instance.getPlatformVersion(), '42');
    FlutterAppFunctionsPlatform.instance = initialPlatform;
  });

  group('register + invoke', () {
    test('invokes a registered string-returning function', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'echo',
          description: 'Echoes its input back.',
          parameters: [AppFunctionParameter.string('message')],
          returnType: AppFunctionReturnType.string,
          handler: (context, params) async {
            return params['message'] as String;
          },
        ),
      );

      final result = await FlutterAppFunctions.instance.invoke(
        'echo',
        <String, dynamic>{'message': 'hello'},
      );
      expect(result, 'hello');
    });

    test('returns null for void-returning functions', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'doNothing',
          description: 'Returns nothing.',
          returnType: AppFunctionReturnType.voidType,
          handler: (context, params) async {},
        ),
      );

      final result = await FlutterAppFunctions.instance.invoke('doNothing');
      expect(result, isNull);
    });

    test('returns int64 as int', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'count',
          description: 'Counts active tasks.',
          returnType: AppFunctionReturnType.int64,
          handler: (context, params) async => 7,
        ),
      );

      final result = await FlutterAppFunctions.instance.invoke('count');
      expect(result, 7);
    });

    test('returns List<String> for stringList return type', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'list',
          description: 'Returns a list of strings.',
          returnType: AppFunctionReturnType.stringList,
          handler: (context, params) async => <String>['a', 'b'],
        ),
      );

      final result = await FlutterAppFunctions.instance.invoke('list');
      expect(result, <String>['a', 'b']);
    });
  });

  group('registry validation', () {
    test('throws AppFunctionInvalidArgument for missing required param',
        () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'greet',
          description: 'Greets the user.',
          parameters: [AppFunctionParameter.string('name')],
          returnType: AppFunctionReturnType.string,
          handler: (context, params) async => 'hi ${params['name']}',
        ),
      );

      expect(
        () => FlutterAppFunctions.instance.invoke('greet'),
        throwsA(isA<AppFunctionInvalidArgumentException>()),
      );
    });

    test('throws AppFunctionInvalidArgument for wrong type', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'greet',
          description: 'Greets the user.',
          parameters: [AppFunctionParameter.string('name')],
          returnType: AppFunctionReturnType.string,
          handler: (context, params) async => 'hi',
        ),
      );

      expect(
        () => FlutterAppFunctions.instance
            .invoke('greet', <String, dynamic>{'name': 123}),
        throwsA(isA<AppFunctionInvalidArgumentException>()),
      );
    });

    test('throws AppFunctionInvalidArgument for unknown parameter', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'greet',
          description: 'Greets the user.',
          parameters: [AppFunctionParameter.string('name')],
          returnType: AppFunctionReturnType.string,
          handler: (context, params) async => 'hi',
        ),
      );

      expect(
        () => FlutterAppFunctions.instance.invoke(
          'greet',
          <String, dynamic>{'name': 'Ada', 'extra': 'oops'},
        ),
        throwsA(isA<AppFunctionInvalidArgumentException>()),
      );
    });

    test('throws AppFunctionInvalidArgument for enum violation', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'search',
          description: 'Search contacts.',
          parameters: [
            AppFunctionParameter.string(
              'filterType',
              enumValues: ['INDIVIDUAL', 'GROUP'],
            ),
          ],
          returnType: AppFunctionReturnType.stringList,
          handler: (context, params) async => <String>[],
        ),
      );

      expect(
        () => FlutterAppFunctions.instance.invoke(
          'search',
          <String, dynamic>{'filterType': 'BOGUS'},
        ),
        throwsA(isA<AppFunctionInvalidArgumentException>()),
      );
    });

    test('throws AppFunctionNotFound for unknown functionId', () async {
      expect(
        () => FlutterAppFunctions.instance.invoke('notRegistered'),
        throwsA(isA<AppFunctionFunctionNotFoundException>()),
      );
    });
  });

  group('handler-thrown exceptions', () {
    test('preserves AppFunctionException subtype across invoke()', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'fail',
          description: 'Always fails.',
          returnType: AppFunctionReturnType.voidType,
          handler: (context, params) async {
            throw AppFunctionPermissionRequiredException('not allowed');
          },
        ),
      );

      expect(
        () => FlutterAppFunctions.instance.invoke('fail'),
        throwsA(
          isA<AppFunctionPermissionRequiredException>()
              .having((e) => e.message, 'message', 'not allowed'),
        ),
      );
    });

    test('wraps unknown errors as AppFunctionAppUnknownException', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'buggy',
          description: 'Has a bug.',
          returnType: AppFunctionReturnType.voidType,
          handler: (context, params) async {
            throw StateError('boom');
          },
        ),
      );

      expect(
        () => FlutterAppFunctions.instance.invoke('buggy'),
        throwsA(isA<AppFunctionAppUnknownException>()),
      );
    });
  });

  group('registry CRUD', () {
    test('unregister removes a function', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'a',
          description: 'A',
          returnType: AppFunctionReturnType.voidType,
          handler: (_, _) async {},
        ),
      );
      expect(FlutterAppFunctions.instance.length, 1);
      FlutterAppFunctions.instance.unregister('a');
      expect(FlutterAppFunctions.instance.length, 0);
    });
  });

  group('platform support', () {
    test(
        'register throws AppFunctionPlatformNotSupportedException on iOS '
        'and leaves the registry empty', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        () => FlutterAppFunctions.instance.register(
          AppFunctionDefinition(
            id: 'a',
            description: 'A',
            returnType: AppFunctionReturnType.voidType,
            handler: (_, _) async {},
          ),
        ),
        throwsA(
          isA<AppFunctionPlatformNotSupportedException>()
              .having((e) => e.platform, 'platform', 'iOS')
              .having(
                (e) => e.message,
                'message',
                contains('flutter_app_functions is Android-only'),
              ),
        ),
      );
      expect(FlutterAppFunctions.instance.length, 0);
    });

    test(
        'invoke throws on iOS even when a function with the given id was '
        'previously registered on Android', () async {
      FlutterAppFunctions.instance.register(
        AppFunctionDefinition(
          id: 'a',
          description: 'A',
          returnType: AppFunctionReturnType.voidType,
          handler: (_, _) async {},
        ),
      );
      expect(FlutterAppFunctions.instance.length, 1);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(
        () => FlutterAppFunctions.instance.invoke('a'),
        throwsA(isA<AppFunctionPlatformNotSupportedException>()),
      );
    });

    test('getPlatformVersion throws on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(
        () => FlutterAppFunctions.instance.getPlatformVersion(),
        throwsA(
          isA<AppFunctionPlatformNotSupportedException>()
              .having((e) => e.platform, 'platform', 'iOS'),
        ),
      );
    });

    test(
        'local-only operations (unregister, unregisterAll, ensureInitialized) '
        'are no-ops on non-Android platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(() => FlutterAppFunctions.instance.unregister('anything'),
          returnsNormally);
      expect(() => FlutterAppFunctions.instance.unregisterAll(),
          returnsNormally);
      expect(() => FlutterAppFunctions.instance.ensureInitialized(),
          returnsNormally);
    });

    test('registerAll propagates the platform error from the first call', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        () => FlutterAppFunctions.instance.registerAll([
          AppFunctionDefinition(
            id: 'a',
            description: 'A',
            returnType: AppFunctionReturnType.voidType,
            handler: (_, _) async {},
          ),
        ]),
        throwsA(
          isA<AppFunctionPlatformNotSupportedException>()
              .having((e) => e.platform, 'platform', 'macOS'),
        ),
      );
    });
  });
}
