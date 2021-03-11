## 0.3.6-dev.2 - 2021-03-12

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
