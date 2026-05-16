import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_theme.dart';
import '../design_system/sr_button.dart';
import '../design_system/sr_chart.dart';
import '../design_system/sr_chip.dart';
import '../path_picker.dart' show PathPicker;
import '../project_models.dart';
import '../shared_widgets.dart';

class CheckpointsTab extends StatefulWidget {
  const CheckpointsTab({
    required this.client,
    required this.project,
    required this.onInferenceHandoff,
    this.onFineTuneHandoff,
    this.onNavigateToTab,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<String> onInferenceHandoff;
  final void Function(String checkpointId, String? coreWeightsPath)? onFineTuneHandoff;
  final void Function(int)? onNavigateToTab;

  @override
  State<CheckpointsTab> createState() => _CheckpointsTabState();
}

class _CheckpointsTabState extends State<CheckpointsTab> {
  CheckpointAggregate? _aggregate;
  CheckpointSummary? _selected;
  final Set<String> _selectedForComparison = <String>{};
  OnnxReadiness? _onnxReadiness;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadOnnxReadiness();
    _loadAggregate();
  }

  @override
  void didUpdateWidget(CheckpointsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadAggregate();
    }
  }

  Future<void> _loadAggregate() async {
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
      _selectedForComparison.clear();
    });
    try {
      final aggregate = await widget.client.checkpointAggregate(widget.project.id);
      if (mounted) {
        setState(() {
          _aggregate = aggregate;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadOnnxReadiness() async {
    try {
      final r = await widget.client.onnxReadiness();
      if (mounted) setState(() => _onnxReadiness = r);
    } catch (_) {}
  }

  String? _findRunIdForCheckpoint(String checkpointId) {
    for (final checkpoint in _aggregate?.checkpoints ?? []) {
      if (checkpoint.id == checkpointId) {
        return checkpoint.runId;
      }
    }
    return null;
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
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).extension<SrTokens>()!.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // Find the run ID for this checkpoint
      final runId = _findRunIdForCheckpoint(checkpoint.id);
      if (runId != null) {
        await widget.client.deleteCheckpoint(
          projectId: widget.project.id,
          runId: runId,
          checkpointId: checkpoint.id,
        );
        await _loadAggregate(); // Refresh data
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPth(CheckpointSummary checkpoint) async {
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      final runId = _findRunIdForCheckpoint(checkpoint.id);
      if (runId != null) {
        await widget.client.exportCheckpointPth(
          projectId: widget.project.id,
          runId: runId,
          checkpointId: checkpoint.id,
          destination: dest,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $dest')),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportOnnx(CheckpointSummary checkpoint) async {
    if (_onnxReadiness?.available != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ONNX export requires the onnx package. Install it in the backend environment.')),
      );
      return;
    }
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      final runId = _findRunIdForCheckpoint(checkpoint.id);
      if (runId != null) {
        await widget.client.exportCheckpointOnnx(
          projectId: widget.project.id,
          runId: runId,
          checkpointId: checkpoint.id,
          destination: dest,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ONNX to $dest')),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadAggregate, child: const Text('Retry')),
          ],
        ),
      );
    }

    final models = widget.project.models.where((m) =>
        m.trainHistory != null && m.trainHistory!.isNotEmpty).toList();
    final runs = widget.project.runs;

    if (models.isEmpty && runs.isEmpty) {
      return const BlockedState(
        title: 'Checkpoints',
        message: 'No training history yet. Train a model to create checkpoints.',
        icon: Icons.save_alt,
      );
    }

    final checkpoints = _aggregate?.checkpoints.where((c) => !c.deleted).toList() ?? [];
    final bestCheckpoint = _aggregate?.bestCheckpoint;
    final actions = _aggregate?.actions ?? <String, ActionState>{};

    if (checkpoints.isEmpty) {
      return _EmptyCheckpoints(onNavigateToTab: widget.onNavigateToTab);
    }

    return Column(
      children: [
        _AggregateHeader(
          checkpointCount: checkpoints.length,
          bestCheckpoint: bestCheckpoint,
          actions: actions,
          onExportBest: bestCheckpoint != null && actions['export_best']?.supported == true
              ? () => _exportPth(bestCheckpoint)
              : null,
          onContinueFromBest: bestCheckpoint != null && actions['continue_from_best']?.supported == true
              ? () => widget.onInferenceHandoff(bestCheckpoint.id)
              : null,
        ),
        
        if (bestCheckpoint != null && _aggregate?.psnrDelta != null)
          _PsnrStrip(
            checkpoints: checkpoints,
            psnrDelta: _aggregate!.psnrDelta!,
          ),
        
        Expanded(
          child: ListView(
            children: [
              for (final model in models)
                _ModelSessionGroup(
                  model: model,
                  checkpoints: checkpoints,
                  bestCheckpoint: bestCheckpoint,
                  selected: _selected,
                  selectedForComparison: _selectedForComparison,
                  onSelected: (checkpoint) {
                    setState(() => _selected = checkpoint);
                  },
                  onToggleComparison: (checkpointId, isMultiSelect) {
                    setState(() {
                      if (isMultiSelect) {
                        if (_selectedForComparison.contains(checkpointId)) {
                          _selectedForComparison.remove(checkpointId);
                        } else {
                          _selectedForComparison.add(checkpointId);
                        }
                      } else {
                        _selectedForComparison.clear();
                        _selectedForComparison.add(checkpointId);
                      }
                    });
                  },
                  onInference: (checkpoint) => widget.onInferenceHandoff(checkpoint.id),
                  onFineTune: (checkpoint) => widget.onFineTuneHandoff?.call(
                    checkpoint.id,
                    'models/${model.id}/core_weights/${checkpoint.runId}_core.pth',
                  ),
                  onDelete: _confirmDelete,
                  onExportPth: _exportPth,
                  onExportOnnx: _exportOnnx,
                ),
              if (models.isEmpty && checkpoints.isNotEmpty)
                _LegacyCheckpointList(
                  checkpoints: checkpoints,
                  bestCheckpoint: bestCheckpoint,
                  selected: _selected,
                  selectedForComparison: _selectedForComparison,
                  onSelected: (checkpoint) {
                    setState(() => _selected = checkpoint);
                  },
                  onToggleComparison: (checkpointId, isMultiSelect) {
                    setState(() {
                      if (isMultiSelect) {
                        if (_selectedForComparison.contains(checkpointId)) {
                          _selectedForComparison.remove(checkpointId);
                        } else {
                          _selectedForComparison.add(checkpointId);
                        }
                      } else {
                        _selectedForComparison.clear();
                        _selectedForComparison.add(checkpointId);
                      }
                    });
                  },
                  onInference: (checkpoint) => widget.onInferenceHandoff(checkpoint.id),
                  onFineTune: (checkpoint) => widget.onFineTuneHandoff?.call(
                    checkpoint.id,
                    null,
                  ),
                  onDelete: _confirmDelete,
                  onExportPth: _exportPth,
                  onExportOnnx: _exportOnnx,
                ),
            ],
          ),
        ),
        
        _ComparisonFooter(
          selectedCount: _selectedForComparison.length,
          canPrune: actions['prune']?.supported == true,
          canCompare: _selectedForComparison.length >= 2,
          onPrune: actions['prune']?.supported == true ? () => _handlePrune() : null,
          onCompare: _selectedForComparison.length >= 2 ? () => _handleCompare() : null,
          onDeleteSelected: _selectedForComparison.isNotEmpty
              ? () => _confirmBatchDelete(_selectedForComparison.toList())
              : null,
        ),
      ],
    );
  }

  void _handlePrune() {
    // TODO: Implement prune functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prune functionality not yet implemented')),
    );
  }

  void _handleCompare() {
    // TODO: Implement compare functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compare functionality not yet implemented')),
    );
  }

  Future<void> _confirmBatchDelete(List<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${ids.length} checkpoint${ids.length == 1 ? '' : 's'}?'),
        content: const Text('Selected checkpoints will be permanently deleted. Historical references will be preserved but disabled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).extension<SrTokens>()!.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    int deleted = 0;
    for (final id in ids) {
      final runId = _findRunIdForCheckpoint(id);
      if (runId == null) continue;
      try {
        await widget.client.deleteCheckpoint(
          projectId: widget.project.id,
          runId: runId,
          checkpointId: id,
        );
        deleted++;
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.toString());
        break;
      }
    }
    if (mounted) {
      setState(() => _selectedForComparison.clear());
      await _loadAggregate();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deleted checkpoint${deleted == 1 ? '' : 's'}.')),
      );
    }
  }
}

