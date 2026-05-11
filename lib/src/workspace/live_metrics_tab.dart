import 'package:flutter/material.dart';

import '../app_config.dart';
import '../backend_client.dart';
import '../polling.dart';
import '../project_models.dart';
import '../shared_widgets.dart';

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
    final status = await widget.client.activeRunStatus(widget.project.id);
    final run = status.run;
    if (run == null) {
      return _LiveSnapshot(status: status);
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
      metrics: metrics,
      telemetry: telemetry,
      preview: preview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final run = snapshot?.status.run;
    if (run == null && _error == null) {
      return const BlockedState(
        title: 'Live Metrics',
        message: 'Metrics appear after a run is active or recently completed.',
        icon: Icons.monitor_heart_outlined,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (snapshot != null && run != null) _StatusBar(snapshot: snapshot),
          const SizedBox(height: 12),
          Expanded(
            child: snapshot == null || run == null
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _MetricCards(snapshot: snapshot),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _MetricCharts(metrics: snapshot.metrics),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [
                            _HardwarePanel(telemetry: snapshot.telemetry),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _PreviewGrid(preview: snapshot.preview),
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

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.snapshot});

  final _LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
    final run = status.run!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(run.isActive ? Icons.play_circle : Icons.history),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${run.name} · ${status.modelName ?? run.modelId} · ${status.datasetName ?? run.datasetId}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('epoch ${status.epoch} · iter ${status.iteration}'),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                value: status.progress.clamp(0, 1),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(status.progress * 100).clamp(0, 100).round()}%'),
          ],
        ),
      ),
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
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      childAspectRatio: 1.8,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final key in keys)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    definitions[key]?.label ?? key,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatMetric(metrics[key], definitions[key]?.unit),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
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
      return const Card(child: Center(child: Text('No metric records yet.')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: CustomPaint(
                painter: _LineChartPainter(records: records),
                child: const SizedBox.expand(),
              ),
            ),
          ],
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Hardware telemetry pending.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hardware', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${value.device} · ${value.deviceType}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _telemetryRow('Memory used', value.memoryUsed),
            _telemetryRow('Memory total', value.memoryTotal),
            _telemetryRow('Utilization', value.utilization),
            _telemetryRow('Temperature', value.temperature),
            _telemetryRow('Speed', value.iterationSpeed),
          ],
        ),
      ),
    );
  }

  Widget _telemetryRow(String label, TelemetryField field) {
    final text = field.available
        ? '${field.value}${field.unit == null ? '' : ' ${field.unit}'}'
        : 'Unavailable';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          Text(text),
        ],
      ),
    );
  }
}

class _PreviewGrid extends StatelessWidget {
  const _PreviewGrid({required this.preview});

  final PreviewEnvelope? preview;

  @override
  Widget build(BuildContext context) {
    final value = preview;
    if (value == null || value.assets.isEmpty) {
      return const Card(
        child: Center(child: Text('No validation preview yet.')),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Validation Preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.25,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  for (final asset in value.assets)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
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
                              child: Text(
                                asset.kind,
                                style: const TextStyle(fontSize: 12),
                              ),
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
      ),
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
    this.metrics,
    this.telemetry,
    this.preview,
  });

  final ActiveRunStatus status;
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
