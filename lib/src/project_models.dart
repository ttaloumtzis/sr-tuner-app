class ProjectEnvelope {
  ProjectEnvelope({
    required this.project,
    required this.projectId,
    required this.rootPath,
    required this.projectFile,
  });

  final ProjectState project;
  final String projectId;
  final String rootPath;
  final String projectFile;

  factory ProjectEnvelope.fromJson(Map<String, dynamic> json) {
    return ProjectEnvelope(
      project: ProjectState.fromJson(json['project'] as Map<String, dynamic>),
      projectId: json['project_id'] as String,
      rootPath: json['root_path'] as String,
      projectFile: json['project_file'] as String,
    );
  }
}

class ProjectState {
  ProjectState({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.selectedTab,
    required this.datasets,
    required this.models,
    required this.runs,
    required this.datasetCount,
    required this.modelCount,
    required this.runCount,
  });

  final String id;
  final String name;
  final String rootPath;
  final int selectedTab;
  final List<DatasetSummary> datasets;
  final List<ModelSummary> models;
  final List<RunSummary> runs;
  final int datasetCount;
  final int modelCount;
  final int runCount;

  factory ProjectState.fromJson(Map<String, dynamic> json) {
    final workspace =
        json['workspace'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final datasets = [
      for (final item in json['datasets'] as List<dynamic>? ?? const [])
        DatasetSummary.fromJson(item as Map<String, dynamic>),
    ];
    final models = [
      for (final item in json['models'] as List<dynamic>? ?? const [])
        ModelSummary.fromJson(item as Map<String, dynamic>),
    ];
    final runs = [
      for (final item in json['runs'] as List<dynamic>? ?? const [])
        RunSummary.fromJson(item as Map<String, dynamic>),
    ];
    return ProjectState(
      id: json['id'] as String,
      name: json['name'] as String,
      rootPath: json['root_path'] as String? ?? '',
      selectedTab: workspace['selected_tab'] as int? ?? 0,
      datasets: datasets,
      models: models,
      runs: runs,
      datasetCount: datasets.length,
      modelCount: models.length,
      runCount: runs.length,
    );
  }
}

class DatasetSummary {
  DatasetSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.scale,
    required this.storageMode,
    required this.usable,
    required this.pairCount,
    required this.validationMode,
  });

  final String id;
  final String name;
  final String type;
  final int scale;
  final String storageMode;
  final bool usable;
  final int pairCount;
  final String validationMode;

  factory DatasetSummary.fromJson(Map<String, dynamic> json) {
    final validation =
        json['validation'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return DatasetSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'paired',
      scale: json['scale'] as int? ?? 0,
      storageMode: json['storage_mode'] as String? ?? 'external',
      usable: validation['usable'] as bool? ?? false,
      pairCount: validation['pair_count'] as int? ?? 0,
      validationMode: validation['mode'] as String? ?? 'quick',
    );
  }
}

class ModelSummary {
  ModelSummary({
    required this.id,
    required this.name,
    required this.architecture,
    required this.scale,
    required this.numFeatures,
    required this.numBlocks,
    required this.status,
  });

  final String id;
  final String name;
  final String architecture;
  final int scale;
  final int numFeatures;
  final int numBlocks;
  final String status;

  factory ModelSummary.fromJson(Map<String, dynamic> json) {
    return ModelSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      architecture:
          json['architecture'] as String? ?? 'internal_residual_pixelshuffle',
      scale: json['scale'] as int? ?? 4,
      numFeatures: json['num_features'] as int? ?? 32,
      numBlocks: json['num_blocks'] as int? ?? 4,
      status: json['status'] as String? ?? 'untrained',
    );
  }
}

class VideoReadiness {
  VideoReadiness({
    required this.available,
    required this.tool,
    required this.message,
  });

  final bool available;
  final String tool;
  final String message;

  factory VideoReadiness.fromJson(Map<String, dynamic> json) {
    return VideoReadiness(
      available: json['available'] as bool? ?? false,
      tool: json['tool'] as String? ?? 'ffmpeg',
      message: json['message'] as String? ?? '',
    );
  }
}

class DatasetStorageEstimate {
  DatasetStorageEstimate({
    required this.fileCount,
    required this.totalBytes,
    required this.destination,
    required this.destinationExists,
  });

  final int fileCount;
  final int totalBytes;
  final String destination;
  final bool destinationExists;

  factory DatasetStorageEstimate.fromJson(Map<String, dynamic> json) {
    return DatasetStorageEstimate(
      fileCount: json['file_count'] as int? ?? 0,
      totalBytes: json['total_bytes'] as int? ?? 0,
      destination: json['destination'] as String? ?? '',
      destinationExists: json['destination_exists'] as bool? ?? false,
    );
  }
}

