# alex

[![pub package](https://img.shields.io/pub/v/alex)](https://pub.dev/packages/alex)
[![Analyze & Test](https://github.com/Innim/alex/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/Innim/alex/actions/workflows/dart.yml)
[![innim lint](https://img.shields.io/badge/style-innim_lint-40c4ff.svg)](https://pub.dev/packages/innim_lint)

**alex** - command line tool for working with Flutter projects.

## Getting started

### Installing

It's recommended to install the package globally and use as an executable.

You can install the package from the command line with Flutter:

```
$ flutter pub global activate alex
```

And follow the instructions (you should add PATH variable on unix systems).

Now you can execute commands with

```
$ alex
```

Check the version with:

```
$ alex --version
```

⚠️ **Attention!** If when you try to run `alex` you will see something like:

```
~/Development/flutter/.pub-cache/bin/alex: line 17: pub: command not found
```

In such case you can edit specified file (`~/Development/flutter/.pub-cache/bin/alex` in this example). All you need to change in it - it's use `flutter pub` instead of `pub` or `dart pub`, so replace `pub global run alex:alex "$@"` with `flutter pub global run alex:alex "$@"`, save the file, and you are all set.

#### Updating

To update alex you can use the command:

```
$ alex update
```

Or, if you want, you can update alex by executing the same command as for installing:

```
$ flutter pub global activate alex
```

To check for updates, you can use the command:

```
$ alex update check
```

See [Commands > Update](#update).

#### Fix problems with cyrillic encoding on Windows

When entering Cyrillic characters (while saving changelog) they may not be displayed correctly or may not be displayed at all.
To avoid this, it is recommended to use the external git bash terminal (C:\Program Files\Git), in the settings of which you must specify encoding (Options -> Text -> Character set -> UTF-8).

![](https://raw.githubusercontent.com/Innim/alex/master/readme_images/bash.png)

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

```
alex release <command>
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

```
alex release start
```

_Note: You can change GIT branches, localization parameters, CI/CD and other settings in your project's [configuration](#configuration)._

**Options:**

- `--check_locale=<LOCALE>` (`-l`) - Locale to check before release if translations exist for all strings. If not specified, "en" locale will be checked.
- `--skip_l10n` (`-s`) - Skip translations check during release.
- `--local` (`-b`) - Run local release build for Android and iOS platforms.
- `--entry-point=<path>` (`-e`) - Entry point of the app (e.g., lib/main_test.dart). Only for local release builds.
- `--platforms=<PLATFORMS>` (`-p`) - Target build platforms: ios, android. You can pass multiple platforms separated by commas. Defaults to "android,ios". Only for local release builds.

**Pre-release scripts:**

You can define pre-release scripts in your project's [configuration](#configuration):

```yaml
scripts:
    pre_release_scripts_paths: [ 'tools/generate_rates_cache.dart' ]
```

These scripts will be executed before the release process starts.

**Examples:**

Basic release (default mode):
```
alex release start
```

Local build for manual upload to store or any other distribution:
```
alex release start --local
```

Release with custom entry point and specific platform:
```
alex release start --local --entry-point=lib/main_dev.dart --platforms=android
```

Skip translations check:
```
alex release start --skip_l10n
```

### Feature

Work with feature branches and issues.

```
alex feature <command>
```

or 

```
alex f <command>
```

#### Finish feature 

Finish feature by issue id:
- merge feature branch into `develop`;
- update CHANGELOG;
- delete feature branch from remote;
- merge `develop` in `pipe/test`.

```
alex feature finish --issue={issueId}
```

or

```
alex f f -i{issueId}
```

Also you can run command without issue id:

```
alex f f
```

Then alex will print all current feature branches and ask for issue id in interactive mode.

If you have a problem with interactive mode (for example encoding issues on Window),
you can provide changelog line as an argument:

```
alex f f -i{issueId} -c"Some new feature"
```

It's important to use double quote (`"`) on Windows, but on macOS or Linux you can also use a single quote (`'`).

### l10n

Work with localization files.

#### Extract string to ARB

```
alex l10n extract
```

#### Generate Dart code by ARB

```
alex l10n generate
```

#### Generate XML for translation

```
alex l10n to_xml
```
Also you can export json localization to xml.
Json localization can be used for a backend localization.

```
alex l10n to_xml --from=json --source=/path/to/json/localization/dir
```

Also you can export only difference (new and changed strings) to xml.
You should specify the path to the directory for files with changes.

```
alex l10n to_xml --diff-path=/path/to/files/with/changes/diffs/
```

#### Check translations for all strings

To check all translations for all locales, you can use the command:

```
alex l10n check_translations
```

or just:

```
alex l10n check
```

If you want to check translations for a specific locale, you can use the `--locale` option:

```
alex l10n check --locale=en
```

#### Import translations from XML

It's for working with translations from Google Play.

You can export xml translations to the project arb translations:

```
alex l10n from_xml
```

Also you can export to the Android localization:

```
alex l10n from_xml --to=android
```

And to the iOS localization:

```
alex l10n from_xml --to=ios
```

Localization xml files for iOS should start with `ios_` prefix.

#### Import translation from Google Play to project XML files

When you download and unzip translations from Google Play,
you need to import them in project's xml files. You can 
copy it all manually, but it's very inconvenient.
So you can use the command `import_xml` to do it.

```
alex l10n import_xml --path=path/to/dir/with/translations
```

If the files have the suffix `_diffs` then they will be imported as a list of changes.


#### Cleanup XML files

Remove unused strings from XML files. Check ARB files for all keys and remove
unused strings from XML files for all locales.

```
alex l10n cleanup_xml
```

### Code 

Work with code.

#### Generate code

Generate `JsonSerializable` and other.

```
alex code gen
```

### Pubspec

Work with pubspec and dependencies.

```
alex pubspec <command>
```

or 

```
alex pub <command>
```

#### Update dependency

Update specified dependency. It's useful when you want to update
dependency for git. 

```
alex pubspec update
```

and input package name. Or define it right in a command:

```
alex pubspec update -dPACKAGE_NAME
```

#### Get dependencies

Run `pub get` for all projects/packages in folder (recursively). It's useful
when you have multiple packages or project and package in single repository.

```
alex pubspec get
```

or 

```
alex pub get
```

### Update

Manage updates for `alex`.

To update `alex` to the latest version:

```
alex update
```


To check if a new version is available:

```
alex update check
```

### Global settings

Set global settings for alex.

Currently supported settings:

- `open_ai_api_key` - OpenAI API key for using ChatGPT features.

#### Set settings

Allow to set setting's value.

```
alex settings set <name> <value>
```

For example:

```
alex settings set open_ai_api_key abc123
```

## Development

Do not forget regenerate code when updating the version:

```
alex code gen
```

or 

```
dart pub run build_runner build --delete-conflicting-outputs
```