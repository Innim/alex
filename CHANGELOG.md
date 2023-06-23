## 1.6.0-alpha.2

* [Release] Parameter `--entry-point` to define the entry point for local build.

## 1.6.0-alpha.1

* Using ChatGPT to generate Release Notes (only en and ru locales). You should set global setting `open_ai_api_key` to use it.
* Added global settings. You can set it using new `alex settings set` command.

## 1.5.4

* Load config recursive by default. 
* **Fixed**: broken release command with localization.
* **Fixed**: broken release command with configuration in subfolder.

## 1.5.3

* Support for configuring names for GIT branches.

## 1.5.2+1

* [Release] **Fixed**: failed on empty commit attempt during local build.

## 1.5.2

* [Release] Added flag `--local` for local build.
* [Release] Added flag `--skip_l10n` to skip localization process when release.
* [Release] Added `ci` section in `alex` configuration. Ability to disable CI for project.

## 1.5.1+1

* Fix  "CHANGELOG.md has unknown structure" error when run release start command.

## 1.5.1

* [Release] Automatically generate and commit translations after check before run release.

## 1.5.0

* [L10n] Added `check_translate` command to check for translations for all locale strings.

* [Release] Automatically check translations for locale (en by default) before run release.

## 1.4.1

* [L10n] import and export only difference strings of xml file.

## 1.4.0+2

* [Release] For iOS increased What's New section length to 4000 characters.

## 1.4.0+1

* [L10n] More details in error message if no files for import was found.

## 1.4.0

* [Code] `code gen` command supports run generation for subproject from root folder.

## 1.3.0+1

* Disable output for checking FVM.

## 1.3.0

