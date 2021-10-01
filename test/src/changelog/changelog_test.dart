import 'package:alex/src/changelog/changelog.dart';
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
