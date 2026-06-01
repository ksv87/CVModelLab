enum ParseIssueSeverity {
  warning,
  error,
}

class ParseIssue {
  const ParseIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final ParseIssueSeverity severity;
  final String message;
  final String? path;
}

class ParseResult<T> {
  const ParseResult({
    required this.value,
    required this.issues,
  });

  final T? value;
  final List<ParseIssue> issues;

  bool get hasErrors {
    return issues.any((ParseIssue issue) {
      return issue.severity == ParseIssueSeverity.error;
    });
  }
}
