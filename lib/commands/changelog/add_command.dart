import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';

const _sectionAdded = 'added';
const _sectionFixed = 'fixed';
const _sectionPreRelease = 'pre-release';

/// Command to add an entry in CHANGELOG.md.
class AddCommand extends AlexCommand {
  static const _argSection = CmdArg('section', abbr: 's');
  static const _argIssue = CmdArg('issue', abbr: 'i');

  AddCommand()
      : super(
          'add',
          'Add an entry in CHANGELOG.md.\n\n'
              'The entry is added in the section of the changes that are not '
              'released yet. If the changelog starts with a released version, '
              'then the section for the next release is created at the top - '
              'an entry must never get into a version that is already out.\n\n'
              'Example: alex changelog add "Some new feature" -s added -i 42',
          const ['a'],
        ) {
    argParser
      ..addArg(
        _argSection,
        help: 'Section of the changelog to add the entry in.',
        allowed: const [_sectionAdded, _sectionFixed, _sectionPreRelease],
        defaultsTo: _sectionAdded,
        valueHelp: 'SECTION',
      )
      ..addArg(
        _argIssue,
        help: 'Issue number to reference in the entry. '
            'A markdown link is used if issue_url is set in the config.',
        valueHelp: 'NUMBER',
      )
      ..addFormatOption();
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final line = args.rest.join(' ').trim();

    if (line.isEmpty) {
      return error(1,
          message: 'Nothing to add - the entry is not provided. '
              'Example: alex changelog add "Some new feature"');
    }

    const fs = IOFileSystem();
    if (!await Spec.exists(fs)) {
      return error(1,
          message: 'You should run command from project root directory.');
    }

    final changelog = Changelog(fs);
    if (!await changelog.exists) {
      return error(1, message: 'CHANGELOG.md is not found.');
    }

    final section = args.getString(_argSection) ?? _sectionAdded;
    final issueId = args.getInt(_argIssue);

    final sectionAdded = await changelog.ensureNextReleaseSection();

    switch (section) {
      case _sectionFixed:
        await changelog.addFixedEntry(line, issueId, config.issueUrl);
        break;
      case _sectionPreRelease:
        await changelog.addPreReleaseEntry(line, issueId, config.issueUrl);
        break;
      case _sectionAdded:
      default:
        await changelog.addAddedEntry(line, issueId, config.issueUrl);
        break;
    }

    await changelog.save();

    final summary = 'added in $section'
        '${sectionAdded ? ', a section for the next release was created' : ''}';

    if (isJsonFormat) {
      return jsonResult(
        exitCode: 0,
        summary: summary,
        data: <String, dynamic>{
          'entry': line,
          'section': section,
          if (issueId != null) 'issue': issueId,
          'nextReleaseSectionCreated': sectionAdded,
        },
      );
    }

    if (sectionAdded) {
      printInfo('Section for the changes that are not released yet '
          'was created at the top of CHANGELOG.md.');
    }

    return success(message: '📝 Entry added in the $section section.');
  }
}
