import 'package:alex/src/agents/project_facts.dart';
import 'package:alex/src/config.dart';
import 'package:test/test.dart';

void main() {
  group('parseLocales()', () {
    test('should return sorted locales of the matched files', () {
      final res = ProjectFacts.parseLocales(
        const ['intl_ru.arb', 'intl_en.arb', 'intl_pt_BR.arb'],
        'intl_{locale}.arb',
      );

      expect(res, ['en', 'pt_BR', 'ru']);
    });

    test('should skip files that do not match the pattern', () {
      final res = ProjectFacts.parseLocales(
        const [
          'intl_en.arb',
          'messages_en.dart',
          'intl_en.arb.bak',
          'l10n.dart'
        ],
        'intl_{locale}.arb',
      );

      expect(res, ['en']);
    });

    test('should keep a locale with a numeric region', () {
      final res = ProjectFacts.parseLocales(
        const ['intl_es_419.arb', 'intl_en_001.arb', 'intl_en.arb'],
        'intl_{locale}.arb',
      );

      expect(res, ['en', 'en_001', 'es_419']);
    });

    test('should skip the file with the extracted messages', () {
      final res = ProjectFacts.parseLocales(
        const ['intl_messages.arb', 'intl_en.arb', 'intl_ru.arb'],
        'intl_{locale}.arb',
      );

      expect(res, ['en', 'ru']);
    });

    test('should support a custom pattern', () {
      final res = ProjectFacts.parseLocales(
        const ['app_en.arb', 'app_ru.arb'],
        'app_{locale}.arb',
      );

      expect(res, ['en', 'ru']);
    });
  });

  group('lines', () {
    test('should describe the project', () {
      final facts = ProjectFacts(
        l10n: L10nConfig(),
        git: const AlexGitConfig(),
        rootPath: '/projects/demo',
        configPath: 'alex.yaml',
        packageName: 'demo_app',
        packageVersion: '1.2.3+4',
        isFlutter: true,
        fvmVersion: '3.32.6',
        hasL10n: true,
        locales: const ['en', 'ru'],
      );

      final res = facts.lines.join('\n');

      expect(res, contains('Project root: `/projects/demo`'));
      expect(res, contains('Alex config: `alex.yaml`'));
      expect(res, contains('Package: `demo_app` 1.2.3+4 (Flutter)'));
      expect(res, contains('FVM (3.32.6)'));
      expect(res, contains('Locales (2): `en`, `ru`'));
      expect(res, contains('Branches: master `master`'));
    });

    test('should mark a project without Flutter as Dart', () {
      final facts = ProjectFacts(
        l10n: L10nConfig(),
        git: const AlexGitConfig(),
        packageName: 'some_tool',
      );

      expect(facts.lines.join('\n'), contains('Package: `some_tool` (Dart)'));
    });

    test('should skip the localization facts if there is no l10n', () {
      final facts = ProjectFacts(
        l10n: L10nConfig(),
        git: const AlexGitConfig(),
        packageName: 'some_tool',
      );

      final res = facts.lines.join('\n');

      expect(res, isNot(contains('Locales')));
      expect(res, isNot(contains('ARB')));
      expect(res, isNot(contains('XML')));
    });

    test('should list the packages of a multi-package project only', () {
      ProjectFacts factsOf(List<ProjectPackage> packages) => ProjectFacts(
            l10n: L10nConfig(),
            git: const AlexGitConfig(),
            packageName: 'demo_app',
            packages: packages,
          );

      const single = [ProjectPackage(name: 'demo_app', path: '.')];
      const multi = [
        ProjectPackage(name: 'demo_app', path: '.'),
        ProjectPackage(name: 'demo_core', path: 'packages/core'),
      ];

      expect(factsOf(single).lines.join('\n'), isNot(contains('Packages')));
      expect(
          factsOf(multi).lines.join('\n'),
          contains('Packages (2): `demo_app` (`.`), `demo_core` '
              '(`packages/core`)'));
    });
  });
}
