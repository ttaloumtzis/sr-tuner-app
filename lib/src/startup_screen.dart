import 'dart:io';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'backend_client.dart';
import 'classic_components.dart';
import 'path_picker.dart';
import 'project_models.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    required this.busy,
    required this.error,
    required this.recentProjects,
    required this.onRefreshRecent,
    required this.onForgetRecent,
    required this.onCreate,
    required this.onOpen,
    super.key,
  });

  final bool busy;
  final ApiException? error;
  final List<RecentProject> recentProjects;
  final Future<void> Function() onRefreshRecent;
  final Future<void> Function(String path) onForgetRecent;
  final Future<void> Function(String parentPath, String name, {bool createHere})
  onCreate;
  final Future<void> Function(String path) onOpen;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _picker = const PathPicker();
  late final TextEditingController _parentController;
  late final TextEditingController _nameController;
  late final TextEditingController _openController;
  late final TextEditingController _searchController;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    _parentController = TextEditingController(text: '$home/projects');
    _nameController = TextEditingController(text: 'sr_project');
    _openController = TextEditingController();
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _parentController.dispose();
    _nameController.dispose();
    _openController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCreateParent() async {
    final path = await _picker.pickFolder(confirmButtonText: 'Select folder');
    if (path != null) {
      _parentController.text = path;
    }
  }

  Future<void> _pickOpenFolder() async {
    final path = await _picker.pickFolder(confirmButtonText: 'Open project');
    if (path != null) {
      _openController.text = path;
      await widget.onOpen(path);
    }
  }

  List<RecentProject> get _filteredRecent {
    final query = _searchController.text.trim().toLowerCase();
    return [
      for (final project in widget.recentProjects)
        if ((_filter == 'all' || project.status == _filter) &&
            (query.isEmpty ||
                project.name.toLowerCase().contains(query) ||
                project.path.toLowerCase().contains(query)))
          project,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.all(tokens.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(error: widget.error),
                  SizedBox(height: tokens.gap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 860;
                        final left = _CreateOpenColumn(
                          busy: widget.busy,
                          parentController: _parentController,
                          nameController: _nameController,
                          openController: _openController,
                          onPickCreateParent: _pickCreateParent,
                          onPickOpenFolder: _pickOpenFolder,
                          onCreate: widget.onCreate,
                          onOpen: widget.onOpen,
                        );
                        final right = _RecentColumn(
                          busy: widget.busy,
                          searchController: _searchController,
                          filter: _filter,
                          recentProjects: _filteredRecent,
                          onFilterChanged: (value) =>
                              setState(() => _filter = value),
                          onRefresh: widget.onRefreshRecent,
                          onForget: widget.onForgetRecent,
                          onOpen: widget.onOpen,
                        );
                        if (narrow) {
                          return ListView(
                            children: [
                              left,
                              SizedBox(height: tokens.gap),
                              right,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 390, child: left),
                            SizedBox(width: tokens.gap),
                            Expanded(child: right),
                          ],
                        );
                      },
                    ),
                  ),
                  if (widget.busy) ...[
                    SizedBox(height: tokens.compactGap),
                    const SrProgressBar(kind: SrProgressKind.indeterminate),
                  ],
                  SizedBox(height: tokens.compactGap),
                  Text(
                    'Projects are folders. Move the folder when needed; sr-tuner finds the canonical sr-tuner.project.json manifest inside it. .srtproj archive import is planned and disabled in this build.',
                    style: TextStyle(color: tokens.muted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.error});

  final ApiException? error;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 12),
            const SrChip(label: 'Classic Workspace', selected: true),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            SrChip(label: 'Train from paired images', icon: Icons.grid_view),
            SrChip(label: 'Extract frames from video', icon: Icons.movie),
            SrChip(label: 'Run local inference', icon: Icons.auto_awesome),
          ],
        ),
        if (error != null) ...[
          SizedBox(height: tokens.compactGap),
          SrBanner(
            title: error!.code,
            message: error!.message,
            severity: 'error',
            icon: Icons.error_outline,
          ),
        ],
      ],
    );
  }
}

