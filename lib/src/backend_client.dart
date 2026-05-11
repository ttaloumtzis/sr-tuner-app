import 'dart:convert';
import 'dart:io';

import 'app_config.dart';
import 'project_models.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.details = const {},
    this.recoverable = true,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic> details;
  final bool recoverable;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

class BackendClient {
  BackendClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  String? _sessionToken;

  set sessionToken(String? value) {
    _sessionToken = value;
  }

  Future<Map<String, dynamic>> health() => _get('/health');

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
  }) async {
    return VideoWizardMetadata.fromJson(
      await _post('/projects/$projectId/datasets/video/metadata', {
        'name': name,
        'source_video': sourceVideo,
        'scale': scale,
        'fps': fps,
        'frame_limit': frameLimit,
        'output_format': 'png',
        'downscale_method': 'bicubic',
      }),
    );
  }

  Future<UnsupportedState> resynthesizeDataset({
    required String projectId,
    required String datasetId,
  }) async {
    return UnsupportedState.fromJson(
      await _post('/projects/$projectId/datasets/$datasetId/resynthesize', {}),
    );
  }

  Future<ProjectEnvelope> generateVideoDataset({
    required String projectId,
    required String name,
    required String sourceVideo,
    required int scale,
    required double fps,
    int? frameLimit,
  }) async {
    final response = await _post('/projects/$projectId/datasets/video', {
      'name': name,
      'source_video': sourceVideo,
      'scale': scale,
      'fps': fps,
      'frame_limit': frameLimit,
      'output_format': 'png',
      'downscale_method': 'bicubic',
    });
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> createModel({
    required String projectId,
    required String name,
    required int scale,
    required int numFeatures,
    required int numBlocks,
  }) async {
    final response = await _post('/projects/$projectId/models', {
      'name': name,
      'scale': scale,
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
    required int scale,
  }) async {
    final response = await _post(
      '/projects/$projectId/model-templates/$templateId/save-as-model?name=${Uri.encodeQueryComponent(name)}&scale=$scale',
      {},
    );
    return ProjectEnvelope.fromJson(response);
  }

  Future<ProjectEnvelope> updateModelLr({
    required String projectId,
    required String modelId,
    required double lr,
  }) async {
    final response = await _put('/projects/$projectId/models/$modelId', {
      'optimizer': {'type': 'adam', 'lr': lr, 'beta1': 0.9, 'beta2': 0.99},
    });
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
    return [
      for (final item in response['devices'] as List<dynamic>? ?? const [])
        DeviceOption.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<ProjectEnvelope> createRun({
    required String projectId,
    required String name,
    required String datasetId,
    required String modelId,
    required String trainMode,
    required String device,
    required int epochs,
    required int checkpointCadence,
    required double validationPercentage,
    required int validationSeed,
    required bool validationShuffle,
    required bool tensorboard,
    required String precision,
    required bool compile,
    required int warmupEpochs,
    required String schedulerType,
    required String diffMode,
  }) async {
    final response = await _post('/projects/$projectId/runs', {
      'name': name,
      'dataset_id': datasetId,
      'model_id': modelId,
      'train_mode': trainMode,
      'device': device,
      'epochs': epochs,
      'checkpoint_cadence': checkpointCadence,
      'validation_percentage': validationPercentage,
      'validation_seed': validationSeed,
      'validation_shuffle': validationShuffle,
      'tensorboard': tensorboard,
      'precision': precision,
      'compile': compile,
      'warmup_epochs': warmupEpochs,
      'scheduler_type': schedulerType,
      'diff_mode': diffMode,
    });
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
    int checkpointCadence = 1,
    double validationPercentage = 0.1,
    int validationSeed = 42,
    bool validationShuffle = true,
    bool tensorboard = false,
    String precision = 'float32',
    bool compile = false,
    int warmupEpochs = 0,
    String schedulerType = 'cosine',
    String diffMode = 'absolute',
  }) async {
    return TrainingEstimate.fromJson(
      await _post('/projects/$projectId/training/estimate', {
        'name': name,
        'dataset_id': datasetId,
        'model_id': modelId,
        'train_mode': trainMode,
        'device': device,
        'epochs': epochs,
        'checkpoint_cadence': checkpointCadence,
        'validation_percentage': validationPercentage,
        'validation_seed': validationSeed,
        'validation_shuffle': validationShuffle,
        'tensorboard': tensorboard,
        'precision': precision,
        'compile': compile,
        'warmup_epochs': warmupEpochs,
        'scheduler_type': schedulerType,
        'diff_mode': diffMode,
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
  }) async {
    return PreviewEnvelope.fromJson(
      await _get('/projects/$projectId/runs/$runId/preview'),
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
    final token = _sessionToken;
    if (token != null) {
      request.headers.set('x-sr-tuner-token', token);
    }
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
    required String runId,
    required String checkpointId,
    required String inputPath,
    String? outputDir,
    String outputFormat = 'png',
    String mode = 'single',
    String device = 'cpu',
    TileConfig? tileConfig,
  }) async {
    final response = await _post('/projects/$projectId/inference', {
      'run_id': runId,
      'checkpoint_id': checkpointId,
      'input_path': inputPath,
      'output_dir': ?outputDir,
      'output_format': outputFormat,
      'mode': mode,
      'device': device,
      'tile_config': (tileConfig ?? TileConfig()).toJson(),
    });
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

  Future<Map<String, dynamic>> _get(String path) async {
    final request = await _httpClient.getUrl(AppConfig.apiUri(path));
    return _readJson(await request.close());
  }

  Future<List<dynamic>> _getList(String path) async {
    final request = await _httpClient.getUrl(AppConfig.apiUri(path));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty
        ? <dynamic>[]
        : jsonDecode(text) as List<dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Backend request failed.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _jsonRequest('POST', path, body);
    return _readJson(await request.close());
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _jsonRequest('PUT', path, body);
    return _readJson(await request.close());
  }

  Future<HttpClientRequest> _jsonRequest(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _httpClient.openUrl(method, AppConfig.apiUri(path));
    request.headers.contentType = ContentType.json;
    final token = _sessionToken;
    if (token != null) {
      request.headers.set('x-sr-tuner-token', token);
    }
    request.write(jsonEncode(body));
    return request;
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          error['message']?.toString() ?? 'Backend request failed.',
          statusCode: response.statusCode,
          code: error['code']?.toString(),
          details: error['details'] as Map<String, dynamic>? ?? const {},
          recoverable: error['recoverable'] as bool? ?? true,
        );
      }
      throw ApiException(
        decoded['detail']?.toString() ?? 'Backend request failed.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void close() {
    _httpClient.close(force: true);
  }
}
