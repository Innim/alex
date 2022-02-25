import 'dart:io';

import 'package:alex/src/const.dart';
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
