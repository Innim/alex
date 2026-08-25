import 'dart:convert';
import 'dart:io';

import 'package:alex/commands/release/demo.dart';
import 'package:alex/src/config.dart';
import 'package:alex/src/console/console.dart';
import 'package:alex/src/const.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:alex/src/git/git.dart';
import 'package:alex/src/run/cmd.dart';
import 'package:alex/src/run/flutter_cmd.dart';
import 'package:alex/src/settings.dart';
import 'package:alex/src/version.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

const _kArgVerboseFlutterCmd = CmdArg('verboseFlutterCmd');

/// Базовый класс команды.
abstract class AlexCommand extends Command<int> {
  final String _name;
  final String _description;
  final List<String> _aliases;

  Console? _console;
  Cmd? _cmd;
  FlutterCmd? _flutter;
  bool _isResultPrinted = false;
  String? _lastErrorMessage;

  // TODO: as an argument in constructor
  final _logger = Logger('alex');

  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: true,
  )..addVerboseFlag();

  AlexCommand(this._name, this._description, [this._aliases = const []]);

  @override
  String get name => _name;

  @override
  ArgParser get argParser => _argParser;

  @override
  String get description => _description;

  @override
  List<String> get aliases => _aliases;

  /// Full name of the command with all the parent commands,
  /// for example `code check`.
  String get fullName {
    final parts = <String>[name];

    var parent = this.parent;
    while (parent != null) {
      parts.insert(0, parent.name);
      parent = parent.parent;
    }

    return parts.join(' ');
  }

  /// Exit codes of the command with their meaning,
  /// except the common ones (`0` - success, `2` - error).
  ///
  /// Used in a machine readable index of the commands
  /// (see `alex agents guide`).
  Map<int, String> get exitCodes => const {};

  /// Whether the command can ask a question in the standard input.
  ///
  /// Such a command can't be used by a script or an agent
  /// without the options that provide all the answers.
  ///
  /// Used in a machine readable index of the commands
  /// (see `alex agents guide`).
  bool get isInteractive => false;

  @protected
  Console get console => _console ??= const StdConsole();

  @protected
  Cmd get cmd => _cmd ??= Cmd();

  @protected
  FlutterCmd get flutter =>
      _flutter ??= FlutterCmd(cmd, isVerbose: isVerboseFlutterCmd);

  @protected
  set console(Console value) => _console = value;

  @protected
  bool get isVerbose => argResults!.isVerbose();

  /// Whether a machine readable result is requested (`--format=json`).
  @protected
  bool get isJsonFormat => argResults?.isJsonFormat() ?? false;

  /// Prints the result of the command in the standard output
  /// as a single JSON object and returns the [exitCode].
  ///
  /// Should be called only if [isJsonFormat] is `true`.
  /// Common fields of the envelope are filled here, so they are the same
  /// for every command; [data] is a command specific payload.
  @protected
  int jsonResult({
    required int exitCode,
    String? summary,
    Map<String, dynamic> data = const {},
  }) {
    print.result(jsonEncode(<String, dynamic>{
      'alex': packageVersion,
      'command': fullName,
      'ok': exitCode == 0,
      'exitCode': exitCode,
      if (summary != null) 'summary': summary,
      ...data,
    }));

    _isResultPrinted = true;
    return exitCode;
  }

  @protected
  bool get isVerboseFlutterCmd =>
      (argResults!.options.contains(_kArgVerboseFlutterCmd.name)
          ? argResults!.getBool(_kArgVerboseFlutterCmd)
          : null) ??
      isVerbose;

  @protected
  AlexConfig get config {
    if (!AlexConfig.hasInstance) {
      AlexConfig.load(recursive: true);
    }
    return AlexConfig.instance;
  }

  @protected
  AlexSettings get settings => AlexSettings();

  @override
  @nonVirtual
  Future<int> run() async {
    print.setRootLoggerLevel(isVerbose: isVerbose);

    try {
      return _jsonResultIfNeeded(await doRun());
    } on RunException catch (e) {
      return _jsonResultIfNeeded(errorBy(e));
    } catch (e, st) {
      printVerbose('Exception: $e\nStackTrace: $st');
      return _jsonResultIfNeeded(error(2, message: 'Failed by: $e'));
    }
  }

  @protected
  Future<int> doRun();

  /// Prints the result in the machine readable mode, if the command
  /// has finished without printing it itself.
  ///
  /// It happens when the command has failed - by an exception or just by
  /// returning an error code - before it got to the result. So a script
  /// always gets a JSON object in the standard output.
  int _jsonResultIfNeeded(int exitCode) {
    if (!isJsonFormat || _isResultPrinted) return exitCode;

    final message = _lastErrorMessage;
    // Summary is a single line, the whole message is in the `error` field.
    final summary = message?.split('\n').first.trim();

    return jsonResult(
      exitCode: exitCode,
      summary: summary?.isNotEmpty == true
          ? summary
          : (exitCode == 0 ? 'done' : 'failed'),
      data: <String, dynamic>{if (message != null) 'error': message},
    );
  }

  @protected
  AlexConfig findConfigAndSetWorkingDir() {
    final config = this.config;
    setCurrentDir(config.rootPath);
    return config;
  }

  @protected
  void setCurrentDir(String path) {
    if (!p.equals(Directory.current.path, path)) {
      printInfo('Set current dir: $path');
      Directory.current = path;
    }
  }

  @protected
  Logger get out => _logger;

  /// Prints message if verbose flag is on.
  @protected
  void printVerbose(String message) {
    if (isVerbose) _logger.fine(message);
  }

  /// Prints some info message in output.
  @protected
  void printInfo(String message) => _logger.info(message);

  /// Prints warning message in output.
  @protected
  void printWarning(String message) => _logger.warning(message);

  /// Prints error message in error output.
  @protected
  void printError(String message) => _logger.severe(message);

  /// Prints 0 code and prints a success message if provided.
  @protected
  int success({String? message}) {
    if (message != null) printInfo(message);
    return 0;
  }

  /// Returns error code and prints a error message if provided.
  @protected
  int error(int code, {String? message}) {
    if (message != null) {
      printError(message);
      // Kept for the machine readable result, if the command has failed
      // before it printed one.
      _lastErrorMessage = message;
    }
    return code;
  }

  /// Returns error code by exception.
  @protected
  int errorBy(RunException exception, {String? title}) {
    final sb = StringBuffer();
    if (title?.isNotEmpty == true) sb.writeln(title);
    if (exception.message?.isNotEmpty == true) sb.write(exception.message);
    return error(exception.exitCode, message: sb.toString());
  }

  GitCommands getGit(AlexConfig config, {bool isDemo = false}) {
    final gitConfig = config.git;
    final Git gitClient;
    if (!isDemo) {
      gitClient = GitClient();
    } else {
      gitClient = DemoGit(verbose: isVerbose);
    }

    return GitCommands(gitClient, gitConfig);
  }
}

