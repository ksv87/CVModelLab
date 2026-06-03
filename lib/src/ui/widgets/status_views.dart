import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    required this.explanation,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String explanation;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  explanation,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FriendlyErrorView extends StatefulWidget {
  const FriendlyErrorView({
    required this.error,
    this.onRetry,
    super.key,
  });

  final FriendlyError error;
  final VoidCallback? onRetry;

  @override
  State<FriendlyErrorView> createState() => _FriendlyErrorViewState();
}

class _FriendlyErrorViewState extends State<FriendlyErrorView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocaleScope.l10n(context);
    final String message = widget.error.key == null
        ? widget.error.message
        : l10n.t(widget.error.key!, widget.error.params);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.error.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (widget.onRetry != null)
                  TextButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(message),
            if (widget.error.details != null &&
                widget.error.details!.isNotEmpty) ...[
              TextButton.icon(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_showDetails ? 'Hide details' : 'Show details'),
              ),
              if (_showDetails)
                SelectableText(
                  widget.error.details!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class TaskProgressOverlay extends StatelessWidget {
  const TaskProgressOverlay({
    required this.progress,
    this.onCancel,
    super.key,
  });

  final LongRunningTaskProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      progress.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(progress.message),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: progress.progress),
                    if (progress.canCancel && onCancel != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