class JobState {
  JobState({
    required this.id,
    required this.type,
    required this.status,
    required this.progress,
    required this.logs,
  });

  final String id;
  final String type;
  final String status;
  final double progress;
  final List<String> logs;

  bool get isTerminal =>
      const {'completed', 'failed', 'canceled'}.contains(status);

  factory JobState.fromJson(Map<String, dynamic> json) {
    return JobState(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      logs: [
        for (final line in json['logs'] as List<dynamic>? ?? const [])
          line.toString(),
      ],
    );
  }
}

class RunSummary {
  RunSummary({
    required this.id,
    required this.name,
    required this.datasetId,
    required this.modelId,
    required this.state,
    required this.trainMode,
    required this.device,
    required this.epochs,
    required this.checkpointCadence,
    required this.logDir,
  });

  final String id;
  final String name;
  final String datasetId;
  final String modelId;
  final String state;
  final String trainMode;
  final String device;
  final int epochs;
  final int checkpointCadence;
  final String? logDir;

  bool get isActive => const {
    'running',
    'pausing',
    'paused',
    'resuming',
    'stopping',
  }.contains(state);

  factory RunSummary.fromJson(Map<String, dynamic> json) {
    final settings =
        json['settings'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return RunSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'run',
      datasetId: json['dataset_id'] as String? ?? '',
      modelId: json['model_id'] as String? ?? '',
      state: json['state'] as String? ?? 'configured',
      trainMode: json['train_mode'] as String? ?? 'new',
      device: settings['device'] as String? ?? 'cpu',
      epochs: settings['epochs'] as int? ?? 10,
      checkpointCadence: settings['checkpoint_cadence'] as int? ?? 1,
      logDir: json['log_dir'] as String?,
    );
  }
}

class TrainingReadiness {
  TrainingReadiness({
    required this.available,
    required this.message,
    required this.dependencies,
  });

  final bool available;
  final String message;
  final List<DependencySummary> dependencies;

