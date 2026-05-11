import 'package:flutter/material.dart';

import '../app_config.dart';
import '../backend_client.dart';
import '../classic_components.dart';
import '../polling.dart';
import '../project_models.dart';

class LiveMetricsTab extends StatefulWidget {
  const LiveMetricsTab({
    required this.client,
    required this.project,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;

  @override
  State<LiveMetricsTab> createState() => _LiveMetricsTabState();
}

class _LiveMetricsTabState extends State<LiveMetricsTab> {
  BoundedPoller<_LiveSnapshot>? _poller;
  _LiveSnapshot? _snapshot;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(LiveMetricsTab oldWidget) {
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
    _poller = BoundedPoller<_LiveSnapshot>(
      interval: const Duration(seconds: 2),
      fetch: _fetchSnapshot,
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

  Future<_LiveSnapshot> _fetchSnapshot() async {
    final detail = await widget.client.liveRunDetail(widget.project.id);
    final status = await widget.client.activeRunStatus(widget.project.id);
    final run = detail.run ?? status.run;
    if (run == null) {
      return _LiveSnapshot(status: status, detail: detail);
    }
    final metrics = await widget.client.runMetrics(
      projectId: widget.project.id,
      runId: run.id,
    );
    final telemetry = await widget.client.hardwareTelemetry(widget.project.id);
    final preview = await widget.client.validationPreview(
      projectId: widget.project.id,
      runId: run.id,
    );
    return _LiveSnapshot(
      status: status,
      detail: detail,
      metrics: metrics,
      telemetry: telemetry,
      preview: preview,
    );
  }

  Future<void> _snapshotCheckpoint(RunSummary run) async {
    setState(() => _busy = true);
    try {
      await widget.client.snapshotCheckpoint(
        projectId: widget.project.id,
        runId: run.id,
      );
      await _fetchSnapshot().then((value) {
        if (mounted) {
          setState(() => _snapshot = value);
        }
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop(RunSummary run) async {
    final loss = _snapshot?.status.latestMetrics['train_loss_total'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop ${run.name}?'),
        content: Text(
          'Latest loss: ${_formatMetric(loss, null)}. The latest checkpoint context is preserved when the backend has written one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop run'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.client.stopRun(projectId: widget.project.id, runId: run.id);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final snapshot = _snapshot;
    final run = snapshot?.detail.run ?? snapshot?.status.run;
    if (run == null && _error == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.gap),
        child: SrEmptyState(
          title: 'Live is idle',
          message:
              'Start a run or resume a configured run to see metrics, validation previews, and recent events.',
          icon: Icons.monitor_heart_outlined,
          action: Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start a run'),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.replay),
                label: const Text('Resume run'),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(tokens.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) SrBanner(message: _error!, severity: 'error'),
          if (snapshot != null && run != null)
            _StatusStrip(
              snapshot: snapshot,
              busy: _busy,
              onSnapshot: () => _snapshotCheckpoint(run),
              onPause: null,
              onStop: () => _stop(run),
            ),
          SizedBox(height: tokens.gap),
          Expanded(
            child: snapshot == null || run == null
                ? const Center(child: CircularProgressIndicator())
                : snapshot.detail.oomError != null
                ? _OomState(snapshot: snapshot)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ListView(
                          children: [
                            _MetricCards(snapshot: snapshot),
                            SizedBox(height: tokens.gap),
                            SizedBox(
                              height: 260,
                              child: _MetricCharts(metrics: snapshot.metrics),
                            ),
                            SizedBox(height: tokens.gap),
                            _EventsPanel(detail: snapshot.detail),
                          ],
                        ),
                      ),
                      SizedBox(width: tokens.gap),
                      SizedBox(
                        width: 410,
                        child: ListView(
                          children: [
                            _HardwarePanel(telemetry: snapshot.telemetry),
                            SizedBox(height: tokens.gap),
                            SizedBox(
                              height: 360,
                              child: _ValidationPanel(
                                detail: snapshot.detail,
                                preview: snapshot.preview,
                              ),
                            ),
                          ],
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.snapshot,
    required this.busy,
    required this.onSnapshot,
    required this.onPause,
    required this.onStop,
  });

  final _LiveSnapshot snapshot;
  final bool busy;
  final VoidCallback? onSnapshot;
  final VoidCallback? onPause;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final run = snapshot.detail.run ?? status.run!;
    return SrSection(
      title: run.name,
      subtitle:
          '${status.modelName ?? run.modelId} · ${status.datasetName ?? run.datasetId} · epoch ${status.epoch} · iter ${status.iteration}',
      trailing: Wrap(
        spacing: 8,
        children: [
          SrChip(
            label: run.isActive ? 'LIVE' : run.state,
            icon: Icons.circle,
            selected: run.isActive,
            severity: run.isActive ? 'success' : 'info',
          ),
          OutlinedButton.icon(
            onPressed: busy || !run.isActive ? null : onSnapshot,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Snapshot'),
          ),
          OutlinedButton.icon(
            onPressed: busy || !run.isActive ? null : onPause,
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
          OutlinedButton.icon(
            onPressed: busy || !run.isActive ? null : onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ProgressWithLabel(
                  label: 'Epoch progress',
                  value: snapshot.detail.epochProgress,
                  kind: SrProgressKind.striped,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ProgressWithLabel(
                  label: 'Run progress',
                  value: snapshot.detail.runProgress,
                  kind: SrProgressKind.solid,
                ),
              ),
            ],
          ),
          if (snapshot.detail.etaSeconds != null) ...[
            const SizedBox(height: 8),
            Text('ETA ${snapshot.detail.etaSeconds}s'),
          ],
        ],
      ),
    );
  }
}

class _ProgressWithLabel extends StatelessWidget {
  const _ProgressWithLabel({
    required this.label,
    required this.value,
    required this.kind,
  });

  final String label;
  final double value;
  final SrProgressKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${(value * 100).clamp(0, 100).round()}%'),
          ],
        ),
        const SizedBox(height: 6),
        SrProgressBar(value: value, kind: kind),
      ],
    );
  }
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({required this.snapshot});

  final _LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = snapshot.status.latestMetrics;
    final definitions = snapshot.metrics?.definitions ?? {};
    final keys = [
      'train_loss_total',
      'val_psnr',
      'val_ssim',
      'learning_rate',
      'iterations_per_second',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in keys)
          SizedBox(
            width: 170,
            child: SrMetricCard(
              label: definitions[key]?.label ?? key,
              value: _formatMetric(metrics[key], definitions[key]?.unit),
            ),
          ),
      ],
    );
  }
}

class _MetricCharts extends StatelessWidget {
  const _MetricCharts({required this.metrics});

  final MetricsEnvelope? metrics;

  @override
  Widget build(BuildContext context) {
    final records = metrics?.records ?? const <MetricRecord>[];
    if (records.isEmpty) {
      return const SrSection(
        title: 'Loss / PSNR',
        child: Center(child: Text('No metric records yet.')),
      );
    }
    return SrSection(
      title: 'Loss / PSNR',
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _LineChartPainter(records: records),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HardwarePanel extends StatelessWidget {
  const _HardwarePanel({required this.telemetry});

  final HardwareTelemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    final value = telemetry;
    if (value == null) {
      return const SrSection(
        title: 'GPU stats',
        child: Text('Hardware telemetry pending.'),
      );
    }
    return SrSection(
      title: 'GPU stats',
      subtitle: '${value.device} · ${value.deviceType}',
      child: Column(
        children: [
          _telemetryRow(context, 'Memory used', value.memoryUsed),
          _telemetryRow(context, 'Memory total', value.memoryTotal),
          _telemetryRow(context, 'Utilization', value.utilization),
          _telemetryRow(context, 'Temperature', value.temperature),
          _telemetryRow(context, 'Speed', value.iterationSpeed),
        ],
      ),
    );
  }

  Widget _telemetryRow(
    BuildContext context,
    String label,
    TelemetryField field,
  ) {
    final text = field.available
        ? '${field.value}${field.unit == null ? '' : ' ${field.unit}'}'
        : 'Unavailable';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: srTokens(context).muted),
            ),
          ),
          Text(text),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.detail, required this.preview});

  final LiveRunDetail detail;
  final PreviewEnvelope? preview;

  @override
  Widget build(BuildContext context) {
    final value = preview;
    return SrSection(
      title: 'Validation samples',
      subtitle: detail.validationSamples.isEmpty
          ? 'Preview assets'
          : '${detail.validationSamples.length} samples',
      child: value == null || value.assets.isEmpty
          ? const SrImagePlaceholder(label: 'No validation preview yet')
          : GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.25,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                for (final asset in value.assets)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          AppConfig.apiUri(asset.url).toString(),
                          fit: BoxFit.cover,
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: Colors.black54,
                            child: Text(asset.kind),
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

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.detail});

  final LiveRunDetail detail;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Recent events',
      trailing: OutlinedButton.icon(
        onPressed: detail.openLog.supported ? () {} : null,
        icon: const Icon(Icons.article_outlined),
        label: const Text('Open log'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final event in detail.recentEvents)
            ListTile(
              dense: true,
              leading: const Icon(Icons.bolt),
              title: Text(event.description),
              subtitle: Text(event.timestamp),
            ),
          if (detail.recentEvents.isEmpty)
            const Text('No recent live events yet.'),
          if (detail.logTail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Log tail', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                border: Border.all(color: srTokens(context).border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(detail.logTail.join('\n')),
            ),
          ],
        ],
      ),
    );
  }
}

