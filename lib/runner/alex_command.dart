import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';

/// Базовый класс команды.
abstract class AlexCommand extends Command<int> {
  final String _name;
  final String _description;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
  )..addFlag('verbose', help: 'Show additional diagnostic info');

  AlexCommand(this._name, this._description);

  @override
  String get name => _name;

  @override
  ArgParser get argParser => _argParser;

  @override
  String get description => _description;

  /// Prints message if verbose flag is on.
  @protected
  void printVerbose(String message) {
    if (argResults['verbose'] as bool) print(message);
  }

  /// Prints some info message in output.
  @protected
  void printInfo(String message) => print(message);

  /// Prints error message in error output.
  @protected
  void printError(String message) => stderr.writeln(message);

  /// Prints 0 code and prints a success message if provided.
  @protected
  int success({String message}) {
    if (message != null) printInfo(message);
    return 0;
  }

  /// Returns error code and prints a error message if provided.
  @protected
  int error(int code, {String message}) {
    if (message != null) printError(message);
    return code;
  }

  /// Returns error code by exception.
  @protected
  int errorBy(RunException exception) {
    assert(exception != null);
    return error(exception.exitCode, message: exception.message);
  }

  // Run `flutter pub run` command.
  @protected
  Future<ProcessResult> runPub(String cmd, List<String> arguments) async {
    final executable = 'flutter';
    final args = ['pub', 'run', cmd, ...arguments];

    printVerbose('Run: $executable ${args.join(" ")}');

    return Process.run(executable, args);
  }
}
