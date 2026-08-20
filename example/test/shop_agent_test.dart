import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app_functions/flutter_app_functions.dart';
import 'package:flutter_app_functions_example/shop_agent.dart';
import 'package:flutter_app_functions_example/shop_demo.dart';

void main() {
  // register() installs a MethodChannel handler, which needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShopStore store;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterAppFunctions.instance.unregisterAll();
    store = ShopStore();
    // Auto-confirm, so the test exercises the agent rather than the sheet.
    ShopConfirmation.handler = (_) async => true;
    attachShopAppFunctions(store);
  });

  tearDown(() {
    ShopConfirmation.handler = null;
    FlutterAppFunctions.instance.unregisterAll();
    debugDefaultTargetPlatformOverride = null;
  });

  Set<String> registeredIds() =>
      FlutterAppFunctions.instance.registeredIds.toSet();

  group('dynamic registration', () {
    test('placeOrder is absent until there is both a cart and an address', () {
      expect(registeredIds(), isNot(contains('placeOrder')));

      store.addToCart(ShopStore.catalog.first, 1);
      expect(registeredIds(), isNot(contains('placeOrder')),
          reason: 'a cart alone is not enough');

      store.setDeliveryAddress('addr_work');
      expect(registeredIds(), contains('placeOrder'));
    });

    test('signing out withdraws the mutating functions', () {
      expect(registeredIds(), contains('addToCart'));

      store.setSignedIn(false);

      expect(registeredIds(), isNot(contains('addToCart')));
      expect(registeredIds(), contains('searchProducts'),
          reason: 'read-only browsing stays available');
    });
  });

  group('agent composition', () {
    test('one prompt chains five primitives and passes ids between them',
        () async {
      final agent = ShopAgent(brain: RuleBasedBrain());

      final run = await agent.run(
        'Order 2 bags of dark roast coffee and send it to my office',
      );

      expect(
        run.steps.map((s) => s.functionId).toList(),
        ['searchProducts', 'addToCart', 'listAddresses', 'setDeliveryAddress',
          'placeOrder'],
      );
      expect(run.steps.every((s) => !s.failed), isTrue,
          reason: run.steps.map((s) => s.error).join(', '));

      // The productId in step 2 came out of step 1's result, and the
      // addressId in step 4 came out of step 3's.
      expect(run.steps[1].arguments['productId'], 'sku_coffee_dark');
      expect(run.steps[1].arguments['quantity'], 2);
      expect(run.steps[3].arguments['addressId'], 'addr_work');

      expect(store.orders, hasLength(1));
      expect(store.orders.single.deliverTo, 'Office');
      expect(store.cart, isEmpty, reason: 'placing an order clears the cart');
    });

    test('a read-only question makes exactly one call', () async {
      final agent = ShopAgent(brain: RuleBasedBrain());

      final run = await agent.run("What's in my cart?");

      expect(run.steps.map((s) => s.functionId).toList(), ['viewCart']);
      expect(store.orders, isEmpty);
    });

    test('a declined confirmation surfaces as a typed error, not a crash',
        () async {
      ShopConfirmation.handler = (_) async => false;
      final agent = ShopAgent(brain: RuleBasedBrain());

      final run = await agent.run('Order a mug and send it to my office');

      final placeOrder =
          run.steps.where((s) => s.functionId == 'placeOrder').single;
      expect(placeOrder.failed, isTrue);
      expect(placeOrder.error, contains('AppFunctionPermissionRequired'));
      expect(store.orders, isEmpty);
    });
  });
}
