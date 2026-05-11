import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
import '../project_models.dart';

class ModelTab extends StatefulWidget {
  const ModelTab({
    required this.client,
    required this.project,
    required this.onProjectChanged,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<ProjectState> onProjectChanged;

  @override
  State<ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends State<ModelTab> {
  final _name = TextEditingController(text: 'internal_x4');
  ModelTemplateCatalog? _catalog;
  ModelTemplate? _selected;
  String _filter = 'all';
  int _scale = 4;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await widget.client.modelTemplates(widget.project.id);
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _selected = catalog.templates.isEmpty
              ? null
              : catalog.templates.first;
          final template = _selected;
          if (template != null && template.supportedScales.isNotEmpty) {
            _scale = template.supportedScales.first;
            _name.text = '${template.id}_x$_scale';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _saveAsModel() async {
    final template = _selected;
    if (template == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await widget.client.saveTemplateAsModel(
        projectId: widget.project.id,
        templateId: template.id,
        name: _name.text.trim(),
        scale: _scale,
      );
      widget.onProjectChanged(envelope.project);
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
                SizedBox(
                  width: 390,
                  child: _TemplateList(
                    catalog: catalog,
                    selected: _selected,
                    filter: _filter,
                    onFilter: (value) => setState(() => _filter = value),
                    onSelect: (template) => setState(() {
                      _selected = template;
                      if (template.supportedScales.isNotEmpty) {
                        _scale = template.supportedScales.first;
                      }
                      _name.text = '${template.id}_x$_scale';
                    }),
                  ),
                ),
                SizedBox(width: tokens.gap),
                Expanded(
                  child: _TemplateDetail(
                    template: _selected,
                    existingModels: widget.project.models,
                    name: _name,
                    scale: _scale,
                    busy: _busy,
                    error: _error,
                    onScale: (value) => setState(() {
                      _scale = value;
                      final template = _selected;
                      if (template != null) {
                        _name.text = '${template.id}_x$_scale';
                      }
                    }),
                    onReset: () {
                      final template = _selected;
                      if (template == null) {
                        return;
                      }
                      setState(() {
                        if (template.supportedScales.isNotEmpty) {
                          _scale = template.supportedScales.first;
                        }
                        _name.text = '${template.id}_x$_scale';
                      });
                    },
                    onSave: _saveAsModel,
                  ),
                ),
              ],
            ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.catalog,
    required this.selected,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
  });

  final ModelTemplateCatalog catalog;
  final ModelTemplate? selected;
  final String filter;
  final ValueChanged<String> onFilter;
  final ValueChanged<ModelTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final filters = ['all', ...catalog.filters.values.expand((items) => items)];
    final deduped = filters.toSet().toList();
    final templates = catalog.templates.where((template) {
      if (filter == 'all') {
        return true;
      }
      return template.bestFor == filter ||
          template.speedLabel == filter ||
          template.supportState == filter;
    }).toList();
    return SrSection(
      title: 'Templates',
      subtitle: 'Metadata-first catalog with support guards',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in deduped)
                ChoiceChip(
                  label: Text(item),
                  selected: filter == item,
                  onSelected: (_) => onFilter(item),
                ),
            ],
          ),
          SizedBox(height: tokens.compactGap),
          for (final template in templates)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                selected: selected?.id == template.id,
                enabled: true,
                leading: Icon(
                  template.supportState == 'supported'
                      ? Icons.memory
                      : Icons.lock_outline,
                ),
                title: Text(template.displayName),
                subtitle: Text(
                  '${template.architectureSummary} · ${template.bestFor} · ${template.speedLabel}',
                ),
                trailing: SrChip(
                  label: template.supportState,
                  severity: template.supportState == 'supported'
                      ? 'success'
                      : 'warning',
                ),
                onTap: () => onSelect(template),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateDetail extends StatelessWidget {
  const _TemplateDetail({
    required this.template,
    required this.existingModels,
    required this.name,
    required this.scale,
    required this.busy,
    required this.onScale,
    required this.onReset,
    required this.onSave,
    this.error,
  });

  final ModelTemplate? template;
  final List<ModelSummary> existingModels;
  final TextEditingController name;
  final int scale;
  final bool busy;
  final ValueChanged<int> onScale;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final value = template;
    if (value == null) {
      return const SrEmptyState(
        title: 'Select a template',
        message: 'Model templates load from the backend catalog.',
        icon: Icons.memory,
      );
    }
    final supported = value.supportState == 'supported';
    return ListView(
      children: [
        SrBanner(
          title: 'Non-destructive switching',
          message:
              'Changing the selected template only edits the draft configuration. Existing datasets, runs, checkpoints, and inference records remain intact.',
          severity: 'info',
        ),
        SizedBox(height: tokens.gap),
        Row(
          children: [
            Expanded(
              child: SrMetricCard(
                label: 'Parameters',
                value: value.parameterCount == null
                    ? 'Unknown'
                    : _formatCount(value.parameterCount!),
              ),
            ),
            SizedBox(width: tokens.compactGap),
            Expanded(
              child: SrMetricCard(label: 'VRAM', value: value.vramEstimate),
            ),
            SizedBox(width: tokens.compactGap),
            Expanded(
              child: SrMetricCard(label: 'Crop', value: '${value.inputCrop}px'),
            ),
            SizedBox(width: tokens.compactGap),
            Expanded(
              child: SrMetricCard(
                label: 'Scale',
                value: value.supportedScales.map((item) => 'x$item').join(', '),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SrSection(
                title: value.displayName,
                subtitle: value.architectureSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!supported)
                      SrBanner(
                        message:
                            value.unavailable?.message ??
                            'This template is visible for planning but cannot be trained by the current backend.',
                        severity: 'warning',
                      ),
                    SizedBox(height: tokens.compactGap),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Model name',
                      ),
                    ),
                    SizedBox(height: tokens.compactGap),
                    DropdownButtonFormField<int>(
                      initialValue: scale,
                      decoration: const InputDecoration(labelText: 'Scale'),
                      items: [
                        for (final item in value.supportedScales)
                          DropdownMenuItem(value: item, child: Text('x$item')),
                      ],
                      onChanged: busy ? null : (item) => onScale(item ?? scale),
                    ),
                    SizedBox(height: tokens.compactGap),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: value.resetAction.supported && !busy
                              ? onReset
                              : null,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset to defaults'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              supported &&
                                  value.saveAsModelAction.supported &&
                                  !busy
                              ? onSave
                              : null,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save as model'),
                        ),
                        OutlinedButton.icon(
                          onPressed: value.importAction.supported
                              ? () {}
                              : null,
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Import template'),
                        ),
                      ],
                    ),
                    if (busy) ...[
                      SizedBox(height: tokens.compactGap),
                      const SrProgressBar(kind: SrProgressKind.indeterminate),
                    ],
                    if (error != null) ...[
                      SizedBox(height: tokens.compactGap),
                      SrBanner(message: error!, severity: 'error'),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: tokens.gap),
            Expanded(
              child: Column(
                children: [
                  SrSection(
                    title: 'Architecture flow',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final step in value.architectureSteps)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_forward),
                            title: Text(step),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.gap),
                  SrSection(
                    title: 'Hyperparameters',
                    child: Column(
                      children: [
                        for (final entry in value.hyperparameters.entries)
                          _KeyValue(entry.key, entry.value.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.gap),
        SrSection(
          title: 'Project models',
          child: existingModels.isEmpty
              ? const Text('No saved models yet.')
              : Column(
                  children: [
                    for (final model in existingModels)
                      ListTile(
                        leading: const Icon(Icons.memory),
                        title: Text(model.name),
                        subtitle: Text(
                          '${model.architecture} · x${model.scale} · ${model.numFeatures} features · ${model.numBlocks} blocks',
                        ),
                        trailing: Text(model.status),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: srTokens(context).muted),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}
