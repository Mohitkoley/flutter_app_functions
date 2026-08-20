import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

/// A small e-commerce demo showing the pattern that matters most with
/// AppFunctions: you expose a handful of *small, composable* primitives, and
/// the agent decides which ones to call and in what order.
///
/// There is deliberately no `checkout()` mega-function here. A request like
/// "order another bag of the coffee and send it to my office" is satisfied by
/// the agent chaining `searchProducts` -> `addToCart` -> `listAddresses` ->
/// `setDeliveryAddress` -> `placeOrder`. Nobody wrote that sequence; it is
/// composed at run time from the intent.

// ---------------------------------------------------------------------------
// Domain
// ---------------------------------------------------------------------------

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.keywords,
  });

  final String id;
  final String name;
  final double price;
  final List<String> keywords;

  Map<String, dynamic> toJson() => {
    'productId': id,
    'name': name,
    'price': price,
  };
}

class CartLine {
  CartLine({required this.product, required this.quantity});

  final Product product;
  int quantity;

  double get lineTotal => product.price * quantity;

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'name': product.name,
    'quantity': quantity,
    'lineTotal': lineTotal,
  };
}

class Address {
  const Address({required this.id, required this.label, required this.line});

  final String id;
  final String label;
  final String line;

  Map<String, dynamic> toJson() => {
    'addressId': id,
    'label': label,
    'address': line,
  };
}

class Order {
  const Order({
    required this.id,
    required this.total,
    required this.deliverTo,
    required this.lines,
  });

  final String id;
  final double total;
  final String deliverTo;
  final List<String> lines;
}

/// Ordinary Flutter app state. The agent mutates exactly this, through the
/// same handlers, so the UI updates through the normal [ChangeNotifier] path.
class ShopStore extends ChangeNotifier {
  ShopStore();

  static const List<Product> catalog = [
    Product(
      id: 'sku_coffee_dark',
      name: 'Dark Roast Coffee Beans 1kg',
      price: 840,
      keywords: ['coffee', 'beans', 'dark', 'roast'],
    ),
    Product(
      id: 'sku_coffee_filter',
      name: 'Filter Coffee Powder 500g',
      price: 380,
      keywords: ['coffee', 'filter', 'powder'],
    ),
    Product(
      id: 'sku_mug',
      name: 'Ceramic Mug 350ml',
      price: 450,
      keywords: ['mug', 'cup', 'ceramic'],
    ),
    Product(
      id: 'sku_kettle',
      name: 'Pour Over Kettle',
      price: 2400,
      keywords: ['kettle', 'pour', 'over', 'gooseneck'],
    ),
  ];

  final List<Address> addresses = const [
    Address(id: 'addr_home', label: 'Home', line: '12 Nehru Road, Pune'),
    Address(id: 'addr_work', label: 'Office', line: 'Tower B, Baner, Pune'),
  ];

  final List<CartLine> cart = [];
  final List<Order> orders = [];

  bool isSignedIn = true;
  String? deliveryAddressId;
  String? coupon;

  double get subtotal =>
      cart.fold<double>(0, (sum, line) => sum + line.lineTotal);

  double get discount => coupon == null ? 0 : subtotal * 0.10;

  double get total => subtotal - discount;

  Address? get deliveryAddress {
    if (deliveryAddressId == null) return null;
    for (final a in addresses) {
      if (a.id == deliveryAddressId) return a;
    }
    return null;
  }

  /// True when an order could actually be placed right now. Drives whether
  /// `placeOrder` is registered at all.
  bool get canPlaceOrder => cart.isNotEmpty && deliveryAddress != null;

  List<Product> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    return catalog.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      return p.keywords.any((k) => q.contains(k));
    }).toList();
  }

  Product? productById(String id) {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addToCart(Product product, int quantity) {
    for (final line in cart) {
      if (line.product.id == product.id) {
        line.quantity += quantity;
        notifyListeners();
        return;
      }
    }
    cart.add(CartLine(product: product, quantity: quantity));
    notifyListeners();
  }

  bool removeFromCart(String productId) {
    final before = cart.length;
    cart.removeWhere((line) => line.product.id == productId);
    final removed = cart.length != before;
    if (removed) notifyListeners();
    return removed;
  }

  void setDeliveryAddress(String addressId) {
    deliveryAddressId = addressId;
    notifyListeners();
  }

  void applyCoupon(String code) {
    coupon = code;
    notifyListeners();
  }

  void setSignedIn(bool value) {
    isSignedIn = value;
    if (!value) {
      cart.clear();
      deliveryAddressId = null;
      coupon = null;
    }
    notifyListeners();
  }

  Order placeOrder() {
    final order = Order(
      id: 'ord_${orders.length + 1001}',
      total: total,
      deliverTo: deliveryAddress!.label,
      lines: cart.map((l) => '${l.quantity} x ${l.product.name}').toList(),
    );
    orders.insert(0, order);
    cart.clear();
    coupon = null;
    notifyListeners();
    return order;
  }
}