class _AggregateHeader extends StatelessWidget {
  const _AggregateHeader({
    required this.checkpointCount,
    required this.bestCheckpoint,
    required this.actions,
    required this.onExportBest,
    required this.onContinueFromBest,
  });

  final int checkpointCount;
  final CheckpointSummary? bestCheckpoint;
  final Map<String, ActionState> actions;
  final VoidCallback? onExportBest;
  final VoidCallback? onContinueFromBest;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$checkpointCount checkpoints',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (bestCheckpoint != null) ...[
                      const SizedBox(width: 6),
                      SrChip(
                        label: 'best ${bestCheckpoint!.path.split('/').last}',
                        icon: Icons.star,
                        kind: SrChipKind.ok,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-pruned to top 3 + manual saves',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              SrButton(
                label: 'Export best',
                icon: Icons.download,
                onPressed: onExportBest,
                size: SrButtonSize.sm,
              ),
              const SizedBox(width: 6),
              SrButton(
                label: 'Continue from best',
                icon: Icons.play_arrow,
                onPressed: onContinueFromBest,
                size: SrButtonSize.sm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PsnrStrip extends StatelessWidget {
  const _PsnrStrip({
    required this.checkpoints,
    required this.psnrDelta,
  });

  final List<CheckpointSummary> checkpoints;
  final double psnrDelta;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final psnrValues = checkpoints
        .map((c) => c.metrics['val_psnr'] ?? 0.0)
        .where((v) => v > 0)
        .toList()
        .reversed
        .toList();
    
    if (psnrValues.isEmpty) return const SizedBox.shrink();
    
    final min = psnrValues.reduce((a, b) => a < b ? a : b);
    final max = psnrValues.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PSNR across saved checkpoints',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.muted,
                ),
              ),
              Tooltip(
                message: 'Improvement in validation PSNR from the first saved checkpoint to the current best (dB).',
                child: Text(
                  '${min.toStringAsFixed(2)} → ${max.toStringAsFixed(2)} dB · Δ PSNR +${psnrDelta.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'IBM Plex Mono',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SrSparkChart(
            points: psnrValues,
            height: 60,
            color: tokens.accent,
          ),
        ],
      ),
    );
  }
}

