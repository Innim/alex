import 'package:alex/commands/pubspec/src/pubspec_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as p;

class GetCommand extends PubspecCommandBase {
  GetCommand()
      : super(
            'get',
            'Get dependencies (execute "pub get" command) '
                'for all projects and packages in folder (recursively).');

  @override
  Future<int> doRun() async {
    printVerbose('Get dependencies');

    try {
      final pubspecFiles = await getPubspecs();
      if (pubspecFiles.isNotEmpty) {
        for (final file in pubspecFiles) {
          await pubGetOrFail(path: p.dirname(file.path));
        }

        printInfo('Got dependencies for ${pubspecFiles.length} pubspec files.');
      }

      return success(message: 'Done ✅');
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }
}
