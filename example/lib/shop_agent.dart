import 'dart:convert';

import 'package:flutter_app_functions/flutter_app_functions.dart';

/// One tool call the agent made, plus what came back.
class AgentStep {
  AgentStep({
    required this.thought,
    required this.functionId,
    required this.arguments,
    this.result,
    this.error,
  });

  final String thought;
  final String functionId;
  final Map<String, dynamic> arguments;
  final String? result;
  final String? error;

  bool get failed => error != null;
}

/// What the brain decided to do next. A null [functionId] means "done".
class AgentDecision {
  const AgentDecision.call(
    this.functionId, {
    this.arguments = const {},
    required this.thought,
  }) : finalMessage = null;

  const AgentDecision.finish(this.finalMessage)
    : functionId = null,
      arguments = const {},
      thought = '';

  final String? functionId;
  final Map<String, dynamic> arguments;
  final String thought;
  final String? finalMessage;
}

/// The decision-making half of the loop.
///
/// Swap [RuleBasedBrain] for [LlmBrain] to move from a scripted demo to a
/// real model without touching [ShopAgent] or any app function.
abstract class ShopAgentBrain {
  Future<AgentDecision> nextStep({
    required String prompt,
    required List<AppFunctionDefinition> tools,
    required List<AgentStep> history,
  });
}

/// The agent loop itself.
///
/// This is the whole pattern in about twenty lines: ask the brain what to do,
/// execute it against the registry, feed the result back, repeat. The app
/// functions do not know an agent exists, and the brain does not know Flutter
/// exists.
class ShopAgent {
  ShopAgent({required this.brain, this.maxSteps = 8});

  final ShopAgentBrain brain;
  final int maxSteps;

  Future<AgentRun> run(String prompt) async {
    final history = <AgentStep>[];

    for (var i = 0; i < maxSteps; i++) {
      // Only the functions registered *right now* are offered. If the cart is
      // empty, `placeOrder` is simply not in this list.
      final tools = FlutterAppFunctions.instance.definitions.toList();

      final decision = await brain.nextStep(
        prompt: prompt,
        tools: tools,
        history: history,
      );

      if (decision.functionId == null) {
        return AgentRun(steps: history, message: decision.finalMessage ?? '');
      }

      try {
        final result = await FlutterAppFunctions.instance.invoke(
          decision.functionId!,
          decision.arguments,
        );
        history.add(
          AgentStep(
            thought: decision.thought,
            functionId: decision.functionId!,
            arguments: decision.arguments,
            result: result?.toString(),
          ),
        );
      } on AppFunctionException catch (e) {
        // Typed failures are information, not a crash. The brain sees the
        // error on the next turn and can recover or explain.
        history.add(
          AgentStep(
            thought: decision.thought,
            functionId: decision.functionId!,
            arguments: decision.arguments,
            error: '${e.code}: ${e.message}',
          ),
        );
      }
    }

    return AgentRun(steps: history, message: 'Stopped after $maxSteps steps.');
  }
}

class AgentRun {
  const AgentRun({required this.steps, required this.message});

  final List<AgentStep> steps;
  final String message;
}

// ---------------------------------------------------------------------------
// Demo brain
// ---------------------------------------------------------------------------

/// A deliberately small planner so the demo runs with no API key.
///
/// It is not clever, and that is the point: even this can satisfy "order more
/// coffee and send it to my office" by chaining five primitives and passing
/// ids from one result into the next. A real model does the same thing, just
/// without the hand-written rules.
class RuleBasedBrain implements ShopAgentBrain {
  @override
  Future<AgentDecision> nextStep({
    required String prompt,
    required List<AppFunctionDefinition> tools,
    required List<AgentStep> history,
  }) async {
    final p = prompt.toLowerCase();
    final available = tools.map((t) => t.id).toSet();
    final called = history.map((s) => s.functionId).toSet();

    bool wants(List<String> words) => words.any(p.contains);

    final wantsCartQuestion = wants([
      "what's in",
      'what is in',
      'show cart',
      'view cart',
    ]);

    // A question about the cart is read-only and self-contained: answer it and
    // stop. Checked before anything else, because the word "cart" also appears
    // in requests that *do* mutate.
    if (wantsCartQuestion) {
      if (called.contains('viewCart')) {
        return AgentDecision.finish(_summarise(history));
      }
      return const AgentDecision.call(
        'viewCart',
        thought: 'The user is asking about the cart, so just read it.',
      );
    }

    final wantsOrder = wants(['order', 'buy', 'checkout', 'place']);
    final wantsAdd = wantsOrder || wants(['add', 'cart']);

    // Coupons.
    final couponMatch = RegExp(
      r'\b([a-z]+\d+)\b',
    ).firstMatch(p.replaceAll('coupon', ' '));
    if (wants(['coupon', 'discount', 'promo']) &&
        !called.contains('applyCoupon') &&
        available.contains('applyCoupon') &&
        couponMatch != null) {
      return AgentDecision.call(
        'applyCoupon',
        arguments: {'code': couponMatch.group(1)!.toUpperCase()},
        thought: 'The user mentioned a coupon code.',
      );
    }

    // 1. Resolve words into a productId.
    if (wantsAdd &&
        !called.contains('searchProducts') &&
        available.contains('searchProducts')) {
      return AgentDecision.call(
        'searchProducts',
        arguments: {'query': _guessQuery(p)},
        thought: 'I need a productId before I can add anything to the cart.',
      );
    }

    // 2. Add the first match.
    if (wantsAdd &&
        called.contains('searchProducts') &&
        !called.contains('addToCart') &&
        available.contains('addToCart')) {
      final productId = _firstProductId(history);
      if (productId != null) {
        return AgentDecision.call(
          'addToCart',
          arguments: {'productId': productId, 'quantity': _guessQuantity(p)},
          thought: 'searchProducts gave me $productId, so add it.',
        );
      }
    }

    if (!wantsOrder) {
      return AgentDecision.finish(_summarise(history));
    }

    // 3. Resolve the delivery address.
    if (!called.contains('listAddresses') &&
        available.contains('listAddresses')) {
      return const AgentDecision.call(
        'listAddresses',
        thought: 'Ordering needs an address, and I only have a label so far.',
      );
    }

    // 4. Pick the address whose label the user named.
    if (called.contains('listAddresses') &&
        !called.contains('setDeliveryAddress') &&
        available.contains('setDeliveryAddress')) {
      final addressId = _matchAddressId(history, p);
      if (addressId != null) {
        return AgentDecision.call(
          'setDeliveryAddress',
          arguments: {'addressId': addressId},
          thought: 'Matched the address the user named to $addressId.',
        );
      }
    }

    // 5. Place it — but only if the app is currently offering that operation.
    if (!called.contains('placeOrder')) {
      if (!available.contains('placeOrder')) {
        return const AgentDecision.finish(
          'I could not place the order: the app is not currently offering '
          'placeOrder, which means the cart is empty or no address is set.',
        );
      }
      return const AgentDecision.call(
        'placeOrder',
        thought: 'Cart and address are ready, so place the order.',
      );
    }

    return AgentDecision.finish(_summarise(history));
  }

