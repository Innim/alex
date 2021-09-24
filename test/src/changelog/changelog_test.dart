import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

part 'changelog_test.contents.dart';

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

- New bug fix.
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

- New bug fix.
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
}

class _FileSystemMock extends Mock implements FileSystem {
  final String content;

  _FileSystemMock(this.content);

  @override
  Future<String> readString(String path) {
    return Future.value(content);
  }
}
