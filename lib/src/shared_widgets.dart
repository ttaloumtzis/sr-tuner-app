import 'package:flutter/material.dart';

import 'backend_client.dart';
import 'project_models.dart';

class ApiErrorBanner extends StatelessWidget {
  const ApiErrorBanner({required this.error, super.key});

  final ApiException? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const SizedBox.shrink();
    }
    final value = error!;
    return MaterialBanner(
      leading: Icon(
        value.recoverable ? Icons.info_outline : Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.message),
          if (value.code != null)
            Text(
              value.code!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
        ],
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}

class BlockedState extends StatelessWidget {
  const BlockedState({
    required this.title,
    required this.message,
    this.icon = Icons.lock_outline,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Colors.white54),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class JobProgressPanel extends StatelessWidget {
  const JobProgressPanel({
    required this.job,
    required this.onCancel,
    super.key,
  });

  final JobState job;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('${job.type} · ${job.status}')),
                Text('${(job.progress * 100).clamp(0, 100).round()}%'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: job.progress.clamp(0, 1)),
          ],
        ),
      ),
    );
  }
}
