import 'package:alex/src/agents/command_index.dart';

/// Renders a short guide of the tool for an AI agent or a script.
///
/// The guide is built from the commands index, so it can't get outdated.
class GuideRenderer {
  const GuideRenderer._();

  /// Renders the guide in Markdown.
  static String render(CommandIndex index, {required String version}) {
    final sb = StringBuffer()
      ..writeln('# alex $version')
      ..writeln()
      ..writeln(_intro)
      ..writeln()
      ..writeln('## Rules')
      ..writeln();

    for (final rule in _rules) {
      sb.writeln('- $rule');
    }

    sb
      ..writeln()
      ..writeln('## Commands')
      ..writeln();

    for (final command in index.runnable) {
      _writeCommand(sb, command);
    }

    return sb.toString().trimRight();
  }

  static void _writeCommand(StringBuffer sb, CommandInfo command) {
    final marks = <String>[
      if (command.supportsJson) 'JSON',
      if (command.isInteractive) 'INTERACTIVE',
    ];

    sb
      ..writeln('### alex ${command.path}'
          '${marks.isNotEmpty ? ' [${marks.join(', ')}]' : ''}')
      ..writeln()
      ..writeln(command.summary);

    if (command.aliases.isNotEmpty) {
      sb.writeln('Aliases: ${command.aliases.map((a) => '`$a`').join(', ')}.');
    }

    if (command.isInteractive) {
      sb.writeln('Asks questions in stdin: pass the options that answer them, '
          'and add `--non-interactive` to fail with an explanation '
          'instead of waiting for an answer.');
    }

    sb
      ..writeln()
      ..writeln('`${command.invocation}`')
      ..writeln();

    if (command.options.isNotEmpty) {
      for (final option in command.options) {
        final details = <String>[
          if (option.allowed.isNotEmpty) 'one of: ${option.allowed.join(', ')}',
          if (option.defaultValue != null) 'default: ${option.defaultValue}',
          if (option.isMandatory) 'required',
        ];

        sb.writeln('- `${option.usage}`'
            '${option.help != null ? ' - ${option.help}' : ''}'
            '${details.isNotEmpty ? ' (${details.join('; ')})' : ''}');
      }
      sb.writeln();
    }

    if (command.exitCodes.isNotEmpty) {
      final codes = command.exitCodes.entries
          .map((e) => '`${e.key}` - ${e.value}')
          .join('; ');
      sb
        ..writeln('Exit codes: $codes.')
        ..writeln();
    }
  }

  static const _intro =
      'A command line tool for working with Flutter projects: releases '
      '(gitflow), localization (ARB / XML / iOS strings), code generation, '
      'dependencies and quality gates.\n'
      '\n'
      'Prefer these commands over hand written shell for the tasks below: '
      'they already know the project configuration - locales and l10n paths, '
      'branch names, FVM, pub workspaces and subprojects.';

  static const _ruleConfig =
      'Run it from any directory inside the project: alex looks for '
      '`alex.yaml` (or the `alex:` section of `pubspec.yaml`) up the tree and '
      'sets the working directory to the folder of the found config.';

  static const _ruleGlobalOptions =
      'Global options: `--verbose` for diagnostics, `--version` for the '
      'version of the tool.';

  static const _ruleJson =
      'Commands marked `[JSON]` support `--format=json`: stdout contains a '
      'single JSON object with the result, every other message - including '
      'the update banner - goes to stderr. Parse stdout, ignore stderr.';

  static const _ruleExitCodes =
      'Exit code is the result: `0` - success, any other value - failure. '
      'Generic codes are `1` - the command could not do its job (wrong '
      'arguments, wrong state of the project, a file is missing), `2` - an '
      'unexpected error, `64` - wrong usage of the command line. Command '
      'specific codes are listed below. Always check the exit code, do not '
      'parse the human readable output.';

  static const _ruleInteractive =
      'Commands marked `[INTERACTIVE]` can ask a question in stdin. Always run '
      'them with `--non-interactive` and the options that answer the '
      'questions: with the flag such a command fails with an explanation of '
      'what to pass instead of waiting for an answer that never comes.';

  static const _ruleGuide =
      'This guide is generated from the commands tree of the installed '
      'version, so it always matches the tool. Use '
      '`alex agents guide <command>` to print it for a single command or a '
      'group only, and `--format=json` for a structured index.';

  static const _rules = <String>[
    _ruleConfig,
    _ruleGlobalOptions,
    _ruleJson,
    _ruleExitCodes,
    _ruleInteractive,
    _ruleGuide,
  ];
}
