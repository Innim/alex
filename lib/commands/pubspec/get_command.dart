import 'package:alex/commands/pubspec/src/pubspec_command_base.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:path/path.dart' as p;

class GetCommand extends PubspecCommandBase {
  GetCommand()
      : super(
          'get',
          'Get dependencies (execute "pub get" command) '
              'for all projects and packages in folder (recursively).',
        );

  @override
  Future<int> doRun() async {
    printVerbose('Get dependencies');

    final rootDir = p.current;
    printVerbose('Current directory: $rootDir');

    final pubspecFiles = await getPubspecs();
    if (pubspecFiles.isNotEmpty) {
      printVerbose('Found ${pubspecFiles.length} pubspec files.');

      var workspaceDetected = false;
      final filtered = (pubspecFiles.length == 1
              ? pubspecFiles
              : pubspecFiles.where((f) {
                  final pubspec = Spec.byFile(f);

                  if (pubspec.isWorkspaceRoot()) {
                    workspaceDetected = true;
                    return true;
                  }

                  if (pubspec.isResolveFromWorkspace()) {
                    printVerbose('Skipping ${f.path}: resolved from workspace');
                    workspaceDetected = true;
                    return false;
                  }

                  if (!pubspec.hasAnyDependencies() &&
                      !pubspec.hasEnvironmentConstraint()) {
                    printVerbose(
                      'Skipping ${f.path}: no dependencies and no environment constraint',
                    );
                    return false;
                  }

                  return true;
                }))
          .toList();

      if (filtered.isEmpty) {
        if (workspaceDetected) {
          // we have at least one pubspec to process
          // assume that all pubspecs belong to one workspace
          printInfo(
            'All pubspec files belong to workspace, but no root pubspec found. '
            'Using the first one.',
          );
          filtered.add(pubspecFiles.first);
        }
      } else if (filtered.length < pubspecFiles.length) {
        // TODO: check workspace to make sure that they include all filtered pubspecs
        if (workspaceDetected) printInfo('Workspace detected.');

        final skipped = pubspecFiles.length - filtered.length;
        printVerbose('Skipped $skipped pubspec ${_files(skipped)}');
      }

      if (filtered.isNotEmpty) {
        final total = filtered.length;
        printVerbose(
          'Getting dependencies for $total pubspec ${_files(total)}.',
        );

        await flutter.initFvm();

        var done = 0;

        for (final file in filtered) {
          final relativePath = p.relative(file.path, from: rootDir);
          printInfo(
            'Getting dependencies for ./$relativePath [${done + 1}/$total]',
          );

          final printOutput = isVerbose;
          await flutter.pubGetOrFail(
            path: p.dirname(file.path),
            printStdOut: printOutput,
            immediatePrint: printOutput,
          );
          done++;
        }

        printInfo('Got dependencies for $done pubspec ${_files(done)}.');

        return success(message: 'Done ✅');
      } else {
        return success(message: 'No valid pubspec files found.');
      }
    } else {
      return success(message: 'No pubspec files found.');
    }
  }
}

String _files(int count) => count == 1 ? 'file' : 'files';
