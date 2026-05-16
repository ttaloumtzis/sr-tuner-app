import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../classic_components.dart';
import '../polling.dart';
import '../project_models.dart';
import '../shared_widgets.dart';
import 'checkpoints_tab.dart';
import 'dataset_tab.dart';
import 'inference_tab.dart';
import 'live_metrics_tab.dart';
import 'model_tab.dart';
import 'overview_tab.dart';
import 'training_tab.dart';

class ProjectWorkspace extends StatefulWidget {
  const ProjectWorkspace({
    required this.client,
    required this.project,
    required this.error,
    required this.onTabChanged,
    required this.onProjectChanged,
    required this.onCloseProject,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ApiException? error;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<ProjectState> onProjectChanged;
  final VoidCallback onCloseProject;

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BoundedPoller<DashboardSummary>? _dashboardPoller;
  DashboardSummary? _dashboard;
  String? _inferenceHandoffCheckpointId;
  String? _fineTuneHandoffCheckpointId;
  String? _fineTuneHandoffCoreWeightsPath;
  bool _dashboardError = false;
  final PageStorageBucket _tabStorage = PageStorageBucket();

  static const _tabs = [
    'Overview',
    'Dataset',
    'Model',
    'Training',
    'Live',
    'Checkpoints',
    'Inference',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.project.selectedTab.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_onTabChanged);
    _startDashboardPolling();
  }

  @override
  void didUpdateWidget(ProjectWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.project.selectedTab.clamp(0, _tabs.length - 1);
    if (selected != _tabController.index) {
      _tabController.index = selected;
    }
    if (oldWidget.project.id != widget.project.id) {
      _startDashboardPolling();
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      widget.onTabChanged(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _dashboardPoller?.stop();
    super.dispose();
  }

  void _startDashboardPolling() {
    _dashboardPoller?.stop();
    _dashboardPoller = BoundedPoller<DashboardSummary>(
      interval: const Duration(seconds: 5),
      fetch: () => widget.client.dashboardSummary(widget.project.id),
      onData: (value) {
        if (mounted) {
          setState(() {
            _dashboard = value;
            _dashboardError = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _dashboardError = true);
      },
    )..start();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Scaffold(
      body: Column(
        children: [
          _ProjectHeader(
            project: widget.project,
            dashboard: _dashboard,
            onCloseProject: widget.onCloseProject,
            onSaveWorkspace: _saveWorkspacePreference,
          ),
          Container(
            decoration: BoxDecoration(
              color: tokens.panel,
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (var index = 0; index < _tabs.length; index++)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_tabs[index]),
                        if (index == 4 &&
                            (_dashboard?.activeRunState == 'running')) ...[
                          const SizedBox(width: 6),
                          const _LiveBadge(),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          ApiErrorBanner(error: widget.error),
          Expanded(
            child: PageStorage(
              bucket: _tabStorage,
              child: TabBarView(
                controller: _tabController,
                children: [
                  OverviewTab(
                    key: const PageStorageKey('overview-tab'),
                    client: widget.client,
                    project: widget.project,
                    onNavigateToTab: _navigateToTab,
                  ),
                  DatasetTab(
                    key: const PageStorageKey('dataset-tab'),
                    client: widget.client,
                    project: widget.project,
                    onProjectChanged: widget.onProjectChanged,
                  ),
                  ModelTab(
                    key: const PageStorageKey('model-tab'),
                    client: widget.client,
                    project: widget.project,
                    onProjectChanged: widget.onProjectChanged,
                    onNavigateToTab: _navigateToTab,
                  ),
                  TrainingTab(
                    key: const PageStorageKey('training-tab'),
                    client: widget.client,
                    project: widget.project,
                    onProjectChanged: widget.onProjectChanged,
                    initialFineTuneCheckpointId: _fineTuneHandoffCheckpointId,
                    initialFineTuneCoreWeightsPath: _fineTuneHandoffCoreWeightsPath,
                  ),
                  LiveMetricsTab(
                    key: const PageStorageKey('live-tab'),
                    client: widget.client,
                    project: widget.project,
                  ),
                  CheckpointsTab(
                    key: const PageStorageKey('checkpoints-tab'),
                    client: widget.client,
                    project: widget.project,
                    onNavigateToTab: _navigateToTab,
                    onInferenceHandoff: (checkpointId) {
                      setState(
                        () => _inferenceHandoffCheckpointId = checkpointId,
                      );
                      _navigateToTab(6);
                    },
                    onFineTuneHandoff: (checkpointId, coreWeightsPath) {
                      setState(() {
                        _fineTuneHandoffCheckpointId = checkpointId;
                        _fineTuneHandoffCoreWeightsPath = coreWeightsPath;
                      });
                      _navigateToTab(3);
                    },
                  ),
                  InferenceTab(
                    key: const PageStorageKey('inference-tab'),
                    client: widget.client,
                    project: widget.project,
                    initialCheckpointId: _inferenceHandoffCheckpointId,
                    onHandoffConsumed: () => setState(() => _inferenceHandoffCheckpointId = null),
                  ),
                ],
              ),
            ),
          ),
          _StatusBar(project: widget.project, dashboard: _dashboard, dashboardError: _dashboardError),
        ],
      ),
    );
  }

  void _navigateToTab(int index) {
    final bounded = index.clamp(0, _tabs.length - 1);
    _tabController.animateTo(bounded);
    widget.onTabChanged(bounded);
  }

  Future<void> _saveWorkspacePreference({
    String? theme,
    String? density,
  }) async {
    try {
      final envelope = await widget.client.saveWorkspace(
        projectId: widget.project.id,
        theme: theme,
        density: density,
      );
      widget.onProjectChanged(envelope.project);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 1500),
            content: Text('Preferences saved.'),
          ),
        );
      }
    } on ApiException {
      return;
    }
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.dashboard,
    required this.onCloseProject,
    required this.onSaveWorkspace,
  });

  final ProjectState project;
  final DashboardSummary? dashboard;
  final VoidCallback onCloseProject;
  final Future<void> Function({String? theme, String? density}) onSaveWorkspace;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final summary = dashboard == null
        ? '${project.datasetCount} datasets · ${project.modelCount} models · ${project.runCount} runs'
        : '${dashboard!.datasetCount} datasets · ${dashboard!.modelCount} models · ${dashboard!.runCount} runs · ${dashboard!.datasetPairTotal} pairs';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.gap,
        vertical: tokens.compactGap,
      ),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Project menu',
            onSelected: (value) {
              if (value == 'close') {
                onCloseProject();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'close', child: Text('Close project')),
              PopupMenuItem(
                enabled: false,
                child: Text('Export .srtproj archive unavailable'),
              ),
              PopupMenuItem(
                enabled: false,
                child: Text('Reveal in file manager unavailable'),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              summary,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted),
            ),
          ),
          Tooltip(
            message:
                'Native desktop window chrome is used; no custom titlebar.',
            child: SrChip(
              label: dashboard?.backendStatus ?? 'backend',
              severity: dashboard?.backendStatus == 'ok' ? 'success' : 'error',
              icon: Icons.dns_outlined,
            ),
          ),
          const SizedBox(width: 8),
          SrChip(label: dashboard?.deviceBadge ?? 'CPU', icon: Icons.memory),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Workspace settings',
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              switch (value) {
                case 'theme_light':
                  onSaveWorkspace(theme: 'light');
                case 'theme_dark':
                  onSaveWorkspace(theme: 'dark');
                case 'density_compact':
                  onSaveWorkspace(density: 'compact');
                case 'density_comfortable':
                  onSaveWorkspace(density: 'comfortable');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'theme_light', child: Text('Theme: light')),
              PopupMenuItem(value: 'theme_dark', child: Text('Theme: dark')),
              PopupMenuItem(
                value: 'density_compact',
                child: Text('Density: compact'),
              ),
              PopupMenuItem(
                value: 'density_comfortable',
                child: Text('Density: comfortable'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Close project',
            onPressed: onCloseProject,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return const SrChip(label: 'LIVE', severity: 'success', selected: true);
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.project,
    required this.dashboard,
    this.dashboardError = false,
  });

  final ProjectState project;
  final DashboardSummary? dashboard;
  final bool dashboardError;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final status = dashboard?.statusBar;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SrChip(
            label: status?.busyState ?? 'idle',
            severity: status?.busyState == 'busy' ? 'warning' : 'success',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status?.projectPath ?? project.rootPath,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.muted),
            ),
          ),
          if (status?.vcsBranch != null) ...[
            const SrKeyboardHint('git'),
            const SizedBox(width: 6),
            Text(status!.vcsBranch!, style: TextStyle(color: tokens.muted)),
            const SizedBox(width: 12),
          ],
          if (dashboardError) ...[
            Tooltip(
              message: 'Dashboard unavailable — retrying…',
              child: Icon(Icons.sync_problem, color: tokens.muted, size: 14),
            ),
            const SizedBox(width: 10),
          ],
          if (status?.diskWarning == true) ...[
            Icon(Icons.warning_amber, color: tokens.warning, size: 16),
            const SizedBox(width: 4),
            Text('Low disk', style: TextStyle(color: tokens.warning)),
            const SizedBox(width: 12),
          ],
          Text(
            status?.appVersion ?? 'local backend',
            style: TextStyle(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}
