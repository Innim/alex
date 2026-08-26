/// Severity of an issue reported by `flutter analyze` / `dart analyze`.
enum AnalyzeIssueSeverity {
  info,
  warning,
  error;

  /// Returns severity by its name in the analyzer output
  /// or `null` if the name is unknown.
  static AnalyzeIssueSeverity? byName(String value) {
    switch (value.toLowerCase()) {
      case 'info':
      case 'hint':
      case 'lint':
        return AnalyzeIssueSeverity.info;
      case 'warning':
        return AnalyzeIssueSeverity.warning;
      case 'error':
        return AnalyzeIssueSeverity.error;
      default:
        return null;
    }
  }
}

/// Single issue from the analyzer output.
class AnalyzeIssue {
  final AnalyzeIssueSeverity severity;
  final String message;
  final String file;
  final int line;
  final int column;
  final String? rule;

  const AnalyzeIssue({
    required this.severity,
    required this.message,
    required this.file,
    required this.line,
    required this.column,
    this.rule,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'severity': severity.name,
        'message': message,
        'file': file,
        'line': line,
        'column': column,
        if (rule != null) 'rule': rule,
      };

  @override
  String toString() => '$file:$line:$column • ${severity.name} • $message'
      '${rule != null ? ' • $rule' : ''}';
}

/// Result of the analyzer run.
class AnalyzeResult {
  /// Issues parsed from the output.
  final List<AnalyzeIssue> issues;

  /// Total count of issues reported by the analyzer itself
  /// (from the `N issues found.` line), if it was found in the output.
  ///
  /// May differ from [issues] length if some lines were not recognized.
  final int? reportedCount;

  const AnalyzeResult({
    required this.issues,
    this.reportedCount,
  });

  /// Count of issues to report: the analyzer's own count if it's available
  /// and greater than the count of the parsed ones, otherwise the parsed one.
  int get count {
    final parsed = issues.length;
    final reported = reportedCount;
    if (reported == null) return parsed;
    return reported > parsed ? reported : parsed;
  }

  bool get hasIssues => count > 0;

  int countBySeverity(AnalyzeIssueSeverity severity) =>
      issues.where((i) => i.severity == severity).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'count': count,
        'errors': countBySeverity(AnalyzeIssueSeverity.error),
        'warnings': countBySeverity(AnalyzeIssueSeverity.warning),
        'infos': countBySeverity(AnalyzeIssueSeverity.info),
        'issues': issues.map((i) => i.toJson()).toList(),
      };
}
