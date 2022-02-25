import 'dart:io';

import 'package:alex/src/const.dart';
import 'package:logging/logging.dart';

/// Prints some info message in output.
void info(String message) => stdout.writeln(message);

/// Prints error message in error output.
void error(String message) => stderr.writeln(message);

/// Prints error message in error output.
void exception(Object message, [StackTrace? stackTrace]) =>
    error(message.toString() + (isDebug ? '\n$stackTrace' : ''));

/// Prints some verbose message in output.
// ignore: avoid_print
void verbose(String message) => print('[verbose] $message');

void setupRootLogger({bool isVerbose = false}) {
  Logger.root.level = isVerbose ? Level.ALL : Level.INFO;
  _setupLogger(Logger.root);
}

void _setupLogger(Logger logger) {
  logger.onRecord.listen((record) {
    final print = record.level.value < Level.INFO.value
        ? verbose
        : (record.level.value < Level.SEVERE.value ? info : error);

    print(record.message);
  });
}
