import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
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
  TrainingEstimate? _estimate;
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
    for (final controller in [
      _name,
      _epochs,
      _checkpointCadence,
      _validation,
      _seed,
      _warmup,
    ]) {
      controller.addListener(_loadEstimate);
    }
    _loadReadiness();
    _loadEstimate();
  }

  @override
  void didUpdateWidget(TrainingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) {
      _selectDefaults();
      _loadEstimate();
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

  Future<void> _loadEstimate() async {
    final datasetId = _datasetId;
    final modelId = _modelId;
    if (datasetId == null || modelId == null) {
      return;
    }
    try {
      final estimate = await widget.client.trainingEstimate(
        projectId: widget.project.id,
        name: _name.text.trim(),
        datasetId: datasetId,
        modelId: modelId,
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
      if (mounted) {
        setState(() => _estimate = estimate);
      }
    } catch (_) {
      // Estimate is advisory and should not block run setup rendering.
    }
  }

  Future<void> _createRun() async {
    final guard = _estimate?.lowPairGuard;
    if (guard != null && !guard.supported && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Low pair count'),
          content: Text(guard.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Add more data'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }
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

  Future<void> _stop(RunSummary run) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop ${run.name}?'),
        content: Text(
          'Latest known state: ${run.state}. Checkpoints are retained according to this run\'s retention policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop run'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _runAction(
        () =>
            widget.client.stopRun(projectId: widget.project.id, runId: run.id),
      );
    }
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
    final tokens = srTokens(context);
    final compatible = _selectedCompatible(datasets, models);
    final readiness = _readiness;
    final canCreate = !_busy && compatible && (readiness?.available ?? false);
    return Padding(
      padding: EdgeInsets.all(tokens.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_estimate?.lowPairGuard != null)
            SrBanner(
              title: 'Low pair warning',
              message: _estimate!.lowPairGuard!.message,
              severity: 'warning',
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.compactGap),
              child: SrBanner(message: _error!, severity: 'error'),
            ),
          SizedBox(height: tokens.gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      _BasicsSection(
                        name: _name,
                        datasets: datasets,
                        models: models,
                        selectedDataset: _datasetId,
                        selectedModel: _modelId,
                        compatible: compatible,
                        busy: _busy,
                        onDataset: (value) {
                          setState(() => _datasetId = value);
                          _loadEstimate();
                        },
                        onModel: (value) {
                          setState(() => _modelId = value);
                          _loadEstimate();
                        },
                      ),
                      SizedBox(height: tokens.gap),
                      _ScheduleSection(
                        epochs: _epochs,
                        checkpointCadence: _checkpointCadence,
                        validation: _validation,
                        seed: _seed,
                        validationShuffle: _validationShuffle,
                        busy: _busy,
                        onShuffle: (value) {
                          setState(() => _validationShuffle = value);
                          _loadEstimate();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.gap),
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      _OptimizerSection(
                        devices: _devices,
                        device: _device,
                        precision: _precision,
                        scheduler: _scheduler,
                        warmup: _warmup,
                        tensorboard: _tensorboard,
                        compile: _compile,
                        busy: _busy,
                        onDevice: (value) {
                          setState(() => _device = value);
                          _loadEstimate();
                        },
                        onPrecision: (value) {
                          setState(() => _precision = value);
                          _loadEstimate();
                        },
                        onScheduler: (value) {
                          setState(() => _scheduler = value);
                          _loadEstimate();
                        },
                        onTensorboard: (value) {
                          setState(() => _tensorboard = value);
                          _loadReadiness();
                          _loadEstimate();
                        },
                        onCompile: (value) {
                          setState(() => _compile = value);
                          _loadEstimate();
                        },
                      ),
                      SizedBox(height: tokens.gap),
                      _LossSection(
                        diffMode: _diffMode,
                        estimate: _estimate,
                        busy: _busy,
                        onDiffMode: (value) {
                          setState(() => _diffMode = value);
                          _loadEstimate();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.gap),
                Expanded(
                  flex: 4,
                  child: ListView(
                    children: [
                      _EstimateSection(
                        estimate: _estimate,
                        readiness: readiness,
                        canCreate: canCreate,
                        busy: _busy,
                        onCreate: _createRun,
                      ),
                      SizedBox(height: tokens.gap),
                      _RunList(
                        runs: widget.project.runs,
                        datasets: widget.project.datasets,
                        models: widget.project.models,
                        busy: _busy,
                        onLaunch: _launch,
                        onPause: _pause,
                        onStop: _stop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _BasicsSection extends StatelessWidget {
  const _BasicsSection({
    required this.name,
    required this.datasets,
    required this.models,
    required this.selectedDataset,
    required this.selectedModel,
    required this.compatible,
    required this.busy,
    required this.onDataset,
    required this.onModel,
  });

  final TextEditingController name;
  final List<DatasetSummary> datasets;
  final List<ModelSummary> models;
  final String? selectedDataset;
  final String? selectedModel;
  final bool compatible;
  final bool busy;
  final ValueChanged<String?> onDataset;
  final ValueChanged<String?> onModel;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Basics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Run name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedDataset,
            decoration: const InputDecoration(labelText: 'Dataset'),
            items: [
              for (final dataset in datasets)
                DropdownMenuItem(
                  value: dataset.id,
                  child: Text('${dataset.name} · x${dataset.scale}'),
                ),
            ],
            onChanged: busy ? null : onDataset,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final model in models)
                DropdownMenuItem(
                  value: model.id,
                  child: Text('${model.name} · x${model.scale}'),
                ),
            ],
            onChanged: busy ? null : onModel,
          ),
          if (!compatible) ...[
            const SizedBox(height: 8),
            SrBanner(
              message: 'Selected dataset and model scales do not match.',
              severity: 'error',
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.epochs,
    required this.checkpointCadence,
    required this.validation,
    required this.seed,
    required this.validationShuffle,
    required this.busy,
    required this.onShuffle,
  });

  final TextEditingController epochs;
  final TextEditingController checkpointCadence;
  final TextEditingController validation;
  final TextEditingController seed;
  final bool validationShuffle;
  final bool busy;
  final ValueChanged<bool> onShuffle;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Schedule and validation',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _numberField(epochs, 'Epochs')),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(checkpointCadence, 'Checkpoint every'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField(validation, 'Validation split')),
              const SizedBox(width: 8),
              Expanded(child: _numberField(seed, 'Seed')),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shuffle validation split'),
            value: validationShuffle,
            onChanged: busy ? null : onShuffle,
          ),
        ],
      ),
    );
  }
}

class _OptimizerSection extends StatelessWidget {
  const _OptimizerSection({
    required this.devices,
    required this.device,
    required this.precision,
    required this.scheduler,
    required this.warmup,
    required this.tensorboard,
    required this.compile,
    required this.busy,
    required this.onDevice,
    required this.onPrecision,
    required this.onScheduler,
    required this.onTensorboard,
    required this.onCompile,
  });

  final List<DeviceOption> devices;
  final String device;
  final String precision;
  final String scheduler;
  final TextEditingController warmup;
  final bool tensorboard;
  final bool compile;
  final bool busy;
  final ValueChanged<String> onDevice;
  final ValueChanged<String> onPrecision;
  final ValueChanged<String> onScheduler;
  final ValueChanged<bool> onTensorboard;
  final ValueChanged<bool> onCompile;

  @override
  Widget build(BuildContext context) {
    return SrSection(
      title: 'Optimizer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: device,
            decoration: const InputDecoration(labelText: 'Device'),
            items: [
              for (final option in devices)
                DropdownMenuItem(value: option.id, child: Text(option.label)),
            ],
            onChanged: busy ? null : (value) => onDevice(value ?? 'cpu'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'float32', label: Text('FP32')),
              ButtonSegment(value: 'mixed', label: Text('Mixed')),
            ],
            selected: {precision},
            onSelectionChanged: busy
                ? null
                : (value) => onPrecision(value.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: scheduler,
                  decoration: const InputDecoration(labelText: 'Scheduler'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'cosine', child: Text('Cosine')),
                    DropdownMenuItem(value: 'step', child: Text('Step')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => onScheduler(value ?? 'cosine'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _numberField(warmup, 'Warmup')),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('TensorBoard logging'),
            value: tensorboard,
            onChanged: busy ? null : onTensorboard,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compile model'),
            value: compile,
            onChanged: busy ? null : onCompile,
          ),
        ],
      ),
    );
  }
}

class _LossSection extends StatelessWidget {
  const _LossSection({
    required this.diffMode,
    required this.estimate,
    required this.busy,
    required this.onDiffMode,
  });

  final String diffMode;
  final TrainingEstimate? estimate;
  final bool busy;
  final ValueChanged<String> onDiffMode;

  @override
  Widget build(BuildContext context) {
    final unsupported = estimate?.unsupportedLosses ?? const [];
    return SrSection(
      title: 'Loss',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: diffMode,
            decoration: const InputDecoration(labelText: 'Preview diff'),
            items: const [
              DropdownMenuItem(value: 'absolute', child: Text('Absolute')),
              DropdownMenuItem(value: 'heatmap', child: Text('Heatmap')),
              DropdownMenuItem(value: 'both', child: Text('Both')),
            ],
            onChanged: busy ? null : (value) => onDiffMode(value ?? 'absolute'),
          ),
          const SizedBox(height: 12),
          const _LossRow(label: 'L1 pixel loss', supported: true),
          for (final loss in unsupported)
            _LossRow(
              label: loss.actionLabel ?? loss.code,
              supported: false,
              message: loss.message,
            ),
        ],
      ),
    );
  }
}

