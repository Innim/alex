import 'dart:convert';

import 'package:alex/internal/print.dart' as print;
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/agents/command_index.dart';
import 'package:alex/src/agents/guide_renderer.dart';
import 'package:alex/src/version.dart';

/// Exit code if a command from the arguments is not found.
const _kExitCodeUnknownCommand = 10;

/// Command to print a short guide of the tool for an AI agent or a script.
class GuideCommand extends AlexCommand {
  GuideCommand()
      : super(
          'guide',
          'Print a short guide of alex for an AI agent or a script.\n\n'
              'The guide is generated from the commands tree of the installed '
              'version, so it always matches the tool: '
              'the list of commands, their options, '
              'which of them support a machine readable output '
              'and which are interactive, and the exit codes.\n\n'
              'Pass a command path to print the guide for it only, '
              'for example: alex agents guide l10n.\n\n'
              'Exit code is 0 if the guide is printed, '
              '$_kExitCodeUnknownCommand if there is no command '
              'with the specified path.',
        ) {
    argParser.addFormatOption();
  }

  @override
  Map<int, String> get exitCodes => const {
        _kExitCodeUnknownCommand: 'unknown command',
      };

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final path = args.rest;

    final fullIndex = CommandIndex.build(runner!);
    final index = fullIndex.filter(path);

    if (index == null) {
      return error(_kExitCodeUnknownCommand,
          message: 'There is no command "${path.join(' ')}". '
              'Run "alex agents guide" to see all commands.');
    }

    if (args.isJsonFormat()) {
      print.result(jsonEncode(<String, dynamic>{
        'alex': packageVersion,
        'command': 'agents guide',
        'ok': true,
        'summary': '${index.runnable.length} command(s)',
        'commands': index.toJson(),
      }));
    } else {
      print.info(GuideRenderer.render(index, version: packageVersion));
    }

    return 0;
  }
}
