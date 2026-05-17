import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart' hide SrChip;
import '../classic_theme.dart';
import '../design_system/sr_chip.dart';
import '../project_models.dart';

class ModelTab extends StatefulWidget {
  const ModelTab({
    required this.client,
    required this.project,
    required this.onProjectChanged,
    this.onNavigateToTab,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<ProjectState> onProjectChanged;
  final void Function(int)? onNavigateToTab;

  @override
  State<ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends State<ModelTab> {
  final _nameCtrl = TextEditingController(text: 'internal');
  final _featuresCtrl = TextEditingController(text: '32');
  final _blocksCtrl = TextEditingController(text: '4');
  ModelTemplateCatalog? _catalog;
  ModelTemplate? _selected;
  bool _busy = false;
  String? _error;
  bool _createMode = false;

  int _features = 32;
  int _blocks = 4;

  String? _editingModelId;
  final _editNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _featuresCtrl.dispose();
    _blocksCtrl.dispose();
    _editNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await widget.client.modelTemplates(widget.project.id);
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _selected = catalog.templates.isEmpty ? null : catalog.templates.first;
          final template = _selected;
          if (template != null) _nameCtrl.text = template.id;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _switchToCreate() {
    setState(() {
      _createMode = true;
      _editingModelId = null;
    });
  }

  void _switchToManage() {
    setState(() {
      _createMode = false;
      _editingModelId = null;
    });
  }

  void _selectTemplate(ModelTemplate template) {
    setState(() {
      _selected = template;
      _nameCtrl.text = template.id;
      _createMode = true;
      _editingModelId = null;
    });
  }

  Future<void> _saveAsModel() async {
    final template = _selected;
    if (template == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final envelope = await widget.client.saveTemplateAsModel(
        projectId: widget.project.id,
        templateId: template.id,
        name: _nameCtrl.text.trim(),
        numFeatures: _features,
        numBlocks: _blocks,
      );
      widget.onProjectChanged(envelope.project);
      setState(() => _createMode = false);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteModel(ModelSummary model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: const Text('This removes the model configuration. Existing run artifacts and checkpoints remain intact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete model')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      final envelope = await widget.client.deleteModel(
        projectId: widget.project.id, modelId: model.id,
      );
      widget.onProjectChanged(envelope.project);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicateModel(ModelSummary model) async {
    final name = '${model.name} (copy)';
    setState(() { _busy = true; _error = null; });
    try {
      final envelope = await widget.client.duplicateModel(
        projectId: widget.project.id, modelId: model.id, name: name,
      );
      widget.onProjectChanged(envelope.project);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _renameModel(ModelSummary model, String newName) async {
    setState(() { _busy = true; _error = null; });
    try {
      final envelope = await widget.client.updateModel(
        projectId: widget.project.id, modelId: model.id, name: newName.trim(),
      );
      widget.onProjectChanged(envelope.project);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() { _busy = false; _editingModelId = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final catalog = _catalog;
    return Padding(
      padding: EdgeInsets.all(tokens.gap),
      child: catalog == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : SrBanner(message: _error!, severity: 'error'),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: _ArchitectureSidebar(
                  catalog: catalog,
                  selected: _selected,
                  onSelect: _selectTemplate,
                )),
                SizedBox(width: tokens.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('Manage')),
                              ButtonSegment(value: true, label: Text('Create')),
                            ],
                            selected: {_createMode},
                            onSelectionChanged: (v) {
                              if (v.first) { _switchToCreate(); }
                              else { _switchToManage(); }
                            },
                          ),
                          const Spacer(),
                          if (_error != null)
                            Flexible(child: SrBanner(message: _error!, severity: 'error')),
                        ],
                      ),
                      SizedBox(height: tokens.compactGap),
                      Expanded(
                        child: _createMode
                            ? _CreatePanel(
                                name: _nameCtrl,
                                featuresCtrl: _featuresCtrl,
                                blocksCtrl: _blocksCtrl,
                                features: _features,
                                blocks: _blocks,
                                busy: _busy,
                                selectedTemplate: _selected,
                                onFeaturesChanged: (v) => setState(() { _features = v; _featuresCtrl.text = v.toString(); }),
                                onFeaturesTextChanged: (t) {
                                  final v = int.tryParse(t);
                                  if (v != null && v >= 8 && v <= 256) setState(() => _features = v);
                                },
                                onBlocksChanged: (v) => setState(() { _blocks = v; _blocksCtrl.text = v.toString(); }),
                                onBlocksTextChanged: (t) {
                                  final v = int.tryParse(t);
                                  if (v != null && v >= 1 && v <= 64) setState(() => _blocks = v);
                                },
                                onSave: _saveAsModel,
                                onReset: () => setState(() {
                                  _features = 32;
                                  _blocks = 4;
                                  _featuresCtrl.text = '32';
                                  _blocksCtrl.text = '4';
                                  final t = _selected;
                                  if (t != null) _nameCtrl.text = t.id;
                                }),
                              )
                            : _ManagePanel(
                                models: widget.project.models,
                                busy: _busy,
                                editingModelId: _editingModelId,
                                editNameCtrl: _editNameCtrl,
                                onStartRename: (model) {
                                  _editNameCtrl.text = model.name;
                                  setState(() => _editingModelId = model.id);
                                },
                                onCancelRename: () => setState(() => _editingModelId = null),
                                onConfirmRename: (model) => _renameModel(model, _editNameCtrl.text),
                                onDelete: _deleteModel,
                                onDuplicate: _duplicateModel,
                                runs: widget.project.runs,
                                onTrain: (model) => widget.onNavigateToTab?.call(3),
                                onNavigateToTab: widget.onNavigateToTab,
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

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _ArchitectureSidebar extends StatelessWidget {
  const _ArchitectureSidebar({
    required this.catalog,
    required this.selected,
    required this.onSelect,
  });

  final ModelTemplateCatalog catalog;
  final ModelTemplate? selected;
  final ValueChanged<ModelTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrSection(
          title: 'Architectures',
          subtitle: 'Supported model architectures',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final template in catalog.templates)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onSelect(template),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: selected?.id == template.id
                          ? BoxDecoration(border: Border.all(color: tokens.accent, width: 2), borderRadius: BorderRadius.circular(tokens.radius))
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(template.supportState == 'supported' ? Icons.memory : Icons.lock_outline, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(template.displayName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              SrChip(
                                label: template.supportState,
                                kind: template.supportState == 'supported' ? SrChipKind.ok : SrChipKind.warn,
                                size: SrChipSize.sm,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: _specChip(tokens, 'Params', template.parameterCount == null ? '?' : _formatCount(template.parameterCount!))),
                            const SizedBox(width: 6),
                            Expanded(child: _specChip(tokens, 'VRAM', template.vramEstimate)),
                          ]),
                          const SizedBox(height: 6),
                          if (template.bestFor.isNotEmpty)
                            Text(template.bestFor, style: TextStyle(fontSize: 11, color: tokens.muted)),
                          const SizedBox(height: 4),
                          SrChip(
                            label: 'scale-agnostic',
                            kind: SrChipKind.accent,
                            size: SrChipSize.sm,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specChip(SrTokens tokens, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 11)),
    );
  }
}

// ── Create Panel ──────────────────────────────────────────────────────────────

class _CreatePanel extends StatelessWidget {
  const _CreatePanel({
    required this.name,
    required this.featuresCtrl,
    required this.blocksCtrl,
    required this.features,
    required this.blocks,
    required this.busy,
    required this.onFeaturesChanged,
    required this.onFeaturesTextChanged,
    required this.onBlocksChanged,
    required this.onBlocksTextChanged,
    required this.onSave,
    required this.onReset,
    this.selectedTemplate,
  });

  final TextEditingController name;
  final TextEditingController featuresCtrl;
  final TextEditingController blocksCtrl;
  final int features;
  final int blocks;
  final bool busy;
  final ModelTemplate? selectedTemplate;
  final ValueChanged<int> onFeaturesChanged;
  final ValueChanged<String> onFeaturesTextChanged;
  final ValueChanged<int> onBlocksChanged;
  final ValueChanged<String> onBlocksTextChanged;
  final VoidCallback onSave;
  final VoidCallback onReset;

  bool get _isSupported => selectedTemplate?.supportState == 'supported';

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              if (!_isSupported && selectedTemplate != null)
                SrBanner(
                  message: '${selectedTemplate!.displayName} is coming soon — only Internal Residual PixelShuffle can be trained today.',
                  severity: 'info',
                )
              else
                SrBanner(
                  title: 'Scale-agnostic architecture',
                  message: 'I/O layers are auto-configured from dataset scale at training time. Output scale is configurable at inference.',
                  severity: 'info',
                ),
              SizedBox(height: tokens.gap),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Model name'),
                enabled: _isSupported,
              ),
              SizedBox(height: tokens.gap),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Features: $features', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: featuresCtrl,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          keyboardType: TextInputType.number,
                          onChanged: busy ? null : onFeaturesTextChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 8, max: 256, divisions: 248,
                          value: features.toDouble().clamp(8, 256),
                          label: features.toString(),
                          onChanged: busy ? null : (v) => onFeaturesChanged(v.round()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Blocks: $blocks', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: blocksCtrl,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          keyboardType: TextInputType.number,
                          onChanged: busy ? null : onBlocksTextChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 1, max: 64, divisions: 63,
                          value: blocks.toDouble().clamp(1, 64),
                          label: blocks.toString(),
                          onChanged: busy ? null : (v) => onBlocksChanged(v.round()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: tokens.gap),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                  FilledButton.icon(
                    onPressed: (busy || !_isSupported) ? null : onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save as model'),
                  ),
                ],
              ),
              if (busy) ...[
                SizedBox(height: tokens.compactGap),
                const SrProgressBar(kind: SrProgressKind.indeterminate),
              ],
            ],
          ),
        ),
        SizedBox(width: tokens.gap),
        SizedBox(
          width: 260,
          child: _HardwareEstimatePanel(features: features, blocks: blocks),
        ),
      ],
    );
  }
}

