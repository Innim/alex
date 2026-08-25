import 'dart:convert';

import 'package:alex/internal/print.dart' as print;
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/agents/project_facts.dart';
import 'package:alex/src/version.dart';

/// Command to print the facts about the project.
class InfoCommand extends AlexCommand {
  InfoCommand()
      : super(
          'info',
          'Print the facts about the project.\n\n'
              'Package and version, path to the alex config, packages of a '
              'multi-package project, Flutter version pinned with FVM, '
              'locales and localization paths, git branches.\n\n'
              'Everything is taken from the alex config and the project '
              'files, so a script or an AI agent can get all of it with a '
              'single call instead of reading several files.',
          ['facts'],
        ) {
    argParser.addFormatOption();
  }

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final facts = await ProjectFacts.collect(config);

    if (argResults!.isJsonFormat()) {
      print.result(jsonEncode(<String, dynamic>{
        'alex': packageVersion,
        'command': 'info',
        'ok': true,
        'summary': _summary(facts),
        ...facts.toJson(),
      }));
    } else {
      printInfo('alex $packageVersion');
      for (final line in facts.lines) {
        printInfo('- $line');
      }
    }

    return 0;
  }

  String _summary(ProjectFacts facts) {
    final name = facts.packageName ?? 'unknown package';
    final version = facts.packageVersion;
    return '$name${version != null ? ' $version' : ''}, '
        '${facts.isFlutter ? 'flutter' : 'dart'}, '
        '${facts.locales.length} locale(s), '
        '${facts.packages.length} package(s)';
  }
}
