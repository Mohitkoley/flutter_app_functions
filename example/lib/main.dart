import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final demoStore = DemoProductivityStore();
  registerProductivityAppFunctions(demoStore);

  runApp(MyApp(store: demoStore));
}

void registerProductivityAppFunctions(DemoProductivityStore store) {
  final appFunctions = FlutterAppFunctions.instance;

  if (defaultTargetPlatform != TargetPlatform.android) {
    appFunctions.ensureInitialized();
    return;
  }

  appFunctions
    ..register(
      AppFunctionDefinition(
        id: 'createTask',
        description:
            'Create a task or reminder in the user\'s productivity app. '
            'Use this when the user asks to remember, schedule, or track work.',
        parameters: [
          AppFunctionParameter.string(
            'title',
            description: 'Short task title, for example "Pick up package".',
          ),
          AppFunctionParameter.optionalString(
            'dueDateTime',
            description:
                'Natural language or ISO-like due time, for example "today 5 PM".',
          ),
          AppFunctionParameter.optionalString(
            'location',
            description: 'Where the task should happen, for example "Work".',
          ),
        ],
        returnType: AppFunctionReturnType.string,
        handler: (context, params) async {
          final task = store.createTask(
            title: params['title'] as String,
            dueDateTime: params['dueDateTime'] as String?,
            location: params['location'] as String?,
          );
          return jsonEncode(task.toJson());
        },
      ),
    )
    ..register(
      AppFunctionDefinition(
        id: 'addItemsToShoppingList',
        description:
            'Add grocery or shopping items to the active shopping list. '
            'Use this after extracting ingredients or product names from a user request.',
        parameters: [
          AppFunctionParameter.stringList(
            'items',
            description:
                'Names of items to add, for example ["noodles", "soy sauce"].',
          ),
          AppFunctionParameter.optionalString(
            'source',
            description:
                'Where the items came from, for example "Lisa noodle recipe".',
          ),
        ],
        returnType: AppFunctionReturnType.stringList,
        handler: (context, params) async {
          final addedItems = store.addShoppingItems(
            items: params['items'] as List<String>,
            source: params['source'] as String?,
          );
          return addedItems.map((item) => item.label).toList();
        },
      ),
    )
    ..register(
      AppFunctionDefinition(
        id: 'completeTask',
        description:
            'Mark one task as complete. Use this when the user says a task is done.',
        parameters: [
          AppFunctionParameter.int(
            'taskId',
            description: 'The numeric id of the task to complete.',
          ),
        ],
        returnType: AppFunctionReturnType.string,
        handler: (context, params) async {
          final taskId = params['taskId'] as int;
          final completed = store.completeTask(taskId);
          if (completed == null) {
            throw AppFunctionElementNotFoundException(
              'No task exists with id $taskId.',
            );
          }
          return jsonEncode(completed.toJson());
        },
      ),
    )
    ..register(
      AppFunctionDefinition(
        id: 'summarizeToday',
        description:
            'Summarize the user\'s current tasks and shopping list for today.',
        returnType: AppFunctionReturnType.string,
        handler: (context, params) async => store.summaryForAgent(),
      ),
    );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.store});

  final DemoProductivityStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AppFunctions MCP Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ProductivityAgentDemo(store: store),
    );
  }
}

class ProductivityAgentDemo extends StatefulWidget {
  const ProductivityAgentDemo({super.key, required this.store});

  final DemoProductivityStore store;

  @override
  State<ProductivityAgentDemo> createState() => _ProductivityAgentDemoState();
}

