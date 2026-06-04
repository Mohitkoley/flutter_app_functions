import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_app_functions/flutter_app_functions.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize and register your agent tool listeners
  FlutterAppFunctions.instance.registerToolHandler((
    toolName,
    parametersJson,
  ) async {
    // Standard simulation of parsing incoming agent intents
    if (toolName == 'create_task') {
      try {
        final Map<String, dynamic> data = jsonDecode(parametersJson);
        final String title = data['title'] ?? 'Untitled Task';
        final String notes = data['notes'] ?? '';

        // Emulate writing code/storing logic or state mutation
        return 'Successfully created task "$title" with notes: "$notes"';
      } catch (e) {
        return 'Failed to parse execution parameters.';
      }
    }

    return 'Tool "$toolName" executed but no specific handling exists.';
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext materialContext) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Agent AppFunctions MCP Hub')),
        body: const Center(
          child: Text(
            'AppFunctions background listener active.\nWaiting for on-device agent calls...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
