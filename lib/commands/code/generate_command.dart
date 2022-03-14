import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/pub_spec.dart';
import 'src/code_command_base.dart';

/// Command to run code generation.
class GenerateCommand extends CodeCommandBase {
  static const _buildRunner = 'build_runner';

  GenerateCommand() : super('gen', 'Run code generation.');

  @override
  Future<int> doRun() async {
    printInfo('Start code generation...');

    try {
      printVerbose('Search for pubspec with $_buildRunner dependency');
      final pubspecFile = await _findPubspec();
      if (pubspecFile != null) {
        setCurrentDir(pubspecFile.parent.path);
      }

      await flutter.runPubOrFail(
        'build_runner',
        [
          'build',
          '--delete-conflicting-outputs',
        ],
        prependWithPubGet: true,
      );
    } on RunException catch (e) {
      return errorBy(e);
    }

    return success(message: 'Code generation complete!');
  }

  Future<File?> _findPubspec() async {
    final files = await Spec.getPubspecs();
    for (final file in files) {
      final pubspec = Spec.byFile(file);
      printVerbose('Checking ${file.path}');
      if (pubspec.hasDevDependency(_buildRunner)) {
        printVerbose('Found $_buildRunner');
        return file;
      }
      printVerbose('No $_buildRunner - skipped');
    }

    return null;
  }
}
