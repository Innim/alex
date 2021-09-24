part of 'changelog_test.dart';

const addAddedResultWithAddedAndFixed = '''
## Next release

### Added 

- Some new feature.
- New added line.

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

// TODO: change order Added <> Fixed
const addAddedResultWithFixed = '''
## Next release

### Fixed

- New bug fix.

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
