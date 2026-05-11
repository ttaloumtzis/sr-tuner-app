import 'dart:io';

import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../path_picker.dart' show PathPicker;
import '../project_models.dart';
import '../shared_widgets.dart';

class InferenceTab extends StatefulWidget {
  const InferenceTab({
    required this.client,
    required this.project,
    this.initialCheckpointId,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final String? initialCheckpointId;

  @override
  State<InferenceTab> createState() => _InferenceTabState();
}

class _InferenceTabState extends State<InferenceTab> {
  String? _selectedRunId;
  String? _selectedCheckpointId;
  CheckpointSummary? _selectedCheckpoint;
  CheckpointListEnvelope? _checkpointEnvelope;

  String _inputPath = '';
  String? _outputDir;
  String _mode = 'single';
  String _device = 'cpu';
  String _outputFormat = 'png';

  bool _tilingEnabled = false;
  int _tileSize = 512;
  int _tileOverlap = 32;
  String _paddingMode = 'reflect';
  String _blendStrategy = 'average';

  InferenceReadiness? _readiness;
  List<DeviceOption> _devices = [];
  InferenceRecord? _lastResult;
  bool _running = false;
  String? _error;

  List<InferenceRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadReadiness();
    _loadHistory();
    if (widget.initialCheckpointId != null) {
      _preselectCheckpoint(widget.initialCheckpointId!);
    } else {
      _autoSelectRun();
    }
  }

  @override
  void didUpdateWidget(InferenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCheckpointId != widget.initialCheckpointId &&
        widget.initialCheckpointId != null) {
      _preselectCheckpoint(widget.initialCheckpointId!);
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.client.devices();
      if (mounted) setState(() => _devices = devices);
    } catch (_) {}
  }

  Future<void> _loadReadiness() async {
    try {
      final r = await widget.client.inferenceReadiness(device: _device);
      if (mounted) setState(() => _readiness = r);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final env = await widget.client.listInferenceHistory(widget.project.id);
      if (mounted) setState(() => _history = env.records.reversed.toList());
    } catch (_) {}
  }

  void _autoSelectRun() {
    final runs = widget.project.runs;
    if (runs.isEmpty) return;
    _loadRunCheckpoints(runs.last.id);
  }

  void _preselectCheckpoint(String checkpointId) {
    for (final run in widget.project.runs) {
      _loadRunCheckpoints(run.id, preselectCheckpointId: checkpointId);
      break;
    }
  }