// ── Hardware Estimate Panel ────────────────────────────────────────────────────

class _HardwareEstimatePanel extends StatelessWidget {
  const _HardwareEstimatePanel({required this.features, required this.blocks});

  final int features;
  final int blocks;

  static int _paramCount(int f, int b) =>
      (f * f * b * 18) + (f * 3 * 18);

  static String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final params = _paramCount(features, blocks);
    final paramB = params * 4;   // float32
    final gradB  = params * 4;
    final optB   = params * 4 * 2;  // Adam: first + second moment
    final totalB = paramB + gradB + optB;

    return SrSection(
      title: 'Hardware estimate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(label: 'Parameters', value: _formatCount(params), tokens: tokens, bold: true),
          const SizedBox(height: 12),
          Text('Memory breakdown (float32)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted)),
          const SizedBox(height: 6),
          _Row(label: 'Bare model', value: _fmtBytes(paramB), tokens: tokens),
          _Row(label: '+ Gradients', value: '+${_fmtBytes(gradB)}', tokens: tokens),
          _Row(label: '+ Optimizer', value: '+${_fmtBytes(optB)}', tokens: tokens,
              note: 'Adam (2× moments)'),
          Divider(color: tokens.border, height: 16),
          _Row(label: 'Training peak', value: '~${_fmtBytes(totalB)}', tokens: tokens, bold: true),
          const SizedBox(height: 8),
          Text(
            'Excludes activations. See Training tab for full VRAM estimate with batch size and crop.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.tokens,
    this.note,
    this.bold = false,
  });

  final String label;
  final String value;
  final SrTokens tokens;
  final String? note;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (note != null)
                  Text(note!, style: TextStyle(fontSize: 10, color: tokens.muted)),
              ],
            ),
          ),
          Text(value, style: style?.copyWith(color: bold ? null : tokens.accent)),
        ],
      ),
    );
  }
}

