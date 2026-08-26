import 'package:alex/src/check/analyze_output_parser.dart';
import 'package:alex/src/check/analyze_result.dart';
import 'package:test/test.dart';

void main() {
  group('parse()', () {
    test('should return empty result for a clean flutter analyze output', () {
      const output = '''
Analyzing some_app...
No issues found! (ran in 5.3s)
''';

      final res = AnalyzeOutputParser.parse(output);

      expect(res.issues, isEmpty);
      expect(res.count, 0);
      expect(res.hasIssues, false);
      expect(res.reportedCount, 0);
    });

    test('should parse issues of the flutter analyze output', () {
      const output = '''
Analyzing some_app...

   info • Unused import: 'dart:io' • lib/src/a.dart:1:8 • unused_import
  error • The name 'Foo' isn't defined • lib/src/b.dart:10:3 • undefined_identifier
warning • Unnecessary cast • lib/src/c.dart:5:12 • unnecessary_cast

3 issues found. (ran in 6.1s)
''';

      final res = AnalyzeOutputParser.parse(output);

      expect(res.count, 3);
      expect(res.issues.length, 3);
      expect(res.reportedCount, 3);
      expect(res.countBySeverity(AnalyzeIssueSeverity.error), 1);
      expect(res.countBySeverity(AnalyzeIssueSeverity.warning), 1);
      expect(res.countBySeverity(AnalyzeIssueSeverity.info), 1);

      final first = res.issues.first;
      expect(first.severity, AnalyzeIssueSeverity.info);
      expect(first.message, "Unused import: 'dart:io'");
      expect(first.file, 'lib/src/a.dart');
      expect(first.line, 1);
      expect(first.column, 8);
      expect(first.rule, 'unused_import');
    });

    test('should parse issues of the dart analyze output', () {
      const output = '''
Analyzing alex...

   info - lib/src/a.dart:1:8 - Unused import: 'dart:io'. Try removing the import directive. - unused_import
  error - lib/src/b.dart:10:3 - The name 'Foo' isn't defined. - undefined_identifier

2 issues found.
''';

      final res = AnalyzeOutputParser.parse(output);

      expect(res.count, 2);
      expect(res.reportedCount, 2);

      final error = res.issues.last;
      expect(error.severity, AnalyzeIssueSeverity.error);
      expect(error.file, 'lib/src/b.dart');
      expect(error.line, 10);
      expect(error.column, 3);
      expect(error.message, "The name 'Foo' isn't defined.");
      expect(error.rule, 'undefined_identifier');
    });

    test('should use the reported count if some issues were not recognized',
        () {
      const output = '''
   info • Unused import • lib/src/a.dart:1:8 • unused_import
   some unrecognized issue line

5 issues found.
''';

      final res = AnalyzeOutputParser.parse(output);

      expect(res.issues.length, 1);
      expect(res.count, 5);
      expect(res.hasIssues, true);
    });

    test('should parse issues without a rule', () {
      const output =
          '  error • Target of URI does not exist • lib/src/a.dart:3:8';

      final res = AnalyzeOutputParser.parse(output);

      expect(res.issues.length, 1);
      expect(res.issues.single.rule, isNull);
      expect(res.issues.single.severity, AnalyzeIssueSeverity.error);
    });

    test('should return empty result for an output without issues info', () {
      final res = AnalyzeOutputParser.parse('Analyzing some_app...');

      expect(res.issues, isEmpty);
      expect(res.reportedCount, isNull);
      expect(res.count, 0);
    });
  });
}