class CmdArg {
  final String name;
  final String? abbr;

  const CmdArg(this.name, {this.abbr});
}

extension CmdArgArgParserExtension on ArgParser {
  void addArg(CmdArg info,
          {String? help,
          String? valueHelp,
          Iterable<String>? allowed,
          Map<String, String>? allowedHelp,
          String? defaultsTo,
          void Function(String?)? callback,
          bool hide = false}) =>
      addOption(
        info.name,
        abbr: info.abbr,
        help: help,
        valueHelp: valueHelp,
        allowed: allowed,
        allowedHelp: allowedHelp,
        defaultsTo: defaultsTo,
        callback: callback,
        hide: hide,
      );

  void addFlagArg(CmdArg info,
          {String? help,
          String? valueHelp,
          Iterable<String>? allowed,
          Map<String, String>? allowedHelp,
          bool? defaultsTo = false,
          // ignore: avoid_positional_boolean_parameters
          void Function(bool)? callback,
          bool hide = false}) =>
      addFlag(
        info.name,
        abbr: info.abbr,
        help: help,
        defaultsTo: defaultsTo,
        callback: callback,
        hide: hide,
      );

  void addVerboseFlag() =>
      addFlag(kVerbose, help: 'Show additional diagnostic info');

  /// Adds the `--format` option.
  ///
  /// In the [kFormatJson] mode a command prints a single JSON object
  /// in the standard output, all other messages go to the error output.
  void addFormatOption() => addOption(
        kFormat,
        help: 'Output format.',
        allowed: const [kFormatText, kFormatJson],
        allowedHelp: const {
          kFormatText: 'Human readable output.',
          kFormatJson: 'Single JSON object in stdout '
              '(all other messages go to stderr).',
        },
        defaultsTo: kFormatText,
      );

  void addVerboseFlutterCmdFlag() => addFlagArg(
        _kArgVerboseFlutterCmd,
        help: 'All flutter commands will be run with verbose flag',
        defaultsTo: false,
      );
}

extension CmdArgArgResultsExtension on ArgResults {
  bool getBool(CmdArg arg) => this[arg.name] as bool;

  bool isVerbose() => this[kVerbose] as bool;

  /// Returns `true` if the machine readable output is requested.
  bool isJsonFormat() =>
      options.contains(kFormat) && this[kFormat] == kFormatJson;

  int? getInt(CmdArg arg) {
    final val = this[arg.name] as String?;
    return val == null ? null : int.tryParse(val);
  }

  String? getString(CmdArg arg) {
    return this[arg.name] as String?;
  }
}
