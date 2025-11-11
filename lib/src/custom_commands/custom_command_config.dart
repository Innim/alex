import 'dart:io';

import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_argument.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

/// Custom command definition.
class CustomCommandDefinition {
  /// Name of the command.
  final String name;

  /// Description of the command.
  final String description;

  /// Aliases for the command.
  final List<String> aliases;

  /// Arguments for the command.
  final List<CustomCommandArgument> arguments;

  /// Actions to execute.
  final List<CustomCommandAction> actions;

  CustomCommandDefinition({
    required this.name,
    required this.description,
    this.aliases = const [],
    this.arguments = const [],
    required this.actions,
  });

  factory CustomCommandDefinition.fromYaml(YamlMap data) {
    final aliasesList = data['aliases'] as YamlList?;
    final argumentsList = data['arguments'] as YamlList?;
    final actionsList = data['actions'] as YamlList?;

    if (actionsList == null || actionsList.isEmpty) {
      throw Exception('Custom command requires at least one action');
    }

    final cmdName = data['name'] as String? ?? '<unnamed>';

    // Parse arguments with error context
    final arguments = <CustomCommandArgument>[];
    if (argumentsList != null) {
      for (var i = 0; i < argumentsList.length; i++) {
        try {
          final argData = argumentsList[i] as YamlMap;
          arguments.add(CustomCommandArgument.fromYaml(argData));
        } catch (e) {
          final argData = argumentsList[i] as YamlMap;
          var location = 'argument ${i + 1} in command "$cmdName"';
          try {
            final span = argData.span;
            location = 'line ${span.start.line + 1}:${span.start.column + 1} (argument ${i + 1} in command "$cmdName")';
          } catch (_) {
            // Span not available
          }
          throw Exception('Error parsing $location: $e');
        }
      }
    }

    // Parse actions with error context
    final actions = <CustomCommandAction>[];
    for (var i = 0; i < actionsList.length; i++) {
      try {
        final actionData = actionsList[i] as YamlMap;
        actions.add(CustomCommandAction.fromYaml(actionData));
      } catch (e) {
        final actionData = actionsList[i] as YamlMap;
        final actionType = actionData['type'] as String? ?? '<unknown>';
        var location = 'action ${i + 1} (type: $actionType) in command "$cmdName"';
        try {
          final span = actionData.span;
          location = 'line ${span.start.line + 1}:${span.start.column + 1} (action ${i + 1}, type: $actionType, command: "$cmdName")';
        } catch (_) {
          // Span not available
        }
        throw Exception('Error parsing $location: $e');
      }
    }

    return CustomCommandDefinition(
      name: cmdName,
      description: data['description'] as String? ?? '',
      aliases: aliasesList?.map((e) => e.toString()).toList() ?? [],
      arguments: arguments,
      actions: actions,
    );
  }

  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'name': name,
      'description': description,
    };

    if (aliases.isNotEmpty) {
      result['aliases'] = aliases;
    }
    if (arguments.isNotEmpty) {
      result['arguments'] = arguments.map((e) => e.toYaml()).toList();
    }
    result['actions'] = actions.map((e) => e.toYaml()).toList();

    return result;
  }
}

/// Configuration for custom commands.
class CustomCommandsConfig {
  static const _configFileName = 'alex_custom_commands.yaml';
  static final _logger = Logger('custom_commands_config');

  // File search limits
  static const int _maxParentDirSearchDepth = 10;

  static CustomCommandsConfig? _instance;

  // Returns instance of loaded configuration.
  static CustomCommandsConfig get instance {
    if (_instance == null) {
      load();
    }
    return _instance!;
  }

  static bool get hasInstance => _instance != null;

  /// Load configuration from default location.
  static void load({String? path}) {
    if (_instance != null) {
      _logger.warning('Config already loaded, reloading...');
      _instance = null;
    }

    _logger.fine('Looking for custom commands config file...');
    final configPath = path ?? _findConfigFile();
    if (configPath == null) {
      _logger.fine('Custom commands config file not found, using empty config');
      _instance = CustomCommandsConfig._([], null);
      return;
    }

    _logger.info('Found custom commands config at: $configPath');
    try {
      _instance = _loadFromFile(configPath);
      _logger.info('Successfully loaded custom commands config from: $configPath');
    } catch (e, stackTrace) {
      _logger.severe('Failed to load custom commands config: $e');
      _logger.fine('Stack trace: $stackTrace');
      _instance = CustomCommandsConfig._([], null);
    }
  }

