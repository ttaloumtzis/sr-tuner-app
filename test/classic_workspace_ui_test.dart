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
    var forgottenPath = '';
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
          onForgetRecent: (path) async => forgottenPath = path,
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

    await tester.tap(find.byTooltip('Remove from recent projects'));
    await tester.pumpAndSettle();
    expect(find.text('Remove recent project?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(forgottenPath, '/tmp/demo');
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
    expect(find.text('Add source'), findsNothing);
    expect(find.text('Create dataset'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create dataset'));
    await tester.pumpAndSettle();
    expect(find.text('Type 1 · Paired folders'), findsOneWidget);
    expect(find.text('Type 2 · Extract from video'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('Architectures'), findsOneWidget);
    expect(find.text('Internal residual'), findsWidgets);
    expect(find.text('Supported model architectures'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pump();
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
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Validation'), findsOneWidget);
    expect(find.text('Optimizer'), findsOneWidget);
    expect(find.text('Loss'), findsOneWidget);
    expect(find.text('Setup estimate and launch readiness'), findsOneWidget);
    expect(find.text('Clone settings'), findsOneWidget);
    expect(find.text('Resume training'), findsOneWidget);
    expect(find.text('Delete config'), findsOneWidget);

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
    expect(find.text('Training epoch'), findsAtLeastNWidgets(1));
    expect(find.text('Run progress'), findsOneWidget);
    expect(find.text('Metric charts'), findsOneWidget);
    expect(find.text('Loss'), findsAtLeastNWidgets(1));
    expect(find.text('PSNR'), findsAtLeastNWidgets(1));
    expect(find.text('SSIM'), findsAtLeastNWidgets(1));
    expect(find.text('Validation samples'), findsOneWidget);
    expect(find.text('Input pending'), findsOneWidget);
    expect(find.text('Output pending'), findsOneWidget);
    expect(find.text('Target pending'), findsOneWidget);
    expect(find.text('Diff pending'), findsOneWidget);
    expect(find.text('Recent events'), findsOneWidget);
    expect(client.lastPreviewIndex, 0);
  });

  testWidgets('training runs can be deleted from the run list', (tester) async {
    tester.view.physicalSize = const Size(1900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeBackendClient();
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ClassicTheme.dark(),
        home: Scaffold(
          body: TrainingTab(
            client: client,
            project: _projectWithWorkflow(),
            onProjectChanged: (_) => changed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Delete config'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete config'));
    await tester.pumpAndSettle();

    expect(find.text('Delete run_x4?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(client.deletedRuns, 1);
    expect(changed, isTrue);
  });

  testWidgets(
    'training setup can be saved when launch dependencies are missing',
    (tester) async {
      tester.view.physicalSize = const Size(1900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakeBackendClient(trainingReady: false);
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ClassicTheme.dark(),
          home: Scaffold(
            body: TrainingTab(
              client: client,
              project: _projectWithWorkflow(),
              onProjectChanged: (_) => changed = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Launch readiness'), findsOneWidget);
      expect(find.text('Launch blocked'), findsOneWidget);
      expect(find.text('Create configured run'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Create configured run'),
      );
      await tester.pumpAndSettle();

      expect(client.createdRuns, 1);
      expect(changed, isTrue);
    },
  );
}

class _FakeBackendClient extends BackendClient {
  _FakeBackendClient({this.liveRun = false, this.trainingReady = true});

  final bool liveRun;
  final bool trainingReady;
  int selectedTab = 0;
  int createdRuns = 0;
  int deletedRuns = 0;
  int? lastPreviewIndex;

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
      phase: liveRun ? 'training' : 'idle',
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
      available: trainingReady,
      message: trainingReady
          ? 'Training dependencies are ready.'
          : 'Required training dependencies are missing.',
      dependencies: [
        DependencySummary(
          name: 'torch',
          available: trainingReady,
          required: true,
          message: trainingReady ? 'Ready' : 'Missing',
        ),
        DependencySummary(
          name: 'tensorboard',
          available: false,
          required: tensorboard,
          message: 'Optional logging dependency is missing.',
        ),
      ],
    );
  }

  @override
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
    createdRuns += 1;
    return ProjectEnvelope(
      projectId: projectId,
      rootPath: '/tmp/demo',
      projectFile: '/tmp/demo/sr-tuner.project.json',
      project: _projectWithWorkflow(),
    );
  }

  @override
  Future<ProjectEnvelope> deleteRunConfig({
    required String projectId,
    required String runId,
  }) async {
    deletedRuns += 1;
    return ProjectEnvelope(
      projectId: projectId,
      rootPath: '/tmp/demo',
      projectFile: '/tmp/demo/sr-tuner.project.json',
      project: _projectWithWorkflow(),
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
    return TrainingEstimate(
      available: true,
      estimatedTimeSeconds: 1800,
      iterationsPerEpoch: 120,
      vramPeakBytes: 2147483648,
      ramPeakBytes: 4294967296,
      diskPerCheckpointBytes: 10485760,
      unsupportedLosses: const [],
      suggestedFixes: const [],
      retention: const {'keep_best': true},
      ema: null,
    );
  }

  @override
  Future<LiveRunDetail> liveRunDetail(String projectId) async {
    return LiveRunDetail(
      active: liveRun,
      run: liveRun ? _run(active: true) : null,
      epochProgress: 0.45,
      runProgress: 0.42,
      phase: liveRun ? 'training' : 'idle',
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
        'val_ssim': MetricDefinition(
          name: 'val_ssim',
          label: 'SSIM',
          kind: 'quality',
          unit: null,
        ),
      },
      records: [
        MetricRecord(
          step: 1,
          epoch: 1,
          iteration: 1,
          values: const {
            'train_loss_total': 0.2,
            'val_psnr': 27.0,
            'val_ssim': 0.81,
          },
        ),
        MetricRecord(
          step: 2,
          epoch: 2,
          iteration: 42,
          values: const {
            'train_loss_total': 0.12,
            'val_psnr': 28.4,
            'val_ssim': 0.86,
          },
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
    int previewIndex = 0,
  }) async {
    lastPreviewIndex = previewIndex;
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

  @override
  Future<CheckpointAggregate> checkpointAggregate(String projectId) async {
    return CheckpointAggregate(
      checkpoints: [
        CheckpointSummary(
          id: 'ckpt_1',
          runId: 'run_1',
          epoch: 42,
          iteration: 4200,
          path: '/tmp/demo/checkpoints/ckpt-ep42.pt',
          sizeBytes: 67000000,
          savedAt: '2024-01-01T12:42:00Z',
          metrics: const {
            'val_psnr': 28.94,
            'val_ssim': 0.871,
            'val_lpips': 0.092,
          },
          tags: const ['best_psnr', 'manual'],
          deleted: false,
          modelArchitecture: 'internal_residual_pixelshuffle',
          scale: 4,
        ),
        CheckpointSummary(
          id: 'ckpt_2',
          runId: 'run_1',
          epoch: 40,
          iteration: 4000,
          path: '/tmp/demo/checkpoints/ckpt-ep40.pt',
          sizeBytes: 67000000,
          savedAt: '2024-01-01T11:20:00Z',
          metrics: const {
            'val_psnr': 28.82,
            'val_ssim': 0.868,
            'val_lpips': 0.094,
          },
          tags: const [],
          deleted: false,
          modelArchitecture: 'internal_residual_pixelshuffle',
          scale: 4,
        ),
      ],
      bestCheckpoint: CheckpointSummary(
        id: 'ckpt_1',
        runId: 'run_1',
        epoch: 42,
        iteration: 4200,
        path: '/tmp/demo/checkpoints/ckpt-ep42.pt',
        sizeBytes: 67000000,
        savedAt: '2024-01-01T12:42:00Z',
        metrics: const {
          'val_psnr': 28.94,
          'val_ssim': 0.871,
          'val_lpips': 0.092,
        },
        tags: const ['best_psnr', 'manual'],
        deleted: false,
        modelArchitecture: 'internal_residual_pixelshuffle',
        scale: 4,
      ),
      psnrDelta: 4.89,
      actions: {
        'export_best': ActionState(
          id: 'export_best',
          label: 'Export best',
          supported: true,
        ),
        'continue_from_best': ActionState(
          id: 'continue',
          label: 'Continue from best',
          supported: true,
        ),
        'prune': ActionState(id: 'prune', label: 'Prune', supported: true),
      },
    );
  }

  @override
  Future<InferenceReadiness> inferenceReadiness({String device = 'cpu'}) async {
    return InferenceReadiness(
      available: true,
      message: 'Inference dependencies are ready.',
      dependencies: const [],
    );
  }

  @override
  Future<InferenceInspector> inferenceInspector(String projectId) async {
    return InferenceInspector(
      blockedChecklist: const [],
      inspector: const {
        'bit_depth': 16,
        'psnr_gain': 5.2,
        'sharpness_gain': 0.38,
        'runtime_seconds': 2.4,
        'width': 1920,
        'height': 1280,
      },
      recent: const [],
      addTileAction: ActionState(
        id: 'add_tile',
        label: 'Add tile',
        supported: true,
      ),
      batchDropZone: ActionState(
        id: 'batch_drop',
        label: 'Batch drop',
        supported: true,
      ),
      tuning: {
        'denoise_strength': UnsupportedState(
          supported: true,
          reason: '',
          code: '',
          message: '',
        ),
        'detail_boost': UnsupportedState(
          supported: true,
          reason: '',
          code: '',
          message: '',
        ),
        'color_preserve': UnsupportedState(
          supported: true,
          reason: '',
          code: '',
          message: '',
        ),
      },
      compareView: const {},
    );
  }

  @override
  Future<InferenceHistoryEnvelope> listInferenceHistory(
    String projectId,
  ) async {
    return InferenceHistoryEnvelope(records: const []);
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
    batchSize: 16,
    checkpointCadence: 1,
    logDir: '/tmp/demo/logs',
  );
}
