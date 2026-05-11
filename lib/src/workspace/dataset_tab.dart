import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../path_picker.dart';
import '../project_models.dart';

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
  String _validationMode = 'quick';
  String _storageOperation = 'reference';
  bool _busy = false;
  String? _error;
  VideoReadiness? _videoReadiness;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
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
    } catch (_) {
      // Readiness is advisory for this tab.
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
      final frameLimit = int.tryParse(_frameLimit.text.trim());
      final envelope = await widget.client.generateVideoDataset(
        projectId: widget.project.id,
        name: _videoName.text.trim(),
        sourceVideo: _videoPath.text.trim(),
        scale: _videoScale,
        fps: double.tryParse(_videoFps.text.trim()) ?? 1.0,
        frameLimit: frameLimit,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create Dataset',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _path,
                                  decoration: const InputDecoration(
                                    labelText: 'Paired dataset folder',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Select dataset folder',
                                onPressed: _busy ? null : _pickDataset,
                                icon: const Icon(Icons.folder_open),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _scale,
                            decoration: const InputDecoration(
                              labelText: 'Scale',
                            ),
                            items: const [2, 3, 4, 8]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text('x$value'),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _scale = value ?? 4),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _validationMode,
                            decoration: const InputDecoration(
                              labelText: 'Validation',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'quick',
                                child: Text('Quick'),
                              ),
                              DropdownMenuItem(
                                value: 'full',
                                child: Text('Full'),
                              ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(
                                    () => _validationMode = value ?? 'quick',
                                  ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _storageOperation,
                            decoration: const InputDecoration(
                              labelText: 'Storage',
                            ),
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
                            onChanged: _busy
                                ? null
                                : (value) => setState(
                                    () => _storageOperation =
                                        value ?? 'reference',
                                  ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _register,
                            icon: const Icon(Icons.add),
                            label: const Text('Register Dataset'),
                          ),
                          if (_busy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            _videoReadiness?.message ??
                                'Checking video dependency...',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Generate From Video',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _videoName,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _videoPath,
                                  decoration: const InputDecoration(
                                    labelText: 'Source video',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Select video',
                                onPressed: _busy ? null : _pickVideo,
                                icon: const Icon(Icons.video_file),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _videoScale,
                            decoration: const InputDecoration(
                              labelText: 'Scale',
                            ),
                            items: const [2, 3, 4, 8]
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text('x$value'),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _videoScale = value ?? 4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _videoFps,
                                  decoration: const InputDecoration(
                                    labelText: 'FPS',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _frameLimit,
                                  decoration: const InputDecoration(
                                    labelText: 'Frame limit',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed:
                                _busy || !(_videoReadiness?.available ?? false)
                                ? null
                                : _generateVideoDataset,
                            icon: const Icon(Icons.movie_creation_outlined),
                            label: const Text('Generate Dataset'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _DatasetList(datasets: widget.project.datasets)),
        ],
      ),
    );
  }
}

class _DatasetList extends StatelessWidget {
  const _DatasetList({required this.datasets});

  final List<DatasetSummary> datasets;

  @override
  Widget build(BuildContext context) {
    if (datasets.isEmpty) {
      return const Center(child: Text('No datasets yet.'));
    }
    return ListView.separated(
      itemCount: datasets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final dataset = datasets[index];
        return Card(
          child: ListTile(
            leading: Icon(
              dataset.usable ? Icons.check_circle : Icons.warning_amber,
            ),
            title: Text(dataset.name),
            subtitle: Text(
              '${dataset.type} · x${dataset.scale} · ${dataset.storageMode} · ${dataset.pairCount} pairs',
            ),
            trailing: Text(dataset.validationMode),
          ),
        );
      },
    );
  }
}
