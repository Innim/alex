import 'dart:convert';
import 'dart:io';

import 'package:alex/runner/alex_command.dart';

class HelloWorldCommand extends AlexCommand {
  HelloWorldCommand() : super('hello', 'Hello world description') {
    argParser.addOption('name', abbr: 'n');
  }

  @override
  Future<int> run() async {
    printInfo('Enter you name: ');

    final name = readLine();

    printInfo('Hello $name');
    return 0;
  }

  String readLine() {
    final line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
    return line.trim();
  }
}
