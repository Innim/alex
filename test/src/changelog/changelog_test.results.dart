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

const addAddedWithIssueIdResultWithAddedAndFixed = '''
## Next release

### Added 

- Some new feature.
- New added line. (#123)

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

const linkIssueReferencesResult = '''
## Next release

### Added 

- Some new feature ([#123](https://example.com/issue/123)).
- Another feature ([#456](https://example.com/issue/456)).

### Fixed

- Bug fix ([#789](https://example.com/issue/789)).

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1 ([#100](https://example.com/issue/100)).
- Feature 2 ([#200](https://example.com/issue/200)).

### Fixed

- Bug fix ([#300](https://example.com/issue/300)).
''';

const linkIssueReferencesResultWithTrailingSlash = '''
## Next release

### Added 

- Some new feature ([#123](https://example.com/issue/123)).
- Another feature ([#456](https://example.com/issue/456)).

### Fixed

- Bug fix ([#789](https://example.com/issue/789)).

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1 ([#100](https://example.com/issue/100)).
- Feature 2 ([#200](https://example.com/issue/200)).

### Fixed

- Bug fix ([#300](https://example.com/issue/300)).
''';

const linkIssueReferencesMixedResult = '''
## Next release

### Added 

- Some new feature ([#123](https://example.com/issue/123)).
- Already linked [#456](https://example.com/456).

### Fixed

- Bug fix ([#789](https://example.com/issue/789)).
- Another fix [#999](https://example.com/999).

## v0.8.0+4064 - 2021-09-24

### Added

- Feature 1 ([#100](https://example.com/issue/100)).
''';
