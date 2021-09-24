import 'package:alex/runner/alex_command.dart';

abstract class FeatureCommandBase extends AlexCommand {
  FeatureCommandBase(String name, String description,
      [List<String> aliases = const []])
      : super(name, description, aliases);
}
