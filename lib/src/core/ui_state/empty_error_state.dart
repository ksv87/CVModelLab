import '../i18n/message_key.dart';

class EmptyStateModel {
  const EmptyStateModel({
    required this.title,
    required this.explanation,
    this.actionLabel,
  });

  final String title;
  final String explanation;
  final String? actionLabel;
}

class FriendlyError {
  const FriendlyError({
    required this.title,
    required this.message,
    this.details,
    this.key,
    this.params = const <String, Object?>{},
  });

  final String title;
  final String message;
  final String? details;
  final MessageKey? key;
  final Map<String, Object?> params;
}

FriendlyError friendlyErrorFrom(Object error, {String? fallbackTitle}) {
  final String raw = error.toString();
  final String lower = raw.toLowerCase();
  if (lower.contains('format') || lower.contains('json')) {
    return FriendlyError(
      title: fallbackTitle ?? 'Invalid JSON',
      message:
          'The selected file is not valid JSON or does not match the expected CV Model Lab format.',
      details: raw,
      key: MessageKey.errorInvalidJson,
    );
  }
  if (lower.contains('permission') ||
      lower.contains('operation not permitted')) {
    return FriendlyError(
      title: fallbackTitle ?? 'Permission denied',
      message:
          'CV Model Lab could not access the selected file or folder. Pick it again or choose a location you can read and write.',
      details: raw,
      key: MessageKey.errorPermissionDenied,
    );
  }
  if (lower.contains('ap') && lower.contains('unavailable')) {
    return FriendlyError(
      title: fallbackTitle ?? 'AP evaluator unavailable',
      message:
          'COCO AP evaluation cannot run in this environment. On web, import AP metrics JSON instead.',
      details: raw,
      key: MessageKey.errorApUnavailable,
    );
  }
  return FriendlyError(
    title: fallbackTitle ?? 'Operation failed',
    message:
        'The operation could not be completed. Review the details or try again with a different file or folder.',
    details: raw,
    key: MessageKey.errorOperationFailed,
  );
}