  String _guessQuery(String prompt) {
    for (final word in ['coffee', 'mug', 'kettle', 'filter']) {
      if (prompt.contains(word)) return word;
    }
    return prompt.split(' ').where((w) => w.length > 3).join(' ');
  }

  int _guessQuantity(String prompt) {
    final m = RegExp(r'\b(\d+)\b').firstMatch(prompt);
    if (m != null) return int.parse(m.group(1)!);
    return 1;
  }

  String? _firstProductId(List<AgentStep> history) {
    for (final step in history) {
      if (step.functionId != 'searchProducts' || step.result == null) continue;
      final decoded = jsonDecode(step.result!);
      if (decoded is List && decoded.isNotEmpty) {
        return (decoded.first as Map)['productId'] as String?;
      }
    }
    return null;
  }

  String? _matchAddressId(List<AgentStep> history, String prompt) {
    for (final step in history) {
      if (step.functionId != 'listAddresses' || step.result == null) continue;
      final decoded = jsonDecode(step.result!) as List;
      for (final entry in decoded) {
        final label = ((entry as Map)['label'] as String).toLowerCase();
        if (prompt.contains(label)) return entry['addressId'] as String;
      }
      if (decoded.isNotEmpty) {
        return (decoded.first as Map)['addressId'] as String?;
      }
    }
    return null;
  }

  String _summarise(List<AgentStep> history) {
    if (history.isEmpty) {
      return 'I could not map that to any available operation.';
    }
    final last = history.last;
    if (last.failed) return 'That did not work — ${last.error}.';
    return last.result ?? 'Done.';
  }
}

// ---------------------------------------------------------------------------
// Real model
// ---------------------------------------------------------------------------

/// Where a real model plugs in.
///
/// The registry is already a tool manifest: `definition.toJson()` emits id,
/// description, parameters and return type, which is the shape every
/// tool-calling API wants. The loop in [ShopAgent] does not change at all —
/// only this class does.
///
/// ```dart
/// final tools = tools.map((t) => {
///       'name': t.id,
///       'description': t.description,
///       'input_schema': {
///         'type': 'object',
///         'properties': {
///           for (final p in t.parameters)
///             p.name: {'type': _jsonType(p.type), 'description': p.description},
///         },
///         'required': [
///           for (final p in t.parameters) if (p.required) p.name,
///         ],
///       },
///     }).toList();
///
/// // POST to the Messages API with these tools plus the conversation so far,
/// // then translate the response:
/// //   a tool_use block  -> AgentDecision.call(block.name, arguments: block.input)
/// //   a text-only reply -> AgentDecision.finish(text)
/// // Feed each AgentStep back as a tool_result on the next turn.
/// ```
///
/// Keep the key out of the app: proxy through your own backend rather than
/// shipping a provider key inside an APK.
class LlmBrain implements ShopAgentBrain {
  LlmBrain({required this.sendRequest});

  /// Injected transport so this file stays free of HTTP and secrets.
  final Future<AgentDecision> Function({
    required String prompt,
    required List<Map<String, dynamic>> toolSchemas,
    required List<AgentStep> history,
  })
  sendRequest;

  @override
  Future<AgentDecision> nextStep({
    required String prompt,
    required List<AppFunctionDefinition> tools,
    required List<AgentStep> history,
  }) {
    return sendRequest(
      prompt: prompt,
      toolSchemas: tools.map((t) => t.toJson()).toList(),
      history: history,
    );
  }
}
