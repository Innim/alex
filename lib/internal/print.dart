import 'dart:io';

import 'package:logging/logging.dart';

const _kVerbosePrefix = '[verbose] ';
final _verboseIndent = ' ' * _kVerbosePrefix.length;

bool _useStdErrForMessages = false;

/// Redirects all messages (info and verbose) to the error output.
///
/// Should be used when the standard output is reserved for a machine readable
/// result of a command (see `--format=json`), so any other message
/// can't be mixed with it.
void setMessagesOutputToStdErr({bool value = true}) =>
    _useStdErrForMessages = value;

IOSink get _messagesSink => _useStdErrForMessages ? stderr : stdout;

/// Prints some info message in output.
void info(String message) => _messagesSink.writeln(message);

/// Prints error message in error output.
void error(String message) => stderr.writeln(message);

/// Prints error message in error output.
void exception(Object message, [StackTrace? stackTrace]) =>
    error(message.toString()); // + (isDebug ? '\n$stackTrace' : ''));

/// Prints some verbose message in output.
void verbose(String message) {
  final sink = _messagesSink;
  final lines = message.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final prefix = i == 0 ? _kVerbosePrefix : _verboseIndent;
    sink.writeln('$prefix$line');
  }
}

/// Prints a result of a command in the standard output.
///
/// Should be used only for a machine readable result,
/// see [setMessagesOutputToStdErr].
void result(String value) => stdout.writeln(value);

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
