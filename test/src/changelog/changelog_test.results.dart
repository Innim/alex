part of 'changelog_test.dart';

const addAddedResultWithAddedAndFixed = '''
## Next release

### Added 

- Some new feature.
- New added line.

### Fixed

- Some bug fix.

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

const addAddedResultWithEmpty = '''
## Next release

### Added

- New added line.

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

const addAddedResultWithFixed = '''
## Next release

### Added

- New added line.

### Fixed

- Some bug fix.

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

const addFixedResultWithAdded = '''
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

const addPreReleaseResultWithAddedAndFixed = '''
## Next release

### Added 

- Some new feature.

### Fixed

- Some bug fix.

### Pre-release

- New added line.

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

const addFixedResultWithAddedAndPreRelease = '''
## Next release

### Added 

- Some new feature.

### Fixed

- New bug fix.

### Pre-release

- Some feature preview.

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
