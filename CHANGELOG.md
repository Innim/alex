## Next

* [Code] `check`: new `--gen` flag - the code generation is run before the other gates, and the gate fails with exit code `13` if it has changed anything. It's the classic failure: a model or a bloc event was changed, `build_runner` was not run, and the error shows up somewhere else. Uncommitted changes don't break the check: the content of the changes is compared, not just the list of the changed files, so it works in the middle of the work, not only on a clean tree. The generation itself is the same as in `alex code gen` - with subprojects and pub workspaces.

## 1.15.1

* [Agents] `init`: the section written in `CLAUDE.md` / `AGENTS.md` contains only what is stable, because the file is committed and shared by the whole team: no local paths (the project root was written as an absolute path of the machine where the command was run), no path to the alex config, no package version and no exact Flutter version (the file would have to be regenerated after every build and every SDK update - the fact that the project uses FVM is what matters). Only the branches that really exist in the repository are reported: every branch has a default value in the config, so a project can have no such branch at all (`pipe/test` is the usual case). Both local and remote branches are checked, without a network request; if there is no repository, then all the configured branches are listed as before. `alex info` still reports all of it - it's a live query, not a file to commit - and marks the configured branches that are not found.
* [Common] A command run in a project without the alex configuration fails with a handled error and exit code `3` instead of an unhandled exception: the message says that the project is not configured and what to create. If the config is found, but can't be loaded (a broken YAML, an empty `alex` section), then the message contains the file and the reason - it's not reported as a missing config anymore. A `pubspec.yaml` without the `alex` section is not treated as a broken config, it's just a project that doesn't use alex. A broken config is not silently replaced by another one anymore: if `alex.yaml` can't be loaded, then the `alex` section of `pubspec.yaml` is not used instead of it - the file the user edits is the file alex must run with.

## 1.15.0

