import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'backend_client.dart';
import 'backend_process.dart';
import 'project_models.dart';
import 'startup_screen.dart';
import 'workspace/project_workspace.dart';
import 'workspace_store.dart';

class ProjectController extends StatefulWidget {
  const ProjectController({super.key});

  @override
  State<ProjectController> createState() => _ProjectControllerState();
}

class _ProjectControllerState extends State<ProjectController>
    with WidgetsBindingObserver {
  final _client = BackendClient();
  final _store = WorkspaceStore();
  late final BackendProcess _backend = BackendProcess(_client);

  ProjectState? _project;
  List<RecentProject> _recentProjects = const [];
  ApiException? _error;
  bool _busy = true;
  Future<void>? _disposeFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreProject());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_disposeResources());
    }
  }

  Future<void> _restoreProject() async {
    final lastPath = await _store.readLastProjectPath();
    if (lastPath == null || !Directory(lastPath).existsSync()) {
      setState(() => _busy = false);
      unawaited(_loadRecentProjects());
      return;
    }
    await _runProjectAction(() async {
      await _backend.ensureStarted();
      final envelope = await _client.openProject(lastPath);
      _project = envelope.project;
    });
  }

  Future<void> _runProjectAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final project = _project;
      if (project != null) {
        await _store.saveLastProjectPath(project.rootPath);
      }
    } on ApiException catch (error) {
      _error = error;
    } catch (error) {
      _error = ApiException(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      if (_project == null) {
        unawaited(_loadRecentProjects());
      }
    }
  }

  Future<void> _loadRecentProjects() async {
    try {
      await _backend.ensureStarted();
      final envelope = await _client.recentProjects();
      if (mounted) {
        setState(() => _recentProjects = envelope.projects);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recentProjects = const []);
      }
    }
  }

  Future<void> _forgetRecentProject(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _backend.ensureStarted();
      final envelope = await _client.forgetRecentProject(path);
      if (mounted) {
        setState(() => _recentProjects = envelope.projects);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } catch (error) {
      setState(() => _error = ApiException(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createProject(
    String parentPath,
    String name, {
    bool createHere = false,
  }) async {
    await _runProjectAction(() async {
      await _backend.ensureStarted();
      final envelope = await _client.createProject(
        parentPath: parentPath,
        name: name,
        createHere: createHere,
      );
      _project = envelope.project;
    });
  }

  Future<void> _openProject(String path) async {
    await _runProjectAction(() async {
      await _backend.ensureStarted();
      final envelope = await _client.openProject(path);
      _project = envelope.project;
    });
  }

  Future<void> _saveSelectedTab(int index) async {
    final project = _project;
    if (project == null) {
      return;
    }
    try {
      final envelope = await _client.saveWorkspace(
        projectId: project.id,
        selectedTab: index,
      );
      setState(() => _project = envelope.project);
    } on ApiException catch (error) {
      setState(() => _error = error);
    } catch (error) {
      setState(() => _error = ApiException(error.toString()));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _disposeResourcesOnce();
    _disposeFuture = future;
    return future;
  }

  Future<void> _disposeResourcesOnce() async {
    await _backend.dispose();
    _client.close();
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    if (project != null) {
      return ProjectWorkspace(
        client: _client,
        project: project,
        error: _error,
        onTabChanged: _saveSelectedTab,
        onProjectChanged: (value) async {
          await _store.saveLastProjectPath(value.rootPath);
          setState(() => _project = value);
        },
        onCloseProject: () {
          setState(() => _project = null);
          unawaited(_loadRecentProjects());
        },
      );
    }
    return StartupScreen(
      busy: _busy,
      error: _error,
      recentProjects: _recentProjects,
      onRefreshRecent: _loadRecentProjects,
      onForgetRecent: _forgetRecentProject,
      onCreate: _createProject,
      onOpen: _openProject,
    );
  }
}
