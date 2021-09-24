part of 'changelog_test.dart';

const nextReleaseWithAdded = '''
## Next release

### Added 

- Some new feature.

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1.
- Feature 2.

### Fixed

- Bug fix.

## v0.7.9+4060 - 2021-08-30

### Added

- Old feature.

### Fixed

- Old bug fix 1.
- Old bug fix 2.
''';

const nextReleaseWithAddedAndFixed = '''
## Next release

### Added 

- Some new feature.

### Fixed

- New bug fix.

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1.
- Feature 2.

### Fixed

- Bug fix.

## v0.7.9+4060 - 2021-08-30

### Added

- Old feature.

### Fixed

- Old bug fix 1.
- Old bug fix 2.
''';

const nextReleaseWithFixed = '''
## Next release

### Fixed

- New bug fix.

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1.
- Feature 2.

### Fixed

- Bug fix.

## v0.7.9+4060 - 2021-08-30

### Added

- Old feature.

### Fixed

- Old bug fix 1.
- Old bug fix 2.
''';

const nextReleaseEmpty = '''
## Next release

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1.
- Feature 2.

### Fixed

- Bug fix.

## v0.7.9+4060 - 2021-08-30

### Added

- Old feature.

### Fixed

- Old bug fix 1.
- Old bug fix 2.
''';

const nextReleaseEmptyNoLine = '''
## Next release
## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1.
- Feature 2.

### Fixed

- Bug fix.

## v0.7.9+4060 - 2021-08-30

### Added

- Old feature.

### Fixed

- Old bug fix 1.
- Old bug fix 2.
''';

const nextReleaseWithNoReleasedVersion = '''
## Next release

### Added 

- Some new feature.

### Fixed

- New bug fix.

''';
