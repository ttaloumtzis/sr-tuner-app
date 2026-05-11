import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../path_picker.dart' show PathPicker;
import '../project_models.dart';
import '../shared_widgets.dart';

class CheckpointsTab extends StatefulWidget {
  const CheckpointsTab({
    required this.client,
    required this.project,
    required this.onInferenceHandoff,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<String> onInferenceHandoff;

  @override
  State<CheckpointsTab> createState() => _CheckpointsTabState();
}

class _CheckpointsTabState extends State<CheckpointsTab> {
  String? _selectedRunId;
  CheckpointListEnvelope? _envelope;
  CheckpointSummary? _selected;
  OnnxReadiness? _onnxReadiness;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadOnnxReadiness();
    _autoSelectRun();
  }

  @override
  void didUpdateWidget(CheckpointsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _autoSelectRun();
    }
  }

  void _autoSelectRun() {
    final runs = widget.project.runs;
    if (runs.isEmpty) return;
    final runId = _selectedRunId ?? runs.last.id;
    _loadCheckpoints(runId);
  }

  Future<void> _loadOnnxReadiness() async {
    try {
      final r = await widget.client.onnxReadiness();
      if (mounted) setState(() => _onnxReadiness = r);
    } catch (_) {}
  }

  Future<void> _loadCheckpoints(String runId) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedRunId = runId;
      _selected = null;
    });
    try {
      final envelope = await widget.client.listRunCheckpoints(
        projectId: widget.project.id,
        runId: runId,
      );
      if (mounted) {
        setState(() {
          _envelope = envelope;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _confirmDelete(CheckpointSummary checkpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete checkpoint?'),
        content: Text('Epoch ${checkpoint.epoch} will be permanently deleted. Historical references will be preserved but disabled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = await widget.client.deleteCheckpoint(
        projectId: widget.project.id,
        runId: _selectedRunId!,
        checkpointId: checkpoint.id,
      );
      if (mounted) setState(() { _envelope = updated; _selected = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPth(CheckpointSummary checkpoint) async {
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      await widget.client.exportCheckpointPth(
        projectId: widget.project.id,
        runId: _selectedRunId!,
        checkpointId: checkpoint.id,
        destination: dest,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to $dest')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportOnnx(CheckpointSummary checkpoint) async {
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      await widget.client.exportCheckpointOnnx(
        projectId: widget.project.id,
        runId: _selectedRunId!,
        checkpointId: checkpoint.id,
        destination: dest,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ONNX to $dest')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final runs = widget.project.runs;
    if (runs.isEmpty) {
      return const BlockedState(
        title: 'Checkpoints',
        message: 'No runs yet. Train a model to create checkpoints.',
        icon: Icons.save_alt,
      );
    }

    final checkpoints = _envelope?.checkpoints.where((c) => !c.deleted).toList() ?? [];

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
                  width: 220,
                  child: _RunSelector(
                    runs: runs,
                    selectedRunId: _selectedRunId,
                    onRunSelected: _loadCheckpoints,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : checkpoints.isEmpty
                          ? const _EmptyCheckpoints()
                          : _CheckpointTable(
                              checkpoints: checkpoints,
                              selected: _selected,
                              onSelected: (c) => setState(() => _selected = c),
                            ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 280,
                  child: _DetailsPanel(
                    checkpoint: _selected,
                    onnxReadiness: _onnxReadiness,
                    onDelete: _selected != null ? () => _confirmDelete(_selected!) : null,
                    onExportPth: _selected != null ? () => _exportPth(_selected!) : null,
                    onExportOnnx: _selected != null && (_onnxReadiness?.available ?? false)
                        ? () => _exportOnnx(_selected!)
                        : null,
                    onInference: _selected != null
                        ? () => widget.onInferenceHandoff(_selected!.id)
                        : null,
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

class _RunSelector extends StatelessWidget {
  const _RunSelector({
    required this.runs,
    required this.selectedRunId,
    required this.onRunSelected,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final ValueChanged<String> onRunSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Runs', style: Theme.of(context).textTheme.titleSmall),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: runs.length,
              itemBuilder: (context, index) {
                final run = runs[index];
                final selected = run.id == selectedRunId;
                return ListTile(
                  selected: selected,
                  title: Text(run.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    run.state,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () => onRunSelected(run.id),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCheckpoints extends StatelessWidget {
  const _EmptyCheckpoints();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.save_alt, size: 40, color: Colors.white38),
          SizedBox(height: 12),
          Text('No checkpoints for this run yet.', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _CheckpointTable extends StatelessWidget {
  const _CheckpointTable({
    required this.checkpoints,
    required this.selected,
    required this.onSelected,
  });

  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? selected;
  final ValueChanged<CheckpointSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _colHeader('Epoch', flex: 1),
                _colHeader('PSNR', flex: 2),
                _colHeader('Loss', flex: 2),
                _colHeader('Size', flex: 2),
                _colHeader('Tags', flex: 3),
                _colHeader('Saved', flex: 3),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: checkpoints.length,
              itemBuilder: (context, index) {
                final ckpt = checkpoints[index];
                final isSelected = ckpt.id == selected?.id;
                return InkWell(
                  onTap: () => onSelected(ckpt),
                  child: Container(
                    color: isSelected ? Colors.white10 : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _col(ckpt.epoch.toString(), flex: 1),
                        _col(_fmtMetric(ckpt.metrics['val_psnr'], 'dB'), flex: 2),
                        _col(_fmtMetric(ckpt.metrics['train_loss_total'], null), flex: 2),
                        _col(_fmtSize(ckpt.sizeBytes), flex: 2),
                        Expanded(
                          flex: 3,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              for (final tag in ckpt.tags)
                                _TagChip(tag: tag),
                            ],
                          ),
                        ),
                        _col(_fmtDate(ckpt.savedAt), flex: 3),
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

  Widget _colHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _col(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  static const _colors = {
    'latest': Color(0xff58c48a),
    'best_psnr': Color(0xff6aa6ff),
    'best_loss': Color(0xffffc857),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[tag] ?? Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(tag, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.checkpoint,
    required this.onnxReadiness,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
    required this.onInference,
  });

  final CheckpointSummary? checkpoint;
  final OnnxReadiness? onnxReadiness;
  final VoidCallback? onDelete;
  final VoidCallback? onExportPth;
  final VoidCallback? onExportOnnx;
  final VoidCallback? onInference;

  @override
  Widget build(BuildContext context) {
    final ckpt = checkpoint;
    if (ckpt == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select a checkpoint to see details.', style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    final onnx = onnxReadiness;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkpoint details', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _row('Epoch', ckpt.epoch.toString()),
            _row('Iteration', ckpt.iteration.toString()),
            _row('Architecture', ckpt.modelArchitecture.isEmpty ? '—' : ckpt.modelArchitecture),
            _row('Scale', ckpt.scale > 0 ? '×${ckpt.scale}' : '—'),
            _row('PSNR', _fmtMetric(ckpt.metrics['val_psnr'], 'dB')),
            _row('Loss', _fmtMetric(ckpt.metrics['train_loss_total'], null)),
            _row('Size', _fmtSize(ckpt.sizeBytes)),
            _row('Saved', _fmtDate(ckpt.savedAt)),
            if (ckpt.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final t in ckpt.tags) _TagChip(tag: t)],
              ),
            ],
            const Spacer(),
            const Divider(),
            if (onnx != null && !onnx.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'ONNX: ${onnx.message}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            OutlinedButton.icon(
              onPressed: onInference,
              icon: const Icon(Icons.compare, size: 16),
              label: const Text('Run Inference'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onExportPth,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export .pth'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onExportOnnx,
              icon: const Icon(Icons.transform, size: 16),
              label: const Text('Export ONNX'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

String _fmtMetric(double? value, String? unit) {
  if (value == null || value == 0) return '—';
  final s = value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsPrecision(3);
  return unit == null ? s : '$s $unit';
}

String _fmtSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

String _fmtDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';
  } catch (_) {
    return iso;
  }
}

String _p(int n) => n.toString().padLeft(2, '0');