  Future<void> _loadRunCheckpoints(String runId, {String? preselectCheckpointId}) async {
    setState(() {
      _selectedRunId = runId;
      _selectedCheckpoint = null;
      _selectedCheckpointId = null;
    });
    try {
      final env = await widget.client.listRunCheckpoints(
        projectId: widget.project.id,
        runId: runId,
      );
      if (!mounted) return;
      setState(() {
        _checkpointEnvelope = env;
        if (preselectCheckpointId != null) {
          final match = env.checkpoints
              .where((c) => c.id == preselectCheckpointId && !c.deleted)
              .firstOrNull;
          if (match != null) {
            _selectedCheckpoint = match;
            _selectedCheckpointId = match.id;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickInput() async {
    if (_mode == 'single') {
      final path = await const PathPicker().pickFile();
      if (path != null && mounted) setState(() => _inputPath = path);
    } else {
      final path = await const PathPicker().pickFolder();
      if (path != null && mounted) setState(() => _inputPath = path);
    }
  }

  Future<void> _pickOutputDir() async {
    final path = await const PathPicker().pickFolder(confirmButtonText: 'Save here');
    if (path != null && mounted) setState(() => _outputDir = path);
  }

  Future<void> _runInference() async {
    if (_selectedRunId == null || _selectedCheckpointId == null) {
      setState(() => _error = 'Select a checkpoint first.');
      return;
    }
    if (_inputPath.isEmpty) {
      setState(() => _error = 'Select an input image or folder.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final record = await widget.client.runInference(
        projectId: widget.project.id,
        runId: _selectedRunId!,
        checkpointId: _selectedCheckpointId!,
        inputPath: _inputPath,
        outputDir: _outputDir,
        outputFormat: _outputFormat,
        mode: _mode,
        device: _device,
        tileConfig: TileConfig(
          enabled: _tilingEnabled,
          tileSize: _tileSize,
          overlap: _tileOverlap,
          paddingMode: _paddingMode,
          blendStrategy: _blendStrategy,
        ),
      );
      if (mounted) {
        setState(() {
          _lastResult = record;
          _history = [record, ..._history];
          _running = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.toString(); _running = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final runs = widget.project.runs;
    if (runs.isEmpty) {
      return const BlockedState(
        title: 'Inference',
        message: 'No checkpoints yet. Train a model and save a checkpoint first.',
        icon: Icons.compare,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: _SettingsPanel(
                    runs: runs,
                    selectedRunId: _selectedRunId,
                    selectedCheckpoint: _selectedCheckpoint,
                    checkpoints: _checkpointEnvelope?.checkpoints.where((c) => !c.deleted).toList() ?? [],
                    onRunSelected: _loadRunCheckpoints,
                    onCheckpointSelected: (c) => setState(() {
                      _selectedCheckpoint = c;
                      _selectedCheckpointId = c.id;
                    }),
                    inputPath: _inputPath,
                    onPickInput: _pickInput,
                    outputDir: _outputDir,
                    onPickOutput: _pickOutputDir,
                    mode: _mode,
                    onModeChanged: (v) => setState(() { _mode = v; _inputPath = ''; }),
                    device: _device,
                    devices: _devices,
                    onDeviceChanged: (v) {
                      setState(() => _device = v);
                      _loadReadiness();
                    },
                    outputFormat: _outputFormat,
                    onFormatChanged: (v) => setState(() => _outputFormat = v),
                    tilingEnabled: _tilingEnabled,
                    onTilingChanged: (v) => setState(() => _tilingEnabled = v),
                    tileSize: _tileSize,
                    onTileSizeChanged: (v) => setState(() => _tileSize = v),
                    tileOverlap: _tileOverlap,
                    onTileOverlapChanged: (v) => setState(() => _tileOverlap = v),
                    paddingMode: _paddingMode,
                    onPaddingModeChanged: (v) => setState(() => _paddingMode = v),
                    blendStrategy: _blendStrategy,
                    onBlendStrategyChanged: (v) => setState(() => _blendStrategy = v),
                    readiness: _readiness,
                    running: _running,
                    onRun: _runInference,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultPanel(
                    result: _lastResult,
                    inputPath: _inputPath,
                    running: _running,
                    history: _history,
                    onHistorySelected: (r) => setState(() => _lastResult = r),
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

// ── Settings panel ─────────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.runs,
    required this.selectedRunId,
    required this.selectedCheckpoint,
    required this.checkpoints,
    required this.onRunSelected,
    required this.onCheckpointSelected,
    required this.inputPath,
    required this.onPickInput,
    required this.outputDir,
    required this.onPickOutput,
    required this.mode,
    required this.onModeChanged,
    required this.device,
    required this.devices,
    required this.onDeviceChanged,
    required this.outputFormat,
    required this.onFormatChanged,
    required this.tilingEnabled,
    required this.onTilingChanged,
    required this.tileSize,
    required this.onTileSizeChanged,
    required this.tileOverlap,
    required this.onTileOverlapChanged,
    required this.paddingMode,
    required this.onPaddingModeChanged,
    required this.blendStrategy,
    required this.onBlendStrategyChanged,
    required this.readiness,
    required this.running,
    required this.onRun,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final CheckpointSummary? selectedCheckpoint;
  final List<CheckpointSummary> checkpoints;
  final ValueChanged<String> onRunSelected;
  final ValueChanged<CheckpointSummary> onCheckpointSelected;
  final String inputPath;
  final VoidCallback onPickInput;
  final String? outputDir;
  final VoidCallback onPickOutput;
  final String mode;
  final ValueChanged<String> onModeChanged;
  final String device;
  final List<DeviceOption> devices;
  final ValueChanged<String> onDeviceChanged;
  final String outputFormat;
  final ValueChanged<String> onFormatChanged;
  final bool tilingEnabled;
  final ValueChanged<bool> onTilingChanged;
  final int tileSize;
  final ValueChanged<int> onTileSizeChanged;
  final int tileOverlap;
  final ValueChanged<int> onTileOverlapChanged;
  final String paddingMode;
  final ValueChanged<String> onPaddingModeChanged;
  final String blendStrategy;
  final ValueChanged<String> onBlendStrategyChanged;
  final InferenceReadiness? readiness;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final ready = readiness?.available ?? false;

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inference Settings', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _sectionLabel('Run', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedRunId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final run in runs)
                  DropdownMenuItem(value: run.id, child: Text(run.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) { if (v != null) onRunSelected(v); },
            ),
            const SizedBox(height: 10),
            _sectionLabel('Checkpoint', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedCheckpoint?.id,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final c in checkpoints)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('Epoch ${c.epoch}${c.tags.isNotEmpty ? " (${c.tags.join(', ')})" : ""}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  final match = checkpoints.firstWhere((c) => c.id == v);
                  onCheckpointSelected(match);
                }
              },
            ),
            if (selectedCheckpoint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Scale: ×${selectedCheckpoint!.scale}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            const SizedBox(height: 10),
            _sectionLabel('Mode', context),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'single', label: Text('Single')),
                ButtonSegment(value: 'batch', label: Text('Batch')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
            const SizedBox(height: 10),
            _sectionLabel(mode == 'single' ? 'Input image' : 'Input folder', context),
            Row(
              children: [
                Expanded(
                  child: Text(
                    inputPath.isEmpty ? 'None selected' : inputPath.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onPickInput,
                  child: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _sectionLabel('Output folder (optional)', context),
            Row(
              children: [
                Expanded(
                  child: Text(
                    outputDir ?? 'Default (project/inference/)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(onPressed: onPickOutput, child: const Text('Browse')),
              ],
            ),
            const SizedBox(height: 10),
            _sectionLabel('Device', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: device,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final d in devices)
                  DropdownMenuItem(value: d.id, child: Text(d.label)),
              ],
              onChanged: (v) { if (v != null) onDeviceChanged(v); },
            ),
            const SizedBox(height: 10),
            _sectionLabel('Output format', context),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'png', label: Text('PNG')),
                ButtonSegment(value: 'jpg', label: Text('JPG')),
              ],
              selected: {outputFormat},
              onSelectionChanged: (s) => onFormatChanged(s.first),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _sectionLabel('Tiling', context),
                const Spacer(),
                Switch(value: tilingEnabled, onChanged: onTilingChanged),
              ],
            ),
            if (tilingEnabled) ...[
              _labeledSlider('Tile size', tileSize, 64, 1024, (v) => onTileSizeChanged(v.round()), context),
              _labeledSlider('Overlap', tileOverlap, 0, 256, (v) => onTileOverlapChanged(v.round()), context),
              _sectionLabel('Padding', context),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: paddingMode,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                items: const [
                  DropdownMenuItem(value: 'reflect', child: Text('Reflect')),
                  DropdownMenuItem(value: 'replicate', child: Text('Replicate')),
                  DropdownMenuItem(value: 'constant', child: Text('Zero')),
                ],
                onChanged: (v) { if (v != null) onPaddingModeChanged(v); },
              ),
              const SizedBox(height: 8),
              _sectionLabel('Blending', context),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'average', label: Text('Average')),
                  ButtonSegment(value: 'linear', label: Text('Linear')),
                ],
                selected: {blendStrategy},
                onSelectionChanged: (s) => onBlendStrategyChanged(s.first),
              ),
            ],
            const SizedBox(height: 12),
            if (readiness != null && !readiness!.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  readiness!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            FilledButton.icon(
              onPressed: running || !ready ? null : onRun,
              icon: running
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(running ? 'Running…' : 'Run Inference'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Widget _labeledSlider(String label, int value, int min, int max, ValueChanged<double> onChanged, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _sectionLabel(label, context),
          const Spacer(),
          Text('$value', style: const TextStyle(fontSize: 12)),
        ]),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 32,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Result / preview panel ─────────────────────────────────────────────────────

class _ResultPanel extends StatefulWidget {
  const _ResultPanel({
    required this.result,
    required this.inputPath,
    required this.running,
    required this.history,
    required this.onHistorySelected,
  });

  final InferenceRecord? result;
  final String inputPath;
  final bool running;
  final List<InferenceRecord> history;
  final ValueChanged<InferenceRecord> onHistorySelected;

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel> {
  String _previewMode = 'split';

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          _PreviewControls(
            mode: _previewMode,
            onModeChanged: (v) => setState(() => _previewMode = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: _buildPreview(result),
          ),
          const SizedBox(height: 8),
          _ResultInfo(result: result),
        ] else if (widget.running) ...[
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare, size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('Run inference to see results here.', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
        ],
        if (widget.history.isNotEmpty) ...[
          const Divider(),
          SizedBox(
            height: 100,
            child: _HistoryList(
              history: widget.history,
              selected: result,
              onSelected: widget.onHistorySelected,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview(InferenceRecord result) {
    final outputPath = result.outputPath;
    if (outputPath == null) {
      if (result.mode == 'batch') {
        return _BatchResultSummary(result: result);
      }
      return const Center(child: Text('No output preview available.', style: TextStyle(color: Colors.white38)));
    }

    if (_previewMode == 'split') {
      return BeforeAfterComparison(
        inputPath: result.inputPath,
        outputPath: outputPath,
      );
    }

    return _SideBySidePreview(inputPath: result.inputPath, outputPath: outputPath);
  }
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls({required this.mode, required this.onModeChanged});

  final String mode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Preview:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'split', label: Text('Split'), icon: Icon(Icons.compare, size: 14)),
            ButtonSegment(value: 'side', label: Text('Side by side'), icon: Icon(Icons.view_column, size: 14)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
      ],
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.result});

  final InferenceRecord result;

  @override
  Widget build(BuildContext context) {
    final successes = result.perFileResults.where((r) => r.status == 'success').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _chip(Icons.check_circle, '${result.scale}×', const Color(0xff58c48a)),
            const SizedBox(width: 12),
            _chip(Icons.timer, '${result.runtimeSeconds.toStringAsFixed(1)}s', Colors.white54),
            const SizedBox(width: 12),
            _chip(Icons.folder_open, result.mode == 'batch' ? '$successes / ${result.perFileResults.length}' : '1/1', Colors.white54),
            const SizedBox(width: 12),
            Expanded(child: Text(result.outputDir ?? result.outputPath ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(result.status).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(result.status, style: TextStyle(color: _statusColor(result.status), fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => const Color(0xff58c48a),
      'partial' => const Color(0xffffc857),
      _ => Colors.redAccent,
    };
  }
}

class _BatchResultSummary extends StatelessWidget {
  const _BatchResultSummary({required this.result});

  final InferenceRecord result;

  @override
  Widget build(BuildContext context) {
    final successes = result.perFileResults.where((r) => r.status == 'success').toList();
    final failures = result.perFileResults.where((r) => r.status == 'failed').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Batch results', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('${successes.length} succeeded, ${failures.length} failed', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final r in result.perFileResults)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        r.status == 'success' ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: r.status == 'success' ? const Color(0xff58c48a) : Colors.redAccent,
                      ),
                      title: Text(r.filename, style: const TextStyle(fontSize: 12)),
                      subtitle: r.error != null ? Text(r.error!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)) : null,
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

// ── Before/after comparison ────────────────────────────────────────────────────

class BeforeAfterComparison extends StatefulWidget {
  const BeforeAfterComparison({
    required this.inputPath,
    required this.outputPath,
    super.key,
  });

  final String inputPath;
  final String outputPath;

  @override
  State<BeforeAfterComparison> createState() => _BeforeAfterComparisonState();
}

class _BeforeAfterComparisonState extends State<BeforeAfterComparison> {
  double _splitFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final splitX = totalWidth * _splitFraction;

          return GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _splitFraction = (_splitFraction + d.delta.dx / totalWidth).clamp(0.02, 0.98);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Right side: SR output
                _InferenceImage(path: widget.outputPath),
                // Left side: LR input, clipped
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _splitFraction,
                    child: SizedBox(
                      width: totalWidth,
                      child: _InferenceImage(path: widget.inputPath),
                    ),
                  ),
                ),
                // Divider line
                Positioned(
                  left: splitX - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: Container(color: Colors.white70),
                ),
                // Drag handle
                Positioned(
                  left: splitX - 14,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: const Center(
                    child: Icon(Icons.drag_indicator, color: Colors.white70, size: 20),
                  ),
                ),
                // Labels
                Positioned(
                  left: 8,
                  top: 8,
                  child: _label('Before (LR)'),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _label('After (SR)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}

class _InferenceImage extends StatelessWidget {
  const _InferenceImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(child: Text('File not found', style: TextStyle(color: Colors.white38)));
    }
    return InteractiveViewer(
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}

class _SideBySidePreview extends StatelessWidget {
  const _SideBySidePreview({
    required this.inputPath,
    required this.outputPath,
  });

  final String inputPath;
  final String outputPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Before (LR)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(child: _InferenceImage(path: inputPath)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('After (SR)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(child: _InferenceImage(path: outputPath)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── History list ───────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.selected,
    required this.onSelected,
  });

  final List<InferenceRecord> history;
  final InferenceRecord? selected;
  final ValueChanged<InferenceRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('History', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              itemBuilder: (context, index) {
                final r = history[index];
                final isSelected = r.id == selected?.id;
                return GestureDetector(
                  onTap: () => onSelected(r),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white12 : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? Colors.white38 : Colors.transparent),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.inputPath.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text('×${r.scale}  ${r.runtimeSeconds.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(r.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => const Color(0xff58c48a),
      'partial' => const Color(0xffffc857),
      _ => Colors.redAccent,
    };
  }
}