class _OomState extends StatelessWidget {
  const _OomState({required this.snapshot});

  final _LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final detail = snapshot.detail;
    final oom = detail.oomError ?? const <String, dynamic>{};
    final fixes = oom['suggested_fixes'] as List<dynamic>? ?? const [];
    return ListView(
      children: [
        SrBanner(
          title: 'CUDA out of memory',
          message:
              oom['summary']?.toString() ??
              'Training failed because GPU memory was exhausted.',
          severity: 'error',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _HardwarePanel(telemetry: snapshot.telemetry)),
            const SizedBox(width: 12),
            Expanded(
              child: SrSection(
                title: 'Suggested fixes',
                child: Column(
                  children: [
                    for (final fix in fixes)
                      ListTile(
                        leading: const Icon(Icons.build_outlined),
                        title: Text(
                          fix is Map
                              ? (fix['label']?.toString() ?? 'Apply fix')
                              : fix.toString(),
                        ),
                        subtitle: fix is Map && fix['reason'] != null
                            ? Text(fix['reason'].toString())
                            : null,
                        trailing: OutlinedButton(
                          onPressed: null,
                          child: const Text('Apply'),
                        ),
                      ),
                    if (fixes.isEmpty)
                      const Text('No backend-applicable fixes were returned.'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (detail.crashSnapshot != null)
          SrBanner(
            title: 'Crash snapshot',
            message: detail.crashSnapshot!.message,
            severity: detail.crashSnapshot!.supported ? 'success' : 'warning',
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.replay),
              label: const Text('Apply all suggested retry'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.tune),
              label: const Text('Open training settings'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Guide'),
            ),
            OutlinedButton.icon(
              onPressed: detail.openLog.supported ? () {} : null,
              icon: const Icon(Icons.article_outlined),
              label: const Text('Open log'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EventsPanel(detail: detail),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.records});

  final List<MetricRecord> records;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);
    _drawSeries(canvas, size, 'train_loss_total', const Color(0xff58c48a));
    _drawSeries(canvas, size, 'val_psnr', const Color(0xff6aa6ff));
    _drawSeries(canvas, size, 'val_ssim', const Color(0xffffc857));
  }

  void _drawSeries(Canvas canvas, Size size, String key, Color color) {
    final values = [
      for (final record in records)
        if (record.values[key] != null) record.values[key]!,
    ];
    if (values.length < 2) {
      return;
    }
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.000001
        ? 1.0
        : maxValue - minValue;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * (index / (values.length - 1));
      final y = size.height - ((values[index] - minValue) / span * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.records != records;
}

class _LiveSnapshot {
  _LiveSnapshot({
    required this.status,
    required this.detail,
    this.metrics,
    this.telemetry,
    this.preview,
  });

  final ActiveRunStatus status;
  final LiveRunDetail detail;
  final MetricsEnvelope? metrics;
  final HardwareTelemetry? telemetry;
  final PreviewEnvelope? preview;
}

String _formatMetric(double? value, String? unit) {
  if (value == null) {
    return '--';
  }
  final formatted = value.abs() >= 100
      ? value.toStringAsFixed(1)
      : value.toStringAsPrecision(3);
  return unit == null ? formatted : '$formatted $unit';
}
