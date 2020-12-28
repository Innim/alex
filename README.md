# alex

[![pub package](https://img.shields.io/pub/v/alex)](https://pub.dev/packages/alex)

**alex** - command line tool for working with Flutter projects.

## Getting started

### Installing

It's recommended to install the package globally and use as an executable.

You can install the package from the command line:

with pub:

```
$ pub global activate alex
```

with Flutter:

```
$ flutter pub global activate alex
```

And follow the instructions (you should add PATH variable on unix systems).

Now you can execute commands with

```
$ alex
```

⚠️ **Attention!** If you have only Flutter installed and doesn't have separate Dart SDK
installed, then you haven't `pub` command. So when you try to run `alex` you will see something like:

```
~/Development/flutter/.pub-cache/bin/alex: line 17: pub: command not found
```

There are more than one solution for this. You can just install seperate Dart SDK if you want. 

Or, if you don't want to do it, you can edit specified file (`~/Development/flutter/.pub-cache/bin/alex` in this example). All you need to change in it - it's use `flutter pub` instead of `pub`, so replace `pub global run alex:alex "$@"` with `flutter pub global run alex:alex "$@"`, save the file, and you are all set.

### Usage

`alex` is working in the current directory. So if you want to work with a specific project, you should run the command in project's root directory.

#### Configuration

To provide more convinient way to work with project, `alex` can use some configuration.
You can define configuration in your project's `pubspec.yaml`, section  `alex`,
or in separate file `alex.yaml`.

You can see all configuration options and it's default values in the example config [`/alex.yaml`](./alex.yaml).

More about specified configuration parameters - in modules descriptions in the [Commands](#commands) section.

## Commands

// TODO @chessmax: `release` command description

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
alex l10n --from=json --source=/path/to/json/localization/dir
```

#### Import translations from XML

It's for working with translations from Google Play.

You can export xml translations to the project arb translations:

```
alex l10n from_xml
```

Also you can export to the Android localization:

```
alex l10n from_xml --to=anroid
```

And to the iOS localization:

```
alex l10n from_xml --to=ios
```

#### Import translation from Google Play to project XML files

When you download and unzip translations from Google Play,
you need to import it in project's xml files. You can 
copy it all manually, but it's very inconvenient.
So you can use command `import_xml` to do it.

```
alex l10n import_xml --path=path/to/dir/with/translations
```

### Code 

Work with code.

#### Generate code

Generate `JsonSerializable` and other.

```
alex code gen
```