import 'package:alex/commands/pubspec/src/pubspec_command_base.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:alex/src/version_increment.dart';

/// Command to increment a version in the pubspec.yaml.
class VersionCommand extends PubspecCommandBase {
  static const _argBuild = 'build';

  VersionCommand()
      : super(
          'version',
          'Increment a version in ${Spec.fileName}, '
              'where <part> is one of: ${VersionIncrement.namesList}. '
              'A build number is kept as is, '
              'if the --$_argBuild flag is not passed.',
        ) {
    argParser
      ..addFlag(
        _argBuild,
        abbr: 'b',
        help: 'Increment a build number (after +) too. '
            'By default only a version is changed, '
            "because usually a build number is already prepared "
            'for the next build.',
      )
      ..addFormatOption();
  }

  @override
  String get invocation =>
      super.invocation.replaceFirst('[arguments]', '<part> [arguments]');

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final rest = args.rest;

    if (rest.isEmpty) {
      return error(1,
          message: 'A part of the version to increment is required. '
              'Allowed values: ${VersionIncrement.namesList}. '
              'For example: alex pubspec version ${VersionIncrement.minor.name}.');
    }

    if (rest.length > 1) {
      return error(1,
          message: 'Only one part of the version can be incremented, '
              'but got: ${rest.join(', ')}.');
    }

    // Throws a RunException with the allowed values if the part is unknown.
    final increment = VersionIncrement.byName(rest.first);
    final incrementBuild = args[_argBuild] as bool? ?? false;

    const fs = IOFileSystem();

    if (!await Spec.exists(fs)) {
      return error(1,
          message: 'There is no ${Spec.fileName} in the current directory. '
              'Run the command in a directory of a project.');
    }

    final spec = await Spec.pub(fs);

    final version = spec.versionOrNull;
    if (version == null) {
      return error(1,
          message: 'There is no version in ${Spec.fileName}. '
              'Add a line like "version: 1.0.0+1" in the file.');
    }

    final newVersion = increment.apply(version, incrementBuild: incrementBuild);
    printVerbose(
        'Increment ${increment.name} version: $version -> $newVersion');

    final content = await fs.readString(Spec.fileName);
    await fs.writeString(
        Spec.fileName, Spec.replaceVersion(content, newVersion));

    if (isJsonFormat) {
      return jsonResult(
        exitCode: 0,
        summary: '$version -> $newVersion',
        data: <String, dynamic>{
          'part': increment.name,
          'previous': '$version',
          'current': '$newVersion',
          'buildIncremented': incrementBuild,
        },
      );
    }

    return success(message: 'Version updated: $version -> $newVersion');
  }
}