class _CreateOpenColumn extends StatelessWidget {
  const _CreateOpenColumn({
    required this.busy,
    required this.parentController,
    required this.nameController,
    required this.openController,
    required this.onPickCreateParent,
    required this.onPickOpenFolder,
    required this.onCreate,
    required this.onOpen,
  });

  final bool busy;
  final TextEditingController parentController;
  final TextEditingController nameController;
  final TextEditingController openController;
  final VoidCallback onPickCreateParent;
  final VoidCallback onPickOpenFolder;
  final Future<void> Function(String parentPath, String name, {bool createHere})
  onCreate;
  final Future<void> Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SrSection(
          title: 'New project',
          subtitle: 'Create a folder-backed workspace.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PathField(
                controller: parentController,
                label: 'Parent folder',
                onPick: busy ? null : onPickCreateParent,
              ),
              SizedBox(height: tokens.compactGap),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              SizedBox(height: tokens.compactGap),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => onCreate(
                        parentController.text.trim(),
                        nameController.text.trim(),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Create Project'),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.gap),
        SrSection(
          title: 'Open project folder',
          subtitle: 'Select a folder containing sr-tuner.project.json.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PathField(
                controller: openController,
                label: 'Project folder',
                onPick: busy ? null : onPickOpenFolder,
              ),
              SizedBox(height: tokens.compactGap),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => onOpen(openController.text.trim()),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Project'),
              ),
              SizedBox(height: tokens.compactGap),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Import .srtproj archive'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.controller,
    required this.label,
    required this.onPick,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Choose folder',
          onPressed: onPick,
          icon: const Icon(Icons.folder_open),
        ),
      ],
    );
  }
}

class _RecentColumn extends StatelessWidget {
  const _RecentColumn({
    required this.busy,
    required this.searchController,
    required this.filter,
    required this.recentProjects,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onForget,
    required this.onOpen,
  });

  final bool busy;
  final TextEditingController searchController;
  final String filter;
  final List<RecentProject> recentProjects;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String path) onForget;
  final Future<void> Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    return SrSection(
      title: 'Recent projects',
      subtitle: 'Filter local project folders before opening.',
      trailing: IconButton(
        tooltip: 'Refresh recent projects',
        onPressed: busy ? null : onRefresh,
        icon: const Icon(Icons.refresh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search recent projects',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'available', label: Text('Ready')),
                  ButtonSegment(value: 'missing', label: Text('Missing')),
                ],
                selected: {filter},
                onSelectionChanged: (values) => onFilterChanged(values.first),
              ),
            ],
          ),
          SizedBox(height: tokens.compactGap),
          if (recentProjects.isEmpty)
            const SizedBox(
              height: 280,
              child: SrEmptyState(
                title: 'No recent projects',
                message: 'Create or open a project folder to pin it here.',
                icon: Icons.history,
              ),
            )
          else
            SizedBox(
              height: 430,
              child: ListView.separated(
                itemCount: recentProjects.length,
                separatorBuilder: (_, index) =>
                    SizedBox(height: tokens.compactGap),
                itemBuilder: (context, index) {
                  final project = recentProjects[index];
                  return _RecentCard(
                    project: project,
                    busy: busy,
                    onOpen: project.status == 'available'
                        ? () => onOpen(project.path)
                        : null,
                    onForget: () => _confirmForget(context, project),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmForget(
    BuildContext context,
    RecentProject project,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove recent project?'),
        content: Text(
          'This only removes ${project.name} from the recent list. The project folder is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (result == true) {
      await onForget(project.path);
    }
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.project,
    required this.busy,
    required this.onOpen,
    required this.onForget,
  });

  final RecentProject project;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final tokens = srTokens(context);
    final severity = project.status == 'available'
        ? 'success'
        : project.status == 'missing'
        ? 'warning'
        : 'error';
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        padding: EdgeInsets.all(tokens.compactGap),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    project.path,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.muted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      SrChip(label: project.status, severity: severity),
                      SrChip(label: '${project.summary.datasetCount} datasets'),
                      SrChip(label: '${project.summary.runCount} runs'),
                      SrChip(label: '${project.summary.checkpointCount} ckpts'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove from recent projects',
              onPressed: busy ? null : onForget,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              tooltip: onOpen == null ? project.statusMessage : 'Open project',
              onPressed: onOpen,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
