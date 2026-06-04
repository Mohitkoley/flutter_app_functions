import 'exceptions.dart';
import 'models/app_function_definition.dart';
import 'models/app_function_parameter.dart';

/// Internal registry of registered [AppFunctionDefinition]s.
///
/// The plugin maintains a single ordered registry keyed by function ID.
/// Lookups are O(1) and insertion order is preserved so that the bridge
/// can serialise a deterministic metadata snapshot if it needs to.
class AppFunctionRegistry {
  final Map<String, AppFunctionDefinition> _definitions =
      <String, AppFunctionDefinition>{};

  /// Registers [definition]. If a definition with the same [AppFunctionDefinition.id]
  /// already exists it is replaced.
  void register(AppFunctionDefinition definition) {
    _definitions[definition.id] = definition;
  }

  /// Removes the definition with the given [id], if any.
  void unregister(String id) {
    _definitions.remove(id);
  }

  /// Removes every registered definition.
  void clear() {
    _definitions.clear();
  }

  /// Returns the definition registered under [id], or `null` if no such
  /// definition exists.
  AppFunctionDefinition? find(String id) => _definitions[id];

  /// Returns the IDs of every registered definition, in insertion order.
  Iterable<String> get ids => _definitions.keys;

  /// Returns every registered definition, in insertion order.
  Iterable<AppFunctionDefinition> get definitions => _definitions.values;

  /// The number of registered definitions.
  int get length => _definitions.length;

  /// Returns the parameter named [name] in [definition] or throws
  /// [AppFunctionInvalidArgumentException] if [definition] does not
  /// declare such a parameter.
  static AppFunctionParameter parameterOrThrow(
    AppFunctionDefinition definition,
    String name,
  ) {
    for (final p in definition.parameters) {
      if (p.name == name) return p;
    }
    throw AppFunctionInvalidArgumentException(
      'Function ${definition.id} has no parameter named "$name".',
    );
  }

  /// Validates and coerces [raw] against [definition]'s parameter
  /// schema. Returns a new map containing exactly the declared
  /// parameters (or throws an [AppFunctionException] for any violation).
  static Map<String, dynamic> validateAndCoerce(
    AppFunctionDefinition definition,
    Map<String, dynamic> raw,
  ) {
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (!_hasParameter(definition, entry.key)) {
        throw AppFunctionInvalidArgumentException(
          'Function ${definition.id} has no parameter named "${entry.key}".',
        );
      }
    }
    for (final param in definition.parameters) {
      final value = raw[param.name];
      if (value == null) {
        if (param.required) {
          throw AppFunctionInvalidArgumentException(
            'Function ${definition.id} requires parameter "${param.name}".',
          );
        }
        continue;
      }
      result[param.name] = _coerce(param, value);
    }
    return result;
  }

  static bool _hasParameter(AppFunctionDefinition definition, String name) {
    for (final p in definition.parameters) {
      if (p.name == name) return true;
    }
    return false;
  }

  static Object? _coerce(AppFunctionParameter param, Object? value) {
    switch (param.type) {
      case AppFunctionDataType.string:
        if (value is! String) {
          throw AppFunctionInvalidArgumentException(
            'Parameter "${param.name}" must be a string.',
          );
        }
        if (param.enumValues.isNotEmpty && !param.enumValues.contains(value)) {
          throw AppFunctionInvalidArgumentException(
            'Parameter "${param.name}" must be one of: ${param.enumValues.join(", ")}.',
          );
        }
        return value;
      case AppFunctionDataType.int64:
        if (value is int) return value;
        if (value is double && value == value.truncateToDouble()) {
          return value.toInt();
        }
        throw AppFunctionInvalidArgumentException(
          'Parameter "${param.name}" must be a 64-bit integer.',
        );
      case AppFunctionDataType.double:
        if (value is num) return value.toDouble();
        throw AppFunctionInvalidArgumentException(
          'Parameter "${param.name}" must be a double.',
        );
      case AppFunctionDataType.bool:
        if (value is bool) return value;
        throw AppFunctionInvalidArgumentException(
          'Parameter "${param.name}" must be a boolean.',
        );
      case AppFunctionDataType.stringList:
        if (value is List) {
          for (final element in value) {
            if (element is! String) {
              throw AppFunctionInvalidArgumentException(
                'Parameter "${param.name}" must be a list of strings.',
              );
            }
          }
          return value.cast<String>();
        }
        throw AppFunctionInvalidArgumentException(
          'Parameter "${param.name}" must be a list of strings.',
        );
    }
  }
}