class _EstimateSection extends StatelessWidget {
  const _EstimateSection({
    required this.estimate,
    required this.readiness,
    required this.canCreate,
    required this.busy,
    required this.onCreate,
  });

  final TrainingEstimate? estimate;
  final TrainingReadiness? readiness;
  final bool canCreate;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final value = estimate;
    return SrSection(
      title: 'Estimate and checkpoints',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SrMetricCard(
                label: 'Time',
                value: value?.estimatedTimeSeconds == null
                    ? '--'
                    : '${(value!.estimatedTimeSeconds! / 60).ceil()} min',
              ),
              SrMetricCard(
                label: 'Iterations/epoch',
                value: value?.iterationsPerEpoch?.toString() ?? '--',
              ),
              SrMetricCard(
                label: 'VRAM peak',
                value: _formatBytes(value?.vramPeakBytes),
              ),
              SrMetricCard(
                label: 'Checkpoint disk',
                value: _formatBytes(value?.diskPerCheckpointBytes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReadinessPanel(readiness: readiness),
          if (value?.ema != null) ...[
            const SizedBox(height: 12),
            SrBanner(message: value!.ema!.message, severity: 'warning'),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SrChip(label: 'Keep best', selected: true),
              SrChip(label: 'Manual protected', severity: 'success'),
              SrChip(
                label: value?.ema?.supported == true
                    ? 'EMA on'
                    : 'EMA unavailable',
                severity: value?.ema?.supported == true ? 'success' : 'warning',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canCreate ? onCreate : null,
            icon: const Icon(Icons.add),
            label: const Text('Create run'),
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const SrProgressBar(kind: SrProgressKind.indeterminate),
          ],
        ],
      ),
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.readiness});

