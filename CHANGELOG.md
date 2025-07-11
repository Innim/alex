## 1.8.0+3

[L10n] `check_translations`: prints changes if there are any in the repository before checking translations.

## 1.8.0+2

[L10n] `check_translations`: returns exit code `10` if some checks failed.

## 1.8.0+1

~~[L10n] `check_translations`: returns exit code `10` if some checks failed.~~ (broken, use `1.8.0+2`).

## 1.8.0

[L10n] `check_translations` (formerly `check_translate`):

* **BREAKING CHANGE**: Now it checks for all locales by default, not only `en`. You can specify locale with `-l` or `--locale` argument.
* **Power up the command with additional checks**:
  * Check if all strings from the localization file have translations in the specified locale 
  (previous check, but with ability to check all locales).
  * Check if all strings from the localization file was sent for translation.
  * Check if all strings from base XML file have translation in XML for the specified locale.
  * Check if all strings from XML for the specified locale are imported to ARB for this locale.
  * Check if XML for the specified locale has redundant strings that are not in the localization file.
  * Check if there are not duplicated keys in XML for the specified locale.
  * Check if all code is generated for the specified locale.
* Ensure that GIT repository is clean before checking translations. Reset all changes after command execution.

## 1.7.0

[L10n]
* New command `l10n cleanup_xml` to remove unused strings from XML files.

## 1.6.22

[L10n] 
* `import_xml`: Added suggestion when importing archive file with wrong content.

## 1.6.21

[L10n] 
* `from_xml`: Fail if there are duplicated keys in the imported file.

## 1.6.20+1

* [L10n] Fixed: empty output on failed extract command in some cases.

## 1.6.20

* Fail if there are warning during extraction to arb. Affects `l10n extract`, `l10n check_translate`, `release start`.

## 1.6.19

[L10n] 
* `import_xml`: Fix error in the log message about total project locales count.
* `from_xml`: Handle new line symbols for json target.

## 1.6.18

* [L10n] `from_xml` added missing characters for validator checking.

## 1.6.17

[L10n] `import_xml`
* Support name of the directory without `_diffs` suffix. Therefore, now you can import directory with files like this: `intl/intl_diffs_es.xml`;
* Add warning when not all locales was imported.
* **Fixed**: invalid log about locale.
* Refactor of some console output. 

## 1.6.16

* [L10n] `generate` always generate main messages file in the same order.

## 1.6.15

* [L10n] `from_xml` validates strings for Cyrillic and other inappropriate characters for locales,
where Latin is required. Added config parameter `require_latin` (has default value).
* README: "Updating" section.

## 1.6.14

[L10n] `import_xml`:
* More relevant suggestion for `--target` value when failed to find appropriate file for import.
* **Fixed**: Invalid `--diff` flag name in suggestion (should be `--diffs`).

## 1.6.13

* **Fixed**: Program always have 0 exit code, even when execution failed.
* [L10n] `from_xml`:
  * Clearer and more detailed error message if there is no imported key in the base .strings file. Also added suggestions for fixes.
  * Refactor output strings: "export" replaced with more consistent in this context "import".

## 1.6.12

[L10n] `import_xml`:
* Detailed error explanation with a suggestion if can't find appropriate file for import.
* **Fixed**: null check error when imported file is incorrect.

## 1.6.11

* **IMPORTANT** [L10n] `from_xml`: Single quotes in the xml now escaped with another single quote for arb target. 
  See [documentation](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization#escaping-syntax) for details. **Remove** any manual escapes for `'` from xml if you have any.
* Ignore `pubspec.yaml` from hidden folders (like `.dart_tools/`).
* Root `pubspec.yaml` is always the first.
* [L10n] `import_xml`: Prints total locales count in project at the end.
* [L10n] `from_xml`: Message on success for json target.

## 1.6.10

* Check for updates and message about a new version in the output.

## 1.6.9

* [L10n] `import_xml`: Support for `--locale` argument.
* [L10n] `import_xml` **Fixed**: Failed to import diff for not main localization files.
* [L10n] `import_xml` **Fixed**: Incorrect locations fallback (can change language, not only pick up region).

## 1.6.8

* [L10n] `import_xml`: Support for .zip from Google Play as a source (argument `--path`). 
* [L10n] `import_xml`: Automatically detect diffs import for the translation from Google Play with suffix `_diffs`.
* [L10n] `import_xml`: Translations are imported in alphabetical order.

## 1.6.7

* Command to see a current version of alex: `alex --version`.

## 1.6.6

* [L10n] `import_xml`: Support for explicit diffs import (new argument `--diffs`).
* Readme: fixed "Generate XML for translation" section.

## 1.6.5

* [L10n] `import_xml`: Support for import files with suffix `_diffs` in plane directory structure
(`intl/intl_{locale}/intl_diffs.xml` or `intl_diffs/intl_diffs_{locale}/intl_diffs.xml`);

## 1.6.4

* [L10n] `to_xml`: Export new lines as `\n`.
* [L10n] `from_xml` **Fixed**: Adds slash for `\n` on import.

## 1.6.3+1

* [Release] Small help fix.

## 1.6.3

* [Release] Local build now build for Android and iOS by default. See parameter `--platforms`.

## 1.6.2

* [L10n] `to_xml`:
  * Prints info about written diffs.
  * Do not create empty diff file.
* [L10n] `import_xml`:
  * Prints info about imported diffs.
  * Handle diff file with locale at the end.
  * Add documentation about import diffs.
* [L10n] Common prints improvements.

## 1.6.1

* [Release] Support for provide scrips to run before release.

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
