import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancellation token reports cancellation and throws', () {
    final token = CancellationToken();
    expect(token.isCancelled, isFalse);

    token.cancel();

    expect(token.isCancelled, isTrue);
    expect(token.throwIfCancelled, throwsA(isA<TaskCancelledException>()));
  });

  test('task progress copyWith can clear progress', () {
    const progress = LongRunningTaskProgress(
      taskId: 'task',
      title: 'Title',
      message: 'Step',
      progress: 0.5,
      canCancel: true,
    );

    final next = progress.copyWith(message: 'Cancelling', clearProgress: true);

    expect(next.message, 'Cancelling');
    expect(next.progress, isNull);
    expect(next.canCancel, isTrue);
  });
}
