# alex

[![pub package](https://img.shields.io/pub/v/alex)](https://pub.dev/packages/alex)
[![Analyze & Test](https://github.com/Innim/alex/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/Innim/alex/actions/workflows/dart.yml)
[![innim lint](https://img.shields.io/badge/style-innim_lint-40c4ff.svg)](https://pub.dev/packages/innim_lint)

**alex** - command line tool for working with Flutter projects.

## Getting started

### Installing

It is recommended to install the package globally and use it as an executable.

You can install the package from the command line with Flutter:

```bash
$ flutter pub global activate alex
```

And follow the instructions after installation (on Unix systems, you may need to modify your PATH variable).

Once installed, you can run commands with:

```bash
$ alex
```

Check the installed version with:

```bash
$ alex --version
```

If you encounter issues during installation or while running alex, see the [Problem Solving](#problem-solving) section.

#### Updating

To update alex you can use the command:

```bash
$ alex update
```

Or, if you want, you can update alex by executing the same command as for installing:

```bash
$ flutter pub global activate alex
```

To check for updates, you can use the command:

```bash
$ alex update --check
```

See [Commands > Update](#update).


### Usage

`alex` is working in the current directory. So if you want to work with a specific project, you should run the command in project's root directory.

#### Configuration

To provide more convenient way to work with project, `alex` can use some configuration.
You can define configuration in your project's `pubspec.yaml`, section  `alex`,
or in separate file `alex.yaml`.

You can see all configuration options and it's default values in the example config [`/alex.yaml`](./alex.yaml).

More about specified configuration parameters - in modules descriptions in the [Commands](#commands) section.

## Commands

### Release

Manage app releases with automated version control, changelog updates, and build processes.

```bash
$ alex release <command>
```

#### Start release

Start a new release process using gitflow:
- checkout and create release branch from `develop`
- increment version number
- update CHANGELOG.md
- validate translations (optional)
- run pre-release scripts (if configured)
- generate release notes for CI/CD (with ChatGPT if API key is configured, see [Global settings](#global-settings))
- create local builds (optional)
- finish release and merge to `master`

```bash
$ alex release start
```

_Note: You can change GIT branches, localization parameters, CI/CD and other settings in your project's [configuration](#configuration)._

**Options:**

- `--check_locale=<LOCALE>` (`-l`) - Locale to check before release if translations exist for all strings. If not specified, "en" locale will be checked.
- `--skip_l10n` (`-s`) - Skip translations check during release.
- `--increment=<PART>` (`-i`) - Increment a part of the version **of this release** before it's started: `patch`, `minor` or `major`. Build number is kept as is. If not specified, the current version is released as is.
- `--local` (`-b`) - Run local release build for Android and iOS platforms.
- `--entry-point=<path>` (`-e`) - Entry point of the app (e.g., lib/main_test.dart). Only for local release builds.
- `--platforms=<PLATFORMS>` (`-p`) - Target build platforms: ios, android. You can pass multiple platforms separated by commas. Defaults to "android,ios". Only for local release builds.
- `--target-path=<DIR_PATH>` (`-t`) - Target directory to copy build artifacts to. Only for local release builds.

**Local builds:**

Before every local build `alex` cleans the output directory of the target platform
(`build/app/outputs/bundle` for Android and `build/ios/ipa` for iOS),
and after the build it checks that exactly one artifact was created there.
So the release fails with an explanation if the build has finished successfully,
but no distribution file was produced — for example, when an Xcode archive was created,
but the export of an `.ipa` failed.

If `--target-path` is defined, the artifact is copied to that directory and renamed
by the pattern `<name>_v<major>.<minor>.<patch>_<build>.<aab|ipa>`,
for example `sundry_v0.1.2_3.ipa`.
By default `<name>` is a project name from `pubspec.yaml`,
but you can define another one in your project's [configuration](#configuration):

```yaml
build:
    name: sundry
```

Characters which are not allowed in a file name are replaced with `_`.

The target directory must be outside of the repository or must be ignored by git,
otherwise the artifacts would be added in the release commit by `git add -A`.
This is checked before the release is started, along with the write access to the directory,
so the release will not be published if an artifact can't be copied.

**Version increment:**

By default the version from `pubspec.yaml` is released as is,
and after the release is finished a patch and a build number are incremented
and committed in `develop` for the next release: `1.2.3+4` is released,
and `develop` continues with `1.2.4+5`.

If it turns out at the release time that the release should be a minor
or a major one, pass `--increment` (`-i`).
The version is incremented **before** the release is started,
so the release branch, `CHANGELOG.md`, the tag and build artifacts
all use the new version. A build number is kept as is —
it's already prepared for this build:

| `-i`      | Released version | Version in `develop` after the release |
|-----------|------------------|----------------------------------------|
| _not set_ | `1.2.3+4`        | `1.2.4+5`                              |
| `patch`   | `1.2.4+4`        | `1.2.5+5`                              |
| `minor`   | `1.3.0+4`        | `1.3.1+5`                              |
| `major`   | `2.0.0+4`        | `2.0.1+5`                              |

A pre-release suffix is kept as is.

If the version was already raised during the work on the task
(see [`alex pubspec version`](#version)), then nothing should be passed
at the release time — the current version is released.

**Pre-release scripts:**

You can define pre-release scripts in your project's [configuration](#configuration):

```yaml
scripts:
    pre_release_scripts_paths: [ 'tools/generate_rates_cache.dart' ]
```

These scripts will be executed before the release process starts.

**Examples:**

Basic release (default mode):
```bash
$ alex release start
```

Local build for manual upload to store or any other distribution:
```bash
$ alex release start --local
```

Release with custom entry point and specific platform:
```bash
$ alex release start --local --entry-point=lib/main_dev.dart --platforms=android
```

Local build with copying artifacts to a specific directory:
```bash
$ alex release start --local --target-path=../builds/sundry
```

Skip translations check:
```bash
$ alex release start --skip_l10n
```

Release as a minor version (`1.2.3+4` is released as `1.3.0+4`):
```bash
$ alex release start --increment=minor
```

### Feature

Work with feature branches and issues.

```bash
$ alex feature <command>
```

or

```bash
$ alex f <command>
```

#### Finish feature 

Finish feature by issue id:
- merge feature branch into `develop`;
- update CHANGELOG;
- delete feature branch from remote;
- merge `develop` in `pipe/test`.

```bash
$ alex feature finish --issue={issueId}
```

or

```bash
$ alex f f -i{issueId}
```

Also you can run command without issue id:

```bash
$ alex f f
```

Then alex will print all current feature branches and ask for issue id in interactive mode.

If you have a problem with interactive mode (for example encoding issues on Window),
you can provide changelog line as an argument:

```bash
$ alex f f -i{issueId} -c"Some new feature"
```

It's important to use double quote (`"`) on Windows, but on macOS or Linux you can also use a single quote (`'`).

### l10n

Work with localization files.

#### Extract string to ARB

```bash
$ alex l10n extract
```

#### Generate Dart code by ARB

```bash
$ alex l10n generate
```

#### Generate XML for translation

```bash
$ alex l10n to_xml
```

Also you can export json localization to xml.
Json localization can be used for a backend localization.

```bash
$ alex l10n to_xml --from=json --source=/path/to/json/localization/dir
```

Also you can export only difference (new and changed strings) to xml.
You should specify the path to the directory for files with changes.

```bash
$ alex l10n to_xml --diff-path=/path/to/files/with/changes/diffs/
```

#### Check translations for all strings

To check all translations for all locales, you can use the command:

```bash
$ alex l10n check_translations
```

or just:

```bash
$ alex l10n check
```

If you want to check translations for a specific locale, you can use the `--locale` option:

```bash
$ alex l10n check --locale=en
```

Before running checks, the command runs `pub get` and verifies that it didn't introduce any
uncommitted changes in the repository. By default it just prints a warning in such a case. Two optional
flags are useful on CI:

```bash
$ alex l10n check --print-changed-files --fail-on-changed-files
```

* `--print-changed-files` — print the list of changed files (only paths, not their content);
* `--fail-on-changed-files` — exit with code `11` instead of printing a warning,
  so CI can rely on the exit code instead of parsing the output.

#### Import translations from XML

It's for working with translations from Google Play.

You can export xml translations to the project arb translations:

```bash
$ alex l10n from_xml
```

Also you can export to the Android localization:

```bash
$ alex l10n from_xml --to=android
```

And to the iOS localization:

```bash
$ alex l10n from_xml --to=ios
```

Localization xml files for iOS should start with `ios_` prefix.

#### Import translation from Google Play to project XML files

When you download and unzip translations from Google Play,
you need to import them in project's xml files. You can 
copy it all manually, but it's very inconvenient.
So you can use the command `import_xml` to do it.

```bash
$ alex l10n import_xml --path=path/to/dir/with/translations
```

If the files have the suffix `_diffs` then they will be imported as a list of changes.


#### Cleanup XML files

Remove unused strings from XML files. Check ARB files for all keys and remove
unused strings from XML files for all locales.

```bash
$ alex l10n cleanup_xml
```

### Code 

Work with code.

#### Generate code

Generate `JsonSerializable` and other.

```bash
$ alex code gen
```

### Pubspec

Work with pubspec and dependencies.

```bash
$ alex pubspec <command>
```

or 

```bash
$ alex pub <command>
```

#### Update dependency

Update specified dependency. It's useful when you want to update
dependency for git. 

```bash
$ alex pubspec update
```

and input package name. Or define it right in a command:

```bash
$ alex pubspec update -dPACKAGE_NAME
```

#### Get dependencies

Run `pub get` for all projects/packages in folder (recursively). It's useful
when you have multiple packages or project and package in single repository.

```bash
$ alex pubspec get
```

or 

```bash
$ alex pub get
```

#### Version

Increment the version in `pubspec.yaml`.

```bash
$ alex pubspec version <part>
```

where `<part>` is `patch`, `minor` or `major`.

**Only the version is changed, a build number is kept as is**, because usually
it's already prepared for the next build. Pass `--build` (`-b`) to increment
the build number (after `+`) too. A pre-release suffix is always kept as is.

| Command                                | `1.2.3+4` becomes |
|----------------------------------------|-------------------|
| `alex pubspec version patch`           | `1.2.4+4`         |
| `alex pubspec version minor`           | `1.3.0+4`         |
| `alex pubspec version major`           | `2.0.0+4`         |
| `alex pubspec version minor --build`   | `1.3.0+5`         |

Use it when it becomes clear during the work on a task that the next release
should be a minor or a major one — raise the version right away, and then
release it as usual with `alex release start`.
If you realize it only at the release time, use the `--increment` option
of the [`release start`](#start-release) command instead.

The command changes `pubspec.yaml` in the current directory
and doesn't commit anything.

### Update

Manage updates for `alex`.

To update `alex` to the latest version:

```bash
$ alex update
```


To check if a new version is available:

```bash
$ alex update --check
```

### Global settings

Set global settings for alex.

Currently supported settings:

- `open_ai_api_key` - OpenAI API key for using ChatGPT features.

#### Set settings

Allow to set setting's value.

```bash
$ alex settings set <name> <value>
```

For example:

```bash
$ alex settings set open_ai_api_key abc123
```

### Custom Commands

Define your own custom commands to automate repetitive workflows, combine multiple operations, or create project-specific shortcuts.

Custom commands are configured in `alex_custom_commands.yaml` file in your project root.

```bash
$ alex custom <command>
```

> **⚠️ SECURITY WARNING**
>
> Custom commands can execute arbitrary programs, scripts, and shell commands. **NEVER** use custom command YAML files from untrusted sources!
>
> Malicious YAML files can:
> - Delete or modify your files
> - Steal sensitive information (credentials, API keys, etc.)
> - Install malware or backdoors
> - Compromise your entire system
>
> **Only use custom commands that:**
> - You created yourself, OR
> - You have thoroughly reviewed and understand, OR
> - Come from a trusted source you can verify
>
> When in doubt, manually inspect the `alex_custom_commands.yaml` file before running any custom commands.

#### Manage custom commands

List all registered custom commands:

```bash
$ alex custom list
```

Show details of a specific command:

```bash
$ alex custom show --name build-release
```

Add a new custom command interactively:

```bash
$ alex custom add
```

Edit the configuration file:

```bash
$ alex custom edit
```

Remove a custom command:

```bash
$ alex custom remove --name build-release
```

#### Configuration

Custom commands are defined in `alex_custom_commands.yaml`:

```yaml
custom_commands:
  - name: build-release
    description: Build release version with all checks
    aliases: [br, release]
    arguments:
      - name: platform
        type: option
        help: Target platform to build for
        abbr: p
        allowed: [android, ios, web]
        required: true
    actions:
      - type: alex
        command: code gen
      - type: exec
        executable: flutter
        args: [build, '{{platform}}', --release]
```

#### Action types

Custom commands support multiple types of actions:

**exec** - Execute shell command or program:
```yaml
- type: exec
  executable: flutter
  args: [clean]
  working_dir: /optional/path  # optional
```

**alex** - Execute existing alex command:
```yaml
- type: alex
  command: l10n extract
  args: [--locale, en]  # optional
```

**script** - Execute Dart script:
```yaml
- type: script
  path: ./scripts/my_script.dart
  args: [arg1, arg2]  # optional
```

**check_git_branch** - Check current git branch and optionally switch to it:
```yaml
- type: check_git_branch
  branch: pipe/app-gallery/prod
  auto_switch: true  # Switch if not on branch (default: true)
  error_message: "Branch does not exist"  # Custom error message
```

**check_git_clean** - Check that git working directory is clean:
```yaml
- type: check_git_clean
  error_message: "There are uncommitted changes"
```

**change_dir** - Change working directory:
```yaml
- type: change_dir
  path: ios
  error_message: "Directory not found"
```

**delete_file** - Delete file or directory:
```yaml
- type: delete_file
  path: Podfile.lock
  recursive: false  # For directories (default: false)
  ignore_not_found: true  # Don't fail if doesn't exist (default: true)
```

**check_file_exists** - Check if file or directory exists:
```yaml
- type: check_file_exists
  path: ios
  should_exist: true  # true to check exists, false to check not exists
  error_message: "iOS directory not found"
```

**copy_file** - Copy a file:
```yaml
- type: copy_file
  source: config.txt
  destination: config_backup.txt
  overwrite: false  # Whether to overwrite if destination exists (default: false)
```

**rename_file** - Rename a file:
```yaml
- type: rename_file
  old_path: old_name.txt
  new_path: new_name.txt
```

**move_file** - Move a file:
```yaml
- type: move_file
  source: file.txt
  destination: archive/file.txt
```

**create_file** - Create a file with optional content:
```yaml
- type: create_file
  path: config.txt
  content: "Environment: production"  # Optional content with variable substitution
  overwrite: false  # Whether to overwrite if file exists (default: false)
```

**create_dir** - Create a directory:
```yaml
- type: create_dir
  path: output
  recursive: true  # Create parent directories (default: true)
```

**delete_dir** - Delete a directory:
```yaml
- type: delete_dir
  path: temp
  recursive: true  # Delete recursively (default: true)
  ignore_not_found: true  # Don't fail if doesn't exist (default: true)
```

**rename_dir** - Rename a directory:
```yaml
- type: rename_dir
  old_path: old_directory
  new_path: new_directory
```

**replace_in_file** - Replace text in file (supports regex):
```yaml
- type: replace_in_file
  path: pubspec.yaml
  find: 'version: \d+\.\d+\.\d+'
  replace: 'version: {{new_version}}'
  regex: true  # Enable regex matching (default: false)
  error_message: 'Failed to update version'
```

**append_to_file** - Append content to end of file:
```yaml
- type: append_to_file
  path: CHANGELOG.md
  content: |
    ## [{{version}}] - {{date}}
    - New release
  create_if_missing: true  # Create file if doesn't exist (default: true)
```

**prepend_to_file** - Prepend content to beginning of file:
```yaml
- type: prepend_to_file
  path: lib/main.dart
  content: '// Copyright (c) 2024\n'
  create_if_missing: false  # Don't create if doesn't exist (default: true)
```

**print** - Print message to console:
```yaml
- type: print
  message: 'Building for {{platform}}...'
  level: info  # info, warning, or error (default: info)
```

**wait** - Wait for specified duration:
```yaml
- type: wait
  milliseconds: 5000
  message: 'Waiting for services to start...'  # Optional message
```

**check_platform** - Verify current operating system:
```yaml
- type: check_platform
  platform: macos  # macos, linux, or windows
  error_message: 'This command only works on macOS'
```

**create_archive** - Create ZIP or TAR.GZ archive:
```yaml
- type: create_archive
  source: build/app/outputs/bundle/release/
  destination: releases/app-v{{version}}.zip
  format: zip  # zip or tar.gz (default: zip)
```

**extract_archive** - Extract ZIP or TAR.GZ archive:
```yaml
- type: extract_archive
  source: downloads/assets.zip
  destination: assets/
```

#### Variable substitution

Actions support variable substitution using `{{variable_name}}` or `${variable_name}` syntax:

```yaml
arguments:
  - name: platform
    type: option
    required: true
actions:
  - type: exec
    executable: flutter
    args: [build, '{{platform}}']
```

#### Using custom commands

Once defined, custom commands work just like built-in alex commands:

```bash
$ alex build-release --platform android
```

Or using an alias:

```bash
$ alex br -p android
```

#### Verbose mode

Custom commands support the `--verbose` flag to see detailed execution information:

```bash
$ alex build-release --platform android --verbose
```

This will show:
- Each action being executed
- Detailed progress for file operations
- Variable substitution values
- Git operations details

See `alex_custom_commands.yaml.example` in the repository for more examples.

## Problem solving

### Command not found

If, when trying to run `alex`, you see an error like this:

```
~/Development/flutter/.pub-cache/bin/alex: line 17: pub: command not found
```

You can fix it by editing the file mentioned in the error (in this example: `~/Development/flutter/.pub-cache/bin/alex`).
You need to se `dart pub` or `flutter pub` instead of `pub`. So replace the line `pub global run alex:alex "$@"` with `dart pub global run alex:alex "$@"` 
(or `flutter pub global run alex:alex "$@"`, depending on your setup).

Save the file, and you’re good to go.

### Cyrillic Encoding Issues on Windows


When entering Cyrillic characters (e.g., while saving a changelog), they may be displayed incorrectly or not at all.

To fix this, it is recommended to use the external Git Bash terminal (C:\Program Files\Git). In its settings, set the character encoding to UTF-8:
Options -> Text -> Character set -> UTF-8.

![](https://raw.githubusercontent.com/Innim/alex/master/readme_images/bash.png)

## Development

Do not forget regenerate code when updating the version:

```bash
$ alex code gen
```

or 

```bash
$ dart pub run build_runner build --delete-conflicting-outputs
```