// ---------------------------------------------------------------------------
// App functions
// ---------------------------------------------------------------------------

/// Every id this demo owns. Used to unregister only its own functions, since
/// [FlutterAppFunctions.instance] is a process-wide singleton shared with the
/// productivity demo in `main.dart`.
const List<String> kShopFunctionIds = [
  'searchProducts',
  'viewCart',
  'addToCart',
  'removeFromCart',
  'listAddresses',
  'setDeliveryAddress',
  'applyCoupon',
  'placeOrder',
];

/// Keeps the registered function set in sync with [store] for the lifetime of
/// the app.
///
/// Call this once at startup. Registration then tracks state automatically,
/// rather than depending on some widget remembering to re-sync — which also
/// means the agent sees the correct tool set even with no UI attached.
void attachShopAppFunctions(ShopStore store) {
  syncShopAppFunctions(store);
  store.addListener(() => syncShopAppFunctions(store));
}

/// Rebuilds the registered function set from the current [store] state.
///
/// This is the answer to "is registration static?" — it is not. Call this
/// whenever state changes and the agent only ever sees the operations that
/// are legal right now: no `addToCart` while signed out, no `placeOrder`
/// until there is both a cart and an address.
void syncShopAppFunctions(ShopStore store) {
  final appFunctions = FlutterAppFunctions.instance;

  if (defaultTargetPlatform != TargetPlatform.android) {
    appFunctions.ensureInitialized();
    return;
  }

  for (final id in kShopFunctionIds) {
    appFunctions.unregister(id);
  }

  appFunctions
    ..register(_searchProducts(store))
    ..register(_viewCart(store));

  if (store.isSignedIn) {
    appFunctions
      ..register(_addToCart(store))
      ..register(_removeFromCart(store))
      ..register(_listAddresses(store))
      ..register(_setDeliveryAddress(store))
      ..register(_applyCoupon(store));
  }

  if (store.canPlaceOrder) {
    appFunctions.register(_placeOrder(store));
  }
}

AppFunctionDefinition _searchProducts(ShopStore store) => AppFunctionDefinition(
  id: 'searchProducts',
  description:
      'Search the product catalog by name or keyword. Call this first to '
      'turn something the user described in words into a productId. '
      'Does not modify the cart.',
  parameters: [
    AppFunctionParameter.string(
      'query',
      description: 'What the user is looking for, e.g. "coffee".',
    ),
  ],
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async {
    final matches = store.search(params['query'] as String);
    if (matches.isEmpty) {
      throw AppFunctionElementNotFoundException(
        'No products matched "${params['query']}".',
      );
    }
    return jsonEncode(matches.map((p) => p.toJson()).toList());
  },
);

AppFunctionDefinition _viewCart(ShopStore store) => AppFunctionDefinition(
  id: 'viewCart',
  description:
      'Return the current cart contents and totals. Use this to answer '
      'questions about the cart without changing anything.',
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async => jsonEncode({
    'lines': store.cart.map((l) => l.toJson()).toList(),
    'subtotal': store.subtotal,
    'discount': store.discount,
    'total': store.total,
    'deliveryAddress': store.deliveryAddress?.toJson(),
  }),
);

AppFunctionDefinition _addToCart(ShopStore store) => AppFunctionDefinition(
  id: 'addToCart',
  description:
      'Add a product to the cart. Requires a productId from '
      'searchProducts. This does NOT place the order — call placeOrder '
      'separately once the user has confirmed.',
  parameters: [
    AppFunctionParameter.string(
      'productId',
      description: 'A productId returned by searchProducts.',
    ),
    AppFunctionParameter.int(
      'quantity',
      required: false,
      description: 'How many to add. Defaults to 1.',
    ),
  ],
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async {
    final product = store.productById(params['productId'] as String);
    if (product == null) {
      throw AppFunctionElementNotFoundException(
        'No product with id "${params['productId']}".',
      );
    }
    final quantity = (params['quantity'] as int?) ?? 1;
    if (quantity < 1) {
      throw AppFunctionInvalidArgumentException('quantity must be at least 1.');
    }
    store.addToCart(product, quantity);
    // The return value is feedback for the agent, not just the user —
    // it lets the agent say something specific in its next turn.
    return 'Added $quantity x ${product.name}. '
        'Cart total is now ${store.total.toStringAsFixed(0)}.';
  },
);