  /// Reload configuration.
  static void reload() {
    _instance = null;
    load();
  }

  static String? _findConfigFile() {
    // Look for config file in current directory and parent directories
    var dir = Directory.current;
    for (var i = 0; i < _maxParentDirSearchDepth; i++) {
      final configFile = File(p.join(dir.path, _configFileName));
      if (configFile.existsSync()) {
        return configFile.path;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        break; // Reached root
      }
      dir = parent;
    }

    return null;
  }

  static CustomCommandsConfig _loadFromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Config file not found: $path');
    }

    _logger.fine('Reading YAML file: $path');
    final yamlString = file.readAsStringSync();

    _logger.fine('Parsing YAML content (${yamlString.length} characters)');
    final yamlData = loadYaml(yamlString);

    if (yamlData == null) {
      _logger.warning('YAML file is empty or null');
      return CustomCommandsConfig._([], path);
    }

    if (yamlData is! YamlMap) {
      throw Exception('Invalid config file format: expected YamlMap, got ${yamlData.runtimeType}');
    }

    final commandsList = yamlData['custom_commands'] as YamlList?;
    if (commandsList == null) {
      _logger.warning('No "custom_commands" key found in YAML');
      return CustomCommandsConfig._([], path);
    }

    if (commandsList.isEmpty) {
      _logger.fine('custom_commands list is empty');
      return CustomCommandsConfig._([], path);
    }

    _logger.fine('Parsing ${commandsList.length} command definition(s)');
    final commands = <CustomCommandDefinition>[];
    for (var i = 0; i < commandsList.length; i++) {
      try {
        final cmdData = commandsList[i] as YamlMap;
        final cmdName = cmdData['name'] as String? ?? '<unnamed>';
        _logger.fine('Parsing command ${i + 1}: $cmdName');
        final cmd = CustomCommandDefinition.fromYaml(cmdData);
        commands.add(cmd);
        _logger.fine('Successfully parsed command: ${cmd.name}');
      } catch (e, stackTrace) {
        final cmdData = commandsList[i] as YamlMap;
        final cmdName = cmdData['name'] as String? ?? '<unnamed>';

        // Try to get line number from YamlMap if available
        var locationInfo = 'command ${i + 1} ($cmdName)';
        try {
          final span = cmdData.span;
          locationInfo = '$path:${span.start.line + 1}:${span.start.column + 1}';
        } catch (_) {
          // If span is not available, use simple format
        }

        final errorMsg = 'Failed to parse $locationInfo: $e';
        _logger.severe(errorMsg);
        _logger.fine('Stack trace: $stackTrace');

        // Rethrow with more context
        throw Exception(errorMsg);
      }
    }

    return CustomCommandsConfig._(commands, path);
  }

  final List<CustomCommandDefinition> _commands;
  final String? _configPath;

  CustomCommandsConfig._(this._commands, this._configPath);

  /// All custom commands.
  List<CustomCommandDefinition> get commands => List.unmodifiable(_commands);

  /// Path to the config file (null if not loaded from file).
  String? get configPath => _configPath;

  /// Get config file path or create default path.
  String getOrCreateConfigPath() {
    if (_configPath != null) {
      return _configPath!;
    }

    // Default to current directory
    return p.join(Directory.current.path, _configFileName);
  }

  // Find command by name or alias.
  // Returns null if command is not found.
  CustomCommandDefinition? findCommand(String name) {
    for (final cmd in _commands) {
      if (cmd.name == name || cmd.aliases.contains(name)) {
        return cmd;
      }
    }
    return null;
  }

  // Check if command exists.
  bool hasCommand(String name) {
    return findCommand(name) != null;
  }

  // Save configuration to file.
  void save() {
    final path = getOrCreateConfigPath();
    final file = File(path);

    // Convert to YAML string manually for better formatting
    final buffer = StringBuffer();
    buffer.writeln('# Alex Custom Commands Configuration');
    buffer.writeln('# Define your custom commands here');
    buffer.writeln();
    buffer.writeln('custom_commands:');

    for (final cmd in _commands) {
      buffer.writeln('  - name: ${cmd.name}');
      buffer.writeln('    description: ${cmd.description}');

      if (cmd.aliases.isNotEmpty) {
        buffer.writeln('    aliases: ${cmd.aliases}');
      }

      if (cmd.arguments.isNotEmpty) {
        buffer.writeln('    arguments:');
        for (final arg in cmd.arguments) {
          buffer.writeln('      - name: ${arg.name}');
          buffer.writeln('        type: ${arg.type == CustomCommandArgumentType.option ? 'option' : 'flag'}');
          if (arg.help != null) {
            buffer.writeln('        help: ${arg.help}');
          }
          if (arg.abbr != null) {
            buffer.writeln('        abbr: ${arg.abbr}');
          }
          if (arg.defaultValue != null) {
            buffer.writeln('        default: ${arg.defaultValue}');
          }
          if (arg.allowed != null && arg.allowed!.isNotEmpty) {
            buffer.writeln('        allowed: ${arg.allowed}');
          }
          if (arg.required) {
            buffer.writeln('        required: true');
          }
        }
      }

      buffer.writeln('    actions:');
      for (final action in cmd.actions) {
        final actionYaml = action.toYaml();
        buffer.writeln('      - type: ${actionYaml['type']}');

        // Write all other fields from the YAML map
        for (final entry in actionYaml.entries) {
          if (entry.key == 'type') continue; // Already written

          final value = entry.value;
          if (value is List) {
            buffer.writeln('        ${entry.key}: $value');
          } else if (value is Map) {
            buffer.writeln('        ${entry.key}:');
            for (final subEntry in (value as Map<String, dynamic>).entries) {
              buffer.writeln('          ${subEntry.key}: ${_escapeYamlString(subEntry.value.toString())}');
            }
          } else if (value is String) {
            // Escape multiline strings
            if (value.contains('\n')) {
              buffer.writeln('        ${entry.key}: |');
              for (final line in value.split('\n')) {
                buffer.writeln('          $line');
              }
            } else {
              buffer.writeln('        ${entry.key}: ${_escapeYamlString(value)}');
            }
          } else {
            buffer.writeln('        ${entry.key}: $value');
          }
        }
      }
      buffer.writeln();
    }

    file.writeAsStringSync(buffer.toString());
    _logger.info('Saved custom commands config to: $path');
  }

  /// Add a new command.
  void addCommand(CustomCommandDefinition command) {
    if (hasCommand(command.name)) {
      throw Exception('Command already exists: ${command.name}');
    }
    _commands.add(command);
  }

  /// Remove a command.
  bool removeCommand(String name) {
    final index = _commands.indexWhere(
      (cmd) => cmd.name == name || cmd.aliases.contains(name),
    );
    if (index != -1) {
      _commands.removeAt(index);
      return true;
    }
    return false;
  }

  /// Update a command.
  void updateCommand(String name, CustomCommandDefinition newCommand) {
    final index = _commands.indexWhere(
      (cmd) => cmd.name == name || cmd.aliases.contains(name),
    );
    if (index == -1) {
      throw Exception('Command not found: $name');
    }
    _commands[index] = newCommand;
  }

  /// Escape a string for safe YAML output.
  /// Wraps strings in quotes if they contain special YAML characters.
  String _escapeYamlString(String value) {
    // Check if the string needs quoting
    final needsQuoting = value.contains('{') ||
        value.contains('}') ||
        value.contains('[') ||
        value.contains(']') ||
        value.contains(':') ||
        value.contains('#') ||
        value.contains('&') ||
        value.contains('*') ||
        value.contains('!') ||
        value.contains('|') ||
        value.contains('>') ||
        value.contains("'") ||
        value.contains('"') ||
        value.contains('%') ||
        value.contains('@') ||
        value.contains('`') ||
        value.startsWith(' ') ||
        value.endsWith(' ') ||
        value.startsWith('-') ||
        value.startsWith('?');

    if (!needsQuoting) {
      return value;
    }

    // Escape double quotes and wrap in double quotes
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
