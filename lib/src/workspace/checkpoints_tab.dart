import 'dart:io';

import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_theme.dart';
import '../design_system/sr_button.dart';
import '../design_system/sr_chip.dart';
import '../path_picker.dart' show PathPicker;
import '../project_models.dart';
import '../shared_widgets.dart';

class CheckpointsTab extends StatefulWidget {
  const CheckpointsTab({
    required this.client,
    required this.project,
    required this.onInferenceHandoff,
    required this.onProjectChanged,
    this.onFineTuneHandoff,
    this.onNavigateToTab,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<String> onInferenceHandoff;
  final ValueChanged<ProjectState> onProjectChanged;
  final void Function(String checkpointId, String? coreWeightsPath)? onFineTuneHandoff;
  final void Function(int)? onNavigateToTab;

  @override
  State<CheckpointsTab> createState() => _CheckpointsTabState();
}

class _CheckpointsTabState extends State<CheckpointsTab> {
  ModelSummary? _selectedModel;
  double _sidebarWidth = 220;
  String? _error;
  final bool _loading = false;

  @override
  void initState() {
    super.initState();
    _autoSelectModel();
  }

  @override
  void didUpdateWidget(CheckpointsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _autoSelectModel();
    }
  }

  void _autoSelectModel() {
    final models = widget.project.models;
    if (models.isEmpty) {
      setState(() => _selectedModel = null);
      return;
    }
    final current = _selectedModel;
    if (current != null && models.any((m) => m.id == current.id)) return;
    final firstWithHistory = models.cast<ModelSummary?>().firstWhere(
      (m) => m!.trainHistory != null && m.trainHistory!.isNotEmpty,
      orElse: () => models.first,
    );
    setState(() => _selectedModel = firstWithHistory);
  }

  Future<void> _setAsCore(ModelSummary model, CheckpointSummary checkpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set as Core?'),
        content: Text('Promote epoch ${checkpoint.epoch} as the active core weights for "${model.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set as Core')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await widget.client.setCheckpointAsCore(
        projectId: widget.project.id,
        modelId: model.id,
        runId: checkpoint.runId,
        checkpointId: checkpoint.id,
      );
      if (mounted) widget.onProjectChanged(result.project);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteArchivedCheckpoint(ModelSummary model, CheckpointSummary checkpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove checkpoint?'),
        content: Text('Epoch ${checkpoint.epoch} will be removed from history. The file will be deleted from the model directory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).extension<SrTokens>()!.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await widget.client.deleteArchivedCheckpoint(
        projectId: widget.project.id,
        modelId: model.id,
        checkpointId: checkpoint.id,
      );
      if (mounted) widget.onProjectChanged(result.project);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteArchivedSession(ModelSummary model, TrainHistoryEntry session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('All checkpoints for session "${session.datasetName}" will be removed.'),
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
      final result = await widget.client.deleteArchivedSession(
        projectId: widget.project.id,
        modelId: model.id,
        sessionId: session.sessionId,
      );
      if (mounted) widget.onProjectChanged(result.project);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPth(CheckpointSummary checkpoint) async {
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      final srcFile = File(checkpoint.path);
      final destPath = '$dest/${checkpoint.path.split('/').last}';
      await srcFile.copy(destPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to $destPath')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _exportPackage(ModelSummary model, CheckpointSummary checkpoint) async {
    final dest = await const PathPicker().pickFolder(confirmButtonText: 'Export here');
    if (dest == null || !mounted) return;
    try {
      await widget.client.exportModelPackage(
        projectId: widget.project.id,
        modelId: model.id,
        runId: checkpoint.runId,
        checkpointId: checkpoint.id,
        destination: dest,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package export started.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _importPackage() async {
    final src = await const PathPicker().pickFile(
      confirmButtonText: 'Import',
    );
    if (src == null || !mounted) return;
    try {
      final result = await widget.client.importModelPackage(
        projectId: widget.project.id,
        filePath: src,
      );
      if (mounted) widget.onProjectChanged(result.project);
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
            TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
          ],
        ),
      );
    }

    final models = widget.project.models;
    final sessions = _selectedModel?.trainHistory ?? [];

    if (models.isEmpty) {
      return const BlockedState(
        title: 'Checkpoints',
        message: 'No models yet. Create a model to start training.',
        icon: Icons.save_alt,
      );
    }

    return Row(
      children: [
        _ModelSidebar(
          models: models,
          selectedModel: _selectedModel,
          width: _sidebarWidth,
          onSelect: (model) => setState(() => _selectedModel = model),
          onResize: (w) => setState(() => _sidebarWidth = w.clamp(160.0, 320.0)),
          onImport: _importPackage,
        ),
        VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _selectedModel == null
              ? _EmptyCheckpoints(onNavigateToTab: widget.onNavigateToTab)
              : Column(
                  children: [
                    _ModelDetailHeader(
                      model: _selectedModel!,
                      onInferFromCore: () {
                        if (_selectedModel!.coreCheckpointId != null) {
                          widget.onInferenceHandoff(_selectedModel!.coreCheckpointId!);
                        }
                      },
                      onFineTuneFromCore: () {
                        final model = _selectedModel!;
                        if (model.coreCheckpointId != null) {
                          widget.onFineTuneHandoff?.call(
                            model.coreCheckpointId!,
                            model.trainedCoreWeightsPath,
                          );
                        }
                      },
                      onExportPackage: sessions.isNotEmpty
                          ? () {
                              final first = sessions.first.checkpoints.firstOrNull;
                              if (first != null) _exportPackage(_selectedModel!, first);
                            }
                          : null,
                    ),
                    Expanded(
                      child: sessions.isEmpty
                          ? _EmptyCheckpoints(onNavigateToTab: widget.onNavigateToTab)
                          : ListView(
                              children: [
                                for (final session in sessions)
                                  _RunCard(
                                    session: session,
                                    model: _selectedModel!,
                                    onSetAsCore: (ckpt) => _setAsCore(_selectedModel!, ckpt),
                                    onDeleteSession: () => _deleteArchivedSession(_selectedModel!, session),
                                    onDeleteCheckpoint: (ckpt) => _deleteArchivedCheckpoint(_selectedModel!, ckpt),
                                    onExportPth: _exportPth,
                                    onExportPackage: (ckpt) => _exportPackage(_selectedModel!, ckpt),
                                    onInference: (ckpt) => widget.onInferenceHandoff(ckpt.id),
                                    onFineTune: (ckpt) => widget.onFineTuneHandoff?.call(
                                      ckpt.id,
                                      _selectedModel!.trainedCoreWeightsPath,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ModelSidebar extends StatefulWidget {
  const _ModelSidebar({
    required this.models,
    required this.selectedModel,
    required this.width,
    required this.onSelect,
    required this.onResize,
    required this.onImport,
  });

  final List<ModelSummary> models;
  final ModelSummary? selectedModel;
  final double width;
  final ValueChanged<ModelSummary> onSelect;
  final ValueChanged<double> onResize;
  final VoidCallback onImport;

  @override
  State<_ModelSidebar> createState() => _ModelSidebarState();
}

class _ModelSidebarState extends State<_ModelSidebar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final model in widget.models)
                      _buildModelCard(model),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SrButton(
                  label: 'Import Model Package',
                  icon: Icons.download,
                  onPressed: widget.onImport,
                  size: SrButtonSize.sm,
                  style: SrButtonStyle.ghost,
                ),
              ),
            ],
          ),
          // Resize handle
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                widget.onResize(widget.width + details.delta.dx);
              },
              child: Container(
                width: 4,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(ModelSummary model) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final isSelected = model.id == widget.selectedModel?.id;
    final runCount = model.trainHistory?.length ?? 0;
    final ckptCount = model.trainHistory?.fold(0, (sum, s) => sum + s.checkpoints.length) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? tokens.accent.withValues(alpha: 0.1) : null,
        border: Border(
          left: BorderSide(
            color: isSelected ? tokens.accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => widget.onSelect(model),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SrChip(
                    label: model.status,
                    kind: model.status == 'trained' ? SrChipKind.ok : SrChipKind.default_,
                    size: SrChipSize.sm,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$runCount runs · $ckptCount checkpoints',
                    style: TextStyle(fontSize: 11, color: tokens.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelDetailHeader extends StatelessWidget {
  const _ModelDetailHeader({
    required this.model,
    this.onInferFromCore,
    this.onFineTuneFromCore,
    this.onExportPackage,
  });

  final ModelSummary model;
  final VoidCallback? onInferFromCore;
  final VoidCallback? onFineTuneFromCore;
  final VoidCallback? onExportPackage;

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
                      model.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    SrChip(
                      label: model.status,
                      kind: model.status == 'trained' ? SrChipKind.ok : SrChipKind.default_,
                      size: SrChipSize.sm,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${model.numFeatures} features · ${model.numBlocks} blocks',
                  style: TextStyle(fontSize: 12, color: tokens.muted),
                ),
                if (model.coreCheckpointId != null)
                  Text(
                    'Core: ${model.coreCheckpointId}',
                    style: TextStyle(fontSize: 11, color: tokens.accent),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              SrButton(
                label: 'Infer from Core',
                icon: Icons.play_arrow,
                onPressed: model.coreCheckpointId != null ? onInferFromCore : null,
                size: SrButtonSize.sm,
              ),
              const SizedBox(width: 6),
              SrButton(
                label: 'Fine-tune',
                icon: Icons.tune,
                onPressed: model.coreCheckpointId != null ? onFineTuneFromCore : null,
                size: SrButtonSize.sm,
              ),
              const SizedBox(width: 6),
              SrButton(
                label: 'Export Package',
                icon: Icons.download,
                onPressed: onExportPackage,
                size: SrButtonSize.sm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunCard extends StatefulWidget {
  const _RunCard({
    required this.session,
    required this.model,
    required this.onSetAsCore,
    required this.onDeleteSession,
    required this.onDeleteCheckpoint,
    required this.onExportPth,
    required this.onExportPackage,
    required this.onInference,
    required this.onFineTune,
  });

  final TrainHistoryEntry session;
  final ModelSummary model;
  final void Function(CheckpointSummary checkpoint) onSetAsCore;
  final VoidCallback onDeleteSession;
  final void Function(CheckpointSummary checkpoint) onDeleteCheckpoint;
  final void Function(CheckpointSummary checkpoint) onExportPth;
  final void Function(CheckpointSummary checkpoint) onExportPackage;
  final void Function(CheckpointSummary checkpoint) onInference;
  final void Function(CheckpointSummary checkpoint) onFineTune;

  @override
  State<_RunCard> createState() => _RunCardState();
}

class _RunCardState extends State<_RunCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final session = widget.session;
    final bestPsnr = session.bestMetrics['val_psnr'];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: tokens.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                session.datasetName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Text('x${session.scale}', style: TextStyle(color: tokens.muted, fontSize: 12)),
                              if (bestPsnr != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'PSNR: ${bestPsnr.toStringAsFixed(2)} dB',
                                  style: TextStyle(color: tokens.accent, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${session.epochs} epochs · ${session.checkpoints.length} checkpoints',
                            style: TextStyle(fontSize: 11, color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onDeleteSession,
                      icon: Icon(Icons.delete_outline, size: 16, color: tokens.danger),
                      label: Text('Delete', style: TextStyle(color: tokens.danger, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              ...session.checkpoints.map((ckpt) => _CheckpointRow(
                checkpoint: ckpt,
                isCore: ckpt.id == widget.model.coreCheckpointId,
                onSetAsCore: () => widget.onSetAsCore(ckpt),
                onDelete: () => widget.onDeleteCheckpoint(ckpt),
                onExportPth: () => widget.onExportPth(ckpt),
                onExportPackage: () => widget.onExportPackage(ckpt),
                onInference: () => widget.onInference(ckpt),
                onFineTune: () => widget.onFineTune(ckpt),
              )),
          ],
        ),
      ),
    );
  }
}

class _CheckpointRow extends StatelessWidget {
  const _CheckpointRow({
    required this.checkpoint,
    required this.isCore,
    required this.onSetAsCore,
    required this.onDelete,
    required this.onExportPth,
    required this.onExportPackage,
    required this.onInference,
    required this.onFineTune,
  });

  final CheckpointSummary checkpoint;
  final bool isCore;
  final VoidCallback onSetAsCore;
  final VoidCallback onDelete;
  final VoidCallback onExportPth;
  final VoidCallback onExportPackage;
  final VoidCallback onInference;
  final VoidCallback onFineTune;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCore ? tokens.accent.withValues(alpha: 0.08) : null,
        border: Border(
          bottom: BorderSide(color: tokens.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (isCore)
            SrChip(
              label: '★ CORE',
              kind: SrChipKind.ok,
              size: SrChipSize.sm,
            )
          else
            const SizedBox(width: 60),
          const SizedBox(width: 8),
          Text(
            'epoch_${checkpoint.epoch.toString().padLeft(4, '0')}',
            style: TextStyle(fontSize: 12, fontWeight: isCore ? FontWeight.w600 : null),
          ),
          const SizedBox(width: 12),
          Text('PSNR: ${_fmtMetric(checkpoint.metrics['val_psnr'], "dB")}', style: TextStyle(fontSize: 11, color: tokens.muted)),
          const SizedBox(width: 12),
          Text('SSIM: ${_fmtMetric(checkpoint.metrics['val_ssim'], null)}', style: TextStyle(fontSize: 11, color: tokens.muted)),
          if (checkpoint.tags.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...checkpoint.tags.map((tag) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _TagChip(tag: tag),
            )),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, size: 16),
            onSelected: (action) {
              switch (action) {
                case 'set_core':
                  onSetAsCore();
                  break;
                case 'inference':
                  onInference();
                  break;
                case 'fine_tune':
                  onFineTune();
                  break;
                case 'export_pth':
                  onExportPth();
                  break;
                case 'export_package':
                  onExportPackage();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'set_core',
                child: Row(children: [Icon(Icons.star, size: 16), SizedBox(width: 8), Text('Set as Core')]),
              ),
              const PopupMenuItem(
                value: 'inference',
                child: Row(children: [Icon(Icons.compare, size: 16), SizedBox(width: 8), Text('Run inference')]),
              ),
              const PopupMenuItem(
                value: 'fine_tune',
                child: Row(children: [Icon(Icons.tune, size: 16), SizedBox(width: 8), Text('Fine-tune from here')]),
              ),
              const PopupMenuItem(
                value: 'export_pth',
                child: Row(children: [Icon(Icons.download, size: 16), SizedBox(width: 8), Text('Export .pth')]),
              ),
              const PopupMenuItem(
                value: 'export_package',
                child: Row(children: [Icon(Icons.archive, size: 16), SizedBox(width: 8), Text('Export Package')]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Icons.delete_outline, size: 16), SizedBox(width: 8), Text('Remove from history')]),
              ),
            ],
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
              child: Icon(Icons.save_alt, size: 24, color: tokens.muted),
            ),
            const SizedBox(height: 16),
            const Text(
              'No checkpoints yet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Checkpoints are model snapshots saved during training. The best ones become your model.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SrButton(
              label: 'Start training →',
              icon: Icons.play_arrow,
              onPressed: () => onNavigateToTab?.call(3),
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

String _fmtMetric(double? value, String? unit) {
  if (value == null || value == 0) return '—';
  final s = value.abs() >= 100 ? value.toStringAsFixed(1) : value.toStringAsPrecision(3);
  return unit == null ? s : '$s $unit';
}