  final TrainingReadiness? readiness;

  @override
  Widget build(BuildContext context) {
    final value = readiness;
    if (value == null) {
      return const Text('Checking training dependencies...');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrBanner(
          message: value.message,
          severity: value.available ? 'success' : 'error',
        ),
        const SizedBox(height: 8),
        for (final dependency in value.dependencies)
          Text(
            '${dependency.name}: ${dependency.available ? 'available' : 'missing'}',
            style: TextStyle(color: srTokens(context).muted),
          ),
      ],
    );
  }
}

class _LossRow extends StatelessWidget {
  const _LossRow({required this.label, required this.supported, this.message});

  final String label;
  final bool supported;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      enabled: supported,
      leading: Icon(
        supported ? Icons.check_circle_outline : Icons.lock_outline,
      ),
      title: Text(label),
      subtitle: message == null ? null : Text(message!),
      trailing: Text(supported ? 'Supported' : 'Unavailable'),
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
  final ValueChanged<RunSummary> onStop;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return const SrSection(
        title: 'All runs',
        child: Text('No runs configured yet.'),
      );
    }
    return SrSection(
      title: 'All runs',
      child: Column(
        children: [
          for (final run in runs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(_iconForState(run.state)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            run.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        SrChip(label: run.state),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_nameFor(datasets, run.datasetId)} · ${_nameFor(models, run.modelId)} · ${run.device} · ${run.epochs} epochs',
                      style: TextStyle(color: srTokens(context).muted),
                    ),
                    const SizedBox(height: 10),
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
                              : () => onStop(run),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.copy),
                          label: const Text('Clone settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: run.state == 'completed' ? () {} : null,
                          icon: const Icon(Icons.replay),
                          label: const Text('Resume training'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _nameFor(List<dynamic> items, String id) {
    for (final item in items) {
      if (item.id == id) {
        return item.name as String;
      }
    }
    return id;
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

Widget _numberField(TextEditingController controller, String label) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
  );
}

String _formatBytes(int? bytes) {
  final value = bytes;
  if (value == null) {
    return '--';
  }
  if (value > 1024 * 1024 * 1024) {
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (value > 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '$value bytes';
}
