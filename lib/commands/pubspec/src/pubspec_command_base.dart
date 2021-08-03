import 'dart:io';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:alex/runner/alex_command.dart';

abstract class PubspecCommandBase extends AlexCommand {
  static const _pubspecFileName = 'pubspec.yaml';

  PubspecCommandBase(String name, String description)
      : super(name, description);

  @protected
  Future<List<File>> getPubspecs() async {
    final projectPath = p.current;
    final pubspecSearch = Glob("**$_pubspecFileName");
    final pubspecFiles = <File>[];
    await for (final file
        in pubspecSearch.list(root: projectPath, followLinks: false)) {
      if (file is File && p.basename(file.path) == _pubspecFileName) {
        printVerbose('Found ${file.path}');
        pubspecFiles.add(file);
      }
    }

    if (pubspecFiles.isEmpty) {
      printInfo('Pubspec files are not found');
    }

    return pubspecFiles;
  }
}
