import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../project_models.dart';
import '../shared_widgets.dart';
import 'checkpoints_tab.dart';
import 'dataset_tab.dart';
import 'inference_tab.dart';
import 'live_metrics_tab.dart';
import 'model_tab.dart';
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
  String? _inferenceHandoffCheckpointId;

  static const _tabs = [
    'Dataset Setup',
    'Model Config',
    'Training Setup',
    'Live Metrics',
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
  }

  @override
  void didUpdateWidget(ProjectWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.project.selectedTab.clamp(0, _tabs.length - 1);
    if (selected != _tabController.index) {
      _tabController.index = selected;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                widget.project.rootPath,
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close project',
            onPressed: widget.onCloseProject,
            icon: const Icon(Icons.close),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [for (final tab in _tabs) Tab(text: tab)],
        ),
      ),
      body: Column(
        children: [
          ApiErrorBanner(error: widget.error),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DatasetTab(
                  client: widget.client,
                  project: widget.project,
                  onProjectChanged: widget.onProjectChanged,
                ),
                ModelTab(
                  client: widget.client,
                  project: widget.project,
                  onProjectChanged: widget.onProjectChanged,
                ),
                TrainingTab(
                  client: widget.client,
                  project: widget.project,
                  onProjectChanged: widget.onProjectChanged,
                ),
                LiveMetricsTab(client: widget.client, project: widget.project),
                CheckpointsTab(
                  client: widget.client,
                  project: widget.project,
                  onInferenceHandoff: (checkpointId) {
                    setState(() => _inferenceHandoffCheckpointId = checkpointId);
                    _tabController.animateTo(5);
                  },
                ),
                InferenceTab(
                  client: widget.client,
                  project: widget.project,
                  initialCheckpointId: _inferenceHandoffCheckpointId,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0xff0b0e10),
        child: Row(
          children: [
            Text(
              widget.project.name,
              style: const TextStyle(color: Color(0xff58c48a)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.project.rootPath,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const Text(
              'local backend',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
