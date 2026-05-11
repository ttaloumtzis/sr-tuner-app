import 'dart:io';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'backend_client.dart';
import 'path_picker.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    required this.busy,
    required this.error,
    required this.onCreate,
    required this.onOpen,
    super.key,
  });

  final bool busy;
  final ApiException? error;
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

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    _parentController = TextEditingController(text: '$home/projects');
    _nameController = TextEditingController(text: 'sr_project');
    _openController = TextEditingController();
  }

  @override
  void dispose() {
    _parentController.dispose();
    _nameController.dispose();
    _openController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppConfig.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Local super-resolution workstation',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ActionPanel(
                        title: 'Create Project',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _parentController,
                                  decoration: const InputDecoration(
                                    labelText: 'Parent folder',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Select parent folder',
                                onPressed: widget.busy
                                    ? null
                                    : _pickCreateParent,
                                icon: const Icon(Icons.folder_open),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Project name',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: widget.busy
                                ? null
                                : () => widget.onCreate(
                                    _parentController.text.trim(),
                                    _nameController.text.trim(),
                                  ),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Project'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionPanel(
                        title: 'Open Project',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _openController,
                                  decoration: const InputDecoration(
                                    labelText: 'Project folder',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: 'Select project folder',
                                onPressed: widget.busy ? null : _pickOpenFolder,
                                icon: const Icon(Icons.folder_open),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: widget.busy
                                ? null
                                : () => widget.onOpen(
                                    _openController.text.trim(),
                                  ),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Open Project'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.busy) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(),
                ],
                if (widget.error != null) ...[
                  const SizedBox(height: 24),
                  SelectableText(
                    widget.error!.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
