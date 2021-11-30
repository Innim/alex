import 'dart:convert';
import 'dart:io';

abstract class Console {
  String? readLineSync();
}

class StdConsole implements Console {
  const StdConsole();

  @override
  String? readLineSync() =>
      stdin.readLineSync(encoding: Encoding.getByName('utf-8')!);
}
