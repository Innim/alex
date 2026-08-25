import 'package:alex/src/check/analyze_result.dart';

/// Parser of the `flutter analyze` / `dart analyze` output.
///
/// Supports both formats:
/// - `flutter analyze`: `severity • message • file:line:column • rule`
/// - `dart analyze`: `severity - file:line:column - message - rule`
class AnalyzeOutputParser {
  /// `severity • message • file:line:column • rule`.
  static final _flutterIssue = RegExp(
      r'^\s*(\w+)\s+•\s+(.+?)\s+•\s+(\S+):(\d+):(\d+)\s*(?:•\s+(\S+))?\s*$');

  /// `severity - file:line:column - message - rule`.
  static final _dartIssue = RegExp(
      r'^\s*(\w+)\s+-\s+(\S+):(\d+):(\d+)\s+-\s+(.+?)\s*(?:-\s+(\S+))?\s*$');

  /// `N issues found.` / `1 issue found.` / `No issues found!`.
  static final _totalCount = RegExp(r'^\s*(\d+)\s+issues?\s+found');
  static final _noIssues = RegExp(r'^\s*No issues found');

  const AnalyzeOutputParser._();

  /// Parses the analyzer [output].
  static AnalyzeResult parse(String output) {
    final issues = <AnalyzeIssue>[];
    int? reportedCount;

    for (final line in output.split('\n')) {
      if (_noIssues.hasMatch(line)) {
        reportedCount = 0;
        continue;
      }

      final total = _totalCount.firstMatch(line);
      if (total != null) {
        reportedCount = int.tryParse(total.group(1)!);
        continue;
      }

      final issue = _parseIssue(line);
      if (issue != null) issues.add(issue);
    }

    return AnalyzeResult(issues: issues, reportedCount: reportedCount);
  }

  static AnalyzeIssue? _parseIssue(String line) {
    final flutterMatch = _flutterIssue.firstMatch(line);
    if (flutterMatch != null) {
      return _issue(
        severity: flutterMatch.group(1)!,
        message: flutterMatch.group(2)!,
        file: flutterMatch.group(3)!,
        line: flutterMatch.group(4)!,
        column: flutterMatch.group(5)!,
        rule: flutterMatch.group(6),
      );
    }

    final dartMatch = _dartIssue.firstMatch(line);
    if (dartMatch != null) {
      return _issue(
        severity: dartMatch.group(1)!,
        message: dartMatch.group(5)!,
        file: dartMatch.group(2)!,
        line: dartMatch.group(3)!,
        column: dartMatch.group(4)!,
        rule: dartMatch.group(6),
      );
    }

    return null;
  }

  static AnalyzeIssue? _issue({
    required String severity,
    required String message,
    required String file,
    required String line,
    required String column,
    String? rule,
  }) {
    final parsedSeverity = AnalyzeIssueSeverity.byName(severity);
    if (parsedSeverity == null) return null;

    final parsedLine = int.tryParse(line);
    final parsedColumn = int.tryParse(column);
    if (parsedLine == null || parsedColumn == null) return null;

    return AnalyzeIssue(
      severity: parsedSeverity,
      message: message.trim(),
      file: file,
      line: parsedLine,
      column: parsedColumn,
      rule: rule?.trim().isNotEmpty == true ? rule!.trim() : null,
    );
  }
}
