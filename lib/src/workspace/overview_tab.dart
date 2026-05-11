import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
import '../polling.dart';
import '../project_models.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({
    required this.client,
    required this.project,
    required this.onNavigateToTab,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<int> onNavigateToTab;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab>
    with AutomaticKeepAliveClientMixin {
  BoundedPoller<_OverviewSnapshot>? _poller;
  _OverviewSnapshot? _snapshot;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _poller?.stop();
    super.dispose();
  }

  void _startPolling() {
    _poller?.stop();
    _poller = BoundedPoller<_OverviewSnapshot>(
      interval: const Duration(seconds: 5),
      fetch: () async {
        final dashboard = await widget.client.dashboardSummary(
          widget.project.id,
        );
        final activity = await widget.client.activityFeed(widget.project.id);
        final active = await widget.client.activeRunStatus(widget.project.id);
        MetricsEnvelope? metrics;
        if (active.run != null) {
          metrics = await widget.client.runMetrics(
            projectId: widget.project.id,
            runId: active.run!.id,
            limit: 40,
          );
        }
        return _OverviewSnapshot(
          dashboard: dashboard,
          activity: activity.events,
          metrics: metrics,
        );
      },
      onData: (value) {
        if (mounted) {
          setState(() {
            _snapshot = value;
            _error = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      },
    )..start();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = srTokens(context);
    final snapshot = _snapshot;
    if (snapshot == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.gap),
        child: SrBanner(message: _error!, severity: 'error'),
      );
    }
    final dashboard = snapshot.dashboard;
    final lossValues = [
      for (final record in snapshot.metrics?.records ?? const <MetricRecord>[])
        if (record.values['train_loss_total'] != null)
          record.values['train_loss_total']!,
    ];
    return ListView(
      key: const PageStorageKey('overview-scroll'),
      padding: EdgeInsets.all(tokens.gap),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: tokens.compactGap,
              mainAxisSpacing: tokens.compactGap,
              childAspectRatio: 2.15,
              children: [
                SrMetricCard(
                  label: 'Datasets',
                  value: '${dashboard.datasetCount}',
                  caption: '${dashboard.datasetPairTotal} pairs',
                  icon: Icons.dataset_outlined,
                ),
                SrMetricCard(
                  label: 'Models',
                  value: '${dashboard.modelCount}',
                  caption: dashboard.activeModel ?? 'No active model',
                  icon: Icons.memory,
                ),
                SrMetricCard(
                  label: 'Runs',
                  value: '${dashboard.runCount}',
                  caption: dashboard.activeRunState ?? 'No active run',
                  icon: Icons.play_circle_outline,
                ),
                SrMetricCard(
                  label: 'Best PSNR',
                  value: dashboard.bestPsnr?.toStringAsFixed(2) ?? '--',
                  caption: dashboard.deviceBadge,
                  icon: Icons.trending_up,
                ),
              ],
            );
          },
        ),
        SizedBox(height: tokens.gap),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final next = _NextStepCard(
              dashboard: dashboard,
              onNavigateToTab: widget.onNavigateToTab,
            );
            final activity = _ActivityCard(events: snapshot.activity);
            final loss = _LossTrendCard(values: lossValues);
            if (narrow) {
              return Column(
                children: [
                  next,
                  SizedBox(height: tokens.gap),
                  activity,
                  SizedBox(height: tokens.gap),
                  loss,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: next),
                SizedBox(width: tokens.gap),
                Expanded(flex: 3, child: activity),
                SizedBox(width: tokens.gap),
                Expanded(flex: 2, child: loss),
              ],
            );
          },
        ),
        SizedBox(height: tokens.gap),
        _QuickActions(onNavigateToTab: widget.onNavigateToTab),
      ],
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.dashboard, required this.onNavigateToTab});

  final DashboardSummary dashboard;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final next = dashboard.nextStep;
    return SrSection(
      title: 'Next step',
      subtitle: next.state,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrBanner(
            title: next.title,
            message: next.description,
            severity: next.severity,
            icon: Icons.route,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onNavigateToTab(next.targetTab),
            icon: const Icon(Icons.arrow_forward),
            label: Text(next.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.events});

  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return SrSection(
      title: 'Recent activity',
      subtitle: 'Dataset, model, run, checkpoint, and inference events.',
      child: events.isEmpty
          ? const SizedBox(
              height: 180,
              child: SrEmptyState(
                title: 'No activity yet',
                message: 'Project events appear here as workflows complete.',
                icon: Icons.timeline,
              ),
            )
          : Column(
              children: [
                for (final event in events.take(7))
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.compactGap),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SrChip(label: event.category, severity: event.severity),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.description,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LossTrendCard extends StatelessWidget {
  const _LossTrendCard({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Loss trend',
      subtitle: values.isEmpty
          ? 'Waiting for metrics'
          : '${values.length} samples',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SrSparkline(values: values),
          const SizedBox(height: 12),
          SrBanner(
            title: 'Tune LR guidance',
            message: values.length < 6
                ? 'Collect more training metrics before changing the learning rate.'
                : 'If loss flattens for several samples, try a lower learning rate.',
            severity: values.length < 6 ? 'info' : 'warning',
            icon: Icons.speed,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Quick actions',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () => onNavigateToTab(1),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add dataset'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigateToTab(2),
            icon: const Icon(Icons.memory),
            label: const Text('Choose model'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigateToTab(3),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Configure training'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigateToTab(6),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Run inference'),
          ),
        ],
      ),
    );
  }
}

class _OverviewSnapshot {
  _OverviewSnapshot({
    required this.dashboard,
    required this.activity,
    this.metrics,
  });

  final DashboardSummary dashboard;
  final List<ActivityEvent> activity;
  final MetricsEnvelope? metrics;
}
