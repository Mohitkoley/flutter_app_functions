import 'package:flutter/material.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final registry = FlutterAppFunctions.instance;

  // Sample 1: returns a UTF-8 string.
  registry.register(
    AppFunctionDefinition(
      id: 'createTask',
      description: 'Creates a new task in the user\'s task list.',
      parameters: [
        AppFunctionParameter.string('title'),
        AppFunctionParameter.optionalString('notes'),
      ],
      returnType: AppFunctionReturnType.string,
      handler: (context, params) async {
        final title = params['title'] as String;
        final notes = params['notes'] as String?;
        return 'Created task "$title"${notes == null ? '' : ' with notes "$notes"'}';
      },
    ),
  );

  // Sample 2: returns a 64-bit integer count.
  registry.register(
    AppFunctionDefinition(
      id: 'countActiveTasks',
      description: 'Returns the number of active tasks in the user\'s list.',
      returnType: AppFunctionReturnType.int64,
      handler: (context, params) async {
        return 0; // pretend the user has no active tasks
      },
    ),
  );

  // Sample 3: returns a list of strings. Demonstrates how to surface
  // typed errors (e.g. an enum mismatch) back to the agent.
  registry.register(
    AppFunctionDefinition(
      id: 'searchContacts',
      description: 'Searches the user\'s contacts by name.',
      parameters: [
        AppFunctionParameter.string('query'),
        AppFunctionParameter.string(
          'filterType',
          description: 'Either "INDIVIDUAL" or "GROUP".',
        ),
      ],
      returnType: AppFunctionReturnType.stringList,
      handler: (context, params) async {
        final filterType = params['filterType'] as String;
        if (filterType != 'INDIVIDUAL' && filterType != 'GROUP') {
          throw AppFunctionInvalidArgumentException(
            'Unknown filterType "$filterType". Use "INDIVIDUAL" or "GROUP".',
          );
        }
        return <String>['No contacts matched "${params['query']}".'];
      },
    ),
  );

  // Sample 4: returns void (action only). Useful for side-effecting
  // functions like "mark task as done".
  registry.register(
    AppFunctionDefinition(
      id: 'markAllTasksDone',
      description: 'Marks every active task in the user\'s list as done.',
      returnType: AppFunctionReturnType.voidType,
      handler: (context, params) async {
        return; // no return value
      },
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter App Functions Example')),
        body: const Center(
          child: Text(
            'App Functions are registered.\n'
            'Use the App Functions agent or adb shell to invoke:\n'
            '  • createTask\n'
            '  • countActiveTasks\n'
            '  • searchContacts\n'
            '  • markAllTasksDone',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
