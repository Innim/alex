import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// Базовый класс команды.
abstract class AlexCommand extends Command<int> {
  final String _name;
  final String _description;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
  );

  AlexCommand(this._name, this._description);

  @override
  String get name => _name;

  @override
  ArgParser get argParser => _argParser;

  @override
  String get description => _description;
}
