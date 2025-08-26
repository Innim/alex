import 'dart:io';

import 'package:logging/logging.dart';

const _kVerbosePrefix = '[verbose] ';
final _verboseIndent = ' ' * _kVerbosePrefix.length;

/// Prints some info message in output.
void info(String message) => stdout.writeln(message);

/// Prints error message in error output.
void error(String message) => stderr.writeln(message);

/// Prints error message in error output.
void exception(Object message, [StackTrace? stackTrace]) =>
    error(message.toString()); // + (isDebug ? '\n$stackTrace' : ''));

/// Prints some verbose message in output.
void verbose(String message) {
  final lines = message.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final prefix = i == 0 ? _kVerbosePrefix : _verboseIndent;
    // ignore: avoid_print
    print('$prefix$line');
  }
}

void setupRootLogger({bool isVerbose = false}) {
  setRootLoggerLevel(isVerbose: isVerbose);
  _setupLogger(Logger.root);
}

void setRootLoggerLevel({bool isVerbose = false}) {
  Logger.root.level = isVerbose ? Level.ALL : Level.INFO;
}

void _setupLogger(Logger logger) {
  logger.onRecord.listen((record) {
    final print = record.level.value < Level.INFO.value
        ? verbose
        : (record.level.value < Level.SEVERE.value ? info : error);

    print(record.message);
  });
}
