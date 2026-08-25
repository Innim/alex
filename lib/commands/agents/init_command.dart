import 'dart:convert';
import 'dart:io';

import 'package:alex/internal/print.dart' as print;
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/agents/command_index.dart';
import 'package:alex/src/agents/managed_block.dart';
import 'package:alex/src/agents/project_facts.dart';
import 'package:alex/src/agents/section_renderer.dart';
import 'package:alex/src/version.dart';
import 'package:path/path.dart' as p;

/// Exit code if some file is missing or outdated (with the `--check` flag).
const _kExitCodeOutdated = 10;

/// Files with the agent instructions to update by default,
/// if they are not defined in the config or in the arguments.
const _kDefaultFiles = <String>['CLAUDE.md', 'AGENTS.md'];

/// File to create if there is no file with the agent instructions yet.
const _kFallbackFile = 'AGENTS.md';

/// Status of a processed file.
enum _Status {
  created('created'),
  updated('updated'),
  unchanged('unchanged'),
  missing('missing'),
  outdated('outdated');

  final String key;

  const _Status(this.key);

  bool get isProblem => this == _Status.missing || this == _Status.outdated;
}

/// Command to add the alex section in the agent instructions of the project.
class InitCommand extends AlexCommand {
  static const _argFile = 'file';
  static const _argCheck = 'check';

  InitCommand()
      : super(
          'init',
          'Add or update the alex section in the agent instructions '
              'of the project.\n\n'
              'The section describes the project (locales, l10n paths, '
              'branches, FVM) and the commands an agent should use, '
              'so an agent learns about alex from the file it reads first. '
              'Everything is generated from the alex config and the commands '
              'tree, so it can be updated at any time.\n\n'
              'The section is wrapped in the markers '
              '`${ManagedBlock.beginMarker}` and `${ManagedBlock.endMarker}`, '
              'nothing outside of them is changed.\n\n'
              'By default the files are taken from the `agents.files` config '
              'option, or ${_kDefaultFiles.join(' and ')} if they exist, '
              'otherwise $_kFallbackFile is created.\n\n'
              'Exit code is 0 if the files are up to date or updated, '
              '$_kExitCodeOutdated if some file is missing or outdated '
              'and --$_argCheck is passed.',
        ) {
    argParser
      ..addMultiOption(
        _argFile,
        abbr: 'f',
        help: 'File with the agent instructions to add the section in. '
            'Can be passed multiple times.',
        valueHelp: 'PATH',
      )
      ..addFlag(
        _argCheck,
        help: 'Do not change anything, just check that the files exist '
            'and the section in them is up to date.',
        negatable: false,
      )
      ..addFormatOption();
  }

  @override
  Map<int, String> get exitCodes => const {
        _kExitCodeOutdated: 'some file is missing or outdated (with --check)',
      };

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final args = argResults!;
    final isCheck = args[_argCheck] as bool;
    final isJson = args.isJsonFormat();

    final files =
        _targetFiles(config.agents.files, args[_argFile] as List<String>);
    printVerbose('Files: ${files.join(', ')}');

    final facts = await ProjectFacts.collect(config);
    final section = SectionRenderer.render(
      facts: facts,
      index: CommandIndex.build(runner!),
      version: packageVersion,
    );

    final results = <String, _Status>{};

    for (final path in files) {
      final file = File(path);
      final exists = file.existsSync();

      if (!exists && isCheck) {
        results[path] = _Status.missing;
        continue;
      }

      final content = exists ? file.readAsStringSync() : '';

      final String updated;
      try {
        updated = ManagedBlock.apply(content, section);
      } on FormatException catch (e) {
        return error(2, message: 'Can not update $path: ${e.message}');
      }

      if (content == updated) {
        results[path] = _Status.unchanged;
        continue;
      }

      if (isCheck) {
        results[path] = _Status.outdated;
        continue;
      }

      if (!exists) file.parent.createSync(recursive: true);
      file.writeAsStringSync(updated);
      results[path] = exists ? _Status.updated : _Status.created;
    }

    final hasProblems = results.values.any((s) => s.isProblem);

    if (isJson) {
      print.result(jsonEncode(<String, dynamic>{
        'alex': packageVersion,
        'command': 'agents init',
        'ok': !hasProblems,
        'exitCode': hasProblems ? _kExitCodeOutdated : 0,
        'summary':
            results.entries.map((e) => '${e.key}: ${e.value.key}').join(' | '),
        'files': results.entries
            .map((e) => <String, dynamic>{'path': e.key, 'status': e.value.key})
            .toList(),
        'facts': facts.toJson(),
      }));
    } else {
      results.forEach((path, status) {
        printInfo('$path: ${status.key}');
      });

      if (hasProblems) {
        printError('Agent instructions are outdated. '
            'Run "alex agents init" to update them.');
      }
    }

    return hasProblems ? _kExitCodeOutdated : 0;
  }

  List<String> _targetFiles(List<String> fromConfig, List<String> fromArgs) {
    final defined = fromArgs.isNotEmpty ? fromArgs : fromConfig;
    if (defined.isNotEmpty) return _unique(defined);

    final existing = _kDefaultFiles.where((f) => File(f).existsSync());
    if (existing.isNotEmpty) return _unique(existing);

    return const [_kFallbackFile];
  }

  /// Returns paths without duplicates, including the ones
  /// that point to the same file through a link.
  List<String> _unique(Iterable<String> paths) {
    final res = <String>[];
    final resolved = <String>{};

    for (final path in paths) {
      final file = File(path);
      final key = file.existsSync()
          ? file.resolveSymbolicLinksSync()
          : p.canonicalize(path);

      if (resolved.add(key)) res.add(path);
    }

    return res;
  }
}
