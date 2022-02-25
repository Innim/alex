import 'package:alex/runner/alex_command.dart';

class HelloWorldCommand extends AlexCommand {
  HelloWorldCommand() : super('hello', 'Hello world description') {
    argParser.addOption('name', abbr: 'n');
  }

  @override
  Future<int> doRun() async {
    printInfo('Enter you name: ');

    final name = readLine();

    printInfo('Hello $name');
    return 0;
  }

  String? readLine() {
    final line = console.readLineSync();
    return line?.trim();
  }
}
