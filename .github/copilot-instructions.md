# Alex CLI Tool

**alex** is a Dart-based command-line tool for managing Flutter projects. It provides commands for release management, code generation, localization management, and dependency handling.

**Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Working Effectively

### Bootstrap and build the repository:
- **Install Dart SDK**: `curl -o /tmp/dart.zip https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip && cd /tmp && unzip dart.zip && export PATH="/tmp/dart-sdk/bin:$PATH"`
- **Get dependencies**: `dart pub get` -- takes ~1 second (cached) to ~5 seconds (fresh)
- **Generate code**: `dart pub run build_runner build --delete-conflicting-outputs` -- takes ~3 seconds (cached) to ~6 seconds (fresh), NEVER CANCEL. Set timeout to 30+ minutes for complex projects.

### Run tests and analysis:
- **Run tests**: `dart test` -- takes ~4 seconds, NEVER CANCEL. Set timeout to 60+ minutes.
- **Static analysis**: `dart analyze` -- takes ~1 second

### Run the alex CLI tool:
- **Basic usage**: `dart bin/alex.dart --help`
- **Check version**: `dart bin/alex.dart --version` 
- **Code generation via alex**: `dart bin/alex.dart code gen` -- NOTE: Has FVM issues, use direct build_runner command instead
- **Pubspec operations**: `dart bin/alex.dart pubspec get` -- NOTE: Has FVM issues with corrupted Dart SDK downloads
- **Localization**: `dart bin/alex.dart l10n <subcommand>`

## Critical Issues and Workarounds

### FVM Dart SDK Download Issues
**CRITICAL**: FVM has corrupted Dart SDK download issues that cause failures:
```
End-of-central-directory signature not found.  Either this file is not
a zipfile, or it constitutes one disk of a multi-part archive.
```

**Workaround**: Use direct Dart SDK installation instead of FVM/Flutter:
- Download and extract Dart SDK directly from Google's archives
- Add to PATH: `export PATH="/tmp/dart-sdk/bin:$PATH"`
- This bypasses FVM and works reliably for all alex commands

### Code Generation
- **Working method**: `dart pub run build_runner build --delete-conflicting-outputs`  
- **Problematic method**: `dart bin/alex.dart code gen` (fails due to FVM issues)
- **Always run code generation** when updating versions or modifying generated code

## Validation

### Always run these validation steps after making changes:
1. **Dependencies**: `dart pub get` to ensure all dependencies are current
2. **Code generation**: `dart pub run build_runner build --delete-conflicting-outputs` to regenerate code
3. **Tests**: `dart test` -- NEVER CANCEL, all 29 tests must pass
4. **Analysis**: `dart analyze` -- must show "No issues found!"
5. **CLI functionality**: `dart bin/alex.dart --version` to verify tool works

### Manual testing scenarios:
- **Test CLI help**: `dart bin/alex.dart --help` should show available commands
- **Test subcommand help**: `dart bin/alex.dart pubspec --help` to verify command structure
- **Version check**: `dart bin/alex.dart --version` should return current version (v1.9.0)

## Timing Expectations

**CRITICAL**: Set appropriate timeouts and NEVER CANCEL long-running commands:

| Command | Expected Time | Timeout Setting |
|---------|---------------|-----------------|
| `dart pub get` | ~1-5 seconds | 300 seconds |
| `dart pub run build_runner build` | ~3-6 seconds | 30+ minutes for complex projects |
| `dart test` | ~4 seconds | 60+ minutes |  
| `dart analyze` | ~1 second | 300 seconds |

### Build and test warnings:
- **NEVER CANCEL**: Build and test operations may take significantly longer on different systems
- **Always wait for completion**: Builds can take 45+ minutes in some environments
- **Set generous timeouts**: Use 60+ minutes for builds, 30+ minutes for tests

## Common Tasks

The following commands are validated to work correctly:

### Dependencies and Environment
```bash
# Check Dart version
dart --version

# Get project dependencies  
dart pub get

# Check for outdated packages
dart pub outdated
```

### Code Generation and Build
```bash
# Generate code (preferred method)
dart pub run build_runner build --delete-conflicting-outputs

# Alternative via alex (has FVM issues)
dart bin/alex.dart code gen  # May fail due to FVM Dart SDK issues
```

### Testing and Quality
```bash
# Run all tests (29 tests should pass)
dart test

# Static analysis (should show "No issues found!")
dart analyze  
```

### Alex CLI Operations
```bash
# Show main help
dart bin/alex.dart --help

# Check version
dart bin/alex.dart --version

# Pubspec operations (direct dart method recommended)
dart pub get  # Instead of: dart bin/alex.dart pubspec get

# Localization help
dart bin/alex.dart l10n --help
```

## Project Structure Reference

### Repository root contents:
```
.fvm/               # Flutter Version Management (has issues)  
.fvmrc             # FVM config (Flutter 3.19.6)
.github/           # GitHub workflows and actions
alex.yaml          # Alex configuration example
analysis_options.yaml  # Dart analyzer configuration (uses innim_lint)
bin/alex.dart      # Main CLI entry point
lib/               # Core alex library code
pubspec.yaml       # Project dependencies and metadata
test/              # Test files (29 tests)
```

### Key files:
- **`pubspec.yaml`**: Project dependencies, uses Dart SDK >=3.0.0 <4.0.0
- **`analysis_options.yaml`**: Uses innim_lint for code style
- **`bin/alex.dart`**: Main executable entry point
- **`.fvmrc`**: Specifies Flutter 3.19.6 (has download issues, use direct Dart)

### Commands by category:

**Release Management**:
- `alex feature` - Work with feature branches
- `alex release` - App release commands  

**Code & Dependencies**:
- `alex code gen` - Code generation (use direct build_runner instead)
- `alex pubspec get` - Get dependencies (use direct dart pub get instead)
- `alex pubspec update` - Update dependencies

**Localization**:
- `alex l10n extract` - Extract strings to ARB
- `alex l10n generate` - Generate Dart code from ARB
- `alex l10n check_translations` - Validate translations

**Global Settings**:
- `alex settings set <name> <value>` - Configure global settings
- `alex update` - Update alex itself

## Development Workflow

### Making changes to alex:
1. **Setup environment**: Install Dart SDK directly (avoid FVM issues)
2. **Get dependencies**: `dart pub get`
3. **Generate code**: `dart pub run build_runner build --delete-conflicting-outputs`
4. **Run tests**: `dart test` -- ensure all 29 tests pass
5. **Check analysis**: `dart analyze` -- must show "No issues found!"
6. **Test CLI**: `dart bin/alex.dart --version` to verify functionality

### CI/CD Pipeline:
- GitHub Actions runs on Ubuntu with Flutter 3.10.0
- Runs: `flutter analyze` and `flutter test` 
- CI uses Flutter commands, but development can use direct Dart

**Always run `dart analyze` before committing** or the CI build may fail.