* Use [`fvm`](https://fvm.app) if installed.

## 1.2.0

* Support for Dart 2.15 hosted dependency short format.

## 1.1.0

* [L10n] Working with alex configuration defined in pubspec.yaml within subfolder.
* Prints stack trace in debug.

## 1.0.6

* [Finish Feature] Removes local feature branch if it's merged in remote.

## 1.0.5+1

* More detailed error when parse XML failed.

## 1.0.5

* Aliases for `l10n` (`l`) and `l10n generate` (`l10n gen`).

## 1.0.4

* Support for SSH GIT remote URL.

## 1.0.3

* [Finish Feature] Returns to the original branch after finish.
* [L10n] Ability to provide different target filename for `import_xml`. 

## 1.0.2

* [Finish Feature] 
  * Adds issue ID for changelog line.
  * **Fixed**: Description for `changelog` argument.

## 1.0.1+2

* `l10n from_xml`:
  * **Fixed**: cast error on ARB/JSON processing.
  * More detailed log on exception in verbose mode.

## 1.0.1+1

* `l10n to_xml`:
  * **Fixed**: cast error on ARB processing.
  * **Fixed**: exceptions during execution are not handled.
  * More detailed log on exception in verbose mode.

## 1.0.1

* `pub update`: 
  * trim dependency name;
  * error if dependency is not found in any of pubspec files.
* L10n: `from_xml` supports `name` argument for `json` target.
* Finish Feature: Ability to provide changelog line as a command argument.

## 1.0.0

* Migrated to null safety.

## 0.5.6

* L10n: `to_xml` supports `locale` argument.

## 0.5.5

* Release Start: check if has build number in version string

## 0.5.4

* Finish Feature: 
  * Ability to provide issue id in interactive mode.
  * List of current feature branches.
  * Check if run command not in project directory.

## 0.5.3

* L10n: `from_xml` allow values without parameters in plurals if original string doesn't have it.
* Finish Feature: Prints message in console if no changelog entered.

## 0.5.2

* L10n: `to_xml` supports string without parameter for plural.

## 0.5.1

* L10n: Support for [intl_generator](https://pub.dev/packages/intl_generator).
* Handle Git merge conflicts.

## 0.5.0

* New command: `alex feature finish` - used to finish feature.
It's merge branches, update changelog and remote feature branch from remote.

## 0.4.3-dev.0

* `l10n import_xml` support for new Google Play naming: just base filename, without translation id and locale.

## 0.4.2-dev.0

* `pub get` before code generation.

## 0.4.1-dev.0

* New command: `alex pubspec get` - used to get dependencies. It's useful for get dependencies in project with inherit packages, or in repository with multiple packages.
* Alias `pub` for `pubspec` command.

## 0.4.0-dev.0

* New command: `alex pubspec update` - used for update dependency. It's useful for update git dependencies.
* [release] Prints release notes and changelog at the end of successful release.
* [release] Mark required for release notes langs with `*`.

## 0.3.9

* Auto `pub get` on `l10n` `extract` and `generate` commands.

## 0.3.8-dev.3

* Support for Norwegian locale as `nb`.

## 0.3.8-dev.2

* Convert `iw` to `he` for files from Google Play.
* Auto define target locale with region when locale from Google Play contains only lang code.
* Fails run if key is not found for iOS localization files.

## 0.3.8-dev.1

* Added support for `no` locale for iOS (use `nn-NO`).
* Fixed: exceptions in from_xml doesn't handles properly.
* Fixed: `_requireTargetFile()` may return a not existed file.

## 0.3.7-dev.2

* Fixed: RangeError if old file shorter than header.

## 0.3.7-dev.1

* `import_xml` imports only existing locales by default.
Use `--new` argument if you want to import all locales.
* Fixed: `from_xml` did not strip escape slashed with double quotes.

## 0.3.6-dev.5

* Fixed: Changes check for arb files doesn't work on Windows.
* Fixed: Corrupt newline symbols when generate arb on Windows.

## 0.3.6-dev.4

* Fixed: comment before `xml` tag breaks xml file.

## 0.3.6-dev.3

* Fixed: doesn't create file from xml if one not exit.
* Fixed: `to_xml` doesn't consider that locale on backend may be in different format. 

## 0.3.6-dev.2

* L10n: Command `from_xml` updates `.strings` and `.arb` files only if there are changes.

## 0.3.6-dev.1

* L10n: Command `from_xml` for iOS supports all files, not only `InfoPlist.strings`.
* L10n: Command `to_xml` supports iOS localization `.strings` files.
* L10n: Print base ARB when alex search for meta, if meta for key was not found.

## 0.3.5-dev.2

* Error if key has parameters in original file, but doesn't have any in translation.
* Verification of parameters, that was translated by mistake
(previous version doesn't check parameters with non Latin symbols).

## 0.3.5-dev.1

* L10n: New target `json` in `from_xml` command. Used to apply translations for backend.
* **Fixed**: Invalid name when import all files.
* Support for zh locales for iOS.

## 0.3.4-dev.1

* L10n: Command `import_xml` allow to import any file, not only main. Single or all at once.

## 0.3.3-dev.1

* Release: Do not require changelog for locale is it has default.

## 0.3.2-dev.1

* L10n: Command `import_xml` supports custom xml file names format.
* Added `innim_lint` analysis ruleset.

## 0.3.1-dev.2

* Fixed: can't get file from assets on macOS.

## 0.3.1-dev.1

- L10n: Command `import_xml` to import translations from Google Play
to the projects's xml files.

## 0.3.0-dev.6

- L10n: Fixed locale prefix format for iOS in `from_xml`.

## 0.3.0-dev.5

- **Fixed**: Invalid assets path.
- Set minimum textarea height as 5 lines for a release notes.
- "v" prefix removed from branch name/tag.

## 0.3.0-dev.1

- Release: New **Release** feature! Just execute `alex release start` and enjoy 🚀

## 0.2.5-dev.2

- L10n: Fixed locale prefix format for Android in `from_xml`.

## 0.2.5-dev.1

- L10n: `from_xml` supports `ru_RU` format for locales.
- L10n: generation in release mode.
- Pass `--verbose` argument in `pub run` command, if verbose enabled.

## 0.2.4-dev.1

- L10n: handled Android restricted locale names.

## 0.2.3-dev.1

- L10n: Remove escape slashes for strings from xml.

## 0.2.2-dev.1

- Run pub commands prints output immediate (during invocation).
- Run pub commands prints std output even if it's failed.

## 0.2.1-dev.1

- Export json localization (for backend) to xml.

## 0.2.0-dev.2

- Fixed fail to run l10n commands on Windows.

## 0.2.0-dev.1

- Import translations from xml.

## 0.1.0-dev.2

- Working with localization: extract, generate and export to xml.