class _EmptyCheckpoints extends StatelessWidget {
  const _EmptyCheckpoints({this.onNavigateToTab});

  final void Function(int)? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.panelAlt,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border),
              ),
              child: Icon(
                Icons.save_alt,
                size: 24,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No checkpoints yet',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Checkpoints are model snapshots saved during training. The best ones become your model.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SrButton(
                  label: 'Start training →',
                  icon: Icons.play_arrow,
                  onPressed: () => onNavigateToTab?.call(3),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Coming soon — import will be available in a future update.',
                  child: SrButton(
                    label: 'Import .pt file',
                    icon: Icons.download,
                    style: SrButtonStyle.ghost,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointTable extends StatelessWidget {
  const _CheckpointTable({
    required this.checkpoints,
    required this.bestCheckpoint,
    required this.selected,
    required this.selectedForComparison,
    required this.onSelected,
    required this.onToggleComparison,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? bestCheckpoint;
  final CheckpointSummary? selected;
  final Set<String> selectedForComparison;
  final ValueChanged<CheckpointSummary> onSelected;
  final Function(String checkpointId, bool isMultiSelect) onToggleComparison;
  final Function(CheckpointSummary) onInference;
  final Function(CheckpointSummary) onFineTune;
  final Function(CheckpointSummary) onDelete;
  final Function(CheckpointSummary) onExportPth;
  final Function(CheckpointSummary) onExportOnnx;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 24), // Star column
                _colHeader('NAME', flex: 3),
                _colHeader('EPOCH', flex: 1),
                _colHeader('PSNR', flex: 1),
                _colHeader('SSIM', flex: 1),
                _colHeader('LPIPS', flex: 1),
                _colHeader('TAGS', flex: 2),
                _colHeader('SAVED', flex: 1),
                _colHeader('SIZE', flex: 1),
                const SizedBox(width: 80), // Actions column
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: checkpoints.length,
              itemBuilder: (context, index) {
                final checkpoint = checkpoints[index];
                final isBest = checkpoint.id == bestCheckpoint?.id;
                final isSelected = checkpoint.id == selected?.id;
                final isComparisonSelected = selectedForComparison.contains(checkpoint.id);
                
                return _CheckpointRow(
                  checkpoint: checkpoint,
                  isBest: isBest,
                  isSelected: isSelected,
                  isComparisonSelected: isComparisonSelected,
                  onTap: () => onSelected(checkpoint),
                  onComparisonToggle: (isMultiSelect) => onToggleComparison(checkpoint.id, isMultiSelect),
                  onInference: () => onInference(checkpoint),
                  onFineTune: () => onFineTune(checkpoint),
                  onDelete: () => onDelete(checkpoint),
                  onExportPth: () => onExportPth(checkpoint),
                  onExportOnnx: () => onExportOnnx(checkpoint),
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  const _CheckpointRow({
    required this.checkpoint,
    required this.isBest,
    required this.isSelected,
    required this.isComparisonSelected,
    required this.onTap,
    required this.onComparisonToggle,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final CheckpointSummary checkpoint;
  final bool isBest;
  final bool isSelected;
  final bool isComparisonSelected;
  final VoidCallback onTap;
  final Function(bool isMultiSelect) onComparisonToggle;
  final VoidCallback onInference;
  final VoidCallback onFineTune;
  final VoidCallback onDelete;
  final VoidCallback onExportPth;
  final VoidCallback onExportOnnx;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final isStarred = checkpoint.tags.contains('manual');
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isBest ? tokens.accent.withValues(alpha: 0.1) : 
                 isSelected ? tokens.border.withValues(alpha: 0.3) : 
                 Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: tokens.border.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            // Star/Manual indicator
            SizedBox(
              width: 24,
              child: isStarred 
                ? Icon(Icons.star, size: 16, color: tokens.warning)
                : const SizedBox(width: 16),
            ),
            
            // Name
            Expanded(
              flex: 3,
              child: Text(
                checkpoint.path.split('/').last,
                style: TextStyle(
                  fontWeight: isBest ? FontWeight.w600 : FontWeight.normal,
                  color: isBest ? tokens.accent : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Epoch
            Expanded(flex: 1, child: Text(checkpoint.epoch.toString())),
            
            // PSNR (bold if best)
            Expanded(
              flex: 1,
              child: Text(
                _fmtMetric(checkpoint.metrics['val_psnr'], 'dB'),
                style: TextStyle(
                  fontWeight: isBest ? FontWeight.w600 : FontWeight.normal,
                  color: isBest ? tokens.accent : null,
                ),
              ),
            ),
            
            // SSIM
            Expanded(flex: 1, child: Text(_fmtMetric(checkpoint.metrics['val_ssim'], null))),
            
            // LPIPS
            Expanded(flex: 1, child: Text(_fmtMetric(checkpoint.metrics['val_lpips'], null))),
            
            // Tags
            Expanded(
              flex: 2,
              child: Wrap(
                spacing: 4,
                children: checkpoint.tags.map((tag) => _TagChip(tag: tag)).toList(),
              ),
            ),
            
            // Saved time
            Expanded(
              flex: 1,
              child: Text(
                _fmtTime(checkpoint.savedAt),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            
            // Size
            Expanded(
              flex: 1,
              child: Text(
                _fmtSize(checkpoint.sizeBytes),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            
            // Actions
            SizedBox(
              width: 80,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onComparisonToggle(false),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(color: tokens.border),
                        borderRadius: BorderRadius.circular(2),
                        color: isComparisonSelected ? tokens.accent : Colors.transparent,
                      ),
                      child: isComparisonSelected 
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, size: 16),
                    onSelected: (action) {
                      switch (action) {
                        case 'inference':
                          onInference();
                          break;
                        case 'fine_tune':
                          onFineTune();
                          break;
                        case 'export_pth':
                          onExportPth();
                          break;
                        case 'export_onnx':
                          onExportOnnx();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'inference',
                        child: Row(
                          children: [
                            Icon(Icons.compare, size: 16),
                            SizedBox(width: 8),
                            Text('Run inference'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'fine_tune',
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 16),
                            SizedBox(width: 8),
                            Text('Fine-tune from here'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_pth',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 16),
                            SizedBox(width: 8),
                            Text('Export .pth'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_onnx',
                        child: Row(
                          children: [
                            Icon(Icons.transform, size: 16),
                            SizedBox(width: 8),
                            Text('Export ONNX'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    SrChipKind kind;
    switch (tag) {
      case 'best_psnr':
        kind = SrChipKind.ok;
        break;
      case 'best_loss':
        kind = SrChipKind.warn;
        break;
      case 'manual':
        kind = SrChipKind.accent;
        break;
      default:
        kind = SrChipKind.default_;
    }
    
    return SrChip(
      label: tag.replaceAll('_', ' '),
      kind: kind,
      size: SrChipSize.sm,
    );
  }
}

class _ComparisonFooter extends StatelessWidget {
  const _ComparisonFooter({
    required this.selectedCount,
    required this.canPrune,
    required this.canCompare,
    required this.onPrune,
    required this.onCompare,
    this.onDeleteSelected,
  });

  final int selectedCount;
  final bool canPrune;
  final bool canCompare;
  final VoidCallback? onPrune;
  final VoidCallback? onCompare;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Select 2 checkpoints to compare side‑by‑side ·  ⌘click',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.muted,
            ),
          ),
          Row(
            children: [
              if (onDeleteSelected != null) ...[
                TextButton.icon(
                  onPressed: onDeleteSelected,
                  icon: Icon(Icons.delete_outline, size: 16, color: tokens.danger),
                  label: Text(
                    'Delete selected ($selectedCount)',
                    style: TextStyle(color: tokens.danger, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              SrButton(
                label: 'Prune older',
                icon: Icons.delete_outline,
                onPressed: canPrune ? onPrune : null,
                style: SrButtonStyle.ghost,
                size: SrButtonSize.sm,
              ),
              const SizedBox(width: 6),
              SrButton(
                label: 'Compare side‑by‑side',
                icon: Icons.compare,
                onPressed: canCompare ? onCompare : null,
                size: SrButtonSize.sm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _LegacyCheckpointList extends StatelessWidget {
  const _LegacyCheckpointList({
    required this.checkpoints,
    required this.bestCheckpoint,
    required this.selected,
    required this.selectedForComparison,
    required this.onSelected,
    required this.onToggleComparison,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? bestCheckpoint;
  final CheckpointSummary? selected;
  final Set<String> selectedForComparison;
  final ValueChanged<CheckpointSummary> onSelected;
  final Function(String checkpointId, bool isMultiSelect) onToggleComparison;
  final Function(CheckpointSummary) onInference;
  final Function(CheckpointSummary) onFineTune;
  final Function(CheckpointSummary) onDelete;
  final Function(CheckpointSummary) onExportPth;
  final Function(CheckpointSummary) onExportOnnx;

  @override
  Widget build(BuildContext context) {
    return _CheckpointTable(
      checkpoints: checkpoints,
      bestCheckpoint: bestCheckpoint,
      selected: selected,
      selectedForComparison: selectedForComparison,
      onSelected: onSelected,
      onToggleComparison: onToggleComparison,
      onInference: onInference,
      onFineTune: onFineTune,
      onDelete: onDelete,
      onExportPth: onExportPth,
      onExportOnnx: onExportOnnx,
    );
  }
}

class _ModelSessionGroup extends StatelessWidget {
  const _ModelSessionGroup({
    required this.model,
    required this.checkpoints,
    required this.bestCheckpoint,
    required this.selected,
    required this.selectedForComparison,
    required this.onSelected,
    required this.onToggleComparison,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final ModelSummary model;
  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? bestCheckpoint;
  final CheckpointSummary? selected;
  final Set<String> selectedForComparison;
  final ValueChanged<CheckpointSummary> onSelected;
  final Function(String checkpointId, bool isMultiSelect) onToggleComparison;
  final Function(CheckpointSummary) onInference;
  final Function(CheckpointSummary) onFineTune;
  final Function(CheckpointSummary) onDelete;
  final Function(CheckpointSummary) onExportPth;
  final Function(CheckpointSummary) onExportOnnx;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.memory, size: 16, color: tokens.accent),
                  const SizedBox(width: 8),
                  Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  SrChip(
                    label: model.status,
                    kind: model.status == 'trained' ? SrChipKind.ok : SrChipKind.default_,
                    size: SrChipSize.sm,
                  ),
                  const Spacer(),
                  Text(
                    '${model.numFeatures} features · ${model.numBlocks} blocks',
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            for (final session in (model.trainHistory ?? []))
              _TrainingSessionCard(
                session: session,
                modelId: model.id,
                trainedCoreWeightsPath: model.trainedCoreWeightsPath,
                checkpoints: checkpoints,
                bestCheckpoint: bestCheckpoint,
                selected: selected,
                selectedForComparison: selectedForComparison,
                onSelected: onSelected,
                onToggleComparison: onToggleComparison,
                onInference: onInference,
                onFineTune: onFineTune,
                onDelete: onDelete,
                onExportPth: onExportPth,
                onExportOnnx: onExportOnnx,
              ),
          ],
        ),
      ),
    );
  }
}

class _TrainingSessionCard extends StatelessWidget {
  const _TrainingSessionCard({
    required this.session,
    required this.modelId,
    required this.trainedCoreWeightsPath,
    required this.checkpoints,
    required this.bestCheckpoint,
    required this.selected,
    required this.selectedForComparison,
    required this.onSelected,
    required this.onToggleComparison,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final TrainHistoryEntry session;
  final String modelId;
  final String? trainedCoreWeightsPath;
  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? bestCheckpoint;
  final CheckpointSummary? selected;
  final Set<String> selectedForComparison;
  final ValueChanged<CheckpointSummary> onSelected;
  final Function(String checkpointId, bool isMultiSelect) onToggleComparison;
  final Function(CheckpointSummary) onInference;
  final Function(CheckpointSummary) onFineTune;
  final Function(CheckpointSummary) onDelete;
  final Function(CheckpointSummary) onExportPth;
  final Function(CheckpointSummary) onExportOnnx;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final sessionCheckpoints = checkpoints
        .where((c) => c.runId == session.sessionId)
        .toList();

    final bestPsnr = session.bestMetrics['val_psnr'];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: tokens.muted),
              const SizedBox(width: 6),
              Text(
                session.datasetName,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Text('x${session.scale}', style: TextStyle(color: tokens.muted, fontSize: 12)),
              const SizedBox(width: 8),
              if (bestPsnr != null)
                Text(
                  'PSNR: ${bestPsnr.toStringAsFixed(2)} dB',
                  style: TextStyle(color: tokens.accent, fontSize: 12),
                ),
              const Spacer(),
              Text(
                '${session.checkpoints.length} checkpoints · ${session.epochs} epochs',
                style: TextStyle(color: tokens.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatSessionDate(session.completedAt),
                style: TextStyle(color: tokens.muted, fontSize: 11),
              ),
              const Spacer(),
              if (session.bestCheckpointId.isNotEmpty)
                SrChip(
                  label: '★ Best (auto-extracted)',
                  kind: SrChipKind.ok,
                  size: SrChipSize.sm,
                ),
            ],
          ),
          if (sessionCheckpoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...sessionCheckpoints.map((ckpt) => _SessionCheckpointRow(
              checkpoint: ckpt,
              isBest: ckpt.id == session.bestCheckpointId,
              modelId: modelId,
              trainedCoreWeightsPath: trainedCoreWeightsPath,
              selected: selected,
              selectedForComparison: selectedForComparison,
              onTap: () => onSelected(ckpt),
              onComparisonToggle: (isMultiSelect) => onToggleComparison(ckpt.id, isMultiSelect),
              onInference: () => onInference(ckpt),
              onFineTune: () => onFineTune(ckpt),
              onDelete: () => onDelete(ckpt),
              onExportPth: () => onExportPth(ckpt),
              onExportOnnx: () => onExportOnnx(ckpt),
            )),
          ],
        ],
      ),
    );
  }
}

class _SessionCheckpointRow extends StatelessWidget {
  const _SessionCheckpointRow({
    required this.checkpoint,
    required this.isBest,
    required this.modelId,
    required this.trainedCoreWeightsPath,
    required this.selected,
    required this.selectedForComparison,
    required this.onTap,
    required this.onComparisonToggle,
    required this.onInference,
    required this.onFineTune,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportOnnx,
  });

  final CheckpointSummary checkpoint;
  final bool isBest;
  final String modelId;
  final String? trainedCoreWeightsPath;
  final CheckpointSummary? selected;
  final Set<String> selectedForComparison;
  final VoidCallback onTap;
  final Function(bool isMultiSelect) onComparisonToggle;
  final VoidCallback onInference;
  final VoidCallback onFineTune;
  final VoidCallback onDelete;
  final VoidCallback onExportPth;
  final VoidCallback onExportOnnx;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final isSelected = checkpoint.id == selected?.id;
    final isComparisonSelected = selectedForComparison.contains(checkpoint.id);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isBest ? tokens.accent.withValues(alpha: 0.08) : 
                 isSelected ? tokens.border.withValues(alpha: 0.2) : null,
          border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: isBest
                  ? Icon(Icons.auto_awesome, size: 14, color: tokens.warning)
                  : null,
            ),
            SizedBox(
              width: 16,
              child: GestureDetector(
                onTap: () => onComparisonToggle(false),
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.border),
                    borderRadius: BorderRadius.circular(2),
                    color: isComparisonSelected ? tokens.accent : null,
                  ),
                  child: isComparisonSelected
                      ? Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('epoch_${checkpoint.epoch.toString().padLeft(4, '0')}_iter_${checkpoint.iteration.toString().padLeft(6, '0')}',
              style: TextStyle(fontSize: 12, fontWeight: isBest ? FontWeight.w600 : null, color: isBest ? tokens.accent : null),
            ),
            const SizedBox(width: 12),
            Text('PSNR: ${_fmtMetric(checkpoint.metrics['val_psnr'], "dB")}', style: TextStyle(fontSize: 11, color: tokens.muted)),
            const Spacer(),
            SrButton(
              label: 'Infer',
              icon: Icons.play_arrow,
              onPressed: onInference,
              size: SrButtonSize.sm,
            ),
            const SizedBox(width: 4),
            SrButton(
              label: 'Tune',
              icon: Icons.tune,
              onPressed: onFineTune,
              size: SrButtonSize.sm,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSessionDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
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

String _fmtTime(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now().toLocal();
    final diff = now.difference(dt);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'just now';
    }
  } catch (_) {
    return iso;
  }
}

