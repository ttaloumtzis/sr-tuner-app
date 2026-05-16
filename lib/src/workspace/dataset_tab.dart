import 'dart:io';

import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
import '../path_picker.dart';
import '../project_models.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}

enum _DatasetCreateChoice { paired, video }

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
  String? _selectedDatasetId;
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

  DatasetSummary? _selectedDataset(ProjectState project) {
    final selectedId = _selectedDatasetId;
    if (selectedId != null) {
      final selected = project.datasets
          .where((dataset) => dataset.id == selectedId)
          .firstOrNull;
      if (selected != null) {
        return selected;
      }
    }
    return project.datasets.firstOrNull;
  }

  String? _newDatasetId(ProjectState previous, ProjectState next) {
    final previousIds = previous.datasets.map((dataset) => dataset.id).toSet();
    for (final dataset in next.datasets.reversed) {
      if (!previousIds.contains(dataset.id)) {
        return dataset.id;
      }
    }
    return next.datasets.lastOrNull?.id;
  }

  Future<void> _loadDetail({
    ProjectState? project,
    String? datasetId,
    int? previewIndex,
  }) async {
    final sourceProject = project ?? widget.project;
    final dataset = datasetId == null
        ? _selectedDataset(sourceProject)
        : sourceProject.datasets
              .where((dataset) => dataset.id == datasetId)
              .firstOrNull;
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
          _selectedDatasetId = dataset.id;
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

  Future<void> _showCreateDatasetDialog() async {
    if (!mounted) {
      return;
    }
    final choice = await showDialog<_DatasetCreateChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create dataset'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DatasetChoiceTile(
                icon: Icons.folder_copy_outlined,
                title: 'Type 1 · Paired folders',
                message:
                    'Register existing LR/HR image folders with matching filenames.',
                onPressed: () =>
                    Navigator.pop(context, _DatasetCreateChoice.paired),
              ),
              const SizedBox(height: 12),
              _DatasetChoiceTile(
                icon: Icons.video_file_outlined,
                title: 'Type 2 · Extract from video',
                message:
                    'Create LR/HR pairs by sampling frames from a video source.',
                onPressed: () =>
                    Navigator.pop(context, _DatasetCreateChoice.video),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _DatasetCreateChoice.paired:
        await _showPairedDatasetDialog();
      case _DatasetCreateChoice.video:
        await _showVideoWizard();
    }
  }

  Future<void> _showPairedDatasetDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Type 1 dataset'),
        content: SizedBox(
          width: 760,
          child: _PairedDatasetForm(
            busy: _busy,
            name: _name,
            path: _path,
            scale: _scale,
            validationMode: _validationMode,
            storageOperation: _storageOperation,
            onPickFolder: _pickDataset,
            onScaleChanged: (value) => setState(() => _scale = value),
            onValidationChanged: (value) =>
                setState(() => _validationMode = value),
            onStorageChanged: (value) =>
                setState(() => _storageOperation = value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () {
                    Navigator.pop(context);
                    _register();
                  },
            icon: const Icon(Icons.add),
            label: const Text('Create dataset'),
          ),
        ],
      ),
    );
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
      final nextDatasetId = _newDatasetId(widget.project, envelope.project);
      _selectedDatasetId = nextDatasetId;
      widget.onProjectChanged(envelope.project);
      await _loadDetail(project: envelope.project, datasetId: nextDatasetId);
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

  Future<void> _refreshProjectAfterDatasetJob() async {
    final envelope = await widget.client.openProject(widget.project.rootPath);
    final nextDatasetId = _newDatasetId(widget.project, envelope.project);
    _selectedDatasetId = nextDatasetId;
    widget.onProjectChanged(envelope.project);
    await _loadDetail(project: envelope.project, datasetId: nextDatasetId);
  }

  Future<JobState> _startVideoDataset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await widget.client.startVideoDataset(
        projectId: widget.project.id,
        name: _videoName.text.trim(),
        sourceVideo: _videoPath.text.trim(),
        scale: _videoScale,
        fps: double.tryParse(_videoFps.text.trim()) ?? 1.0,
        frameLimit: int.tryParse(_frameLimit.text.trim()),
      );
    } catch (error) {
      setState(() => _error = error.toString());
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _generateVideoDatasetWithProgress() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DatasetCreationProgressDialog(
        title: 'Creating Type 2 dataset',
        start: _startVideoDataset,
        getJob: widget.client.getJob,
        onCompleted: _refreshProjectAfterDatasetJob,
      ),
    );
  }

  Future<void> _deleteSelectedDataset() async {
    final dataset = _selectedDataset(widget.project);
    if (dataset == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${dataset.name}?'),
        content: const Text(
          'This removes the dataset from the project. Project-owned dataset files are removed too; external referenced folders are left untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete dataset'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await widget.client.deleteDataset(
        projectId: widget.project.id,
        datasetId: dataset.id,
      );
      _selectedDatasetId = envelope.project.datasets.firstOrNull?.id;
      widget.onProjectChanged(envelope.project);
      await _loadDetail(project: envelope.project);
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
                    _generateVideoDatasetWithProgress();
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
              onCreateDataset: _showCreateDatasetDialog,
              error: _error,
            )
          : _DatasetPopulatedState(
              datasets: widget.project.datasets,
              detail: _detail,
              error: _error,
              busy: _busy,
              selectedDatasetId: _selectedDatasetId,
              onCreateDataset: _showCreateDatasetDialog,
              onDatasetSelected: (datasetId) {
                setState(() {
                  _selectedDatasetId = datasetId;
                  _detail = null;
                  _previewIndex = 0;
                  _error = null;
                });
                _loadDetail(datasetId: datasetId, previewIndex: 0);
              },
              onExport: () {},
              onDelete: _deleteSelectedDataset,
              onPreview: (index) => _loadDetail(previewIndex: index),
            ),
    );
  }
}