class _ProductivityAgentDemoState extends State<ProductivityAgentDemo> {
  final TextEditingController _promptController = TextEditingController(
    text: 'Remind me to pick up my package at work today at 5 PM',
  );
  final List<AgentLogEntry> _logs = <AgentLogEntry>[];
  bool _running = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _runSimulatedAgent() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _running) return;

    setState(() {
      _running = true;
      _logs.insert(0, AgentLogEntry.user(prompt));
    });

    final toolCall = DemoAgentPlanner.plan(prompt);
    setState(() {
      _logs.insert(0, AgentLogEntry.toolCall(toolCall));
    });

    try {
      final result = await FlutterAppFunctions.instance.invoke(
        toolCall.functionId,
        toolCall.parameters,
      );
      setState(() {
        _logs.insert(0, AgentLogEntry.result(result));
      });
    } on AppFunctionException catch (error) {
      setState(() {
        _logs.insert(0, AgentLogEntry.error('${error.code}: ${error.message}'));
      });
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agent AppFunctions MCP Hub'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('${FlutterAppFunctions.instance.length} tools'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'AppFunctions background listener active',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Real Gemini/AppFunctions callers discover these registered Dart handlers through Android. '
                  'This screen simulates the caller by choosing a function id and JSON parameters, then invoking the same registry.',
                ),
                const SizedBox(height: 16),
                _PromptPanel(
                  controller: _promptController,
                  running: _running,
                  onRun: _runSimulatedAgent,
                  onPromptSelected: (prompt) {
                    _promptController.text = prompt;
                  },
                ),
                const SizedBox(height: 16),
                _RegisteredToolsPanel(
                  definitions: FlutterAppFunctions.instance.definitions
                      .toList(),
                ),
                const SizedBox(height: 16),
                _StoreSnapshotPanel(store: widget.store),
                const SizedBox(height: 16),
                _AgentLogPanel(entries: _logs),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({
    required this.controller,
    required this.running,
    required this.onRun,
    required this.onPromptSelected,
  });

  final TextEditingController controller;
  final bool running;
  final VoidCallback onRun;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    const samplePrompts = <String>[
      'Remind me to pick up my package at work today at 5 PM',
      'Find the noodle recipe from Lisa and add noodles, soy sauce, and scallions to my shopping list',
      'I finished task 1',
      'Summarize my day',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Local AI caller simulation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'User prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final prompt in samplePrompts)
                  OutlinedButton(
                    onPressed: () => onPromptSelected(prompt),
                    child: Text(prompt, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: running ? null : onRun,
              icon: running
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy_outlined),
              label: const Text('Ask simulated agent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisteredToolsPanel extends StatelessWidget {
  const _RegisteredToolsPanel({required this.definitions});

  final List<AppFunctionDefinition> definitions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registered AppFunctions tools',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final definition in definitions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(definition.id),
                subtitle: Text(_toolSignature(definition)),
              ),
          ],
        ),
      ),
    );
  }

  String _toolSignature(AppFunctionDefinition definition) {
    final params = definition.parameters
        .map((param) {
          final requiredMarker = param.required ? '' : '?';
          return '${param.name}: ${param.type.wireName}$requiredMarker';
        })
        .join(', ');
    return '$params -> ${definition.returnType}';
  }
}

class _StoreSnapshotPanel extends StatelessWidget {
  const _StoreSnapshotPanel({required this.store});

  final DemoProductivityStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App state changed by tool calls',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Tasks'),
            if (store.tasks.isEmpty) const Text('No tasks yet.'),
            for (final task in store.tasks)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: task.completed,
                onChanged: null,
                title: Text(task.title),
                subtitle: Text(
                  [
                    if (task.dueDateTime != null) task.dueDateTime,
                    if (task.location != null) task.location,
                  ].join(' - '),
                ),
              ),
            const Divider(),
            const Text('Shopping list'),
            if (store.shoppingItems.isEmpty)
              const Text('No shopping items yet.'),
            for (final item in store.shoppingItems)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shopping_basket_outlined),
                title: Text(item.label),
                subtitle: item.source == null
                    ? null
                    : Text('Source: ${item.source}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgentLogPanel extends StatelessWidget {
  const _AgentLogPanel({required this.entries});

  final List<AgentLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caller trace',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text(
                'Run a prompt to see the function id and parameters an agent would send.',
              ),
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: Text(entry.body),
              ),
          ],
        ),
      ),
    );
  }
}

class DemoAgentPlanner {
  static ToolCall plan(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('shopping') || lower.contains('recipe')) {
      final items = _extractShoppingItems(prompt);
      return ToolCall(
        functionId: 'addItemsToShoppingList',
        parameters: <String, dynamic>{
          'items': items,
          'source': lower.contains('lisa')
              ? 'Lisa recipe request'
              : 'User prompt',
        },
      );
    }

    if (lower.contains('finished') ||
        lower.contains('done') ||
        lower.contains('complete')) {
      return ToolCall(
        functionId: 'completeTask',
        parameters: <String, dynamic>{'taskId': _firstNumber(prompt) ?? 1},
      );
    }

    if (lower.contains('summarize') || lower.contains('summary')) {
      return const ToolCall(functionId: 'summarizeToday');
    }

