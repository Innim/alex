import 'dart:io';

import 'package:alex/src/pub_spec.dart';
import 'src/code_command_base.dart';
import 'package:path/path.dart' as p;

/// Command to run code generation.
class GenerateCommand extends CodeCommandBase {
  static const _buildRunner = 'build_runner';

  GenerateCommand() : super('gen', 'Run code generation.');

  @override
  Future<int> doRun() async {
    printInfo('Start code generation...');

    final rootDirPath = p.current;
    printVerbose('Current directory: $rootDirPath');
    printVerbose('Search for pubspec with $_buildRunner dependency');

    final pubspecFiles = await _findPubspecs();
    printVerbose('Found ${pubspecFiles.length} pubspec files');

    if (pubspecFiles.isEmpty) {
      return success(
        message: '🔍 No pubspec.yaml with $_buildRunner dependency found.',
      );
    }

    for (final pubspecFile in pubspecFiles) {
      final relativePath = p.relative(pubspecFile.path, from: rootDirPath);
      printInfo('Generating code for $relativePath');

      setCurrentDir(pubspecFile.parent.path);
      printVerbose('Current directory: ${Directory.current.path}');

      await flutter.runPubOrFail(
        'build_runner',
        [
          'build',
          '--delete-conflicting-outputs',
        ],
        prependWithPubGet: true,
        title: 'Running code generation',
      );

      printInfo('Generation for $relativePath - DONE');
    }

    return success(message: '🛠️ Code generation complete!');
  }

  Future<List<File>> _findPubspecs() async {
    final res = <File>[];
    final files = await Spec.getPubspecs();
    for (final file in files) {
      final pubspec = Spec.byFile(file);
      printVerbose('Checking ${file.path}');

      if (!pubspec.hasDevDependency(_buildRunner)) {
        printVerbose('No $_buildRunner - skipped');
        continue;
      }

      // workspaces for now only work from root with custom build.yaml
      if (pubspec.isResolveFromWorkspace()) {
        printVerbose('Resolved from workspace - skipped');
        continue;
      }

      printVerbose('Found $_buildRunner');
      res.add(file);
    }

    return res;
  }
}
