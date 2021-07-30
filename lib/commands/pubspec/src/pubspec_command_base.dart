import 'package:alex/runner/alex_command.dart';

abstract class PubspecCommandBase extends AlexCommand {
  PubspecCommandBase(String name, String description)
      : super(name, description);
}
