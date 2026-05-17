import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'app_config.dart';
import 'diagnostic_logger.dart';
import 'logging_schema.dart';
import 'project_models.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.details = const {},
    this.recoverable = true,
    this.correlationId,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic> details;
  final bool recoverable;
  final String? correlationId;

  @override
  String toString() {
    final parts = [message];
    if (code != null) parts.add('($code)');
    if (correlationId != null) parts.add('[correlation: $correlationId]');
    return parts.join(' ');
  }
}

class BackendClient {
  BackendClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final _log = DiagnosticLogger(component: Components.api, minimumLevel: LogLevel.info);
  String? _sessionToken;
  String _correlationId = '';

  set sessionToken(String? value) {
    _sessionToken = value;
  }

  String get currentCorrelationId => _correlationId;

  String beginCorrelatedAction() {
    _correlationId = _generateCorrelationId();
    return _correlationId;
  }

  void resetCorrelation() {
    _correlationId = '';
  }

  static String _generateCorrelationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return [
      for (var i = 0; i < 16; i++)
        bytes[i].toRadixString(16).padLeft(2, '0'),
    ].join('');
  }

  Future<Map<String, dynamic>> health() => _get('/health');

  Future<void> shutdownBackend() async {
    await _post('/shutdown', {});
  }

  Future<ProjectEnvelope> createProject({
    required String parentPath,
    required String name,
    bool createHere = false,
  }) async {
    final response = await _post('/projects', {
      'parent_path': parentPath,
      'name': name,
      'create_here': createHere,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> openProject(String path) async {
    final response = await _post('/projects/open', {'path': path});
    return ProjectEnvelope.fromJson(response);
  }

  Future<RecentProjectsEnvelope> recentProjects() async {
    return RecentProjectsEnvelope.fromJson(await _get('/projects/recent'));
  }

  Future<RecentProjectsEnvelope> forgetRecentProject(String path) async {
    final response = await _delete(
      '/projects/recent?path=${Uri.encodeQueryComponent(path)}',
    );
    return RecentProjectsEnvelope.fromJson(response);
  }

  Future<RecentProjectsEnvelope> forgetAllRecentProjects() async {
    final response = await _delete('/projects/recent/all');
    return RecentProjectsEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> openRecentProject(String path) async {
    final response = await _post('/projects/recent/open', {'path': path});
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> saveWorkspace({
    required String projectId,
    int? selectedTab,
    String? theme,
    String? density,
    Map<String, dynamic>? perProjectUiState,
  }) async {
    final response = await _put('/projects/$projectId/workspace', {
      'selected_tab': ?selectedTab,
      'theme': ?theme,
      'density': ?density,
      'per_project_ui_state': ?perProjectUiState,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<WorkspacePreferences> workspacePreferences(String projectId) async {
    return WorkspacePreferences.fromJson(
      await _get('/projects/$projectId/workspace'),
    );
  }

  Future<DashboardSummary> dashboardSummary(String projectId) async {
    return DashboardSummary.fromJson(
      await _get('/projects/$projectId/dashboard'),
    );
  }

  Future<ActivityFeedEnvelope> activityFeed(String projectId) async {
    return ActivityFeedEnvelope.fromJson(
      await _get('/projects/$projectId/activity'),
    );
  }

  Future<List<DatasetSummary>> listDatasets(String projectId) async {
    final response = await _getList('/projects/$projectId/datasets');
    return [
      for (final item in response)
        DatasetSummary.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<ProjectEnvelope> registerPairedDataset({
    required String projectId,
    required String name,
    required String datasetPath,
    required int scale,
    required String validationMode,
    required String storageOperation,
  }) async {
    final response = await _post('/projects/$projectId/datasets/paired', {
      'name': name,
      'dataset_path': datasetPath,
      'scale': scale,
      'validation_mode': validationMode,
      'storage_operation': storageOperation,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<DatasetStorageEstimate> estimateDatasetStorage({
    required String projectId,
    required String name,
    required String datasetPath,
    required String operation,
  }) async {
    final response = await _post(
      '/projects/$projectId/datasets/storage-estimate',
      {'name': name, 'dataset_path': datasetPath, 'operation': operation},
    );
    return DatasetStorageEstimate.fromJson(response);
  }

  Future<VideoReadiness> videoReadiness() async {
    return VideoReadiness.fromJson(await _get('/dependencies/video'));
  }

  Future<DatasetDetail> datasetDetail({
    required String projectId,
    required String datasetId,
    int previewIndex = 0,
  }) async {
    return DatasetDetail.fromJson(
      await _get(
        '/projects/$projectId/datasets/$datasetId/detail?preview_index=$previewIndex',
      ),
    );
  }

  Future<VideoWizardMetadata> videoWizardMetadata({
    required String projectId,
    required String name,
    required String sourceVideo,
    required int scale,
    required double fps,
    int? frameLimit,
    String downscaleMethod = 'bicubic',
    String outputFormat = 'png',
    double preBlur = 0.0,
    double blur = 0.0,
    double noise = 0.0,
    int jpegQuality = 95,
  }) async {
    return VideoWizardMetadata.fromJson(
      await _post('/projects/$projectId/datasets/video/metadata', {
        'name': name,
        'source_video': sourceVideo,
        'scale': scale,
        'fps': fps,
        'frame_limit': frameLimit,
        'output_format': outputFormat,
        'downscale_method': downscaleMethod,
        'pre_blur': preBlur,
        'blur': blur,
        'noise': noise,
        'jpeg_quality': jpegQuality,
      }),
    );
  }

  Future<JobState> resynthesizeDataset({
    required String projectId,
    required String datasetId,
    String? downscaleMethod,
    String? outputFormat,
    double? preBlur,
    double? blur,
    double? noise,
    int? jpegQuality,
  }) async {
    return JobState.fromJson(
      await _post('/projects/$projectId/datasets/$datasetId/resynthesize', {
        if (downscaleMethod != null) 'downscale_method': downscaleMethod,
        if (outputFormat != null) 'output_format': outputFormat,
        if (preBlur != null) 'pre_blur': preBlur,
        if (blur != null) 'blur': blur,
        if (noise != null) 'noise': noise,
        if (jpegQuality != null) 'jpeg_quality': jpegQuality,
      }),
    );
  }

  Future<ProjectEnvelope> deleteDataset({
    required String projectId,
    required String datasetId,
  }) async {
    final response = await _delete('/projects/$projectId/datasets/$datasetId');
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> generateVideoDataset({
    required String projectId,
    required String name,
    required String sourceVideo,
    required int scale,
    required double fps,
    int? frameLimit,
    String downscaleMethod = 'bicubic',
    String outputFormat = 'png',
    double preBlur = 0.0,
    double blur = 0.0,
    double noise = 0.0,
    int jpegQuality = 95,
  }) async {
    final response = await _post('/projects/$projectId/datasets/video', {
      'name': name,
      'source_video': sourceVideo,
      'scale': scale,
      'fps': fps,
      'frame_limit': frameLimit,
      'output_format': outputFormat,
      'downscale_method': downscaleMethod,
      'pre_blur': preBlur,
      'blur': blur,
      'noise': noise,
      'jpeg_quality': jpegQuality,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<JobState> startVideoDataset({
    required String projectId,
    required String name,
    required String sourceVideo,
    required int scale,
    required double fps,
    int? frameLimit,
    String downscaleMethod = 'bicubic',
    String outputFormat = 'png',
    double preBlur = 0.0,
    double blur = 0.0,
    double noise = 0.0,
    int jpegQuality = 95,
  }) async {
    final response = await _post('/projects/$projectId/datasets/video/start', {
      'name': name,
      'source_video': sourceVideo,
      'scale': scale,
      'fps': fps,
      'frame_limit': frameLimit,
      'output_format': outputFormat,
      'downscale_method': downscaleMethod,
      'pre_blur': preBlur,
      'blur': blur,
      'noise': noise,
      'jpeg_quality': jpegQuality,
    });
    return JobState.fromJson(response);
  }

  Future<ProjectEnvelope> createModel({
    required String projectId,
    required String name,
    required int numFeatures,
    required int numBlocks,
  }) async {
    final response = await _post('/projects/$projectId/models', {
      'name': name,
      'num_features': numFeatures,
      'num_blocks': numBlocks,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<ModelTemplateCatalog> modelTemplates(String projectId) async {
    return ModelTemplateCatalog.fromJson(
      await _get('/projects/$projectId/model-templates'),
    );
  }

  Future<ProjectEnvelope> saveTemplateAsModel({
    required String projectId,
    required String templateId,
    required String name,
    int numFeatures = 32,
    int numBlocks = 4,
    double resScale = 0.1,
  }) async {
    final response = await _post(
      '/projects/$projectId/model-templates/$templateId/save-as-model'
      '?name=${Uri.encodeQueryComponent(name)}'
      '&num_features=$numFeatures'
      '&num_blocks=$numBlocks'
      '&res_scale=$resScale',
      {},
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> updateModel({
    required String projectId,
    required String modelId,
    String? name,
    int? numFeatures,
    int? numBlocks,
    double? lr,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (numFeatures != null) body['num_features'] = numFeatures;
    if (numBlocks != null) body['num_blocks'] = numBlocks;
    if (lr != null) body['optimizer'] = {'type': 'adam', 'lr': lr, 'beta1': 0.9, 'beta2': 0.99};
    final response = await _put('/projects/$projectId/models/$modelId', body);
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> deleteModel({
    required String projectId,
    required String modelId,
  }) async {
    final response = await _delete('/projects/$projectId/models/$modelId');
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> duplicateModel({
    required String projectId,
    required String modelId,
    required String name,
  }) async {
    final response = await _post(
      '/projects/$projectId/models/$modelId/duplicate?name=${Uri.encodeQueryComponent(name)}',
      {},
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<TrainingReadiness> trainingReadiness({
    bool tensorboard = false,
  }) async {
    return TrainingReadiness.fromJson(
      await _get('/dependencies/training?tensorboard=$tensorboard'),
    );
  }

  Future<List<DeviceOption>> devices() async {
    final response = await _get('/devices');
    final defaultDevice = response['default_device'] as String? ?? 'cpu';
    final devices = [
      for (final item in response['devices'] as List<dynamic>? ?? const [])
        DeviceOption.fromJson(item as Map<String, dynamic>),
    ];
    devices.sort((a, b) {
      if (a.id == defaultDevice) return -1;
      if (b.id == defaultDevice) return 1;
      if (a.id == 'cpu') return 1;
      if (b.id == 'cpu') return -1;
      return a.label.compareTo(b.label);
    });
    return devices;
  }

  Future<ProjectEnvelope> createRun({
    required String projectId,
    required String name,
    required String datasetId,
    required String modelId,
    required String trainMode,
    required String device,
    required int epochs,
    required int batchSize,
    required int checkpointCadence,
    required bool validationEnabled,
    required double validationPercentage,
    required int validationEveryEpochs,
    required int validationSeed,
    required bool validationShuffle,
    required bool tensorboard,
    required String precision,
    required bool compile,
    required int warmupEpochs,
    required String schedulerType,
    required String diffMode,
    required double l1Weight,
    required double perceptualWeight,
    required double adversarialWeight,
    double? learningRate,
    String? sourceCoreWeightsPath,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'dataset_id': datasetId,
      'model_id': modelId,
      'train_mode': trainMode,
      'device': device,
      'epochs': epochs,
      'batch_size': batchSize,
      'checkpoint_cadence': checkpointCadence,
      'validation_enabled': validationEnabled,
      'validation_percentage': validationPercentage,
      'validation_every_epochs': validationEveryEpochs,
      'validation_seed': validationSeed,
      'validation_shuffle': validationShuffle,
      'tensorboard': tensorboard,
      'precision': precision,
      'compile': compile,
      'warmup_epochs': warmupEpochs,
      'scheduler_type': schedulerType,
      'diff_mode': diffMode,
      'loss_weights': {
        'l1': l1Weight,
        'perceptual': perceptualWeight,
        'adversarial': adversarialWeight,
      },
    };
    if (learningRate != null) body['learning_rate'] = learningRate;
    if (sourceCoreWeightsPath != null) body['source_core_weights_path'] = sourceCoreWeightsPath;
    final response = await _post('/projects/$projectId/runs', body);
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> deleteRunConfig({
    required String projectId,
    required String runId,
  }) async {
    final response = await _delete('/projects/$projectId/runs/$runId');
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> launchRun({
    required String projectId,
    required String runId,
  }) async {
    final response = await _post('/projects/$projectId/runs/$runId/launch', {
      'run_id': runId,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> pauseRun({
    required String projectId,
    required String runId,
  }) async {
    final response = await _post('/projects/$projectId/runs/$runId/pause', {});
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> resumeRun({
    required String projectId,
    required String runId,
    String? checkpointId,
    String? checkpointPath,
  }) async {
    final response = await _post('/projects/$projectId/runs/$runId/resume', {
      if (checkpointId != null) 'checkpoint_id': checkpointId,
      if (checkpointPath != null) 'checkpoint_path': checkpointPath,
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> syncRunJob({
    required String projectId,
    required String runId,
  }) async {
    final response = await _post('/projects/$projectId/runs/$runId/sync-job', {});
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> stopRun({
    required String projectId,
    required String runId,
  }) async {
    final response = await _post('/projects/$projectId/runs/$runId/stop', {});
    return ProjectEnvelope.fromJson(response);
  }

  Future<ActiveRunStatus> activeRunStatus(String projectId) async {
    return ActiveRunStatus.fromJson(
      await _get('/projects/$projectId/active-run'),
    );
  }

  Future<MetricsEnvelope> runMetrics({
    required String projectId,
    required String runId,
    int limit = 200,
  }) async {
    return MetricsEnvelope.fromJson(
      await _get('/projects/$projectId/runs/$runId/metrics?limit=$limit'),
    );
  }

  Future<HardwareTelemetry> hardwareTelemetry(String projectId) async {
    return HardwareTelemetry.fromJson(
      await _get('/projects/$projectId/hardware'),
    );
  }

  Future<TrainingEstimate> trainingEstimate({
    required String projectId,
    required String name,
    required String datasetId,
    required String modelId,
    String trainMode = 'new',
    String device = 'cpu',
    int epochs = 10,
    int batchSize = 16,
    int checkpointCadence = 1,
    bool validationEnabled = true,
    double validationPercentage = 0.1,
    int validationEveryEpochs = 1,
    int validationSeed = 42,
    bool validationShuffle = true,
    bool tensorboard = false,
    String precision = 'float32',
    bool compile = false,
    int warmupEpochs = 0,
    String schedulerType = 'cosine',
    String diffMode = 'absolute',
    double l1Weight = 1.0,
    double perceptualWeight = 0.0,
    double adversarialWeight = 0.0,
  }) async {
    return TrainingEstimate.fromJson(
      await _post('/projects/$projectId/training/estimate', {
        'name': name,
        'dataset_id': datasetId,
        'model_id': modelId,
        'train_mode': trainMode,
        'device': device,
        'epochs': epochs,
        'batch_size': batchSize,
        'checkpoint_cadence': checkpointCadence,
        'validation_enabled': validationEnabled,
        'validation_percentage': validationPercentage,
        'validation_every_epochs': validationEveryEpochs,
        'validation_seed': validationSeed,
        'validation_shuffle': validationShuffle,
        'tensorboard': tensorboard,
        'precision': precision,
        'compile': compile,
        'warmup_epochs': warmupEpochs,
        'scheduler_type': schedulerType,
        'diff_mode': diffMode,
        'loss_weights': {
          'l1': l1Weight,
          'perceptual': perceptualWeight,
          'adversarial': adversarialWeight,
        },
      }),
    );
  }

  Future<LiveRunDetail> liveRunDetail(String projectId) async {
    return LiveRunDetail.fromJson(
      await _get('/projects/$projectId/live/detail'),
    );
  }

  Future<SnapshotResponse> snapshotCheckpoint({
    required String projectId,
    required String runId,
  }) async {
    return SnapshotResponse.fromJson(
      await _post('/projects/$projectId/runs/$runId/snapshot', {}),
    );
  }

  Future<PreviewEnvelope> validationPreview({
    required String projectId,
    required String runId,
    int previewIndex = 0,
  }) async {
    return PreviewEnvelope.fromJson(
      await _get(
        '/projects/$projectId/runs/$runId/preview?preview_index=$previewIndex',
      ),
    );
  }

  Future<OnnxReadiness> onnxReadiness() async {
    return OnnxReadiness.fromJson(await _get('/dependencies/onnx'));
  }

  Future<CheckpointListEnvelope> listRunCheckpoints({
    required String projectId,
    required String runId,
  }) async {
    return CheckpointListEnvelope.fromJson(
      await _get('/projects/$projectId/runs/$runId/checkpoints'),
    );
  }

  Future<CheckpointAggregate> checkpointAggregate(String projectId) async {
    return CheckpointAggregate.fromJson(
      await _get('/projects/$projectId/checkpoints/aggregate'),
    );
  }

  Future<CheckpointListEnvelope> deleteCheckpoint({
    required String projectId,
    required String runId,
    required String checkpointId,
  }) async {
    final request = await _httpClient.openUrl(
      'DELETE',
      AppConfig.apiUri(
        '/projects/$projectId/runs/$runId/checkpoints/$checkpointId',
      ),
    );
    _addCommonHeaders(request);
    return CheckpointListEnvelope.fromJson(
      await _readJson(await request.close()),
    );
  }

  Future<JobState> exportCheckpointPth({
    required String projectId,
    required String runId,
    required String checkpointId,
    required String destination,
  }) async {
    final response = await _post(
      '/projects/$projectId/runs/$runId/checkpoints/$checkpointId/export-pth',
      {'destination': destination},
    );
    return JobState.fromJson(response);
  }

  Future<JobState> exportCheckpointOnnx({
    required String projectId,
    required String runId,
    required String checkpointId,
    required String destination,
  }) async {
    final response = await _post(
      '/projects/$projectId/runs/$runId/checkpoints/$checkpointId/export-onnx',
      {'destination': destination},
    );
    return JobState.fromJson(response);
  }

  Future<ProjectEnvelope> setCheckpointAsCore({
    required String projectId,
    required String modelId,
    required String runId,
    required String checkpointId,
  }) async {
    final response = await _post(
      '/projects/$projectId/models/$modelId/checkpoints/$runId/$checkpointId/set-core',
      {},
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<JobState> exportModelPackage({
    required String projectId,
    required String modelId,
    required String runId,
    required String checkpointId,
    required String destination,
  }) async {
    final response = await _post(
      '/projects/$projectId/models/$modelId/checkpoints/$runId/$checkpointId/export-package',
      {'destination': destination},
    );
    return JobState.fromJson(response);
  }

  Future<ProjectEnvelope> importModelPackage({
    required String projectId,
    required String filePath,
  }) async {
    final request = await _httpClient.openUrl(
      'POST',
      AppConfig.apiUri('/projects/$projectId/import-model-package'),
    );
    _addCommonHeaders(request);
    request.headers.set('Content-Type', 'application/octet-stream');
    final file = File(filePath);
    await request.addStream(file.openRead());
    final response = await request.close();
    final result = await _readJson(response);
    return ProjectEnvelope.fromJson(result);
  }

  Future<ProjectEnvelope> deleteArchivedCheckpoint({
    required String projectId,
    required String modelId,
    required String checkpointId,
  }) async {
    final response = await _delete(
      '/projects/$projectId/models/$modelId/checkpoints/$checkpointId',
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> deleteArchivedSession({
    required String projectId,
    required String modelId,
    required String sessionId,
  }) async {
    final response = await _delete(
      '/projects/$projectId/models/$modelId/sessions/$sessionId',
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<JobState> getJob(String jobId) async {
    final response = await _get('/jobs/$jobId');
    return JobState.fromJson(response);
  }

  Future<JobState> cancelJob(String jobId) async {
    final response = await _post('/jobs/$jobId/cancel', {});
    return JobState.fromJson(response);
  }

  Future<InferenceReadiness> inferenceReadiness({String device = 'cpu'}) async {
    return InferenceReadiness.fromJson(
      await _get('/dependencies/inference?device=$device'),
    );
  }

  Future<InferenceRecord> runInference({
    required String projectId,
    String? runId,
    String? checkpointId,
    String? modelId,
    int? outputScale,
    required String inputPath,
    String? outputDir,
    String outputFormat = 'png',
    String mode = 'single',
    String device = 'cpu',
    TileConfig? tileConfig,
  }) async {
    final body = <String, dynamic>{
      'input_path': inputPath,
      'output_dir': outputDir,
      'output_format': outputFormat,
      'mode': mode,
      'device': device,
      'tile_config': (tileConfig ?? TileConfig()).toJson(),
    };
    if (modelId != null) {
      body['model_id'] = modelId;
      body['output_scale'] = outputScale ?? 4;
    } else {
      body['run_id'] = runId ?? '';
      body['checkpoint_id'] = checkpointId ?? '';
    }
    final response = await _post('/projects/$projectId/inference', body);
    return InferenceRecord.fromJson(response);
  }

  Future<InferenceHistoryEnvelope> listInferenceHistory(
    String projectId,
  ) async {
    return InferenceHistoryEnvelope.fromJson(
      await _get('/projects/$projectId/inference'),
    );
  }

  Future<InferenceInspector> inferenceInspector(String projectId) async {
    return InferenceInspector.fromJson(
      await _get('/projects/$projectId/inference/inspector'),
    );
  }

  void _addCommonHeaders(HttpClientRequest request) {
    final token = _sessionToken;
    if (token != null) {
      request.headers.set('x-sr-tuner-token', token);
    }
    if (_correlationId.isNotEmpty) {
      request.headers.set('x-correlation-id', _correlationId);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final stopwatch = Stopwatch()..start();
    _log.info(EventNames.requestIngress, 'GET $path', context: {'method': 'GET', 'path': path});
    try {
      final request = await _httpClient.getUrl(AppConfig.apiUri(path));
      _addCommonHeaders(request);
      final result = await _readJson(await request.close());
      _log.info(EventNames.requestComplete, 'GET $path -> OK', context: {
        'method': 'GET', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (e) {
      _log.error(EventNames.requestServiceError, 'GET $path failed: $e', context: {
        'method': 'GET', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<List<dynamic>> _getList(String path) async {
    final stopwatch = Stopwatch()..start();
    _log.info(EventNames.requestIngress, 'GET $path (list)', context: {'method': 'GET', 'path': path});
    try {
      final request = await _httpClient.getUrl(AppConfig.apiUri(path));
      _addCommonHeaders(request);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Try to extract structured error before throwing
        if (text.isNotEmpty) {
          final body = jsonDecode(text);
          if (body is Map<String, dynamic>) {
            final error = body['error'];
            if (error is Map<String, dynamic>) {
              throw ApiException(
                error['message']?.toString() ?? 'Backend request failed.',
                statusCode: response.statusCode,
                code: error['code']?.toString(),
                details: error['details'] as Map<String, dynamic>? ?? const {},
                recoverable: error['recoverable'] as bool? ?? true,
              );
            }
          }
        }
        throw ApiException(
          'Backend request failed.',
          statusCode: response.statusCode,
        );
      }
      final decoded = text.isEmpty ? <dynamic>[] : jsonDecode(text) as List<dynamic>;
      _log.info(EventNames.requestComplete, 'GET $path (list) -> OK', context: {
        'method': 'GET', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'count': decoded.length,
      });
      return decoded;
    } catch (e) {
      _log.error(EventNames.requestServiceError, 'GET $path (list) failed: $e', context: {
        'method': 'GET', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final stopwatch = Stopwatch()..start();
    _log.info(EventNames.requestIngress, 'POST $path', context: {'method': 'POST', 'path': path});
    try {
      final request = await _jsonRequest('POST', path, body);
      final result = await _readJson(await request.close());
      _log.info(EventNames.requestComplete, 'POST $path -> OK', context: {
        'method': 'POST', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (e) {
      _log.error(EventNames.requestServiceError, 'POST $path failed: $e', context: {
        'method': 'POST', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final stopwatch = Stopwatch()..start();
    _log.info(EventNames.requestIngress, 'PUT $path', context: {'method': 'PUT', 'path': path});
    try {
      final request = await _jsonRequest('PUT', path, body);
      final result = await _readJson(await request.close());
      _log.info(EventNames.requestComplete, 'PUT $path -> OK', context: {
        'method': 'PUT', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (e) {
      _log.error(EventNames.requestServiceError, 'PUT $path failed: $e', context: {
        'method': 'PUT', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final stopwatch = Stopwatch()..start();
    _log.info(EventNames.requestIngress, 'DELETE $path', context: {'method': 'DELETE', 'path': path});
    try {
      final request = await _httpClient.openUrl('DELETE', AppConfig.apiUri(path));
      _addCommonHeaders(request);
      final result = await _readJson(await request.close());
      _log.info(EventNames.requestComplete, 'DELETE $path -> OK', context: {
        'method': 'DELETE', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (e) {
      _log.error(EventNames.requestServiceError, 'DELETE $path failed: $e', context: {
        'method': 'DELETE', 'path': path, 'elapsed_ms': stopwatch.elapsedMilliseconds, 'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<HttpClientRequest> _jsonRequest(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _httpClient.openUrl(method, AppConfig.apiUri(path));
    request.headers.contentType = ContentType.json;
    _addCommonHeaders(request);
    request.write(jsonEncode(body));
    return request;
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;

    final responseCorrelationId = response.headers.value('x-correlation-id');
    if (responseCorrelationId != null && responseCorrelationId.isNotEmpty) {
      _correlationId = responseCorrelationId;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          error['message']?.toString() ?? 'Backend request failed.',
          statusCode: response.statusCode,
          code: error['code']?.toString(),
          details: error['details'] as Map<String, dynamic>? ?? const {},
          recoverable: error['recoverable'] as bool? ?? true,
          correlationId: _correlationId.isNotEmpty ? _correlationId : null,
        );
      }
      throw ApiException(
        decoded['detail']?.toString() ?? 'Backend request failed.',
        statusCode: response.statusCode,
        correlationId: _correlationId.isNotEmpty ? _correlationId : null,
      );
    }
    return decoded;
  }

  void close() {
    _httpClient.close(force: true);
  }
}
