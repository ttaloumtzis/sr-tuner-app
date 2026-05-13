import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'backend_client.dart';
import 'backend_process.dart';
import 'diagnostic_logger.dart';
import 'logging_schema.dart';
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
  final _log = DiagnosticLogger(component: Components.frontend, minimumLevel: LogLevel.info);

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
      _backend.killSync();
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
    _client.beginCorrelatedAction();
    _log.info(EventNames.workflowAction, 'Restoring project from last session.', context: {'path': lastPath});
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
      _log.error(EventNames.workflowError, 'Project action failed: ${error.message}', context: {
        'code': error.code,
        'status_code': error.statusCode,
        'correlation_id': error.correlationId,
      });
      _error = error;
    } catch (error) {
      _log.error(EventNames.workflowError, 'Unexpected project action error: $error');
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
    _client.beginCorrelatedAction();
    _log.info(EventNames.workflowAction, 'Loading recent projects.');
    try {
      await _backend.ensureStarted();
      final envelope = await _client.recentProjects();
      if (mounted) {
        setState(() => _recentProjects = envelope.projects);
      }
      _log.info(EventNames.workflowAction, 'Recent projects loaded.', context: {'count': envelope.projects.length});
    } catch (_) {
      if (mounted) {
        setState(() => _recentProjects = const []);
      }
    }
  }

  Future<void> _forgetRecentProject(String path) async {
    _client.beginCorrelatedAction();
    _log.info(EventNames.workflowAction, 'Forgetting recent project.', context: {'path': path});
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
    _client.beginCorrelatedAction();
    _log.info(EventNames.workflowAction, 'Creating project.', context: {
      'parent_path': parentPath,
      'name': name,
      'create_here': createHere,
    });
    await _runProjectAction(() async {
      await _backend.ensureStarted();
      final envelope = await _client.createProject(
        parentPath: parentPath,
        name: name,
        createHere: createHere,
      );
      _project = envelope.project;
      _log.info(EventNames.workflowAction, 'Project created.', context: {'project_id': _project?.id, 'project_name': name});
    });
  }

  Future<void> _openProject(String path) async {
    _client.beginCorrelatedAction();
    _log.info(EventNames.workflowAction, 'Opening project.', context: {'path': path});
    await _runProjectAction(() async {
      await _backend.ensureStarted();
      final envelope = await _client.openProject(path);
      _project = envelope.project;
      _log.info(EventNames.workflowAction, 'Project opened.', context: {'project_id': _project?.id});
    });
  }

  Future<void> _saveSelectedTab(int index) async {
    final project = _project;
    if (project == null) {
      return;
    }
    try {
      _log.info(EventNames.workflowAction, 'Saving selected tab.', context: {'tab_index': index, 'project_id': project.id});
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
    _log.info(EventNames.backendShutdown, 'Project controller disposing.');
    _backend.killSync();
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
    _log.info(EventNames.backendShutdown, 'Shutting down backend and releasing resources.');
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
      onRetry: _restoreProject,
    );
  }
}