class _DatasetEmptyState extends StatelessWidget {
  const _DatasetEmptyState({
    required this.busy,
    required this.videoMessage,
    required this.onCreateDataset,
    this.error,
  });

  final bool busy;
  final String videoMessage;
  final VoidCallback onCreateDataset;
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
        SizedBox(height: tokens.compactGap),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: busy ? null : onCreateDataset,
            icon: const Icon(Icons.add),
            label: const Text('Create dataset'),
          ),
        ),
        SizedBox(height: tokens.gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OnboardingCard(
                icon: Icons.folder_copy_outlined,
                title: 'Type 1 paired folders',
                message: 'Register existing HR/LR folders by filename stem.',
                action: 'Create dataset',
                onPressed: busy ? null : onCreateDataset,
              ),
            ),
            SizedBox(width: tokens.gap),
            Expanded(
              child: _OnboardingCard(
                icon: Icons.video_file_outlined,
                title: 'Type 2 from video',
                message: videoMessage,
                action: 'Create dataset',
                onPressed: busy ? null : onCreateDataset,
              ),
            ),
          ],
        ),
        if (busy) ...[
          SizedBox(height: tokens.gap),
          const SrProgressBar(kind: SrProgressKind.indeterminate),
        ],
        if (error != null) ...[
          SizedBox(height: tokens.gap),
          SrBanner(message: error!, severity: 'error'),
        ],
      ],
    );
  }
}

class _DatasetPopulatedState extends StatelessWidget {
  const _DatasetPopulatedState({
    required this.datasets,
    required this.detail,
    required this.busy,
    required this.selectedDatasetId,
    required this.onCreateDataset,
    required this.onDatasetSelected,
    required this.onExport,
    required this.onDelete,
    required this.onPreview,
    this.error,
  });

