import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_tuner/src/backend_client.dart';
import 'package:sr_tuner/src/classic_components.dart';
import 'package:sr_tuner/src/classic_theme.dart';
import 'package:sr_tuner/src/project_models.dart';
import 'package:sr_tuner/src/startup_screen.dart';
import 'package:sr_tuner/src/workspace/dataset_tab.dart';
import 'package:sr_tuner/src/workspace/live_metrics_tab.dart';
import 'package:sr_tuner/src/workspace/model_tab.dart';
import 'package:sr_tuner/src/workspace/project_workspace.dart';
import 'package:sr_tuner/src/workspace/training_tab.dart';

void main() {
  testWidgets('classic design primitives render key states', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              SrChip(label: 'Ready', selected: true, severity: 'success'),
              SrBanner(message: 'Unavailable', severity: 'warning'),
              SrMetricCard(label: 'Runs', value: '2'),
              SrProgressBar(value: 0.4),
              SrProgressBar(value: 0.5, kind: SrProgressKind.striped),
              SrProgressBar(kind: SrProgressKind.indeterminate),
              SrImagePlaceholder(label: 'Preview'),
              SrStepIndicator(steps: ['Source', 'Review'], currentIndex: 1),
              SrCompareViewer(),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('2. Review'), findsOneWidget);
    expect(find.byType(SrProgressBar), findsNWidgets(3));
  });

  testWidgets('start screen shows two-column picker states and recent search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedPath = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: StartupScreen(
          busy: false,
          error: null,
          recentProjects: [
            RecentProject(
              name: 'demo',
              path: '/tmp/demo',
              status: 'available',
              statusMessage: 'Ready',
              summary: RecentProjectSummary(
                datasetCount: 1,
                modelCount: 1,
                runCount: 2,
                checkpointCount: 3,
              ),
            ),
          ],
          onRefreshRecent: () async {},
          onCreate: (parent, name, {createHere = false}) async {},
          onOpen: (path) async => openedPath = path,
        ),
      ),
    );

    expect(find.text('sr-tuner'), findsOneWidget);
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Open project folder'), findsOneWidget);
    expect(find.text('Import .srtproj archive'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Import .srtproj archive'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Recent projects'), findsOneWidget);
    expect(find.text('demo'), findsOneWidget);
    expect(find.textContaining('Projects are folders'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(openedPath, '/tmp/demo');
  });

  testWidgets(
    'project shell renders overview, menu, status bar, and navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeBackendClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: ClassicTheme.dark(),
          home: ProjectWorkspace(
            client: client,
            project: _project(),
            error: null,
            onTabChanged: (index) => client.selectedTab = index,
            onProjectChanged: (_) {},
            onCloseProject: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Dataset'), findsWidgets);
      expect(find.text('Inference'), findsWidgets);
      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Quick actions'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);
      expect(find.text('CPU'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Open Dataset'));
      await tester.pumpAndSettle();
      expect(client.selectedTab, 1);

      await tester.tap(find.byTooltip('Project menu'));
      await tester.pumpAndSettle();
      expect(find.text('Export .srtproj archive unavailable'), findsOneWidget);
    },
  );

  testWidgets('dataset and model tabs render handoff states from view models', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeBackendClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: DatasetTab(
            client: client,
            project: _projectWithWorkflow(),
            onProjectChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Health checks'), findsOneWidget);
    expect(find.text('LR / HR preview'), findsOneWidget);
    expect(find.text('Channel histogram'), findsOneWidget);
    expect(find.text('Re-synthesize'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: ModelTab(
            client: client,
            project: _projectWithWorkflow(),
            onProjectChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Internal residual'), findsWidgets);
    expect(find.text('Architecture flow'), findsOneWidget);
    expect(find.text('Hyperparameters'), findsOneWidget);
    expect(find.text('Save as model'), findsOneWidget);
  });

  testWidgets('training and live tabs render phase seven controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeBackendClient(liveRun: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: TrainingTab(
            client: client,
            project: _projectWithWorkflow(activeRun: true),
            onProjectChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Schedule and validation'), findsOneWidget);
    expect(find.text('Optimizer'), findsOneWidget);
    expect(find.text('Loss'), findsOneWidget);
    expect(find.text('Estimate and checkpoints'), findsOneWidget);
    expect(find.text('FFT loss'), findsOneWidget);
    expect(find.text('Clone settings'), findsOneWidget);
    expect(find.text('Resume training'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: LiveMetricsTab(
            client: client,
            project: _projectWithWorkflow(activeRun: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Snapshot'), findsOneWidget);
    expect(find.text('Epoch progress'), findsOneWidget);
    expect(find.text('Run progress'), findsOneWidget);
    expect(find.text('Loss / PSNR'), findsOneWidget);
    expect(find.text('Validation samples'), findsOneWidget);
    expect(find.text('Recent events'), findsOneWidget);
  });
}

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient({this.liveRun = false});

  final bool liveRun;
  int selectedTab = 0;

  @override
  Future<DashboardSummary> dashboardSummary(String projectId) async {
    return DashboardSummary(
      datasetCount: 0,
      modelCount: 0,
      runCount: 0,
      datasetPairTotal: 0,
      backendStatus: 'ok',
      deviceBadge: 'CPU',
      appVersion: '0.1.0',
      projectPath: '/tmp/demo',
      diskWarning: false,
      busyState: 'idle',
      statusBar: StatusBarData(
        appVersion: '0.1.0',
        projectPath: '/tmp/demo',
        vcsAvailable: true,
        vcsBranch: 'main',
        backendState: 'ok',
        diskWarning: false,
        busyState: 'idle',
      ),
      nextStep: NextStepGuidance(
        state: 'missing_dataset',
        title: 'Create a dataset',
        description: 'Add LR/HR pairs.',
        actionLabel: 'Open Dataset',
        targetTab: 1,
        severity: 'info',
      ),
    );
  }

  @override
  Future<ActivityFeedEnvelope> activityFeed(String projectId) async {
    return ActivityFeedEnvelope(
      events: [
        ActivityEvent(
          id: 'activity_1',
          timestamp: 'now',
          category: 'project',
          severity: 'info',
          description: 'Project opened.',
        ),
      ],
    );
  }

  @override
  Future<ActiveRunStatus> activeRunStatus(String projectId) async {
    return ActiveRunStatus(
      run: liveRun ? _run(active: true) : null,
      datasetName: liveRun ? 'dataset_x4' : null,
      modelName: liveRun ? 'internal_x4' : null,
      epoch: liveRun ? 2 : 0,
      iteration: liveRun ? 42 : 0,
      progress: liveRun ? 0.42 : 0,
      latestMetrics: liveRun
          ? const {
              'train_loss_total': 0.12,
              'val_psnr': 28.4,
              'val_ssim': 0.91,
              'learning_rate': 0.0001,
              'iterations_per_second': 3.2,
            }
          : const {},
    );
  }

  @override
  Future<DatasetDetail> datasetDetail({
    required String projectId,
    required String datasetId,
    int previewIndex = 0,
  }) async {
    return DatasetDetail(
      dataset: _dataset(),
      sources: [
        DatasetSourceRow(
          id: 'source_1',
          sourceType: 'folder',
          name: 'paired folder',
          pairCount: 120,
          status: 'Readable',
          severity: 'success',
          note: 'LR and HR pairs matched',
          actions: [
            ActionState(id: 'inspect', label: 'Inspect', supported: true),
            ActionState(
              id: 'relink',
              label: 'Relink',
              supported: false,
              reason: 'Unavailable in tests',
            ),
          ],
        ),
      ],
      healthChecks: [
        HealthCheckRow(
          id: 'alignment',
          label: 'Alignment',
          severity: 'success',
          message: 'Pairs match expected dimensions.',
        ),
      ],
      degradationPipeline: const ['Bicubic downscale', 'JPEG 90-100'],
      preview: DatasetPreviewPair(
        index: previewIndex,
        total: 2,
        unavailable: UnsupportedState(
          supported: false,
          reason: 'unavailable',
          code: 'preview_missing',
          message: 'Preview files are not available in widget tests.',
        ),
      ),
      histogram: HistogramSummary(
        available: true,
        channels: const ['L', 'A', 'B'],
        selectedChannel: 'L',
        bins: const [1, 4, 7, 3],
      ),
      rescanAction: ActionState(
        id: 'rescan',
        label: 'Re-scan',
        supported: true,
      ),
      exportAction: ActionState(id: 'export', label: 'Export', supported: true),
      resynthesis: UnsupportedState(
        supported: false,
        reason: 'unsupported',
        code: 'resynthesis_unavailable',
        message: 'Re-synthesis is unavailable for this dataset.',
      ),
    );
  }

  @override
  Future<VideoReadiness> videoReadiness() async {
    return VideoReadiness(
      available: true,
      tool: 'ffmpeg',
      message: 'Video import is ready.',
    );
  }

  @override
  Future<ModelTemplateCatalog> modelTemplates(String projectId) async {
    return ModelTemplateCatalog(
      templates: [
        ModelTemplate(
          id: 'internal',
          displayName: 'Internal residual',
          architectureSummary: 'Residual pixel-shuffle baseline',
          bestFor: 'general',
          speedLabel: 'fast',
          supportedScales: const [4],
          parameterCount: 420000,
          vramEstimate: '2 GB',
          inputCrop: 128,
          supportState: 'supported',
          architectureSteps: const ['Conv', 'Residual blocks', 'Pixel shuffle'],
          hyperparameters: const {'features': 32, 'blocks': 4},
          defaults: const {'scale': 4},
          importAction: ActionState(
            id: 'import',
            label: 'Import template',
            supported: false,
          ),
          resetAction: ActionState(
            id: 'reset',
            label: 'Reset to defaults',
            supported: true,
          ),
          saveAsModelAction: ActionState(
            id: 'save',
            label: 'Save as model',
            supported: true,
          ),
        ),
      ],
      filters: const {
        'support': ['supported'],
        'speed': ['fast'],
      },
    );
  }

  @override
  Future<TrainingReadiness> trainingReadiness({
    bool tensorboard = false,
  }) async {
    return TrainingReadiness(
      available: true,
      message: 'Training dependencies are ready.',
      dependencies: [
        DependencySummary(
          name: 'torch',
          available: true,
          required: true,
          message: 'Ready',
        ),
      ],
    );
  }

  @override
  Future<List<DeviceOption>> devices() async {
    return [
      DeviceOption(id: 'cpu', label: 'CPU', type: 'cpu', available: true),
    ];
  }

  @override
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
    return TrainingEstimate(
      available: true,
      estimatedTimeSeconds: 1800,
      iterationsPerEpoch: 120,
      vramPeakBytes: 2147483648,
      diskPerCheckpointBytes: 10485760,
      unsupportedLosses: [
        UnsupportedState(
          supported: false,
          reason: 'unsupported',
          code: 'fft_loss',
          message: 'FFT loss is not supported by this backend path.',
          actionLabel: 'FFT loss',
        ),
      ],
      suggestedFixes: const [],
      retention: const {'keep_best': true},
      ema: UnsupportedState(
        supported: false,
        reason: 'unsupported',
        code: 'ema_unavailable',
        message: 'EMA checkpoints are unavailable.',
      ),
    );
  }

  @override
  Future<LiveRunDetail> liveRunDetail(String projectId) async {
    return LiveRunDetail(
      active: liveRun,
      run: liveRun ? _run(active: true) : null,
      epochProgress: 0.45,
      runProgress: 0.42,
      etaSeconds: 300,
      recentEvents: [
        ActivityEvent(
          id: 'event_1',
          timestamp: 'now',
          category: 'run',
          severity: 'info',
          description: 'Validation completed.',
        ),
      ],
      logTail: const ['loss=0.12'],
      openLog: ActionState(id: 'open_log', label: 'Open log', supported: false),
      validationSamples: const [
        {'id': 'sample_1', 'psnr': 28.4},
      ],
    );
  }

  @override
  Future<MetricsEnvelope> runMetrics({
    required String projectId,
    required String runId,
    int limit = 200,
  }) async {
    return MetricsEnvelope(
      runId: runId,
      definitions: {
        'train_loss_total': MetricDefinition(
          name: 'train_loss_total',
          label: 'Loss',
          kind: 'loss',
          unit: null,
        ),
        'val_psnr': MetricDefinition(
          name: 'val_psnr',
          label: 'PSNR',
          kind: 'quality',
          unit: 'dB',
        ),
      },
      records: [
        MetricRecord(
          step: 1,
          epoch: 1,
          iteration: 1,
          values: const {'train_loss_total': 0.2, 'val_psnr': 27.0},
        ),
        MetricRecord(
          step: 2,
          epoch: 2,
          iteration: 42,
          values: const {'train_loss_total': 0.12, 'val_psnr': 28.4},
        ),
      ],
    );
  }

  @override
  Future<HardwareTelemetry> hardwareTelemetry(String projectId) async {
    final field = TelemetryField(
      available: true,
      value: 1,
      unit: 'GB',
      reason: null,
    );
    return HardwareTelemetry(
      device: 'CPU',
      deviceType: 'cpu',
      memoryUsed: field,
      memoryTotal: field,
      utilization: field,
      temperature: field,
      iterationSpeed: field,
    );
  }

  @override
  Future<PreviewEnvelope> validationPreview({
    required String projectId,
    required String runId,
  }) async {
    return PreviewEnvelope(
      runId: runId,
      generatedAt: 'now',
      diffMode: 'absolute',
      assets: const [],
    );
  }

  @override
  Future<ProjectEnvelope> saveWorkspace({
    required String projectId,
    int? selectedTab,
    String? theme,
    String? density,
    Map<String, dynamic>? perProjectUiState,
  }) async {
    return ProjectEnvelope(
      project: _project(selectedTab: selectedTab ?? 0),
      projectId: projectId,
      rootPath: '/tmp/demo',
      projectFile: '/tmp/demo/sr-tuner.project.json',
    );
  }
}

ProjectState _project({int selectedTab = 0}) {
  return ProjectState(
    id: 'project_1',
    name: 'demo',
    rootPath: '/tmp/demo',
    selectedTab: selectedTab,
    datasets: const [],
    models: const [],
    runs: const [],
    datasetCount: 0,
    modelCount: 0,
    runCount: 0,
    workspacePreferences: WorkspacePreferences(
      selectedTab: selectedTab,
      theme: 'dark',
      density: 'compact',
      perProjectUiState: const {},
    ),
  );
}

ProjectState _projectWithWorkflow({bool activeRun = false}) {
  return ProjectState(
    id: 'project_1',
    name: 'demo',
    rootPath: '/tmp/demo',
    selectedTab: 0,
    datasets: [_dataset()],
    models: [_model()],
    runs: [_run(active: activeRun)],
    datasetCount: 1,
    modelCount: 1,
    runCount: 1,
    workspacePreferences: WorkspacePreferences(
      selectedTab: 0,
      theme: 'dark',
      density: 'compact',
      perProjectUiState: const {},
    ),
  );
}

DatasetSummary _dataset() {
  return DatasetSummary(
    id: 'dataset_1',
    name: 'dataset_x4',
    type: 'paired',
    scale: 4,
    storageMode: 'reference',
    usable: true,
    pairCount: 120,
    validationMode: 'quick',
  );
}

ModelSummary _model() {
  return ModelSummary(
    id: 'model_1',
    name: 'internal_x4',
    architecture: 'internal_residual_pixelshuffle',
    scale: 4,
    numFeatures: 32,
    numBlocks: 4,
    status: 'configured',
  );
}

RunSummary _run({bool active = false}) {
  return RunSummary(
    id: 'run_1',
    name: 'run_x4',
    datasetId: 'dataset_1',
    modelId: 'model_1',
    state: active ? 'running' : 'configured',
    trainMode: 'new',
    device: 'cpu',
    epochs: 10,
    checkpointCadence: 1,
    logDir: '/tmp/demo/logs',
  );
}
