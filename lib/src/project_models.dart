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
    required this.workspacePreferences,
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
  final WorkspacePreferences workspacePreferences;

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
      workspacePreferences: WorkspacePreferences.fromJson(workspace),
    );
  }
}

class WorkspacePreferences {
  WorkspacePreferences({
    required this.selectedTab,
    required this.theme,
    required this.density,
    required this.perProjectUiState,
  });

  final int selectedTab;
  final String theme;
  final String density;
  final Map<String, dynamic> perProjectUiState;

  factory WorkspacePreferences.fromJson(Map<String, dynamic> json) {
    return WorkspacePreferences(
      selectedTab: json['selected_tab'] as int? ?? 0,
      theme: json['theme'] as String? ?? 'system',
      density: json['density'] as String? ?? 'comfortable',
      perProjectUiState:
          json['per_project_ui_state'] as Map<String, dynamic>? ?? const {},
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
    required this.batchSize,
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
  final int batchSize;
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
      batchSize: settings['batch_size'] as int? ?? 16,
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
  CheckpointListEnvelope({required this.runId, required this.checkpoints});

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
        for (final item
            in json['per_file_results'] as List<dynamic>? ?? const [])
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

class UnsupportedState {
  UnsupportedState({
    required this.supported,
    required this.reason,
    required this.code,
    required this.message,
    this.actionLabel,
  });

  final bool supported;
  final String reason;
  final String code;
  final String message;
  final String? actionLabel;

  factory UnsupportedState.fromJson(Map<String, dynamic> json) {
    return UnsupportedState(
      supported: json['supported'] as bool? ?? false,
      reason: json['reason'] as String? ?? 'unsupported',
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      actionLabel: json['action_label'] as String?,
    );
  }
}

class ActionState {
  ActionState({
    required this.id,
    required this.label,
    required this.supported,
    this.reason,
  });

  final String id;
  final String label;
  final bool supported;
  final String? reason;

  factory ActionState.fromJson(Map<String, dynamic> json) {
    return ActionState(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class RecentProjectsEnvelope {
  RecentProjectsEnvelope({required this.projects});

  final List<RecentProject> projects;

  factory RecentProjectsEnvelope.fromJson(Map<String, dynamic> json) {
    return RecentProjectsEnvelope(
      projects: [
        for (final item in json['projects'] as List<dynamic>? ?? const [])
          RecentProject.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class RecentProject {
  RecentProject({
    required this.name,
    required this.path,
    required this.status,
    required this.statusMessage,
    required this.summary,
    this.lastOpenedAt,
  });

  final String name;
  final String path;
  final String status;
  final String statusMessage;
  final RecentProjectSummary summary;
  final String? lastOpenedAt;

  factory RecentProject.fromJson(Map<String, dynamic> json) {
    return RecentProject(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      lastOpenedAt: json['last_opened_at'] as String?,
      status: json['status'] as String? ?? 'missing',
      statusMessage: json['status_message'] as String? ?? '',
      summary: RecentProjectSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class RecentProjectSummary {
  RecentProjectSummary({
    required this.datasetCount,
    required this.modelCount,
    required this.runCount,
    required this.checkpointCount,
  });

  final int datasetCount;
  final int modelCount;
  final int runCount;
  final int checkpointCount;

  factory RecentProjectSummary.fromJson(Map<String, dynamic> json) {
    return RecentProjectSummary(
      datasetCount: json['dataset_count'] as int? ?? 0,
      modelCount: json['model_count'] as int? ?? 0,
      runCount: json['run_count'] as int? ?? 0,
      checkpointCount: json['checkpoint_count'] as int? ?? 0,
    );
  }
}

class ActivityEvent {
  ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.description,
    this.objectId,
  });

  final String id;
  final String timestamp;
  final String category;
  final String severity;
  final String description;
  final String? objectId;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      category: json['category'] as String? ?? 'project',
      severity: json['severity'] as String? ?? 'info',
      description: json['description'] as String? ?? '',
      objectId: json['object_id'] as String?,
    );
  }
}

class ActivityFeedEnvelope {
  ActivityFeedEnvelope({required this.events});

  final List<ActivityEvent> events;

  factory ActivityFeedEnvelope.fromJson(Map<String, dynamic> json) {
    return ActivityFeedEnvelope(
      events: [
        for (final item in json['events'] as List<dynamic>? ?? const [])
          ActivityEvent.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class StatusBarData {
  StatusBarData({
    required this.appVersion,
    required this.projectPath,
    required this.vcsAvailable,
    required this.backendState,
    required this.diskWarning,
    required this.busyState,
    this.vcsBranch,
    this.diskFreeBytes,
  });

  final String appVersion;
  final String projectPath;
  final String? vcsBranch;
  final bool vcsAvailable;
  final String backendState;
  final int? diskFreeBytes;
  final bool diskWarning;
  final String busyState;

  factory StatusBarData.fromJson(Map<String, dynamic> json) {
    return StatusBarData(
      appVersion: json['app_version'] as String? ?? '',
      projectPath: json['project_path'] as String? ?? '',
      vcsBranch: json['vcs_branch'] as String?,
      vcsAvailable: json['vcs_available'] as bool? ?? false,
      backendState: json['backend_state'] as String? ?? 'ok',
      diskFreeBytes: json['disk_free_bytes'] as int?,
      diskWarning: json['disk_warning'] as bool? ?? false,
      busyState: json['busy_state'] as String? ?? 'idle',
    );
  }
}

class NextStepGuidance {
  NextStepGuidance({
    required this.state,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.targetTab,
    required this.severity,
  });

  final String state;
  final String title;
  final String description;
  final String actionLabel;
  final int targetTab;
  final String severity;

  factory NextStepGuidance.fromJson(Map<String, dynamic> json) {
    return NextStepGuidance(
      state: json['state'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      targetTab: json['target_tab'] as int? ?? 0,
      severity: json['severity'] as String? ?? 'info',
    );
  }
}

class DashboardSummary {
  DashboardSummary({
    required this.datasetCount,
    required this.modelCount,
    required this.runCount,
    required this.datasetPairTotal,
    required this.backendStatus,
    required this.deviceBadge,
    required this.appVersion,
    required this.projectPath,
    required this.diskWarning,
    required this.busyState,
    required this.statusBar,
    required this.nextStep,
    this.activeModel,
    this.bestPsnr,
    this.activeRunState,
    this.diskFreeBytes,
    this.vcsBranch,
  });

  final int datasetCount;
  final int modelCount;
  final int runCount;
  final int datasetPairTotal;
  final String? activeModel;
  final double? bestPsnr;
  final String? activeRunState;
  final String backendStatus;
  final String deviceBadge;
  final String appVersion;
  final String projectPath;
  final int? diskFreeBytes;
  final bool diskWarning;
  final String busyState;
  final String? vcsBranch;
  final StatusBarData statusBar;
  final NextStepGuidance nextStep;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      datasetCount: json['dataset_count'] as int? ?? 0,
      modelCount: json['model_count'] as int? ?? 0,
      runCount: json['run_count'] as int? ?? 0,
      datasetPairTotal: json['dataset_pair_total'] as int? ?? 0,
      activeModel: json['active_model'] as String?,
      bestPsnr: (json['best_psnr'] as num?)?.toDouble(),
      activeRunState: json['active_run_state'] as String?,
      backendStatus: json['backend_status'] as String? ?? 'ok',
      deviceBadge: json['device_badge'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      projectPath: json['project_path'] as String? ?? '',
      diskFreeBytes: json['disk_free_bytes'] as int?,
      diskWarning: json['disk_warning'] as bool? ?? false,
      busyState: json['busy_state'] as String? ?? 'idle',
      vcsBranch: json['vcs_branch'] as String?,
      statusBar: StatusBarData.fromJson(
        json['status_bar'] as Map<String, dynamic>? ?? const {},
      ),
      nextStep: NextStepGuidance.fromJson(
        json['next_step'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class DatasetDetail {
  DatasetDetail({
    required this.dataset,
    required this.sources,
    required this.healthChecks,
    required this.degradationPipeline,
    required this.preview,
    required this.histogram,
    required this.rescanAction,
    required this.exportAction,
    this.resynthesis,
  });

  final DatasetSummary dataset;
  final List<DatasetSourceRow> sources;
  final List<HealthCheckRow> healthChecks;
  final List<String> degradationPipeline;
  final DatasetPreviewPair preview;
  final HistogramSummary histogram;
  final ActionState rescanAction;
  final ActionState exportAction;
  final UnsupportedState? resynthesis;

  factory DatasetDetail.fromJson(Map<String, dynamic> json) {
    return DatasetDetail(
      dataset: DatasetSummary.fromJson(json['dataset'] as Map<String, dynamic>),
      sources: [
        for (final item in json['sources'] as List<dynamic>? ?? const [])
          DatasetSourceRow.fromJson(item as Map<String, dynamic>),
      ],
      healthChecks: [
        for (final item in json['health_checks'] as List<dynamic>? ?? const [])
          HealthCheckRow.fromJson(item as Map<String, dynamic>),
      ],
      degradationPipeline: [
        for (final item
            in json['degradation_pipeline'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      preview: DatasetPreviewPair.fromJson(
        json['preview'] as Map<String, dynamic>? ?? const {},
      ),
      histogram: HistogramSummary.fromJson(
        json['histogram'] as Map<String, dynamic>? ?? const {},
      ),
      rescanAction: ActionState.fromJson(
        json['rescan_action'] as Map<String, dynamic>? ?? const {},
      ),
      exportAction: ActionState.fromJson(
        json['export_action'] as Map<String, dynamic>? ?? const {},
      ),
      resynthesis: json['resynthesis'] == null
          ? null
          : UnsupportedState.fromJson(
              json['resynthesis'] as Map<String, dynamic>,
            ),
    );
  }
}

class DatasetSourceRow {
  DatasetSourceRow({
    required this.id,
    required this.sourceType,
    required this.name,
    required this.pairCount,
    required this.status,
    required this.severity,
    required this.actions,
    this.note,
  });

  final String id;
  final String sourceType;
  final String name;
  final int pairCount;
  final String status;
  final String severity;
  final String? note;
  final List<ActionState> actions;

  factory DatasetSourceRow.fromJson(Map<String, dynamic> json) {
    return DatasetSourceRow(
      id: json['id'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pairCount: json['pair_count'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      note: json['note'] as String?,
      actions: [
        for (final item in json['actions'] as List<dynamic>? ?? const [])
          ActionState.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class HealthCheckRow {
  HealthCheckRow({
    required this.id,
    required this.label,
    required this.severity,
    required this.message,
  });

  final String id;
  final String label;
  final String severity;
  final String message;

  factory HealthCheckRow.fromJson(Map<String, dynamic> json) {
    return HealthCheckRow(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      message: json['message'] as String? ?? '',
    );
  }
}

class DatasetPreviewPair {
  DatasetPreviewPair({
    required this.index,
    required this.total,
    this.lrPath,
    this.hrPath,
    this.unavailable,
  });

  final int index;
  final int total;
  final String? lrPath;
  final String? hrPath;
  final UnsupportedState? unavailable;

  factory DatasetPreviewPair.fromJson(Map<String, dynamic> json) {
    return DatasetPreviewPair(
      index: json['index'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      lrPath: json['lr_path'] as String?,
      hrPath: json['hr_path'] as String?,
      unavailable: json['unavailable'] == null
          ? null
          : UnsupportedState.fromJson(
              json['unavailable'] as Map<String, dynamic>,
            ),
    );
  }
}

class HistogramSummary {
  HistogramSummary({
    required this.available,
    required this.channels,
    required this.bins,
    this.selectedChannel,
    this.unavailable,
  });

  final bool available;
  final List<String> channels;
  final String? selectedChannel;
  final List<int> bins;
  final UnsupportedState? unavailable;

  factory HistogramSummary.fromJson(Map<String, dynamic> json) {
    return HistogramSummary(
      available: json['available'] as bool? ?? false,
      channels: [
        for (final item in json['channels'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      selectedChannel: json['selected_channel'] as String?,
      bins: [
        for (final item in json['bins'] as List<dynamic>? ?? const [])
          item as int,
      ],
      unavailable: json['unavailable'] == null
          ? null
          : UnsupportedState.fromJson(
              json['unavailable'] as Map<String, dynamic>,
            ),
    );
  }
}

class VideoWizardMetadata {
  VideoWizardMetadata({
    required this.sourcePath,
    required this.exists,
    required this.samplingStrategy,
    required this.deduplicationGuidance,
    this.estimatedYield,
    this.outputSizeBytes,
    this.readiness,
  });

  final String sourcePath;
  final bool exists;
  final String samplingStrategy;
  final int? estimatedYield;
  final int? outputSizeBytes;
  final String deduplicationGuidance;
  final UnsupportedState? readiness;

  factory VideoWizardMetadata.fromJson(Map<String, dynamic> json) {
    return VideoWizardMetadata(
      sourcePath: json['source_path'] as String? ?? '',
      exists: json['exists'] as bool? ?? false,
      samplingStrategy: json['sampling_strategy'] as String? ?? '',
      estimatedYield: json['estimated_yield'] as int?,
      outputSizeBytes: json['output_size_bytes'] as int?,
      deduplicationGuidance: json['deduplication_guidance'] as String? ?? '',
      readiness: json['readiness'] == null
          ? null
          : UnsupportedState.fromJson(
              json['readiness'] as Map<String, dynamic>,
            ),
    );
  }
}

class ModelTemplateCatalog {
  ModelTemplateCatalog({required this.templates, required this.filters});

  final List<ModelTemplate> templates;
  final Map<String, List<String>> filters;

  factory ModelTemplateCatalog.fromJson(Map<String, dynamic> json) {
    final rawFilters =
        json['filters'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ModelTemplateCatalog(
      templates: [
        for (final item in json['templates'] as List<dynamic>? ?? const [])
          ModelTemplate.fromJson(item as Map<String, dynamic>),
      ],
      filters: {
        for (final entry in rawFilters.entries)
          entry.key: [
            for (final value in entry.value as List<dynamic>? ?? const [])
              value.toString(),
          ],
      },
    );
  }
}

class ModelTemplate {
  ModelTemplate({
    required this.id,
    required this.displayName,
    required this.architectureSummary,
    required this.bestFor,
    required this.speedLabel,
    required this.supportedScales,
    required this.vramEstimate,
    required this.inputCrop,
    required this.supportState,
    required this.architectureSteps,
    required this.hyperparameters,
    required this.defaults,
    required this.importAction,
    required this.resetAction,
    required this.saveAsModelAction,
    this.parameterCount,
    this.unavailable,
  });

  final String id;
  final String displayName;
  final String architectureSummary;
  final String bestFor;
  final String speedLabel;
  final List<int> supportedScales;
  final int? parameterCount;
  final String vramEstimate;
  final int inputCrop;
  final String supportState;
  final UnsupportedState? unavailable;
  final List<String> architectureSteps;
  final Map<String, dynamic> hyperparameters;
  final Map<String, dynamic> defaults;
  final ActionState importAction;
  final ActionState resetAction;
  final ActionState saveAsModelAction;

  factory ModelTemplate.fromJson(Map<String, dynamic> json) {
    return ModelTemplate(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      architectureSummary: json['architecture_summary'] as String? ?? '',
      bestFor: json['best_for'] as String? ?? '',
      speedLabel: json['speed_label'] as String? ?? '',
      supportedScales: [
        for (final item
            in json['supported_scales'] as List<dynamic>? ?? const [])
          item as int,
      ],
      parameterCount: json['parameter_count'] as int?,
      vramEstimate: json['vram_estimate'] as String? ?? '',
      inputCrop: json['input_crop'] as int? ?? 0,
      supportState: json['support_state'] as String? ?? 'unsupported',
      unavailable: json['unavailable'] == null
          ? null
          : UnsupportedState.fromJson(
              json['unavailable'] as Map<String, dynamic>,
            ),
      architectureSteps: [
        for (final item
            in json['architecture_steps'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      hyperparameters:
          json['hyperparameters'] as Map<String, dynamic>? ?? const {},
      defaults: json['defaults'] as Map<String, dynamic>? ?? const {},
      importAction: ActionState.fromJson(
        json['import_action'] as Map<String, dynamic>? ?? const {},
      ),
      resetAction: ActionState.fromJson(
        json['reset_action'] as Map<String, dynamic>? ?? const {},
      ),
      saveAsModelAction: ActionState.fromJson(
        json['save_as_model_action'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class TrainingEstimate {
  TrainingEstimate({
    required this.available,
    required this.unsupportedLosses,
    required this.suggestedFixes,
    required this.retention,
    this.estimatedTimeSeconds,
    this.iterationsPerEpoch,
    this.vramPeakBytes,
    this.diskPerCheckpointBytes,
    this.lowPairGuard,
    this.ema,
  });

  final bool available;
  final int? estimatedTimeSeconds;
  final int? iterationsPerEpoch;
  final int? vramPeakBytes;
  final int? diskPerCheckpointBytes;
  final UnsupportedState? lowPairGuard;
  final List<UnsupportedState> unsupportedLosses;
  final List<ActionState> suggestedFixes;
  final Map<String, dynamic> retention;
  final UnsupportedState? ema;

  factory TrainingEstimate.fromJson(Map<String, dynamic> json) {
    return TrainingEstimate(
      available: json['available'] as bool? ?? false,
      estimatedTimeSeconds: json['estimated_time_seconds'] as int?,
      iterationsPerEpoch: json['iterations_per_epoch'] as int?,
      vramPeakBytes: json['vram_peak_bytes'] as int?,
      diskPerCheckpointBytes: json['disk_per_checkpoint_bytes'] as int?,
      lowPairGuard: json['low_pair_guard'] == null
          ? null
          : UnsupportedState.fromJson(
              json['low_pair_guard'] as Map<String, dynamic>,
            ),
      unsupportedLosses: [
        for (final item
            in json['unsupported_losses'] as List<dynamic>? ?? const [])
          UnsupportedState.fromJson(item as Map<String, dynamic>),
      ],
      suggestedFixes: [
        for (final item
            in json['suggested_fixes'] as List<dynamic>? ?? const [])
          ActionState.fromJson(item as Map<String, dynamic>),
      ],
      retention: json['retention'] as Map<String, dynamic>? ?? const {},
      ema: json['ema'] == null
          ? null
          : UnsupportedState.fromJson(json['ema'] as Map<String, dynamic>),
    );
  }
}

class LiveRunDetail {
  LiveRunDetail({
    required this.active,
    required this.epochProgress,
    required this.runProgress,
    required this.recentEvents,
    required this.logTail,
    required this.openLog,
    required this.validationSamples,
    this.run,
    this.etaSeconds,
    this.crashSnapshot,
    this.oomError,
  });

  final bool active;
  final RunSummary? run;
  final double epochProgress;
  final double runProgress;
  final int? etaSeconds;
  final List<ActivityEvent> recentEvents;
  final List<String> logTail;
  final ActionState openLog;
  final List<Map<String, dynamic>> validationSamples;
  final UnsupportedState? crashSnapshot;
  final Map<String, dynamic>? oomError;

  factory LiveRunDetail.fromJson(Map<String, dynamic> json) {
    return LiveRunDetail(
      active: json['active'] as bool? ?? false,
      run: json['run'] == null
          ? null
          : RunSummary.fromJson(json['run'] as Map<String, dynamic>),
      epochProgress: (json['epoch_progress'] as num?)?.toDouble() ?? 0,
      runProgress: (json['run_progress'] as num?)?.toDouble() ?? 0,
      etaSeconds: json['eta_seconds'] as int?,
      recentEvents: [
        for (final item in json['recent_events'] as List<dynamic>? ?? const [])
          ActivityEvent.fromJson(item as Map<String, dynamic>),
      ],
      logTail: [
        for (final item in json['log_tail'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      openLog: ActionState.fromJson(
        json['open_log'] as Map<String, dynamic>? ?? const {},
      ),
      validationSamples: [
        for (final item
            in json['validation_samples'] as List<dynamic>? ?? const [])
          item as Map<String, dynamic>,
      ],
      crashSnapshot: json['crash_snapshot'] == null
          ? null
          : UnsupportedState.fromJson(
              json['crash_snapshot'] as Map<String, dynamic>,
            ),
      oomError: json['oom_error'] as Map<String, dynamic>?,
    );
  }
}

class SnapshotResponse {
  SnapshotResponse({this.checkpoint, this.unavailable});

  final CheckpointSummary? checkpoint;
  final UnsupportedState? unavailable;

  factory SnapshotResponse.fromJson(Map<String, dynamic> json) {
    return SnapshotResponse(
      checkpoint: json['checkpoint'] == null
          ? null
          : CheckpointSummary.fromJson(
              json['checkpoint'] as Map<String, dynamic>,
            ),
      unavailable: json['unavailable'] == null
          ? null
          : UnsupportedState.fromJson(
              json['unavailable'] as Map<String, dynamic>,
            ),
    );
  }
}

class CheckpointAggregate {
  CheckpointAggregate({
    required this.checkpoints,
    required this.actions,
    this.bestCheckpoint,
    this.psnrDelta,
  });

  final List<CheckpointSummary> checkpoints;
  final CheckpointSummary? bestCheckpoint;
  final double? psnrDelta;
  final Map<String, ActionState> actions;

  factory CheckpointAggregate.fromJson(Map<String, dynamic> json) {
    final rawActions =
        json['actions'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return CheckpointAggregate(
      checkpoints: [
        for (final item in json['checkpoints'] as List<dynamic>? ?? const [])
          CheckpointSummary.fromJson(item as Map<String, dynamic>),
      ],
      bestCheckpoint: json['best_checkpoint'] == null
          ? null
          : CheckpointSummary.fromJson(
              json['best_checkpoint'] as Map<String, dynamic>,
            ),
      psnrDelta: (json['psnr_delta'] as num?)?.toDouble(),
      actions: {
        for (final entry in rawActions.entries)
          entry.key: ActionState.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }
}

class InferenceInspector {
  InferenceInspector({
    required this.blockedChecklist,
    required this.inspector,
    required this.recent,
    required this.addTileAction,
    required this.batchDropZone,
    required this.tuning,
    required this.compareView,
  });

  final List<ActionState> blockedChecklist;
  final Map<String, dynamic> inspector;
  final List<InferenceRecord> recent;
  final ActionState addTileAction;
  final ActionState batchDropZone;
  final Map<String, UnsupportedState> tuning;
  final Map<String, dynamic> compareView;

  factory InferenceInspector.fromJson(Map<String, dynamic> json) {
    final rawTuning =
        json['tuning'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return InferenceInspector(
      blockedChecklist: [
        for (final item
            in json['blocked_checklist'] as List<dynamic>? ?? const [])
          ActionState.fromJson(item as Map<String, dynamic>),
      ],
      inspector: json['inspector'] as Map<String, dynamic>? ?? const {},
      recent: [
        for (final item in json['recent'] as List<dynamic>? ?? const [])
          InferenceRecord.fromJson(item as Map<String, dynamic>),
      ],
      addTileAction: ActionState.fromJson(
        json['add_tile_action'] as Map<String, dynamic>? ?? const {},
      ),
      batchDropZone: ActionState.fromJson(
        json['batch_drop_zone'] as Map<String, dynamic>? ?? const {},
      ),
      tuning: {
        for (final entry in rawTuning.entries)
          entry.key: UnsupportedState.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
      compareView: json['compare_view'] as Map<String, dynamic>? ?? const {},
    );
  }
}
