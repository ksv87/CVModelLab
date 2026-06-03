class LongRunningTaskProgress {
  const LongRunningTaskProgress({
    required this.taskId,
    required this.title,
    required this.message,
    this.progress,
    this.canCancel = false,
  });

  final String taskId;
  final String title;
  final String message;

  /// A value from 0.0 to 1.0. Null means indeterminate progress.
  final double? progress;
  final bool canCancel;

  LongRunningTaskProgress copyWith({
    String? taskId,
    String? title,
    String? message,
    double? progress,
    bool clearProgress = false,
    bool? canCancel,
  }) {
    return LongRunningTaskProgress(
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      message: message ?? this.message,
      progress: clearProgress ? null : (progress ?? this.progress),
      canCancel: canCancel ?? this.canCancel,
    );
  }
}

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const TaskCancelledException();
    }
  }
}

class TaskCancelledException implements Exception {
  const TaskCancelledException();

  @override
  String toString() => 'Task cancelled.';
}

typedef ProgressCallback = void Function(LongRunningTaskProgress progress);
