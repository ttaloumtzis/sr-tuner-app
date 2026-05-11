import 'dart:io';

import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
import '../path_picker.dart';
import '../project_models.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DatasetTab extends StatefulWidget {
  const DatasetTab({
    required this.client,
    required this.project,
    required this.onProjectChanged,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<ProjectState> onProjectChanged;

  @override
  State<DatasetTab> createState() => _DatasetTabState();
}

class _DatasetTabState extends State<DatasetTab> {
  final _picker = const PathPicker();
  final _name = TextEditingController(text: 'dataset_x4');
  final _path = TextEditingController();
  final _videoName = TextEditingController(text: 'video_dataset_x4');
  final _videoPath = TextEditingController();
  final _videoFps = TextEditingController(text: '1.0');
  final _frameLimit = TextEditingController();
  int _scale = 4;
  int _videoScale = 4;
  int _previewIndex = 0;
  String _validationMode = 'quick';
  String _storageOperation = 'reference';
  bool _busy = false;
  String? _error;
  VideoReadiness? _videoReadiness;
  DatasetDetail? _detail;
  VideoWizardMetadata? _videoMetadata;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
    _loadDetail();
  }

  @override
  void didUpdateWidget(DatasetTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    _videoName.dispose();
    _videoPath.dispose();
    _videoFps.dispose();
    _frameLimit.dispose();
    super.dispose();
  }

  Future<void> _loadReadiness() async {
    try {
      final readiness = await widget.client.videoReadiness();
      if (mounted) {
        setState(() => _videoReadiness = readiness);
      }
    } catch (_) {}
  }

  Future<void> _loadDetail({int? previewIndex}) async {
    final dataset = widget.project.datasets.firstOrNull;
    if (dataset == null) {
      if (mounted) {
        setState(() => _detail = null);
      }
      return;
    }
    try {
      final nextIndex = previewIndex ?? _previewIndex;
      final detail = await widget.client.datasetDetail(
        projectId: widget.project.id,
        datasetId: dataset.id,
        previewIndex: nextIndex,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _previewIndex = detail.preview.index;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _pickDataset() async {
    final path = await _picker.pickFolder(confirmButtonText: 'Select dataset');
    if (path != null) {
      _path.text = path;
    }
  }

  Future<void> _pickVideo() async {
    final path = await _picker.pickFile(confirmButtonText: 'Select video');
    if (path != null) {
      _videoPath.text = path;
      await _loadVideoMetadata();
    }
  }

  Future<void> _loadVideoMetadata() async {
    if (_videoPath.text.trim().isEmpty) {
      return;
    }
    try {
      final metadata = await widget.client.videoWizardMetadata(
        projectId: widget.project.id,
        name: _videoName.text.trim(),
        sourceVideo: _videoPath.text.trim(),
        scale: _videoScale,
        fps: double.tryParse(_videoFps.text.trim()) ?? 1.0,
        frameLimit: int.tryParse(_frameLimit.text.trim()),
      );
      if (mounted) {
        setState(() => _videoMetadata = metadata);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_storageOperation != 'reference' && !await _confirmStorage()) {
        return;
      }
      final envelope = await widget.client.registerPairedDataset(
        projectId: widget.project.id,
        name: _name.text.trim(),
        datasetPath: _path.text.trim(),
        scale: _scale,
        validationMode: _validationMode,
        storageOperation: _storageOperation,
      );
      widget.onProjectChanged(envelope.project);
      await _loadDetail();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmStorage() async {
    final estimate = await widget.client.estimateDatasetStorage(
      projectId: widget.project.id,
      name: _name.text.trim(),
      datasetPath: _path.text.trim(),
      operation: _storageOperation,
    );
    if (!mounted) {
      return false;
    }
    final sizeMb = (estimate.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_storageOperation == 'move' ? 'Move' : 'Copy'} dataset'),
        content: Text(
          '${estimate.fileCount} files, about $sizeMb MB.\nDestination:\n${estimate.destination}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _generateVideoDataset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await widget.client.generateVideoDataset(
        projectId: widget.project.id,
        name: _videoName.text.trim(),
        sourceVideo: _videoPath.text.trim(),
        scale: _videoScale,
        fps: double.tryParse(_videoFps.text.trim()) ?? 1.0,
        frameLimit: int.tryParse(_frameLimit.text.trim()),
      );
      widget.onProjectChanged(envelope.project);
      await _loadDetail();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showVideoWizard() async {
    await _loadVideoMetadata();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extract from video'),
        content: SizedBox(
          width: 720,
          child: _VideoWizard(
            name: _videoName,
            path: _videoPath,
            fps: _videoFps,
            frameLimit: _frameLimit,
            scale: _videoScale,
            metadata: _videoMetadata,
            onScaleChanged: (value) {
              setState(() => _videoScale = value);
              _loadVideoMetadata();
            },
            onPickVideo: _pickVideo,
            onRefresh: _loadVideoMetadata,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _busy || !(_videoReadiness?.available ?? false)
                ? null
                : () {
                    Navigator.pop(context);
                    _generateVideoDataset();
                  },
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Generate dataset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Padding(
      padding: EdgeInsets.all(tokens.gap),
      child: widget.project.datasets.isEmpty
          ? _DatasetEmptyState(
              busy: _busy,
              videoMessage: _videoReadiness?.message ?? 'Checking video tools.',
              onVideo: _showVideoWizard,
              onPickFolder: _pickDataset,
              onRegister: _register,
              name: _name,
              path: _path,
              scale: _scale,
              validationMode: _validationMode,
              storageOperation: _storageOperation,
              onScaleChanged: (value) => setState(() => _scale = value),
              onValidationChanged: (value) =>
                  setState(() => _validationMode = value),
              onStorageChanged: (value) =>
                  setState(() => _storageOperation = value),
              error: _error,
            )
          : _DatasetPopulatedState(
              datasets: widget.project.datasets,
              detail: _detail,
              error: _error,
              busy: _busy,
              onAddSource: _pickDataset,
              onRescan: _loadDetail,
              onExport: () {},
              onVideo: _showVideoWizard,
              onPreview: (index) => _loadDetail(previewIndex: index),
            ),
    );
  }
}

class _DatasetEmptyState extends StatelessWidget {
  const _DatasetEmptyState({
    required this.busy,
    required this.videoMessage,
    required this.onVideo,
    required this.onPickFolder,
    required this.onRegister,
    required this.name,
    required this.path,
    required this.scale,
    required this.validationMode,
    required this.storageOperation,
    required this.onScaleChanged,
    required this.onValidationChanged,
    required this.onStorageChanged,
    this.error,
  });

  final bool busy;
  final String videoMessage;
  final VoidCallback onVideo;
  final VoidCallback onPickFolder;
  final VoidCallback onRegister;
  final TextEditingController name;
  final TextEditingController path;
  final int scale;
  final String validationMode;
  final String storageOperation;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<String> onValidationChanged;
  final ValueChanged<String> onStorageChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return ListView(
      children: [
        SrBanner(
          title: 'Beginner guidance',
          message:
              'Start with a small, clean set of matching low-resolution and high-resolution pairs. Folders remain referenced unless you choose copy or move.',
          severity: 'info',
        ),
        SizedBox(height: tokens.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OnboardingCard(
                icon: Icons.video_file_outlined,
                title: 'Extract from video',
                message: videoMessage,
                action: 'Open wizard',
                onPressed: busy ? null : onVideo,
              ),
            ),
            SizedBox(width: tokens.gap),
            Expanded(
              child: _OnboardingCard(
                icon: Icons.folder_open,
                title: 'Folder of images',
                message: 'Register an LR/HR folder pair or generated dataset.',
                action: 'Choose folder',
                onPressed: busy ? null : onPickFolder,
              ),
            ),
            SizedBox(width: tokens.gap),
            const Expanded(
              child: _OnboardingCard(
                icon: Icons.inventory_2_outlined,
                title: 'Pre-made pairs',
                message:
                    'Use existing paired data with x2, x3, x4, or x8 scale.',
                action: 'Unavailable',
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.gap),
        SrSection(
          title: 'Register paired dataset',
          subtitle: 'Native folder picker fallback for desktop drag/drop.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SrImagePlaceholder(
                label: 'Drop a dataset folder here, or use the picker fallback',
                aspectRatio: 8,
              ),
              SizedBox(height: tokens.compactGap),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: tokens.compactGap),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: path,
                      decoration: const InputDecoration(
                        labelText: 'Paired dataset folder',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Select dataset folder',
                    onPressed: busy ? null : onPickFolder,
                    icon: const Icon(Icons.folder_open),
                  ),
                ],
              ),
              SizedBox(height: tokens.compactGap),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: scale,
                      decoration: const InputDecoration(labelText: 'Scale'),
                      items: const [2, 3, 4, 8]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('x$value'),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => onScaleChanged(value ?? 4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: validationMode,
                      decoration: const InputDecoration(
                        labelText: 'Validation',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'quick', child: Text('Quick')),
                        DropdownMenuItem(value: 'full', child: Text('Full')),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => onValidationChanged(value ?? 'quick'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: storageOperation,
                      decoration: const InputDecoration(labelText: 'Storage'),
                      items: const [
                        DropdownMenuItem(
                          value: 'reference',
                          child: Text('Reference external'),
                        ),
                        DropdownMenuItem(
                          value: 'copy',
                          child: Text('Copy into project'),
                        ),
                        DropdownMenuItem(
                          value: 'move',
                          child: Text('Move into project'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => onStorageChanged(value ?? 'reference'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.compactGap),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: busy ? null : onRegister,
                  icon: const Icon(Icons.add),
                  label: const Text('Register dataset'),
                ),
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
      ],
    );
  }
}

class _DatasetPopulatedState extends StatelessWidget {
  const _DatasetPopulatedState({
    required this.datasets,
    required this.detail,
    required this.busy,
    required this.onAddSource,
    required this.onRescan,
    required this.onExport,
    required this.onVideo,
    required this.onPreview,
    this.error,
  });

  final List<DatasetSummary> datasets;
  final DatasetDetail? detail;
  final bool busy;
  final VoidCallback onAddSource;
  final VoidCallback onRescan;
  final VoidCallback onExport;
  final VoidCallback onVideo;
  final ValueChanged<int> onPreview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final dataset = detail?.dataset ?? datasets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SrChip(label: dataset.name, selected: true, icon: Icons.dataset),
            SrChip(label: 'x${dataset.scale}'),
            SrChip(label: '${dataset.pairCount} pairs', severity: 'success'),
            SrChip(
              label: dataset.usable ? 'Usable' : 'Needs attention',
              severity: dataset.usable ? 'success' : 'warning',
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onAddSource,
              icon: const Icon(Icons.add),
              label: const Text('Add source'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onRescan,
              icon: const Icon(Icons.sync),
              label: const Text('Re-scan'),
            ),
            OutlinedButton.icon(
              onPressed: detail?.exportAction.supported == true
                  ? onExport
                  : null,
              icon: const Icon(Icons.ios_share),
              label: const Text('Export'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onVideo,
              icon: const Icon(Icons.video_file_outlined),
              label: const Text('Extract from video'),
            ),
          ],
        ),
        if (error != null) ...[
          SizedBox(height: tokens.compactGap),
          SrBanner(message: error!, severity: 'error'),
        ],
        SizedBox(height: tokens.gap),
        Expanded(
          child: detail == null
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: ListView(
                        children: [
                          _SourceList(detail: detail!),
                          SizedBox(height: tokens.gap),
                          _HealthChecks(detail: detail!),
                        ],
                      ),
                    ),
                    SizedBox(width: tokens.gap),
                    Expanded(
                      child: ListView(
                        children: [
                          _PreviewPane(detail: detail!, onPreview: onPreview),
                          SizedBox(height: tokens.gap),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _PipelineCard(detail: detail!)),
                              SizedBox(width: tokens.gap),
                              Expanded(child: _HistogramCard(detail: detail!)),
                            ],
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

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: title,
      subtitle: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 34),
          const SizedBox(height: 12),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

class _VideoWizard extends StatelessWidget {
  const _VideoWizard({
    required this.name,
    required this.path,
    required this.fps,
    required this.frameLimit,
    required this.scale,
    required this.metadata,
    required this.onScaleChanged,
    required this.onPickVideo,
    required this.onRefresh,
  });

  final TextEditingController name;
  final TextEditingController path;
  final TextEditingController fps;
  final TextEditingController frameLimit;
  final int scale;
  final VideoWizardMetadata? metadata;
  final ValueChanged<int> onScaleChanged;
  final VoidCallback onPickVideo;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final value = metadata;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SrStepIndicator(
            steps: ['Source', 'Sampling', 'Filters', 'Review'],
            currentIndex: 0,
          ),
          SizedBox(height: tokens.compactGap),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Dataset name'),
          ),
          SizedBox(height: tokens.compactGap),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: path,
                  decoration: const InputDecoration(labelText: 'Source video'),
                  onChanged: (_) => onRefresh(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Select video',
                onPressed: onPickVideo,
                icon: const Icon(Icons.video_file),
              ),
            ],
          ),
          SizedBox(height: tokens.compactGap),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: scale,
                  decoration: const InputDecoration(labelText: 'Scale'),
                  items: const [2, 3, 4, 8]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('x$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => onScaleChanged(value ?? 4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: fps,
                  decoration: const InputDecoration(labelText: 'Frames/sec'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onRefresh(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: frameLimit,
                  decoration: const InputDecoration(labelText: 'Frame limit'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onRefresh(),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.compactGap),
          SrSection(
            title: 'Review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KeyValue(
                  'Source exists',
                  value?.exists == true ? 'Yes' : 'No',
                ),
                _KeyValue(
                  'Sampling',
                  value?.samplingStrategy ?? 'Pick a video to estimate.',
                ),
                _KeyValue(
                  'Estimated yield',
                  value?.estimatedYield == null
                      ? 'Unavailable'
                      : '${value!.estimatedYield} pairs',
                ),
                _KeyValue(
                  'Output size',
                  value?.outputSizeBytes == null
                      ? 'Unavailable'
                      : _formatBytes(value!.outputSizeBytes!),
                ),
                _KeyValue(
                  'Deduplication',
                  value?.deduplicationGuidance ?? 'Pending source metadata.',
                ),
                if (value?.readiness != null)
                  SrBanner(
                    message: value!.readiness!.message,
                    severity: value.readiness!.supported
                        ? 'success'
                        : 'warning',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({required this.detail});

  final DatasetDetail detail;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Sources',
      subtitle: '${detail.sources.length} registered source rows',
      child: Column(
        children: [
          for (final source in detail.sources)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_sourceIcon(source.sourceType)),
                title: Text(source.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${source.pairCount} pairs · ${source.note ?? source.status}',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Source actions',
                  itemBuilder: (context) => [
                    for (final action in source.actions)
                      PopupMenuItem(
                        enabled: action.supported,
                        value: action.id,
                        child: Text(
                          action.supported
                              ? action.label
                              : '${action.label} unavailable',
                        ),
                      ),
                  ],
                ),
                shape: Border(
                  left: BorderSide(
                    width: 4,
                    color: _severityColor(context, source.severity),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthChecks extends StatelessWidget {
  const _HealthChecks({required this.detail});

  final DatasetDetail detail;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Health checks',
      child: Column(
        children: [
          for (final check in detail.healthChecks)
            ListTile(
              dense: true,
              leading: Icon(
                check.severity == 'success'
                    ? Icons.check_circle_outline
                    : check.severity == 'error'
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                color: _severityColor(context, check.severity),
              ),
              title: Text(check.label),
              subtitle: Text(check.message),
            ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.detail, required this.onPreview});

  final DatasetDetail detail;
  final ValueChanged<int> onPreview;

  @override
  Widget build(BuildContext context) {
    final preview = detail.preview;
    final total = preview.total;
    return SrSection(
      title: 'LR / HR preview',
      subtitle: total == 0
          ? 'No preview pairs available'
          : 'Pair ${preview.index + 1} of $total',
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton.outlined(
            tooltip: 'Previous pair',
            onPressed: preview.index <= 0
                ? null
                : () => onPreview(preview.index - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton.outlined(
            tooltip: 'Next pair',
            onPressed: preview.index >= total - 1
                ? null
                : () => onPreview(preview.index + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      child: preview.unavailable != null
          ? SrBanner(message: preview.unavailable!.message, severity: 'warning')
          : Row(
              children: [
                Expanded(
                  child: _PreviewImage(path: preview.lrPath, label: 'LR'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PreviewImage(path: preview.hrPath, label: 'HR'),
                ),
              ],
            ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.path, required this.label});

  final String? path;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.isEmpty || !File(value).existsSync()) {
      return SrImagePlaceholder(label: label, aspectRatio: 1.4);
    }
    return AspectRatio(
      aspectRatio: 1.4,
      child: Image.file(File(value), fit: BoxFit.contain),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.detail});

  final DatasetDetail detail;

  @override
  Widget build(BuildContext context) {
    final resynthesis = detail.resynthesis;
    return SrSection(
      title: 'Degradation pipeline',
      trailing: OutlinedButton.icon(
        onPressed: resynthesis?.supported == true ? () {} : null,
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('Re-synthesize'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.degradationPipeline.isEmpty)
            const Text('No generated degradation metadata recorded.'),
          for (final step in detail.degradationPipeline)
            ListTile(
              dense: true,
              leading: const Icon(Icons.tune),
              title: Text(step),
            ),
          if (resynthesis != null && !resynthesis.supported)
            SrBanner(message: resynthesis.message, severity: 'warning'),
        ],
      ),
    );
  }
}

class _HistogramCard extends StatelessWidget {
  const _HistogramCard({required this.detail});

  final DatasetDetail detail;

  @override
  Widget build(BuildContext context) {
    final histogram = detail.histogram;
    return SrSection(
      title: 'Channel histogram',
      subtitle: histogram.selectedChannel,
      child: histogram.available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final channel in histogram.channels)
                      SrChip(
                        label: channel,
                        selected: channel == histogram.selectedChannel,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: CustomPaint(
                    painter: _HistogramPainter(histogram.bins),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            )
          : SrBanner(
              message:
                  histogram.unavailable?.message ?? 'Histogram unavailable.',
              severity: 'warning',
            ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.bins);

  final List<int> bins;

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) {
      return;
    }
    final maxValue = bins.reduce((a, b) => a > b ? a : b).toDouble();
    final width = size.width / bins.length;
    final paint = Paint()..color = const Color(0xff6aa6ff);
    for (var i = 0; i < bins.length; i++) {
      final height = maxValue == 0 ? 0.0 : size.height * bins[i] / maxValue;
      canvas.drawRect(
        Rect.fromLTWH(i * width, size.height - height, width * 0.75, height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) =>
      oldDelegate.bins != bins;
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

IconData _sourceIcon(String type) => switch (type) {
  'video' => Icons.video_file_outlined,
  'generated' => Icons.auto_fix_high,
  'folder' => Icons.folder_open,
  _ => Icons.dataset_outlined,
};

Color _severityColor(BuildContext context, String severity) {
  final tokens = srTokens(context);
  return switch (severity) {
    'success' => tokens.success,
    'warning' => tokens.warning,
    'error' => tokens.danger,
    _ => tokens.accent,
  };
}

String _formatBytes(int bytes) {
  if (bytes > 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes > 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '$bytes bytes';
}
