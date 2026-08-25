import 'dart:convert';

import 'package:alex/runner/alex_command_runner.dart';
import 'package:args/command_runner.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:alex/src/output/json_format.dart';
import 'package:alex/src/version.dart';

Future<int> run(List<String> args) async {
  try {
    return await AlexCommandRunner().run(args) ?? 2;
  } on UsageException catch (e, st) {
    print.exception(e, st);
    return _failed(args, 64, e.message);
  } catch (e, st) {
    print.exception(e, st);
    return _failed(args, -1, '$e');
  }
}

/// Prints the error result in the machine readable mode, if it was requested,
/// and returns the [exitCode].
///
/// A command prints such a result by itself, but alex can fail before the
/// command is started - on the arguments parsing or on the initialization -
/// so a script gets a JSON object in the standard output in any case.
int _failed(List<String> args, int exitCode, String message) {
  if (!isJsonFormatRequested(args)) return exitCode;

  final command = commandNameFromArgs(args);

  print.result(jsonEncode(<String, dynamic>{
    'alex': packageVersion,
    if (command.isNotEmpty) 'command': command,
    'ok': false,
    'exitCode': exitCode,
    'summary': message.split('\n').first.trim(),
    'error': message,
  }));

  return exitCode;
}