// ── Manage Panel ──────────────────────────────────────────────────────────────

class _ManagePanel extends StatelessWidget {
  const _ManagePanel({
    required this.models,
    required this.runs,
    required this.busy,
    required this.editingModelId,
    required this.editNameCtrl,
    required this.onStartRename,
    required this.onCancelRename,
    required this.onConfirmRename,
    required this.onDelete,
    required this.onDuplicate,
    required this.onTrain,
    this.onNavigateToTab,
  });

  final List<ModelSummary> models;
  final List<RunSummary> runs;
  final bool busy;
  final String? editingModelId;
  final TextEditingController editNameCtrl;
  final ValueChanged<ModelSummary> onStartRename;
  final VoidCallback onCancelRename;
  final ValueChanged<ModelSummary> onConfirmRename;
  final ValueChanged<ModelSummary> onDelete;
  final ValueChanged<ModelSummary> onDuplicate;
  final ValueChanged<ModelSummary> onTrain;
  final void Function(int)? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    if (models.isEmpty) {
      return const Center(child: Text('No models yet. Switch to Create to build one.'));
    }
    return ListView(
      children: [
        for (final model in models) ...[
          Builder(builder: (context) {
            final activeRun = runs.where((r) => r.modelId == model.id && r.isActive).firstOrNull;
            return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: editingModelId == model.id
                            ? SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: editNameCtrl,
                                  autofocus: true,
                                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                  onSubmitted: (_) => onConfirmRename(model),
                                ),
                              )
                            : Text(model.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (activeRun != null) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 4),
                        Text('Training…', style: TextStyle(color: tokens.muted, fontSize: 12)),
                      ],
                      const SizedBox(width: 8),
                      SrChip(
                        label: model.status,
                        kind: model.status == 'trained' ? SrChipKind.ok : SrChipKind.default_,
                        size: SrChipSize.sm,
                      ),
                      if (model.trainHistory != null && model.trainHistory!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        SrChip(
                          label: '${model.trainHistory!.length} session${model.trainHistory!.length == 1 ? '' : 's'}',
                          kind: SrChipKind.accent,
                          size: SrChipSize.sm,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${model.numFeatures} features · ${model.numBlocks} blocks · scale-agnostic',
                    style: TextStyle(color: tokens.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : () => onTrain(model),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Train'),
                      ),
                      if (model.status == 'trained')
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => onDuplicate(model),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Duplicate'),
                        ),
                      if (editingModelId == model.id)
                        OutlinedButton.icon(
                          onPressed: busy ? null : onCancelRename,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Cancel'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => onStartRename(model),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Rename'),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => onDelete(model),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(foregroundColor: tokens.danger),
                      ),
                    ],
                  ),
                  if (model.trainHistory != null && model.trainHistory!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...model.trainHistory!.map((session) => _SessionTile(
                      session: session,
                      modelId: model.id,
                      trainedCoreWeightsPath: model.trainedCoreWeightsPath,
                      onNavigateToTab: onNavigateToTab,
                    )),
                  ],
                ],
              ),
            ),
          );
          }),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Session Tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.modelId,
    required this.trainedCoreWeightsPath,
    this.onNavigateToTab,
  });

  final TrainHistoryEntry session;
  final String modelId;
  final String? trainedCoreWeightsPath;
  final void Function(int)? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final bestPsnr = session.bestMetrics['val_psnr'];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: tokens.muted),
              const SizedBox(width: 6),
              Text(session.datasetName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(width: 8),
              Text('x${session.scale}', style: TextStyle(color: tokens.muted, fontSize: 12)),
              const Spacer(),
              if (bestPsnr != null)
                Text('PSNR: ${bestPsnr.toStringAsFixed(2)} dB', style: TextStyle(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${session.epochs} epochs · ${session.checkpoints.length} checkpoints', style: TextStyle(color: tokens.muted, fontSize: 11)),
          if (session.checkpoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            () {
              final best = session.checkpoints
                  .where((c) => c.id == session.bestCheckpointId)
                  .firstOrNull ?? session.checkpoints.last;
              return InkWell(
                onTap: onNavigateToTab != null ? () => onNavigateToTab!(5) : null,
                borderRadius: BorderRadius.circular(4),
                child: Tooltip(
                  message: onNavigateToTab != null ? 'View all ${session.checkpoints.length} checkpoints' : '',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: tokens.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          best.path.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.accent,
                          ),
                        ),
                      ),
                      SrChip(label: '★ Best', kind: SrChipKind.ok, size: SrChipSize.sm),
                      const SizedBox(width: 6),
                      Text(
                        '+${session.checkpoints.length - 1} more',
                        style: TextStyle(color: tokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
