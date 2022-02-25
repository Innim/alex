import 'dart:io';
import 'package:alex/src/pub_spec.dart';
import 'package:meta/meta.dart';

import 'package:alex/runner/alex_command.dart';

abstract class PubspecCommandBase extends AlexCommand {
  PubspecCommandBase(String name, String description)
      : super(name, description);

  @protected
  Future<List<File>> getPubspecs() => Spec.getPubspecs();
}
