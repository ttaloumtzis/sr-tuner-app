import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../project_models.dart';
import '../shared_widgets.dart';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class TrainingTab extends StatefulWidget {
  const TrainingTab({
    required this.client,
    required this.project,
    required this.onProjectChanged,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<ProjectState> onProjectChanged;

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  final _name = TextEditingController(text: 'run_x4');
  final _epochs = TextEditingController(text: '10');
  final _checkpointCadence = TextEditingController(text: '1');
  final _validation = TextEditingController(text: '0.1');
  final _seed = TextEditingController(text: '42');
  final _warmup = TextEditingController(text: '0');
  TrainingReadiness? _readiness;
  List<DeviceOption> _devices = [
    DeviceOption(id: 'cpu', label: 'CPU', type: 'cpu', available: true),
  ];
  String? _datasetId;
  String? _modelId;
  String _device = 'cpu';
  final String _trainMode = 'new';
  String _precision = 'float32';
  String _scheduler = 'cosine';
  String _diffMode = 'absolute';
  bool _validationShuffle = true;
  bool _tensorboard = false;
  bool _compile = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectDefaults();
    _loadReadiness();
  }

  @override
  void didUpdateWidget(TrainingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) {
      _selectDefaults();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _epochs.dispose();
    _checkpointCadence.dispose();
    _validation.dispose();
    _seed.dispose();
    _warmup.dispose();
    super.dispose();
  }

  void _selectDefaults() {
    _datasetId ??= widget.project.datasets
        .where((dataset) => dataset.usable)
        .firstOrNull
        ?.id;
    _modelId ??= widget.project.models.firstOrNull?.id;
  }

  Future<void> _loadReadiness() async {
    try {
      final readiness = await widget.client.trainingReadiness(
        tensorboard: _tensorboard,
      );
      final devices = await widget.client.devices();
      if (mounted) {
        setState(() {
          _readiness = readiness;
          _devices = devices.isEmpty ? _devices : devices;
          if (!_devices.any((device) => device.id == _device)) {
            _device = 'cpu';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _createRun() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await widget.client.createRun(
        projectId: widget.project.id,
        name: _name.text.trim(),
        datasetId: _datasetId!,
        modelId: _modelId!,
        trainMode: _trainMode,
        device: _device,
        epochs: int.tryParse(_epochs.text.trim()) ?? 10,
        checkpointCadence: int.tryParse(_checkpointCadence.text.trim()) ?? 1,
        validationPercentage: double.tryParse(_validation.text.trim()) ?? 0.1,
        validationSeed: int.tryParse(_seed.text.trim()) ?? 42,
        validationShuffle: _validationShuffle,
        tensorboard: _tensorboard,
        precision: _precision,
        compile: _compile,
        warmupEpochs: int.tryParse(_warmup.text.trim()) ?? 0,
        schedulerType: _scheduler,
        diffMode: _diffMode,
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

  Future<void> _launch(String runId) async {
    await _runAction(
      () => widget.client.launchRun(projectId: widget.project.id, runId: runId),
    );
  }

  Future<void> _pause(String runId) async {
    await _runAction(
      () => widget.client.pauseRun(projectId: widget.project.id, runId: runId),
    );
  }

  Future<void> _stop(String runId) async {
    await _runAction(
      () => widget.client.stopRun(projectId: widget.project.id, runId: runId),
    );
  }

  Future<void> _runAction(Future<ProjectEnvelope> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await action();
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
    final datasets = widget.project.datasets
        .where((dataset) => dataset.usable)
        .toList();
    final models = widget.project.models;
    if (datasets.isEmpty || models.isEmpty) {
      return BlockedState(
        title: 'Training Setup',
        message: datasets.isEmpty && models.isEmpty
            ? 'Create at least one usable dataset and one compatible model before launching training.'
            : datasets.isEmpty
            ? 'Create or register a usable dataset before launching training.'
            : 'Create a model before launching training.',
        icon: Icons.play_circle_outline,
      );
    }
    final compatible = _selectedCompatible(datasets, models);
    final readiness = _readiness;
    final canCreate = !_busy && compatible && (readiness?.available ?? false);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Configure Run',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Run name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _datasetId,
                        decoration: const InputDecoration(labelText: 'Dataset'),
                        items: [
                          for (final dataset in datasets)
                            DropdownMenuItem(
                              value: dataset.id,
                              child: Text(
                                '${dataset.name} · x${dataset.scale}',
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _datasetId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _modelId,
                        decoration: const InputDecoration(labelText: 'Model'),
                        items: [
                          for (final model in models)
                            DropdownMenuItem(
                              value: model.id,
                              child: Text('${model.name} · x${model.scale}'),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _modelId = value),
                      ),
                      if (!compatible) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected dataset and model scales do not match.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _numberField(_epochs, 'Epochs')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _numberField(
                              _checkpointCadence,
                              'Checkpoint every',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              _validation,
                              'Validation split',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _numberField(_seed, 'Seed')),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shuffle validation split'),
                        value: _validationShuffle,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _validationShuffle = value),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _device,
                        decoration: const InputDecoration(labelText: 'Device'),
                        items: [
                          for (final device in _devices)
                            DropdownMenuItem(
                              value: device.id,
                              child: Text(device.label),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _device = value ?? 'cpu'),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'float32', label: Text('FP32')),
                          ButtonSegment(value: 'mixed', label: Text('Mixed')),
                        ],
                        selected: {_precision},
                        onSelectionChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _precision = value.first),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _scheduler,
                              decoration: const InputDecoration(
                                labelText: 'Scheduler',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('None'),
                                ),
                                DropdownMenuItem(
                                  value: 'cosine',
                                  child: Text('Cosine'),
                                ),
                                DropdownMenuItem(
                                  value: 'step',
                                  child: Text('Step'),
                                ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _scheduler = value ?? 'cosine',
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _numberField(_warmup, 'Warmup')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _diffMode,
                        decoration: const InputDecoration(
                          labelText: 'Preview diff',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'absolute',
                            child: Text('Absolute'),
                          ),
                          DropdownMenuItem(
                            value: 'heatmap',
                            child: Text('Heatmap'),
                          ),
                          DropdownMenuItem(value: 'both', child: Text('Both')),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _diffMode = value ?? 'absolute',
                              ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('TensorBoard logging'),
                        subtitle: Text(
                          readiness?.dependencies
                                  .where((item) => item.name == 'tensorboard')
                                  .firstOrNull
                                  ?.message ??
                              '',
                        ),
                        value: _tensorboard,
                        onChanged: _busy
                            ? null
                            : (value) {
                                setState(() => _tensorboard = value);
                                _loadReadiness();
                              },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Compile model'),
                        value: _compile,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _compile = value),
                      ),
                      const SizedBox(height: 8),
                      _ReadinessPanel(readiness: readiness),
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
                      FilledButton.icon(
                        onPressed: canCreate ? _createRun : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Run'),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _RunList(
              runs: widget.project.runs,
              datasets: widget.project.datasets,
              models: widget.project.models,
              busy: _busy,
              onLaunch: _launch,
              onPause: _pause,
              onStop: _stop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
    );
  }

  bool _selectedCompatible(
    List<DatasetSummary> datasets,
    List<ModelSummary> models,
  ) {
    final dataset = datasets.where((item) => item.id == _datasetId).firstOrNull;
    final model = models.where((item) => item.id == _modelId).firstOrNull;
    if (dataset == null || model == null) {
      return false;
    }
    return dataset.scale == model.scale;
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.readiness});

  final TrainingReadiness? readiness;

  @override
  Widget build(BuildContext context) {
    final value = readiness;
    if (value == null) {
      return const Text(
        'Checking training dependencies...',
        style: TextStyle(color: Colors.white60),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          value.message,
          style: TextStyle(
            color: value.available
                ? const Color(0xff58c48a)
                : Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        for (final dependency in value.dependencies)
          Text(
            '${dependency.name}: ${dependency.available ? 'available' : 'missing'}',
            style: const TextStyle(color: Colors.white60),
          ),
      ],
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({
    required this.runs,
    required this.datasets,
    required this.models,
    required this.busy,
    required this.onLaunch,
    required this.onPause,
    required this.onStop,
  });

  final List<RunSummary> runs;
  final List<DatasetSummary> datasets;
  final List<ModelSummary> models;
  final bool busy;
  final ValueChanged<String> onLaunch;
  final ValueChanged<String> onPause;
  final ValueChanged<String> onStop;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return const Center(child: Text('No runs configured yet.'));
    }
    return ListView.separated(
      itemCount: runs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final run = runs[index];
        final dataset =
            datasets
                .where((item) => item.id == run.datasetId)
                .firstOrNull
                ?.name ??
            run.datasetId;
        final model =
            models.where((item) => item.id == run.modelId).firstOrNull?.name ??
            run.modelId;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _iconForState(run.state),
                      color: run.isActive
                          ? const Color(0xff58c48a)
                          : Colors.white60,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            run.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '$dataset · $model · ${run.device} · ${run.epochs} epochs',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    Text(run.state),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          busy || run.isActive || run.state == 'completed'
                          ? null
                          : () => onLaunch(run.id),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Launch'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy || run.state != 'running'
                          ? null
                          : () => onPause(run.id),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy || !run.isActive
                          ? null
                          : () => onStop(run.id),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
                if (run.logDir != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Logs: ${run.logDir}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForState(String state) {
    return switch (state) {
      'running' => Icons.play_circle,
      'paused' => Icons.pause_circle,
      'completed' => Icons.check_circle,
      'failed' => Icons.error,
      'interrupted' => Icons.warning_amber,
      _ => Icons.radio_button_unchecked,
    };
  }
}
