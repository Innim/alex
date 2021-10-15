import 'dart:convert';
import 'dart:io';
import 'package:dart_console/dart_console.dart' as dart_console;

abstract class Console {
  String readLineSync();
}

class StdConsole implements Console {
  const StdConsole();

  @override
  String readLineSync() =>
      stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
}

class DartConsole implements Console {
  final _console = dart_console.Console();
  DartConsole();

  @override
  String readLineSync() {
    return _console.readLine(cancelOnBreak: true);
  }
}