    return ToolCall(
      functionId: 'createTask',
      parameters: <String, dynamic>{
        'title': _extractTaskTitle(prompt),
        if (lower.contains('5 pm') || lower.contains('5pm'))
          'dueDateTime': 'today 5 PM',
        if (lower.contains('work')) 'location': 'Work',
      },
    );
  }

  static List<String> _extractShoppingItems(String prompt) {
    final lower = prompt.toLowerCase();
    final knownItems = <String>[
      'noodles',
      'soy sauce',
      'scallions',
      'ginger',
      'garlic',
      'eggs',
    ];
    final extracted = knownItems.where(lower.contains).toList();
    return extracted.isEmpty ? <String>['noodles', 'soy sauce'] : extracted;
  }

  static String _extractTaskTitle(String prompt) {
    var title = prompt
        .replaceFirst(RegExp('remind me to ', caseSensitive: false), '')
        .replaceFirst(RegExp('please ', caseSensitive: false), '')
        .trim();
    if (title.isEmpty) title = 'Follow up from agent request';
    return title[0].toUpperCase() + title.substring(1);
  }

  static int? _firstNumber(String prompt) {
    final match = RegExp(r'\d+').firstMatch(prompt);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}

class DemoProductivityStore extends ChangeNotifier {
  final List<TaskItem> _tasks = <TaskItem>[];
  final List<ShoppingItem> _shoppingItems = <ShoppingItem>[];
  int _nextTaskId = 1;

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<ShoppingItem> get shoppingItems => List.unmodifiable(_shoppingItems);

  TaskItem createTask({
    required String title,
    String? dueDateTime,
    String? location,
  }) {
    final task = TaskItem(
      id: _nextTaskId++,
      title: title,
      dueDateTime: dueDateTime,
      location: location,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  List<ShoppingItem> addShoppingItems({
    required List<String> items,
    String? source,
  }) {
    final added = items
        .map((item) => ShoppingItem(label: item.trim(), source: source))
        .where((item) => item.label.isNotEmpty)
        .toList();
    _shoppingItems.addAll(added);
    notifyListeners();
    return added;
  }

  TaskItem? completeTask(int taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return null;
    final completed = _tasks[index].copyWith(completed: true);
    _tasks[index] = completed;
    notifyListeners();
    return completed;
  }

  String summaryForAgent() {
    final openTasks = _tasks.where((task) => !task.completed).length;
    final completedTasks = _tasks.where((task) => task.completed).length;
    return 'Open tasks: $openTasks. Completed tasks: $completedTasks. '
        'Shopping items: ${_shoppingItems.map((item) => item.label).join(', ')}.';
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.dueDateTime,
    this.location,
    this.completed = false,
  });

  final int id;
  final String title;
  final String? dueDateTime;
  final String? location;
  final bool completed;

  TaskItem copyWith({bool? completed}) {
    return TaskItem(
      id: id,
      title: title,
      dueDateTime: dueDateTime,
      location: location,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    if (dueDateTime != null) 'dueDateTime': dueDateTime,
    if (location != null) 'location': location,
    'completed': completed,
  };
}

class ShoppingItem {
  const ShoppingItem({required this.label, this.source});

  final String label;
  final String? source;
}

class ToolCall {
  const ToolCall({
    required this.functionId,
    this.parameters = const <String, dynamic>{},
  });

  final String functionId;
  final Map<String, dynamic> parameters;

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'functionId': functionId,
      'parametersJson': jsonEncode(parameters),
    });
  }
}

class AgentLogEntry {
  const AgentLogEntry._({
    required this.title,
    required this.body,
    required this.icon,
  });

  factory AgentLogEntry.user(String prompt) => AgentLogEntry._(
    title: 'User prompt',
    body: prompt,
    icon: Icons.person_outline,
  );

  factory AgentLogEntry.toolCall(ToolCall toolCall) => AgentLogEntry._(
    title: 'Agent selected AppFunction',
    body: toolCall.toPrettyJson(),
    icon: Icons.hub_outlined,
  );

  factory AgentLogEntry.result(Object? result) => AgentLogEntry._(
    title: 'AppFunction result',
    body: '$result',
    icon: Icons.check_circle_outline,
  );

  factory AgentLogEntry.error(String error) => AgentLogEntry._(
    title: 'AppFunction error',
    body: error,
    icon: Icons.error_outline,
  );

  final String title;
  final String body;
  final IconData icon;
}
