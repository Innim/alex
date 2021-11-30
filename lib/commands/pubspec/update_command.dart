import 'dart:io';

import 'package:alex/commands/pubspec/src/pubspec_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:path/path.dart' as p;
import 'package:list_ext/list_ext.dart';

class UpdateCommand extends PubspecCommandBase {
  static const _argDependency = 'dependency';
  static const _argDependencyAbbr = 'd';

  static const _pubspecLockFileName = 'pubspec.lock';

  UpdateCommand()
      : super(
            'update',
            'Update dependency from pubspec.yaml to the last suitable version. '
                'Useful for git dependencies.') {
    argParser
      ..addOption(
        _argDependency,
        abbr: _argDependencyAbbr,
        help: 'Name of the dependency to update.',
        valueHelp: 'PACKAGE_NAME',
      );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    var dependency = args[_argDependency] as String?;

    if (dependency == null || dependency.isEmpty) {
      printInfo('Enter package name to update:');
      dependency = console.readLineSync();

      if (dependency == null || dependency.isEmpty) {
        return error(1,
            message: 'Nothing to update - dependency name is not provider. '
                'You can pass package name as '
                '--$_argDependency=PACKAGE_NAME or '
                '-${_argDependencyAbbr}PACKAGE_NAME');
      }
    }

    printInfo('Updating <$dependency>...');

    try {
      final pubspecFiles = await getPubspecs();
      if (pubspecFiles.isNotEmpty) {
        printVerbose('Sort pubspec files consider mutual dependencies');
        _sortPubpecs(pubspecFiles);

        printVerbose('Update pubspec files');
        var updated = 0;
        for (final file in pubspecFiles) {
          if (await _updatePubspec(file, dependency)) {
            printInfo('Dependency updated for ${file.path}');
            updated++;
          }
        }

        if (updated == 0) {
          printInfo(
              'Dependency <$dependency> is not found in any of pubspec files.');
        } else {
          printInfo('Updated $updated pubspec files.');
        }
      }

      return success(message: 'Bye 👋');
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }

  Future<bool> _updatePubspec(File pubspecFile, String dependency) async {
    printVerbose('Load ${pubspecFile.path}');
    final dirPath = p.dirname(pubspecFile.path);

    // To update dependency from git we need to remove entry from pubspec.lock
    final pubspecLockFile = File(p.join(dirPath, _pubspecLockFileName));

    if (!pubspecLockFile.existsSync()) {
      printVerbose("$_pubspecLockFileName not found. Skipping...");
      return false;
    }

    printVerbose("Load ${pubspecLockFile.path}");
    final content = StringBuffer();
    final needle = '$dependency:';
    var done = false;
    int? indent;
    for (final line in pubspecLockFile.readAsLinesSync()) {
      if (!done) {
        if (indent != null) {
          if (line.indent == indent) {
            done = true;
          } else {
            continue;
          }
        } else if (line.trim() == needle) {
          indent = line.indent;
          continue;
        }
      }

      content.writeln(line);
    }

    if (indent == null) {
      printVerbose('Dependency <$dependency> is not in $_pubspecLockFileName');
    } else {
      printVerbose('Remove <$dependency> entry from $_pubspecLockFileName');
      pubspecLockFile.writeAsStringSync(content.toString());
    }

    // Run pub get to get write updated entry
    await pubGetOrFail(path: dirPath);

    return true;
  }

  void _sortPubpecs(List<File> list) {
    final specs =
        list.toMap((f) => f, (f) => Spec.byString(f.readAsStringSync()));
    list.sort((a, b) {
      final aSpec = specs[a]!;
      final bSpec = specs[b]!;

      final aName = aSpec.name;
      final bName = bSpec.name;

      if (aSpec.dependsOn(bName)) return 1;
      if (bSpec.dependsOn(aName)) return -1;
      return 0;
    });
  }
}

extension _StringExtension on String {
  int get indent => length - trimLeft().length;
}
