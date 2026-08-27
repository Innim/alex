import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/agents/command_index.dart';
import 'package:alex/src/agents/project_facts.dart';
import 'package:alex/src/agents/section_renderer.dart';
import 'package:alex/src/config.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('render()', () {
    test('should not contain a local path or a version', () {
      // The section is written in a file that is committed and shared
      // by the whole team, so it must be the same on every machine
      // and must not change with every build.
      final res = _render(_facts(
        rootPath: '/Users/someone/projects/demo',
        configPath: 'alex.yaml',
        packageName: 'demo_app',
        packageVersion: '0.2.2+9',
        fvmVersion: '3.29.2',
      ));

      expect(res, isNot(contains('/Users/someone')));
      expect(res, isNot(contains('0.2.2+9')));
      expect(res, isNot(contains('3.29.2')));
      expect(res, isNot(contains('alex.yaml')));
    });

    test('should keep the package name and the type', () {
      final res = _render(_facts(packageName: 'demo_app', isFlutter: true));

      expect(res, contains('Package: `demo_app` (Flutter)'));
    });

    test('should report FVM without a version', () {
      final res = _render(_facts(fvmVersion: '3.29.2'));

      expect(res, contains('pinned with FVM - run `flutter` and `dart`'));
    });

    test('should not report FVM if the project does not use it', () {
      // The intro mentions FVM as one of the things alex handles,
      // so only the fact line is checked here.
      expect(_render(_facts()), isNot(contains('pinned with FVM')));
    });

    test('should report only the branches that exist', () {
      // Every branch has a default value in the config, so a project
      // can have no such branch at all - a default is not a fact.
      final res = _render(_facts(
        existingBranches: const {'main', 'develop'},
        git: const AlexGitConfig(
          branches: AlexGitConfigBranches(master: 'main'),
        ),
      ));

      expect(res, contains('master `main`'));
      expect(res, contains('develop `develop`'));
      expect(res, isNot(contains('test `')));
      expect(res, contains('feature prefix `feature/`'));
    });

    test('should report all the branches if it can not be checked', () {
      // No repository - nothing can be said about the branches,
      // so the configured ones are listed as is.
      final res = _render(_facts());

      expect(res, contains('master `master`'));
      expect(res, contains('develop `develop`'));
      expect(res, contains('test `pipe/test`'));
    });

    test('should skip the localization facts if there is no l10n', () {
      final res = _render(_facts());

      expect(res, isNot(contains('Locales')));
      expect(res, isNot(contains('ARB')));
    });

    test('should report locales and l10n paths', () {
      final res = _render(_facts(hasL10n: true, locales: const ['en', 'ru']));

      expect(res, contains('Locales (2): `en`, `ru`'));
      expect(res, contains('ARB: `lib/application/l10n/intl_{locale}.arb`'));
    });
  });
}

ProjectFacts _facts({
  String rootPath = '',
  String configPath = '',
  String? packageName,
  String? packageVersion,
  String? fvmVersion,
  bool isFlutter = false,
  bool hasL10n = false,
  List<String> locales = const [],
  AlexGitConfig git = const AlexGitConfig(),
  Set<String>? existingBranches,
}) =>
    ProjectFacts(
      l10n: L10nConfig(),
      git: git,
      rootPath: rootPath,
      configPath: configPath,
      packageName: packageName,
      packageVersion: packageVersion,
      fvmVersion: fvmVersion,
      isFlutter: isFlutter,
      hasL10n: hasL10n,
      locales: locales,
      existingBranches: existingBranches,
    );

String _render(ProjectFacts facts) {
  final runner = CommandRunner<int>('alex', 'Test runner.')
    ..addCommand(_Cmd('info'));

  return SectionRenderer.render(
    facts: facts,
    index: CommandIndex.build(runner),
    version: '1.0.0',
  );
}

class _Cmd extends AlexCommand {
  _Cmd(String name) : super(name, 'Some command.');

  @override
  Future<int> doRun() async => 0;
}
