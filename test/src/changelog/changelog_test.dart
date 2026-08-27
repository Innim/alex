import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

part 'changelog_test.contents.dart';
part 'changelog_test.results.dart';

void main() {
  group('getNextReleaseChangelog()', () {
    test('should return content of next release section with Added', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseWithAdded));

      final res = await changelog.getNextReleaseChangelog();

      expect(res, '''
### Added 

- Some new feature.
''');
    });

    test('should return content of next release section with Fixed', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseWithFixed));

      final res = await changelog.getNextReleaseChangelog();

      expect(res, '''
### Fixed

- Some bug fix.
''');
    });

    test('should return content of next release section with Added and Fixed',
        () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      final res = await changelog.getNextReleaseChangelog();

      expect(res, '''
### Added 

- Some new feature.

### Fixed

- Some bug fix.
''');
    });

    test('should return content of empty next release section', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseEmpty));

      final res = await changelog.getNextReleaseChangelog();

      expect(res, '');
    });

    test(
        'should return content of next release section when there is no previous version',
        () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithNoReleasedVersion));

      final res = await changelog.getNextReleaseChangelog();

      expect(res, '''
### Added 

- Some new feature.

### Fixed

- New bug fix.
''');
    });
  });

  group('addAddedEntry()', () {
    test('should add line in Added section', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addAddedEntry('New added line');

      expect(await changelog.content, addAddedResultWithAddedAndFixed);
    });

    test('should add section and line if no section', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseEmpty));

      await changelog.addAddedEntry('New added line');

      expect(await changelog.content, addAddedResultWithEmpty);
    });

    test('should add section and line if has only other section', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseWithAdded));

      await changelog.addFixedEntry('New bug fix.');

      expect(await changelog.content, addFixedResultWithAdded);
    });

    test('should add section and line in valid order', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseWithFixed));

      await changelog.addAddedEntry('New added line');

      expect(await changelog.content, addAddedResultWithFixed);
    });

    test('should add third section and line in valid order', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addPreReleaseEntry('New added line');

      expect(await changelog.content, addPreReleaseResultWithAddedAndFixed);
    });

    test('should add middle section and line in valid order', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndPreRelease));

      await changelog.addFixedEntry('New bug fix.');

      expect(await changelog.content, addFixedResultWithAddedAndPreRelease);
    });

    test('should auto add empty line after header', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseEmptyNoLine));

      await changelog.addAddedEntry('New added line');

      expect(await changelog.content, addAddedResultWithEmpty);
    });

    test('should add issueId to line if provided', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addAddedEntry('New added line', 123);

      expect(
        await changelog.content,
        addAddedWithIssueIdResultWithAddedAndFixed,
      );
    });

    test('should not add issueId if already exist', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addAddedEntry('New added line. (#123)', 123);

      expect(
        await changelog.content,
        addAddedWithIssueIdResultWithAddedAndFixed,
      );
    });

    test('should add dot before issueId', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addAddedEntry('New added line (#123)', 123);

      expect(
        await changelog.content,
        addAddedWithIssueIdResultWithAddedAndFixed,
      );
    });

    test('should remove dot after issueId', () async {
      final changelog =
          Changelog(_FileSystemMock(nextReleaseWithAddedAndFixed));

      await changelog.addAddedEntry('New added line (#123).', 123);

      expect(
        await changelog.content,
        addAddedWithIssueIdResultWithAddedAndFixed,
      );
    });
  });

  group('ensureNextReleaseSection()', () {
    test('should do nothing if the section is already there', () async {
      final changelog = Changelog(_FileSystemMock(nextReleaseWithAdded));

      final res = await changelog.ensureNextReleaseSection();

      expect(res, false);
      expect(await changelog.content, nextReleaseWithAdded);
    });

    test('should add the section if the changelog starts with a version',
        () async {
      // Right after a release: a new entry must not get into a version
      // that is already out.
      final changelog = Changelog(_FileSystemMock(releasedOnlyChangelog));

      final res = await changelog.ensureNextReleaseSection();

      expect(res, true);
      expect(await changelog.content, '''
## Next release

## v1.0.0 - 2026-01-01

### Added

- Something old.
''');
    });

    test('should add an entry in the created section', () async {
      final changelog = Changelog(_FileSystemMock(releasedOnlyChangelog));

      await changelog.ensureNextReleaseSection();
      await changelog.addAddedEntry('Some new feature');

      expect(await changelog.content, '''
## Next release

### Added

- Some new feature.

## v1.0.0 - 2026-01-01

### Added

- Something old.
''');
    });

    test('should fail with an explanation for an unknown structure', () async {
      final changelog = Changelog(_FileSystemMock(unknownStructureChangelog));

      expect(
        changelog.ensureNextReleaseSection(),
        throwsA(isA<RunException>().having(
          (e) => e.message,
          'message',
          allOf(contains('unexpected structure'), contains('## Next release')),
        )),
      );
    });
  });

  group('linkIssueReferences()', () {
    test('should convert plain (#N) to markdown links', () async {
      final changelog =
          Changelog(_FileSystemMock(changelogWithPlainIssueReferences));

      final count =
          await changelog.linkIssueReferences('https://example.com/issue');

      expect(count, 6);
      expect(await changelog.content, linkIssueReferencesResult);
    });

    test('should handle trailing slash in issueUrl', () async {
      final changelog =
          Changelog(_FileSystemMock(changelogWithPlainIssueReferences));

      final count =
          await changelog.linkIssueReferences('https://example.com/issue/');

      expect(count, 6);
      expect(
          await changelog.content, linkIssueReferencesResultWithTrailingSlash);
    });

    test('should not modify already-linked issues', () async {
      final changelog =
          Changelog(_FileSystemMock(changelogWithMixedIssueReferences));

      final count =
          await changelog.linkIssueReferences('https://example.com/issue');

      expect(count, 3);
      expect(await changelog.content, linkIssueReferencesMixedResult);
    });

    test('should return 0 when no plain issue references exist', () async {
      final changelog =
          Changelog(_FileSystemMock(changelogWithNoIssueReferences));

      final count =
          await changelog.linkIssueReferences('https://example.com/issue');

      expect(count, 0);
      expect(await changelog.content, changelogWithNoIssueReferences);
    });
  });
}

class _FileSystemMock extends Mock implements FileSystem {
  final String content;

  _FileSystemMock(this.content);

  @override
  Future<String> readString(String path) {
    return Future.value(content);
  }
}