  factory TrainingReadiness.fromJson(Map<String, dynamic> json) {
    return TrainingReadiness(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      dependencies: [
        for (final item in json['dependencies'] as List<dynamic>? ?? const [])
          DependencySummary.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class DependencySummary {
  DependencySummary({
    required this.name,
    required this.available,
    required this.required,
    required this.message,
  });

  final String name;
  final bool available;
  final bool required;
  final String message;

  factory DependencySummary.fromJson(Map<String, dynamic> json) {
    return DependencySummary(
      name: json['name'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      required: json['required'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class DeviceOption {
  DeviceOption({
    required this.id,
    required this.label,
    required this.type,
    required this.available,
  });

  final String id;
  final String label;
  final String type;
  final bool available;

  factory DeviceOption.fromJson(Map<String, dynamic> json) {
    return DeviceOption(
      id: json['id'] as String? ?? 'cpu',
      label: json['label'] as String? ?? 'CPU',
      type: json['type'] as String? ?? 'cpu',
      available: json['available'] as bool? ?? true,
    );
  }
}

class ActiveRunStatus {
  ActiveRunStatus({
    required this.run,
    required this.datasetName,
    required this.modelName,
    required this.epoch,
    required this.iteration,
    required this.progress,
    required this.latestMetrics,
  });

  final RunSummary? run;
  final String? datasetName;
  final String? modelName;
  final int epoch;
  final int iteration;
  final double progress;
  final Map<String, double> latestMetrics;

  factory ActiveRunStatus.fromJson(Map<String, dynamic> json) {
    final dataset = json['dataset'] as Map<String, dynamic>?;
    final model = json['model'] as Map<String, dynamic>?;
    final metrics = json['latest_metrics'] as Map<String, dynamic>? ?? {};
    return ActiveRunStatus(
      run: json['run'] == null
          ? null
          : RunSummary.fromJson(json['run'] as Map<String, dynamic>),
      datasetName: dataset?['name'] as String?,
      modelName: model?['name'] as String?,
      epoch: json['epoch'] as int? ?? 0,
      iteration: json['iteration'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      latestMetrics: {
        for (final entry in metrics.entries)
          entry.key: (entry.value as num?)?.toDouble() ?? 0,
      },
    );
  }
}

class MetricsEnvelope {
  MetricsEnvelope({
    required this.runId,
    required this.definitions,
    required this.records,
  });

  final String runId;
  final Map<String, MetricDefinition> definitions;
  final List<MetricRecord> records;

  factory MetricsEnvelope.fromJson(Map<String, dynamic> json) {
    final rawDefinitions =
        json['definitions'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return MetricsEnvelope(
      runId: json['run_id'] as String? ?? '',
      definitions: {
        for (final entry in rawDefinitions.entries)
          entry.key: MetricDefinition.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      records: [
        for (final item in json['records'] as List<dynamic>? ?? const [])
          MetricRecord.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class MetricDefinition {
  MetricDefinition({
    required this.name,
    required this.label,
    required this.kind,
    required this.unit,
  });

  final String name;
  final String label;
  final String kind;
  final String? unit;

  factory MetricDefinition.fromJson(Map<String, dynamic> json) {
    return MetricDefinition(
      name: json['name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      unit: json['unit'] as String?,
    );
  }
}

class MetricRecord {
  MetricRecord({
    required this.step,
    required this.epoch,
    required this.iteration,
    required this.values,
  });

  final int step;
  final int epoch;
  final int iteration;
  final Map<String, double> values;

  factory MetricRecord.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'] as Map<String, dynamic>? ?? {};
    return MetricRecord(
      step: json['step'] as int? ?? 0,
      epoch: json['epoch'] as int? ?? 0,
      iteration: json['iteration'] as int? ?? 0,
      values: {
        for (final entry in rawValues.entries)
          entry.key: (entry.value as num?)?.toDouble() ?? 0,
      },
    );
  }
}

class HardwareTelemetry {
  HardwareTelemetry({
    required this.device,
    required this.deviceType,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.utilization,
    required this.temperature,
    required this.iterationSpeed,
  });

  final String device;
  final String deviceType;
  final TelemetryField memoryUsed;
  final TelemetryField memoryTotal;
  final TelemetryField utilization;
  final TelemetryField temperature;
  final TelemetryField iterationSpeed;

  factory HardwareTelemetry.fromJson(Map<String, dynamic> json) {
    return HardwareTelemetry(
      device: json['device'] as String? ?? 'cpu',
      deviceType: json['device_type'] as String? ?? 'cpu',
      memoryUsed: TelemetryField.fromJson(
        json['memory_used'] as Map<String, dynamic>? ?? const {},
      ),
      memoryTotal: TelemetryField.fromJson(
        json['memory_total'] as Map<String, dynamic>? ?? const {},
      ),
      utilization: TelemetryField.fromJson(
        json['utilization'] as Map<String, dynamic>? ?? const {},
      ),
      temperature: TelemetryField.fromJson(
        json['temperature'] as Map<String, dynamic>? ?? const {},
      ),
      iterationSpeed: TelemetryField.fromJson(
        json['iteration_speed'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class TelemetryField {
  TelemetryField({
    required this.available,
    required this.value,
    required this.unit,
    required this.reason,
  });

  final bool available;
  final Object? value;
  final String? unit;
  final String? reason;

  factory TelemetryField.fromJson(Map<String, dynamic> json) {
    return TelemetryField(
      available: json['available'] == 'available',
      value: json['value'],
      unit: json['unit'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class PreviewEnvelope {
  PreviewEnvelope({
    required this.runId,
    required this.generatedAt,
    required this.diffMode,
    required this.assets,
  });

  final String runId;
  final String? generatedAt;
  final String diffMode;
  final List<PreviewAsset> assets;

  factory PreviewEnvelope.fromJson(Map<String, dynamic> json) {
    return PreviewEnvelope(
      runId: json['run_id'] as String? ?? '',
      generatedAt: json['generated_at'] as String?,
      diffMode: json['diff_mode'] as String? ?? 'absolute',
      assets: [
        for (final item in json['assets'] as List<dynamic>? ?? const [])
          PreviewAsset.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class PreviewAsset {
  PreviewAsset({
    required this.kind,
    required this.url,
    required this.width,
    required this.height,
  });

  final String kind;
  final String url;
  final int width;
  final int height;

  factory PreviewAsset.fromJson(Map<String, dynamic> json) {
    return PreviewAsset(
      kind: json['kind'] as String? ?? '',
      url: json['url'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }
}

class CheckpointSummary {
  CheckpointSummary({
    required this.id,
    required this.runId,
    required this.epoch,
    required this.iteration,
    required this.path,
    required this.sizeBytes,
    required this.savedAt,
    required this.metrics,
    required this.tags,
    required this.deleted,
    required this.modelArchitecture,
    required this.scale,
  });

  final String id;
  final String runId;
  final int epoch;
  final int iteration;
  final String path;
  final int sizeBytes;
  final String savedAt;
  final Map<String, double> metrics;
  final List<String> tags;
  final bool deleted;
  final String modelArchitecture;
  final int scale;

  bool get isLatest => tags.contains('latest');
  bool get isBestPsnr => tags.contains('best_psnr');
  bool get isBestLoss => tags.contains('best_loss');

  factory CheckpointSummary.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] as Map<String, dynamic>? ?? {};
    return CheckpointSummary(
      id: json['id'] as String? ?? '',
      runId: json['run_id'] as String? ?? '',
      epoch: json['epoch'] as int? ?? 0,
      iteration: json['iteration'] as int? ?? 0,
      path: json['path'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      savedAt: json['saved_at'] as String? ?? '',
      metrics: {
        for (final e in rawMetrics.entries)
          e.key: (e.value as num?)?.toDouble() ?? 0,
      },
      tags: [
        for (final t in json['tags'] as List<dynamic>? ?? const [])
          t.toString(),
      ],
      deleted: json['deleted'] as bool? ?? false,
      modelArchitecture: json['model_architecture'] as String? ?? '',
      scale: json['scale'] as int? ?? 0,
    );
  }
}

class CheckpointListEnvelope {
  CheckpointListEnvelope({
    required this.runId,
    required this.checkpoints,
  });

  final String runId;
  final List<CheckpointSummary> checkpoints;

  factory CheckpointListEnvelope.fromJson(Map<String, dynamic> json) {
    return CheckpointListEnvelope(
      runId: json['run_id'] as String? ?? '',
      checkpoints: [
        for (final item in json['checkpoints'] as List<dynamic>? ?? const [])
          CheckpointSummary.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class OnnxReadiness {
  OnnxReadiness({required this.available, required this.message});

  final bool available;
  final String message;

  factory OnnxReadiness.fromJson(Map<String, dynamic> json) {
    return OnnxReadiness(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class InferenceReadiness {
  InferenceReadiness({
    required this.available,
    required this.message,
    required this.dependencies,
  });

  final bool available;
  final String message;
  final List<DependencySummary> dependencies;

  factory InferenceReadiness.fromJson(Map<String, dynamic> json) {
    return InferenceReadiness(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      dependencies: [
        for (final item in json['dependencies'] as List<dynamic>? ?? const [])
          DependencySummary.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class TileConfig {
  TileConfig({
    this.enabled = false,
    this.tileSize = 512,
    this.overlap = 32,
    this.paddingMode = 'reflect',
    this.blendStrategy = 'average',
  });

  final bool enabled;
  final int tileSize;
  final int overlap;
  final String paddingMode;
  final String blendStrategy;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'tile_size': tileSize,
    'overlap': overlap,
    'padding_mode': paddingMode,
    'blend_strategy': blendStrategy,
  };
}

class PerFileResult {
  PerFileResult({
    required this.filename,
    required this.status,
    this.outputPath,
    this.error,
  });

  final String filename;
  final String status;
  final String? outputPath;
  final String? error;

  factory PerFileResult.fromJson(Map<String, dynamic> json) {
    return PerFileResult(
      filename: json['filename'] as String? ?? '',
      status: json['status'] as String? ?? 'failed',
      outputPath: json['output_path'] as String?,
      error: json['error'] as String?,
    );
  }
}

class InferenceRecord {
  InferenceRecord({
    required this.id,
    required this.checkpointId,
    required this.runId,
    required this.scale,
    required this.mode,
    required this.inputPath,
    required this.device,
    required this.runtimeSeconds,
    required this.status,
    required this.createdAt,
    required this.perFileResults,
    this.outputPath,
    this.outputDir,
  });

  final String id;
  final String checkpointId;
  final String runId;
  final int scale;
  final String mode;
  final String inputPath;
  final String? outputPath;
  final String? outputDir;
  final String device;
  final double runtimeSeconds;
  final String status;
  final String createdAt;
  final List<PerFileResult> perFileResults;

  factory InferenceRecord.fromJson(Map<String, dynamic> json) {
    return InferenceRecord(
      id: json['id'] as String? ?? '',
      checkpointId: json['checkpoint_id'] as String? ?? '',
      runId: json['run_id'] as String? ?? '',
      scale: json['scale'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'single',
      inputPath: json['input_path'] as String? ?? '',
      outputPath: json['output_path'] as String?,
      outputDir: json['output_dir'] as String?,
      device: json['device'] as String? ?? 'cpu',
      runtimeSeconds: (json['runtime_seconds'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] as String? ?? '',
      perFileResults: [
        for (final item in json['per_file_results'] as List<dynamic>? ?? const [])
          PerFileResult.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class InferenceHistoryEnvelope {
  InferenceHistoryEnvelope({required this.records});

  final List<InferenceRecord> records;

  factory InferenceHistoryEnvelope.fromJson(Map<String, dynamic> json) {
    return InferenceHistoryEnvelope(
      records: [
        for (final item in json['records'] as List<dynamic>? ?? const [])
          InferenceRecord.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
