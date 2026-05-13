import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../backend_client.dart';
import '../classic_components.dart';
import '../diagnostic_image.dart';
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
  double _validationPanelWidth = 520;

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
      interval: const Duration(seconds: 1),
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
    final telemetry = await widget.client.hardwareTelemetry(widget.project.id);
    final metrics = await widget.client.runMetrics(
      projectId: widget.project.id,
      runId: run.id,
    );
    final preview = await widget.client.validationPreview(
      projectId: widget.project.id,
      runId: run.id,
      previewIndex: 0,
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
              run: run,
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const handleWidth = 10.0;
                      const minMainWidth = 620.0;
                      const minPanelWidth = 360.0;
                      final maxPanelWidth = math.max(
                        minPanelWidth,
                        constraints.maxWidth -
                            minMainWidth -
                            tokens.gap -
                            handleWidth,
                      );
                      final panelWidth = _validationPanelWidth.clamp(
                        minPanelWidth,
                        maxPanelWidth,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: ListView(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _MetricCards(snapshot: snapshot),
                                    ),
                                    SizedBox(width: tokens.gap),
                                    SizedBox(
                                      width: 410,
                                      child: _HardwarePanel(
                                        telemetry: snapshot.telemetry,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: tokens.gap),
                                SizedBox(
                                  height: 455,
                                  child: _MetricCharts(
                                    metrics: snapshot.metrics,
                                    status: snapshot.status,
                                  ),
                                ),
                                SizedBox(height: tokens.gap),
                                SizedBox(
                                  height: 230,
                                  child: _EventsPanel(detail: snapshot.detail),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: tokens.gap / 2),
                          _ResizeHandle(
                            onDrag: (delta) {
                              setState(() {
                                _validationPanelWidth =
                                    (_validationPanelWidth - delta).clamp(
                                      minPanelWidth,
                                      maxPanelWidth,
                                    );
                              });
                            },
                          ),
                          SizedBox(width: tokens.gap / 2),
                          SizedBox(
                            width: panelWidth,
                            child: ListView(
                              children: [
                                _ValidationPanel(
                                  detail: snapshot.detail,
                                  preview: snapshot.preview,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
    required this.run,
    required this.busy,
    required this.onSnapshot,
    required this.onPause,
    required this.onStop,
  });

  final _LiveSnapshot snapshot;
  final RunSummary run;
  final bool busy;
  final VoidCallback? onSnapshot;
  final VoidCallback? onPause;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.status;
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
                  label: _phaseLabel(snapshot.detail.phase),
                  value: snapshot.detail.epochProgress,
                  detail: _progressDetail(
                    snapshot.status.latestMetrics['epoch_iteration'],
                    snapshot.status.latestMetrics['epoch_total_iterations'],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ProgressWithLabel(
                  label: 'Run progress',
                  value: snapshot.detail.runProgress,
                  detail: _progressDetail(
                    snapshot.status.iteration.toDouble(),
                    snapshot.status.latestMetrics['total_iterations'],
                  ),
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

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 10,
          child: Center(
            child: Container(
              width: 2,
              height: 96,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressWithLabel extends StatelessWidget {
  const _ProgressWithLabel({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final double value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              [
                '${(value * 100).clamp(0, 100).round()}%',
                if (detail.isNotEmpty) detail,
              ].join(' · '),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SrProgressBar(value: value),
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
    final telemetry = snapshot.telemetry;
    final run = snapshot.detail.run ?? snapshot.status.run;
    final cards = [
      _MetricCardSpec(
        label: definitions['train_loss_total']?.label ?? 'Train Loss',
        value: _formatMetric(
          metrics['train_loss_total'],
          definitions['train_loss_total']?.unit,
        ),
      ),
      _MetricCardSpec(
        label: 'PSNR',
        value: _formatMetric(
          metrics['val_psnr'],
          definitions['val_psnr']?.unit,
        ),
      ),
      _MetricCardSpec(
        label: definitions['learning_rate']?.label ?? 'Learning Rate',
        value: _formatMetric(
          metrics['learning_rate'],
          definitions['learning_rate']?.unit,
        ),
      ),
      _MetricCardSpec(
        label: definitions['iterations_per_second']?.label ?? 'Speed',
        value: _formatMetric(
          metrics['iterations_per_second'],
          definitions['iterations_per_second']?.unit,
        ),
      ),
      _MetricCardSpec(
        label: 'Iteration',
        value: snapshot.status.iteration.toString(),
      ),
      _MetricCardSpec(
        label: 'VRAM used',
        value: _formatTelemetry(telemetry?.memoryUsed),
      ),
      _MetricCardSpec(
        label: 'Batch size',
        value: run?.batchSize.toString() ?? '--',
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final card in cards)
          SizedBox(
            width: 170,
            child: SrMetricCard(label: card.label, value: card.value),
          ),
      ],
    );
  }
}

class _MetricCardSpec {
  const _MetricCardSpec({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricCharts extends StatelessWidget {
  const _MetricCharts({required this.metrics, required this.status});

  final MetricsEnvelope? metrics;
  final ActiveRunStatus status;

  @override
  Widget build(BuildContext context) {
    final records = _recordsWithLiveSample(
      metrics?.records ?? const <MetricRecord>[],
      status,
    );
    if (records.isEmpty) {
      return const SrSection(
        title: 'Metric charts',
        child: Center(child: Text('No metric records yet.')),
      );
    }
    final definitions = metrics?.definitions ?? {};
    return SrSection(
      title: 'Metric charts',
      child: Column(
        children: [
          _SingleMetricChart(
            records: records,
            metricKey: 'train_loss_total',
            title: definitions['train_loss_total']?.label ?? 'Loss',
            yAxisLabel: 'Loss',
            color: const Color(0xff58c48a),
          ),
          const SizedBox(height: 12),
          _SingleMetricChart(
            records: records,
            metricKey: 'val_psnr',
            title: definitions['val_psnr']?.label ?? 'PSNR',
            yAxisLabel: 'PSNR',
            color: const Color(0xff6aa6ff),
          ),
          const SizedBox(height: 12),
          _SingleMetricChart(
            records: records,
            metricKey: 'val_ssim',
            title: definitions['val_ssim']?.label ?? 'SSIM',
            yAxisLabel: 'SSIM',
            color: const Color(0xffffc857),
          ),
        ],
      ),
    );
  }
}

class _SingleMetricChart extends StatelessWidget {
  const _SingleMetricChart({
    required this.records,
    required this.metricKey,
    required this.title,
    required this.yAxisLabel,
    required this.color,
  });

  final List<MetricRecord> records;
  final String metricKey;
  final String title;
  final String yAxisLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final record in records)
        if (record.step > 0 && record.values[metricKey] != null)
          record.values[metricKey]!,
    ];
    final chartRecords = [
      for (final record in records)
        if (record.step > 0) record,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(width: 10, height: 2, color: color),
            const SizedBox(width: 6),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              values.isEmpty ? '--' : _formatMetric(values.last, null),
              style: TextStyle(color: srTokens(context).muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 92,
          child: CustomPaint(
            painter: _MetricChartPainter(
              records: chartRecords,
              metricKey: metricKey,
              yAxisLabel: yAxisLabel,
              color: color,
              textColor: srTokens(context).muted,
              axisColor: srTokens(context).border,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
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
      title: value.deviceType == 'cpu' ? 'CPU stats' : 'GPU stats',
      subtitle: '${value.device} · ${value.deviceType}',
      child: Column(
        children: [
          _telemetryRow(context, 'Memory used', value.memoryUsed),
          _telemetryRow(context, 'Memory total', value.memoryTotal),
          _telemetryRow(context, 'Utilization', value.utilization),
          _telemetryRow(context, 'Temperature', value.temperature),
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
    final assetsByKind = <String, PreviewAsset>{
      for (final asset in value?.assets ?? const <PreviewAsset>[])
        asset.kind: asset,
    };
    final slots = [
      _PreviewSlot(
        label: 'Input',
        asset: assetsByKind['lr'],
        cacheKey: value?.generatedAt,
      ),
      _PreviewSlot(
        label: 'Output',
        asset: assetsByKind['sr'],
        cacheKey: value?.generatedAt,
      ),
      _PreviewSlot(
        label: 'Target',
        asset: assetsByKind['hr'],
        cacheKey: value?.generatedAt,
      ),
      if (assetsByKind['diff_absolute'] != null)
        _PreviewSlot(
          label: 'Abs diff',
          asset: assetsByKind['diff_absolute'],
          cacheKey: value?.generatedAt,
        ),
      if (assetsByKind['diff_heatmap'] != null)
        _PreviewSlot(
          label: 'Heat diff',
          asset: assetsByKind['diff_heatmap'],
          cacheKey: value?.generatedAt,
        ),
      if (assetsByKind['diff_absolute'] == null &&
          assetsByKind['diff_heatmap'] == null)
        _PreviewSlot(label: 'Diff', asset: null, cacheKey: value?.generatedAt),
    ];
    return SrSection(
      title: 'Validation samples',
      subtitle: detail.validationSamples.isEmpty
          ? 'Waiting for first preview'
          : '${detail.validationSamples.length} samples',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final tileWidth = (constraints.maxWidth - spacing) / 2;
          final rows = (slots.length / 2).ceil();
          final gridHeight = tileWidth * rows + spacing * math.max(0, rows - 1);
          return SizedBox(
            height: gridHeight,
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final slot in slots) _PreviewTile(slot: slot)],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewSlot {
  const _PreviewSlot({
    required this.label,
    required this.asset,
    required this.cacheKey,
  });

  final String label;
  final PreviewAsset? asset;
  final String? cacheKey;
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.slot});

  final _PreviewSlot slot;

  @override
  Widget build(BuildContext context) {
    final asset = slot.asset;
    if (asset == null) {
      return SrImagePlaceholder(label: '${slot.label} pending');
    }
    final uri = AppConfig.apiUri(asset.url).replace(
      queryParameters: {if (slot.cacheKey != null) 'v': slot.cacheKey!},
    );
    return DiagnosticNetworkImage(
      uri: uri,
      assetKind: asset.kind,
      fit: BoxFit.cover,
      cacheKey: slot.cacheKey,
      label: slot.label,
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
        onPressed: detail.openLog.supported ? () => _openLogDir(detail.logDir) : null,
        icon: const Icon(Icons.article_outlined),
        label: const Text('Open log'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final event in detail.recentEvents.take(3))
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
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
              onPressed: detail.openLog.supported ? () => _openLogDir(detail.logDir) : null,
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

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({
    required this.records,
    required this.metricKey,
    required this.yAxisLabel,
    required this.color,
    required this.textColor,
    required this.axisColor,
  });

  final List<MetricRecord> records;
  final String metricKey;
  final String yAxisLabel;
  final Color color;
  final Color textColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      for (final record in records)
        if (record.values[metricKey] != null)
          _MetricPoint(record: record, value: record.values[metricKey]!),
    ];
    if (points.isEmpty) {
      _drawText(
        canvas,
        'No data yet',
        Offset(size.width / 2 - 34, size.height / 2),
      );
      return;
    }
    final plot = Rect.fromLTWH(
      44,
      8,
      math.max(0, size.width - 56),
      math.max(0, size.height - 40),
    );
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    _drawText(canvas, 'Epoch', Offset(plot.center.dx - 16, size.height - 14));
    _drawText(canvas, yAxisLabel, Offset(0, plot.top + 2));

    final values = [for (final point in points) point.value];
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.000001
        ? 1.0
        : maxValue - minValue;
    for (var index = 0; index < 4; index++) {
      final ratio = index / 3;
      final y = plot.bottom - ratio * plot.height;
      final value = minValue + ratio * span;
      canvas.drawLine(
        Offset(plot.left - 4, y),
        Offset(plot.left, y),
        axisPaint,
      );
      _drawText(canvas, _formatAxisValue(value), Offset(4, y - 7));
    }
    final xTickCount = math.min(points.length, 3);
    for (var index = 0; index < xTickCount; index++) {
      final sourceIndex = xTickCount == 1
          ? 0
          : ((points.length - 1) * index / (xTickCount - 1)).round();
      final ratio = points.length == 1
          ? 0.0
          : sourceIndex / (points.length - 1);
      final x = plot.left + ratio * plot.width;
      canvas.drawLine(
        Offset(x, plot.bottom),
        Offset(x, plot.bottom + 4),
        axisPaint,
      );
      _drawText(
        canvas,
        points[sourceIndex].record.epoch.toString(),
        Offset(x - 4, plot.bottom + 7),
      );
    }
    if (points.length < 2) {
      final y =
          plot.bottom - ((points.first.value - minValue) / span * plot.height);
      canvas.drawCircle(Offset(plot.left, y), 3, Paint()..color = color);
      return;
    }
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = plot.left + plot.width * (index / (points.length - 1));
      final y =
          plot.bottom - ((points[index].value - minValue) / span * plot.height);
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

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _formatAxisValue(double value) {
    if (value.abs() >= 100) {
      return value.toStringAsFixed(0);
    }
    if (value.abs() >= 10) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsPrecision(2);
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.metricKey != metricKey ||
      oldDelegate.color != color;
}

class _MetricPoint {
  const _MetricPoint({required this.record, required this.value});

  final MetricRecord record;
  final double value;
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

String _formatTelemetry(TelemetryField? field) {
  if (field == null || !field.available || field.value == null) {
    return '--';
  }
  return '${field.value}${field.unit == null ? '' : ' ${field.unit}'}';
}

String _phaseLabel(String phase) {
  return switch (phase) {
    'validation' => 'Validation epoch',
    'training' => 'Training epoch',
    _ => 'Epoch progress',
  };
}

String _progressDetail(double? current, double? total) {
  if (current == null || total == null || total <= 0) {
    return '';
  }
  return '${current.round()}/${total.round()} iters';
}

List<MetricRecord> _recordsWithLiveSample(
  List<MetricRecord> records,
  ActiveRunStatus status,
) {
  final liveValues = {
    for (final key in const [
      'train_loss_total',
      'val_psnr',
      'val_ssim',
      'learning_rate',
      'progress',
      'iterations_per_second',
    ])
      if (status.latestMetrics[key] != null) key: status.latestMetrics[key]!,
  };
  if (status.iteration <= 0 || liveValues.isEmpty) {
    return records;
  }
  if (records.isNotEmpty && records.last.iteration >= status.iteration) {
    return records;
  }
  return [
    ...records,
    MetricRecord(
      step: status.epoch,
      epoch: status.epoch,
      iteration: status.iteration,
      values: liveValues,
    ),
  ];
}

void _openLogDir(String? logDir) {
  final path = logDir;
  if (path == null || path.isEmpty) return;
  try {
    io.Process.run('xdg-open', [path]);
  } catch (_) {
    // Fallback: silently ignore if xdg-open is unavailable
  }
}

