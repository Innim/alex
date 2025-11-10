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

    return CustomCommandDefinition(
      name: data['name'] as String? ??
          (throw Exception('Custom command requires "name" field')),
      description: data['description'] as String? ?? '',
      aliases: aliasesList?.map((e) => e.toString()).toList() ?? [],
      arguments: argumentsList
              ?.map((e) => CustomCommandArgument.fromYaml(e as YamlMap))
              .toList() ??
          [],
      actions: actionsList
          .map((e) => CustomCommandAction.fromYaml(e as YamlMap))
          .toList(),
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

  static CustomCommandsConfig? _instance;

  /// Returns instance of loaded configuration.
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

    final configPath = path ?? _findConfigFile();
    if (configPath == null) {
      _logger.fine('Custom commands config file not found, using empty config');
      _instance = CustomCommandsConfig._([], null);
      return;
    }

    try {
      _instance = _loadFromFile(configPath);
      _logger.fine('Loaded custom commands config from: $configPath');
    } catch (e) {
      _logger.warning('Failed to load custom commands config: $e');
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
    for (var i = 0; i < 10; i++) {
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

    final yamlString = file.readAsStringSync();
    final yamlData = loadYaml(yamlString);

    if (yamlData == null) {
      return CustomCommandsConfig._([], path);
    }

    if (yamlData is! YamlMap) {
      throw Exception('Invalid config file format');
    }

    final commandsList = yamlData['custom_commands'] as YamlList?;
    if (commandsList == null || commandsList.isEmpty) {
      return CustomCommandsConfig._([], path);
    }

    final commands = commandsList
        .map((e) => CustomCommandDefinition.fromYaml(e as YamlMap))
        .toList();

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

  /// Find command by name or alias.
  CustomCommandDefinition? findCommand(String name) {
    return _commands.firstWhere(
      (cmd) => cmd.name == name || cmd.aliases.contains(name),
      orElse: () => throw StateError('Command not found: $name'),
    );
  }

  /// Check if command exists.
  bool hasCommand(String name) {
    try {
      findCommand(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Save configuration to file.
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
        if (action is ExecAction) {
          buffer.writeln('      - type: exec');
          buffer.writeln('        command: ${action.command}');
          if (action.workingDir != null) {
            buffer.writeln('        working_dir: ${action.workingDir}');
          }
        } else if (action is AlexAction) {
          buffer.writeln('      - type: alex');
          buffer.writeln('        command: ${action.command}');
          if (action.args.isNotEmpty) {
            buffer.writeln('        args: ${action.args}');
          }
        } else if (action is ScriptAction) {
          buffer.writeln('      - type: script');
          buffer.writeln('        path: ${action.path}');
          if (action.args.isNotEmpty) {
            buffer.writeln('        args: ${action.args}');
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
}
