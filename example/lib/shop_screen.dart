import 'package:flutter/material.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

import 'shop_agent.dart';
import 'shop_demo.dart';

/// Screen for the e-commerce demo.
///
/// The three panels are chosen to make the two ideas visible:
///
/// * the **trace** shows one prompt turning into a chain of tool calls that
///   nobody hard-coded;
/// * the **tools** panel shows the registered set changing as app state
///   changes, which is what makes registration dynamic rather than static.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.store});

  final ShopStore store;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final TextEditingController _controller = TextEditingController(
    text: 'Order 2 bags of dark roast coffee and send it to my office',
  );
  final ShopAgent _agent = ShopAgent(brain: RuleBasedBrain());

  List<AgentStep> _steps = const [];
  String _message = '';
  bool _running = false;

  static const List<String> _samples = [
    'Order 2 bags of dark roast coffee and send it to my office',
    "What's in my cart?",
    'Add a mug to my cart',
    'Apply coupon BREW10',
  ];

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    ShopConfirmation.handler = _confirmOrder;
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    ShopConfirmation.handler = null;
    _controller.dispose();
    super.dispose();
  }

  /// Registration is kept in sync by [attachShopAppFunctions]; this only
  /// needs to repaint the panels.
  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<bool> _confirmOrder(ShopStore store) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm order',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final line in store.cart)
              Text('${line.quantity} x ${line.product.name}'),
            const SizedBox(height: 8),
            Text('Deliver to ${store.deliveryAddress?.label ?? "-"}'),
            Text(
              'Total ${store.total.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Place order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _steps = const [];
      _message = '';
    });
    final run = await _agent.run(_controller.text);
    if (!mounted) return;
    setState(() {
      _steps = run.steps;
      _message = run.message;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PromptCard(
          controller: _controller,
          samples: _samples,
          running: _running,
          onRun: _run,
          onSample: (s) => setState(() => _controller.text = s),
        ),
        const SizedBox(height: 16),
        _TraceCard(steps: _steps, message: _message),
        const SizedBox(height: 16),
        _ToolsCard(store: widget.store),
        const SizedBox(height: 16),
        _StateCard(store: widget.store),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.samples,
    required this.running,
    required this.onRun,
    required this.onSample,
  });

  final TextEditingController controller;
  final List<String> samples;
  final bool running;
  final VoidCallback onRun;
  final ValueChanged<String> onSample;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Ask the agent',
      subtitle:
          'One sentence in. The agent picks which app functions to call, and '
          'in what order.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in samples)
                ActionChip(
                  label: Text(s, overflow: TextOverflow.ellipsis),
                  onPressed: running ? null : () => onSample(s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: running ? null : onRun,
            icon: running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(running ? 'Running...' : 'Run agent'),
          ),
        ],
      ),
    );
  }
}

class _TraceCard extends StatelessWidget {
  const _TraceCard({required this.steps, required this.message});

  final List<AgentStep> steps;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Tool call trace',
      subtitle: 'Each row is one app function the agent chose to call.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isEmpty && message.isEmpty)
            const Text('Run the agent to see the chain.'),
          for (var i = 0; i < steps.length; i++)
            _stepTile(context, i, steps[i]),
          if (message.isNotEmpty) ...[
            const Divider(height: 24),
            Text(message, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _stepTile(BuildContext context, int index, AgentStep step) {
    final color = step.failed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: color,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.functionId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.thought.isNotEmpty)
                  Text(
                    step.thought,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                if (step.arguments.isNotEmpty)
                  Text(
                    'args: ${step.arguments}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                Text(
                  step.failed ? step.error! : (step.result ?? ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: step.failed ? color : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsCard extends StatelessWidget {
  const _ToolsCard({required this.store});

  final ShopStore store;

  @override
  Widget build(BuildContext context) {
    final registered = FlutterAppFunctions.instance.definitions
        .map((d) => d.id)
        .toSet();
    return _Panel(
      title:
          'Registered right now (${registered.where(kShopFunctionIds.contains).length}'
          '/${kShopFunctionIds.length})',
      subtitle:
          'Registration is a runtime call, not a compile-time list. Toggle '
          'sign-in or empty the cart and watch this change.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in kShopFunctionIds)
                Chip(
                  label: Text(id, style: const TextStyle(fontSize: 12)),
                  avatar: Icon(
                    registered.contains(id)
                        ? Icons.check_circle
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: registered.contains(id) ? Colors.green : Colors.grey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Signed in'),
            subtitle: const Text('Signing out removes the mutating functions'),
            value: store.isSignedIn,
            onChanged: store.setSignedIn,
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.store});

  final ShopStore store;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'App state',
      subtitle:
          'The agent mutates this same state, so the UI updates through the '
          'normal ChangeNotifier path.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cart', style: TextStyle(fontWeight: FontWeight.bold)),
          if (store.cart.isEmpty)
            const Text('empty')
          else
            for (final line in store.cart)
              Text(
                '${line.quantity} x ${line.product.name}  '
                '(${line.lineTotal.toStringAsFixed(0)})',
              ),
          const SizedBox(height: 6),
          Text('Deliver to: ${store.deliveryAddress?.label ?? "not set"}'),
          if (store.coupon != null) Text('Coupon: ${store.coupon}'),
          Text('Total: ${store.total.toStringAsFixed(0)}'),
          if (store.orders.isNotEmpty) ...[
            const Divider(height: 20),
            const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final order in store.orders)
              Text(
                '${order.id} — ${order.total.toStringAsFixed(0)} '
                'to ${order.deliverTo}',
              ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
