import 'dart:io';

/// Prints some info message in output.
void info(String message) => stdout.writeln(message);

/// Prints error message in error output.
void error(String message) => stderr.writeln(message);

/// Prints error message in error output.
void exception(Object message) => error(message.toString());

/// Prints some verbose message in output.
// ignore: avoid_print
void verbose(String message) => print(message);
