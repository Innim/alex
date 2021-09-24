## 0.4.3-dev.0 - 2021-09-23

* `l10n import_xml` support for new Google Play naming: just base filename, without translation id and locale.

## 0.4.2-dev.0 - 2021-08-16

* `pub get` before code generation.

## 0.4.1-dev.0 - 2021-08-03

* New command: `alex pubspec get` - used to get dependencies. It's useful for get dependencies in project with inherit packages, or in repository with multiple packages.
* Alias `pub` for `pubspec` command.

## 0.4.0-dev.0 - 2021-07-30

* New command: `alex pubspec update` - used for update dependency. It's useful for update git dependencies.
* [release] Prints release notes and changelog at the end of successful release.
* [release] Mark required for release notes langs with `*`.

## 0.3.9 - 2021-06-17

* Auto `pub get` on `l10n` `extract` and `generate` commands.

## 0.3.8-dev.3 - 2021-06-11

* Support for Norwegian locale as `nb`.

## 0.3.8-dev.2 - 2021-04-25

* Convert `iw` to `he` for files from Google Play.
* Auto define target locale with region when locale from Google Play contains only lang code.
* Fails run if key is not found for iOS localization files.

## 0.3.8-dev.1 - 2021-04-14

* Added support for `no` locale for iOS (use `nn-NO`).
* Fixed: exceptions in from_xml doesn't handles properly.
* Fixed: `_requireTargetFile()` may return a not existed file.

## 0.3.7-dev.2 - 2021-04-12

* Fixed: RangeError if old file shorter than header.

## 0.3.7-dev.1 - 2021-04-02

* `import_xml` imports only existing locales by default.
Use `--new` argument if you want to import all locales.
* Fixed: `from_xml` did not strip escape slashed with double quotes.

## 0.3.6-dev.5 - 2021-03-26

* Fixed: Changes check for arb files doesn't work on Windows.
* Fixed: Corrupt newline symbols when generate arb on Windows.

## 0.3.6-dev.4 - 2021-03-23

* Fixed: comment before `xml` tag breaks xml file.

## 0.3.6-dev.3 - 2021-03-12

* Fixed: doesn't create file from xml if one not exit.
* Fixed: `to_xml` doesn't consider that locale on backend may be in different format. 

## 0.3.6-dev.2 - 2021-03-11

* L10n: Command `from_xml` updates `.strings` and `.arb` files only if there are changes.

## 0.3.6-dev.1 - 2021-03-11

* L10n: Command `from_xml` for iOS supports all files, not only `InfoPlist.strings`.
* L10n: Command `to_xml` supports iOS localization `.strings` files.
* L10n: Print base ARB when alex search for meta, if meta for key was not found.

## 0.3.5-dev.2 - 2021-03-10

* Error if key has parameters in original file, but doesn't have any in translation.
* Verification of parameters, that was translated by mistake
(previous version doesn't check parameters with non Latin symbols).

## 0.3.5-dev.1 - 2021-03-05

* L10n: New target `json` in `from_xml` command. Used to apply translations for backend.
* **Fixed**: Invalid name when import all files.
* Support for zh locales for iOS.

## 0.3.4-dev.1 - 2021-03-05

* L10n: Command `import_xml` allow to import any file, not only main. Single or all at once.

## 0.3.3-dev.1 - 2021-02-15

* Release: Do not require changelog for locale is it has default.

## 0.3.2-dev.1 - 2021-02-08

* L10n: Command `import_xml` supports custom xml file names format.
* Added `innim_lint` analysis ruleset.

## 0.3.1-dev.2 - 2021-01-25

* Fixed: can't get file from assets on macOS.

## 0.3.1-dev.1 - 2021-01-25

- L10n: Command `import_xml` to import translations from Google Play
to the projects's xml files.

## 0.3.0-dev.6 - 2020-11-12

- L10n: Fixed locale prefix format for iOS in `from_xml`.

## 0.3.0-dev.5 - 2020-10-21

- **Fixed**: Invalid assets path.
- Set minimum textarea height as 5 lines for a release notes.
- "v" prefix removed from branch name/tag.

## 0.3.0-dev.1 - 2020-10-15

- Release: New **Release** feature! Just execute `alex release start` and enjoy 🚀

## 0.2.5-dev.2 - 2020-10-07

- L10n: Fixed locale prefix format for Android in `from_xml`.

## 0.2.5-dev.1 - 2020-10-06

- L10n: `from_xml` supports `ru_RU` format for locales.
- L10n: generation in release mode.
- Pass `--verbose` argument in `pub run` command, if verbose enabled.

## 0.2.4-dev.1 - 2020-09-16

- L10n: handled Android restricted locale names.

## 0.2.3-dev.1 - 2020-09-16

- L10n: Remove escape slashes for strings from xml.

## 0.2.2-dev.1 - 2020-09-08

- Run pub commands prints output immediate (during invocation).
- Run pub commands prints std output even if it's failed.

## 0.2.1-dev.1 - 2020-09-07

- Export json localization (for backend) to xml.

## 0.2.0-dev.2 - 2020-09-04

- Fixed fail to run l10n commands on Windows.

## 0.2.0-dev.1 - 2020-09-03

- Import translations from xml.

## 0.1.0-dev.2 - 2020-08-14

- Working with localization: extract, generate and export to xml.
