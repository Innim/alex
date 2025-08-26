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
      return await doRun();
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e, st) {
      printVerbose('Exception: $e\nStackTrace: $st');
      return error(2, message: 'Failed by: $e');
    }
  }

  @protected
  Future<int> doRun();

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

  /// Prints message if verbose flag is on.
  @protected
  void printVerbose(String message) {
    if (isVerbose) _logger.fine(message);
  }

  /// Prints some info message in output.
  @protected
  void printInfo(String message) => _logger.info(message);

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
    if (message != null) printError(message);
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

  /// Run command and add listeners `onOut`/`onErr` on
  /// std and err output.
  @protected
  Future<ProcessResult> runAndListenOutput(
    String executable,
    List<String> arguments, {
    void Function(String out)? onOut,
    void Function(String err)? onErr,
    String? workingDir,
  }) async {
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    final process = await Process.start(executable, arguments,
        workingDirectory: workingDir);

    systemEncoding.decoder.bind(process.stdout).listen((event) {
      stdout.write(event);
      if (onOut != null) onOut(event);
    });
    systemEncoding.decoder.bind(process.stderr).listen((event) {
      stderr.write(event);
      if (onErr != null) onErr(event);
    });

    final exitCode = await process.exitCode;

    return ProcessResult(
        process.pid, exitCode, stdout.toString(), stderr.toString());
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

  void addVerboseFlutterCmdFlag() => addFlagArg(
        _kArgVerboseFlutterCmd,
        help: 'All flutter commands will be run with verbose flag',
        defaultsTo: false,
      );
}

extension CmdArgArgResultsExtension on ArgResults {
  bool getBool(CmdArg arg) => this[arg.name] as bool;

  bool isVerbose() => this[kVerbose] as bool;

  int? getInt(CmdArg arg) {
    final val = this[arg.name] as String?;
    return val == null ? null : int.tryParse(val);
  }

  String? getString(CmdArg arg) {
    return this[arg.name] as String?;
  }
}
