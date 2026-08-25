import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/const.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// Names of the options that are common for all commands,
/// so they are described once in the guide and skipped in the index.
const _kCommonOptions = <String>{
  kVerbose,
  kFormat,
  'help',
  'verboseFlutterCmd',
};

/// Maximum length of an option help in the index.
const _kMaxHelpLength = 200;

/// Option of a command.
class CommandOptionInfo {
  final String name;
  final String? abbr;
  final bool isFlag;
  final String? help;
  final List<String> allowed;
  final String? defaultValue;
  final bool isMandatory;

  const CommandOptionInfo({
    required this.name,
    required this.isFlag,
    this.abbr,
    this.help,
    this.allowed = const [],
    this.defaultValue,
    this.isMandatory = false,
  });

  factory CommandOptionInfo.fromOption(Option option) {
    final defaultValue = option.defaultsTo;
    // `false` for a flag is the obvious default, no need to mention it.
    final hasDefault =
        defaultValue != null && !(option.isFlag && defaultValue == false);
    return CommandOptionInfo(
      name: option.name,
      abbr: option.abbr,
      isFlag: option.isFlag,
      help: _shorten(option.help),
      allowed: option.allowed?.toList(growable: false) ?? const [],
      defaultValue: hasDefault ? '$defaultValue' : null,
      isMandatory: option.mandatory,
    );
  }

  /// Usage of the option, for example `--locale=<value>`.
  String get usage => isFlag ? '--$name' : '--$name=<value>';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': isFlag ? 'flag' : 'option',
        if (abbr != null) 'abbr': abbr,
        if (help != null) 'help': help,
        if (allowed.isNotEmpty) 'allowed': allowed,
        if (defaultValue != null) 'default': defaultValue,
        if (isMandatory) 'mandatory': true,
      };
}

/// Command of the tool.
class CommandInfo {
  /// Full path of the command, for example `code check`.
  final String path;

  final List<String> aliases;
  final String summary;

  /// Invocation string, for example `alex code check [arguments]`.
  final String invocation;

  /// Whether the command can ask a question in the standard input.
  final bool isInteractive;

  /// Whether the command supports the `--format=json` option.
  final bool supportsJson;

  final List<CommandOptionInfo> options;

  /// Exit codes with their meaning, except the common ones.
  final Map<int, String> exitCodes;

  final List<CommandInfo> subcommands;

  const CommandInfo({
    required this.path,
    required this.summary,
    required this.invocation,
    this.aliases = const [],
    this.isInteractive = false,
    this.supportsJson = false,
    this.options = const [],
    this.exitCodes = const {},
    this.subcommands = const [],
  });

  /// Whether the command is just a group of subcommands.
  bool get isGroup => subcommands.isNotEmpty;

  /// All commands that can be run: this one (if it's not a group)
  /// and all its subcommands, recursively.
  List<CommandInfo> get runnable => isGroup
      ? subcommands.expand((c) => c.runnable).toList(growable: false)
      : [this];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'summary': summary,
        'invocation': invocation,
        if (aliases.isNotEmpty) 'aliases': aliases,
        if (isInteractive) 'interactive': true,
        if (supportsJson) 'json': true,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
        if (exitCodes.isNotEmpty)
          'exitCodes': exitCodes.map((k, v) => MapEntry('$k', v)),
        if (subcommands.isNotEmpty)
          'subcommands': subcommands.map((c) => c.toJson()).toList(),
      };
}

/// Index of all commands of the tool, built from the commands tree.
///
/// The tree is the only source of truth, so the index can't get outdated.
class CommandIndex {
  final List<CommandInfo> commands;

  const CommandIndex(this.commands);

  /// Builds the index by the [runner] commands.
  factory CommandIndex.build(CommandRunner<dynamic> runner) {
    return CommandIndex(_children(runner.commands, const []));
  }

  /// Returns the index with the only command by the [path]
  /// or `null` if there is no such command.
  ///
  /// Path can be partial, for example `['l10n']` returns the whole
  /// `l10n` subtree.
  CommandIndex? filter(List<String> path) {
    if (path.isEmpty) return this;

    var current = commands;
    CommandInfo? found;

    for (final name in path) {
      found = current.firstWhereOrNull(name);
      if (found == null) return null;
      current = found.subcommands;
    }

    return CommandIndex([found!]);
  }

  /// All commands that can be run.
  List<CommandInfo> get runnable =>
      commands.expand((c) => c.runnable).toList(growable: false);

  List<Map<String, dynamic>> toJson() =>
      commands.map((c) => c.toJson()).toList();

  static List<CommandInfo> _children(
      Map<String, Command<dynamic>> commands, List<String> parentPath) {
    final res = <CommandInfo>[];

    commands.forEach((key, command) {
      // Aliases are in the map too, so skip them to avoid duplicates.
      if (key != command.name) return;
      if (command.hidden) return;
      // Built-in help command is not a part of the API.
      if (parentPath.isEmpty && command.name == 'help') return;

      res.add(_command(command, parentPath));
    });

    return res;
  }

  static CommandInfo _command(
      Command<dynamic> command, List<String> parentPath) {
    final path = [...parentPath, command.name];
    final alex = command is AlexCommand ? command : null;

    return CommandInfo(
      path: path.join(' '),
      aliases: command.aliases.toList(growable: false),
      summary: _shorten(command.summary) ?? command.name,
      invocation: command.invocation,
      isInteractive: alex?.isInteractive ?? false,
      supportsJson: command.argParser.options.containsKey(kFormat),
      options: _options(command.argParser),
      exitCodes: alex?.exitCodes ?? const {},
      subcommands: _children(command.subcommands, path),
    );
  }

  static List<CommandOptionInfo> _options(ArgParser parser) {
    final res = <CommandOptionInfo>[];

    parser.options.forEach((name, option) {
      if (option.hide) return;
      if (_kCommonOptions.contains(name)) return;

      res.add(CommandOptionInfo.fromOption(option));
    });

    return res;
  }
}

String? _shorten(String? value) {
  if (value == null) return null;

  final line = value.split('\n').first.trim();
  if (line.isEmpty) return null;
  if (line.length <= _kMaxHelpLength) return line;

  return '${line.substring(0, _kMaxHelpLength).trimRight()}...';
}

extension _CommandInfoListExtension on List<CommandInfo> {
  CommandInfo? firstWhereOrNull(String name) {
    for (final command in this) {
      if (command.path.split(' ').last == name) return command;
      if (command.aliases.contains(name)) return command;
    }
    return null;
  }
}
