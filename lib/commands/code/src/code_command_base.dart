import 'package:alex/runner/alex_command.dart';

/// Base command for localization feature.
abstract class CodeCommandBase extends AlexCommand {
  CodeCommandBase(String name, String description) : super(name, description);
}