* New command `alex pubspec version <patch|minor|major>` (alias `alex pub version`) — increments the version in `pubspec.yaml`. By default only the version is changed and a build number is kept as is (usually it's already prepared for the next build); pass `--build` (`-b`) to increment the build number too (#12).
* [Release] `start`: new `--increment` (`-i`) option (`patch`, `minor` or `major`) to increment the version **of this release** before it's started, keeping the build number: `1.2.3+4` is released as `1.3.0+4` with `-i minor`. The release branch, `CHANGELOG.md`, the tag and build artifacts use the new version. Without the option nothing changes — the current version is released as is. After the release a patch and a build number are incremented in `develop` as always, and the new version is printed in the end (#12).
* [Release] `start`: fixed a failure of a local iOS build (`--local`), when alex reported that the artifact was placed in an unexpected directory, though the `.ipa` was built correctly. `flutter build ipa` prints two `✓ Built` lines — for the Xcode archive and for the IPA itself — and alex checked the first one. Now the line with a path in the build output directory is used.
* [Release] `start`: if the release failed, then all the changes made in the repository are rolled back automatically: uncommitted and untracked changes are discarded, release branch and tag are removed (only if they didn't exist before the release), and `develop` and `master` are restored to the state before the release. Every step is printed, and if the rollback itself fails, then instructions for a manual cleanup are shown. Nothing is rolled back as soon as the push is started — a push can update the remote even if it failed as a whole, and a published release should not be rewritten — in that case alex only reports that the release should be finished or reverted manually.
* [Release] `start`: fix the length limit of the release notes in the form. The limit is enforced by alex now, instead of the `maxlength` attribute: a browser counts a newline as CRLF (2 characters), so a note with N newlines was cut N characters earlier than the store allows, and it was impossible to type anything while the counter still showed a value below the limit. The counter shows the number of characters as the store counts them, and it's highlighted if the value is longer than the limit.
* **Fixed**: alex hangs if a command it runs asks for an input. For example, `alex code gen` stopped with no output when `fvm` asked to install a missing Flutter SDK. Such a question can't be answered anyway, because the command gets a pipe instead of the terminal, so its input is closed right after the start now, and the command fails with its own message instead of hanging.
* **Fixed**: the output of a command could be lost, so a failed command could be reported without its error message. Now alex waits for the output to be fully read before it handles the result.
* [Code] New command `check`: runs the quality gates - analyze, tests and (optionally, with the `--build` flag) a debug build of the platform target. Output of the commands is filtered from noise, a short verdict is printed for each gate. Exit code is `0` if all gates passed, `10` if analyze failed, `11` if tests failed, `12` if build failed. Flags `--analyze-only`, `--test-only` and `--fail-fast` are supported, arguments after `--` are passed to the test command. Build target and additional noise patterns can be defined with the new `code.check` config section.
* [Common] New `--format=json` option (supported by `code check`, `info`, `agents` and `l10n check_translations` commands): a command prints a single JSON object with a machine readable report in the standard output, all other messages - including the update banner - go to the error output.
* [Agents] New command group `agents` with the `guide` subcommand: prints a short guide of alex for an AI agent or a script - the rules (config discovery, machine readable output, exit codes, interactive commands) and all commands with their options and exit codes. The guide is generated from the commands tree of the installed version, so it can't get outdated. Supports a command path argument to print a part of it (`alex agents guide l10n`) and `--format=json` for a structured index.
* [Agents] New command `agents init`: adds or updates the alex section in the agent instructions of the project (`CLAUDE.md`, `AGENTS.md` and alike), so an agent learns about alex from the file it reads first. The section describes the project (package, FVM, locales, l10n paths, branches) and the commands to use with their exit codes, and is generated from the alex config, `pubspec.yaml` and the commands tree. Only the content between the `<!-- alex:begin -->` and `<!-- alex:end -->` markers is changed. Files are taken from the new `agents.files` config option, the `--file` (`-f`) option, or `CLAUDE.md`/`AGENTS.md` if they exist. With the `--check` flag nothing is changed and the command fails with exit code `10` if some file is missing or outdated.
* [Common] New `--non-interactive` flag for every command that can ask a question in the standard input (`feature finish`, `pubspec update`, `custom add`). With the flag a command fails with an explanation of the option to pass instead of waiting for an answer that a script can't give. `feature finish` checks everything it would ask about before it starts, so it fails before the branch is merged, not after.
* [Feature] `finish`: new `--section` option (`added`, `fixed` or `pre-release`) to define the section of `CHANGELOG.md` for the entry, instead of choosing it interactively. Default is `added`, as for an empty answer.
* **Fixed** [Feature] `finish`: the command looped forever asking for an issue id when there was no input at all (a closed stdin in a script). Now it fails with a message.
* [L10n] `check_translations`: new `--format=json` option - a single JSON object with the result of every check (a stable `id`, the title, the status, and the problems with locales and keys for the failed ones) is printed in the standard output, so CI or an AI agent doesn't have to parse the human readable report. The list of files changed after `pub get` is reported in JSON too - both when it fails the command and when it's just a warning, so CI can see that the dependencies are not in sync.
* [Common] `--format=json`: an error object (with `ok: false`, the exit code and the message) is printed in the standard output for any failure - not only when a command has finished with a result. It covers an error of a command, a failure of the arguments parsing and a failure before the command is started, so a script always gets a JSON object to parse.
* [Info] New command `alex info` (alias `alex facts`): prints the facts about the project - package and version, path to the alex config, packages of a multi-package project, Flutter version pinned with FVM, locales (by the ARB files) and localization paths, git branches. Supports `--format=json`, so a script or an AI agent can get all of it with a single call instead of reading several files.

## 1.14.0

* [Release] `start`: new `--target-path` (`-t`) option to copy artifacts of a local release build (`--local`) to the specified directory. Artifacts are renamed by the pattern `<name>_v<major>.<minor>.<patch>_<build>.<aab|ipa>` (for example `sundry_v0.1.2_3.ipa`), where `<name>` is a project name from `pubspec.yaml` or the new `build.name` config option. The target directory should be outside of the repository or should be ignored by git, so artifacts can't get in the release commit; it's checked, as well as the write access, before the release is started.
* [Release] `start`: output directory of a local build is cleaned before the build, and after the build alex checks that exactly one artifact was created there. Now the release fails with an explanation instead of finishing successfully when the build produced no distribution file — for example, when an Xcode archive was created, but the export of an `.ipa` failed.

## 1.13.0

* [L10n] `check_translations`: new `--print-changed-files` flag to print the list of files changed after `pub get` (only paths, not their content). Off by default, so local runs are not flooded.
* [L10n] `check_translations`: new `--fail-on-changed-files` flag to fail with exit code `11` instead of printing a warning when some files were changed after `pub get`. Off by default; lets CI rely on the exit code instead of parsing the output.

## 1.12.0

* [Code] `gen`: in a pub workspace, run code generation once from the workspace root with the `--workspace` flag when the resolved `build_runner` version supports it (>= 2.11.0). Can be disabled via the new `code.use_workspace` config option (`alex.yaml` or the `alex:` section of `pubspec.yaml`).

## 1.11.2

* [L10n] `check-translation`: in verbose mode, print the list of changed files and the error details when the clean-status check fails after `pub get`, to make diagnosing dependency mismatches easier.

## 1.11.1

* [Feature] `finish`: new `--squash` (`-s`) flag to squash all feature commits into a single commit when merging into develop. Useful for tasks like golden tests updates.
* **Fixed** [L10n] `from_xml`: false-positive "No parameters found" error for `one`/`two` plural variants when the target locale legitimately omits the count parameter (e.g. Arabic "كل يوم" / "كل يومين"). Other plural quantities (`zero`, `few`, `many`, `other`) are still validated as before.

## 1.11.0

* [Feature] `finish`: append issue references as a markdown link (`[#N](url/N)`) when `issue_url` is set in alex config; falls back to the plain `(#N)` suffix otherwise.
* New command `alex changelog update-issue-links` (alias `cl uil`) — replaces plain `(#N)` issue references in `CHANGELOG.md` with markdown links built from `issue_url`. Reports an error if `issue_url` is not configured.
* New optional config option `issue_url` (in `alex.yaml` or the `alex:` section of `pubspec.yaml`).

## 1.10.1

* [Feature] `finish`: skip appending issue number suffix if the changelog line already contains a markdown link to the issue (e.g. `[#1234](...)`).

## 1.10.0

* **New feature**: Custom commands support! Define your own commands in `alex_custom_commands.yaml` to automate workflows.
  - Execute shell commands, alex commands, or Dart scripts
  - Support for command arguments (options and flags)
  - Variable substitution in actions using `{{var}}` or `${var}` syntax
  - Commands management: `alex custom list`, `add`, `show`, `edit`, `remove`, `check`
  - **Advanced actions** for conditional logic and file operations:
    - `check_git_branch` - Check/switch git branch
    - `check_git_clean` - Verify no uncommitted changes
    - `check_platform` - Verify current OS (macos/linux/windows)
    - `change_dir` - Change working directory
    - `check_file_exists` - Verify file existence
    - `copy_file` - Copy files
    - `rename_file` - Rename files
    - `move_file` - Move files
    - `create_file` - Create files with content
    - `create_dir` - Create directories
    - `delete_file` - Delete files
    - `delete_dir` - Delete directories
    - `rename_dir` - Rename directories
    - `replace_in_file` - Replace text in files (with regex support)
    - `append_to_file` - Append content to files
    - `prepend_to_file` - Prepend content to files
    - `print` - Print messages to console
    - `wait` - Wait for specified duration (in milliseconds)
    - `create_archive` - Create ZIP/TAR.GZ archives
    - `extract_archive` - Extract archives
  - **Verbose mode** support with `--verbose` flag for detailed execution logs
  - See `alex_custom_commands.yaml.example` for examples

## 1.9.4

* [Code] `code gen` command supports run generation for subproject from root folder.

## 1.9.3

* **Fixed**: `alex update` command not working.
* Command `alex update check` replaced with `alex update --check`.

## 1.9.2

* [pubspec] `get`: Skip not valid pubspec files. Different result output when pubspec files are not found.
* README: added "Release" and "Update" sections. Improvements and fixes.

## 1.9.1

* New command `alex update check` to check if there are updates available for **alex**.

## 1.9.0

* New command `alex update` to update **alex** to the latest version.

## 1.8.7

[Pub] `get`:
* Added support for **workspaces**. See [documentation](https://dart.dev/tools/pub/workspaces).

Minimum SDK version is now **3.0.0**.

## 1.8.6+1

* **Fixed**: `from_xml` write `@@locale` at second place in ARB files, but `extract` at first.

## 1.8.6

[L10n]
* Auto adding `@@locale` to ARB files.

## 1.8.5

[L10n] `to_xml`:
* Base XML file now formatted with 2 spaces indent.

## 1.8.4

[L10n] `import_xml`:
* Hint and more detailed log for skipped keys if they are not in the base file.

## 1.8.3

[L10n] `check_translations`:
* More cleaner output for problems with similar keys in different locales.
* Print number of checks and total checks for each check output.

## 1.8.2

* **Fixed**: Double log for intl commands.
* More cleaner output for `l10n generate` and some other commands.

## 1.8.1+1

* **Fixed**: Incorrect error message when there are uncommitted changes.

## 1.8.1

* Handle temporary lock errors when opening local store boxes.

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
