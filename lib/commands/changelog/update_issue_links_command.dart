import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';

/// Replaces plain `(#N)` issue references in CHANGELOG.md with markdown links
/// using `issue_url` from alex config.
class UpdateIssueLinksCommand extends AlexCommand {
  UpdateIssueLinksCommand()
      : super(
          'update-issue-links',
          'Replace plain (#N) issue references in CHANGELOG.md '
              'with markdown links using issue_url from config.',
          const ['uil'],
        );

  @override
  Future<int> doRun() async {
    const fs = IOFileSystem();

    final pubspecExists = await Spec.exists(fs);
    if (!pubspecExists) {
      return error(1,
          message: 'You should run command from project root directory.');
    }

    String? issueUrl;
    try {
      issueUrl = findConfigAndSetWorkingDir().issueUrl;
    } catch (e, st) {
      printVerbose('Failed to load config: $e\nStackTrace: $st');
      return error(1,
          message: 'Failed to load alex config. '
              'Ensure alex.yaml or pubspec.yaml contains a valid `alex` section '
              'with `issue_url`.');
    }

    if (issueUrl == null) {
      return error(1,
          message: 'issue_url is not set in alex config. '
              'Add `issue_url: <base url>` to alex.yaml or to the alex section '
              'of pubspec.yaml.');
    }

    final changelog = Changelog(fs);
    if (!(await changelog.exists)) {
      return error(1, message: 'CHANGELOG.md is not found.');
    }

    final count = await changelog.linkIssueReferences(issueUrl);
    if (count == 0) {
      return success(message: 'No plain issue references to update.');
    }

    await changelog.save();
    return success(message: 'Updated $count issue reference(s).');
  }
}