  final List<DatasetSummary> datasets;
  final DatasetDetail? detail;
  final bool busy;
  final String? selectedDatasetId;
  final VoidCallback onCreateDataset;
  final ValueChanged<String> onDatasetSelected;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final ValueChanged<int> onPreview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final selected = selectedDatasetId == null
        ? null
        : datasets
              .where((dataset) => dataset.id == selectedDatasetId)
              .firstOrNull;
    final dataset = detail?.dataset ?? selected ?? datasets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in datasets)
              InputChip(
                avatar: const Icon(Icons.dataset, size: 14),
                label: Text(item.name),
                selected: item.id == dataset.id,
                onSelected: busy ? null : (_) => onDatasetSelected(item.id),
              ),
            SrChip(label: 'x${dataset.scale}'),
            SrChip(label: '${dataset.pairCount} pairs', severity: 'success'),
            SrChip(
              label: dataset.usable ? 'Usable' : 'Needs attention',
              severity: dataset.usable ? 'success' : 'warning',
            ),
            FilledButton.icon(
              onPressed: busy ? null : onCreateDataset,
              icon: const Icon(Icons.add),
              label: const Text('Create dataset'),
            ),
            OutlinedButton.icon(
              onPressed: detail?.exportAction.supported == true
                  ? onExport
                  : null,
              icon: const Icon(Icons.ios_share),
              label: const Text('Export'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete dataset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
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

class _DatasetChoiceTile extends StatelessWidget {
  const _DatasetChoiceTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radius),
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(tokens.gap),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(tokens.radius),
          color: tokens.panel,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: tokens.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(message, style: TextStyle(color: tokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _PairedDatasetForm extends StatelessWidget {
  const _PairedDatasetForm({
    required this.busy,
    required this.name,
    required this.path,
    required this.scale,
    required this.validationMode,
    required this.storageOperation,
    required this.onPickFolder,
    required this.onScaleChanged,
    required this.onValidationChanged,
    required this.onStorageChanged,
  });

  final bool busy;
  final TextEditingController name;
  final TextEditingController path;
  final int scale;
  final String validationMode;
  final String storageOperation;
  final VoidCallback onPickFolder;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<String> onValidationChanged;
  final ValueChanged<String> onStorageChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SrBanner(
            title: 'Type 1 dataset',
            message:
                'Use a folder containing HR and LR subfolders. Files are matched by filename stem.',
            severity: 'info',
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
                  decoration: const InputDecoration(labelText: 'Validation'),
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
        ],
      ),
    );
  }
}

class _DatasetCreationProgressDialog extends StatefulWidget {
  const _DatasetCreationProgressDialog({
    required this.title,
    required this.start,
    required this.getJob,
    required this.onCompleted,
  });

  final String title;
  final Future<JobState> Function() start;
  final Future<JobState> Function(String jobId) getJob;
  final Future<void> Function() onCompleted;

  @override
  State<_DatasetCreationProgressDialog> createState() =>
      _DatasetCreationProgressDialogState();
}

class _DatasetCreationProgressDialogState
    extends State<_DatasetCreationProgressDialog> {
  String _status = 'Preparing request...';
  double _progress = 0;
  bool _running = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      var job = await widget.start();
      while (mounted && !job.isTerminal) {
        setState(() {
          _progress = job.progress.clamp(0, 1);
          _status = job.logs.isEmpty ? 'Working...' : job.logs.last;
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        job = await widget.getJob(job.id);
      }
      if (!mounted) return;
      _progress = job.progress.clamp(0, 1);
      if (job.status == 'completed') {
        setState(() {
          _running = false;
          _status = 'Dataset created.';
          _progress = 1;
        });
        await widget.onCompleted();
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw ApiException(
          job.logs.isEmpty ? 'Dataset creation failed.' : job.logs.last,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _running = false;
        _failed = true;
        _status = error.toString();
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SrBanner(
              title: _failed
                  ? 'Creation failed'
                  : _running
                  ? 'Working'
                  : 'Complete',
              message: _status,
              severity: _failed
                  ? 'error'
                  : _running
                  ? 'info'
                  : 'success',
            ),
            SizedBox(height: tokens.gap),
            LinearProgressIndicator(value: _progress.clamp(0, 1)),
            const SizedBox(height: 8),
            Text('${(_progress * 100).round()}%'),
          ],
        ),
      ),
      actions: [
        if (!_running)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_failed ? 'Close' : 'Done'),
          ),
      ],
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
          if (value != null && value.exists)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SrChip(label: value.samplingStrategy, severity: 'success'),
                if (value.estimatedYield != null)
                  SrChip(label: '${value.estimatedYield} pairs'),
                if (value.outputSizeBytes != null)
                  SrChip(label: _formatBytes(value.outputSizeBytes!)),
              ],
            )
          else
            SrBanner(
              message: value?.readiness?.message ?? 'Select an existing video.',
              severity: 'warning',
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
      trailing: Tooltip(
        message: 'Coming soon — re-synthesis will be available in a future update.',
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Re-synthesize'),
        ),
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