AppFunctionDefinition _removeFromCart(ShopStore store) => AppFunctionDefinition(
  id: 'removeFromCart',
  description: 'Remove a product from the cart entirely.',
  parameters: [AppFunctionParameter.string('productId')],
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async {
    final removed = store.removeFromCart(params['productId'] as String);
    if (!removed) {
      throw AppFunctionElementNotFoundException(
        'That product is not in the cart.',
      );
    }
    return 'Removed. Cart total is now ${store.total.toStringAsFixed(0)}.';
  },
);

AppFunctionDefinition _listAddresses(ShopStore store) => AppFunctionDefinition(
  id: 'listAddresses',
  description:
      'List the saved delivery addresses with their ids and labels. Call '
      'this before setDeliveryAddress to resolve a label such as '
      '"office" into an addressId.',
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async =>
      jsonEncode(store.addresses.map((a) => a.toJson()).toList()),
);

AppFunctionDefinition _setDeliveryAddress(ShopStore store) =>
    AppFunctionDefinition(
      id: 'setDeliveryAddress',
      description:
          'Choose which saved address the order ships to. Requires an '
          'addressId from listAddresses.',
      parameters: [AppFunctionParameter.string('addressId')],
      returnType: AppFunctionReturnType.string,
      handler: (context, params) async {
        final id = params['addressId'] as String;
        final known = store.addresses.any((a) => a.id == id);
        if (!known) {
          throw AppFunctionElementNotFoundException('Unknown addressId "$id".');
        }
        store.setDeliveryAddress(id);
        return 'Delivering to ${store.deliveryAddress!.label}.';
      },
    );

AppFunctionDefinition _applyCoupon(ShopStore store) => AppFunctionDefinition(
  id: 'applyCoupon',
  description: 'Apply a discount coupon code to the cart.',
  parameters: [
    AppFunctionParameter.string(
      'code',
      description: 'The coupon code, e.g. "BREW10".',
    ),
  ],
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async {
    final code = (params['code'] as String).toUpperCase();
    if (code != 'BREW10') {
      throw AppFunctionInvalidArgumentException('Coupon "$code" is not valid.');
    }
    store.applyCoupon(code);
    return 'Applied $code. New total ${store.total.toStringAsFixed(0)}.';
  },
);

/// Spending money is the one place the agent must not close the loop alone.
///
/// [ShopScreenState.confirmOrder] shows a real confirmation sheet; declining
/// surfaces to the agent as a typed
/// [AppFunctionPermissionRequiredException], exactly as it would on the
/// Android side.
AppFunctionDefinition _placeOrder(ShopStore store) => AppFunctionDefinition(
  id: 'placeOrder',
  description:
      'Place the order for everything currently in the cart, shipping to '
      'the selected delivery address. Only call this once the user has '
      'clearly asked to order. This spends money and asks the user to '
      'confirm.',
  returnType: AppFunctionReturnType.string,
  handler: (context, params) async {
    if (store.cart.isEmpty) {
      throw AppFunctionInvalidArgumentException('The cart is empty.');
    }
    if (store.deliveryAddress == null) {
      throw AppFunctionInvalidArgumentException(
        'No delivery address selected. Call setDeliveryAddress first.',
      );
    }
    final confirmed = await ShopConfirmation.request(store);
    if (!confirmed) {
      throw AppFunctionPermissionRequiredException(
        'The user declined the order.',
      );
    }
    final order = store.placeOrder();
    return 'Order ${order.id} placed for '
        '${order.total.toStringAsFixed(0)}, delivering to ${order.deliverTo}.';
  },
);

/// Indirection so the handler can ask the UI for confirmation without the
/// domain layer depending on a [BuildContext].
class ShopConfirmation {
  static Future<bool> Function(ShopStore store)? handler;

  static Future<bool> request(ShopStore store) async {
    final h = handler;
    if (h == null) return true;
    return h(store);
  }
}
