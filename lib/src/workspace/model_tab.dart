import 'package:flutter/material.dart';

import '../backend_client.dart';
import '../project_models.dart';

class ModelTab extends StatefulWidget {
  const ModelTab({
    required this.client,
    required this.project,
    required this.onProjectChanged,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final ValueChanged<ProjectState> onProjectChanged;

  @override
  State<ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends State<ModelTab> {
  final _name = TextEditingController(text: 'internal_x4');
  int _scale = 4;
  int _features = 32;
  int _blocks = 4;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final envelope = await widget.client.createModel(
        projectId: widget.project.id,
        name: _name.text.trim(),
        scale: _scale,
        numFeatures: _features,
        numBlocks: _blocks,
      );
      widget.onProjectChanged(envelope.project);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create Model',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _scale,
                      decoration: const InputDecoration(labelText: 'Scale'),
                      items: const [2, 3, 4, 8]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('x$value'),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _scale = value ?? 4),
                    ),
                    const SizedBox(height: 12),
                    _NumberStepper(
                      label: 'Features',
                      value: _features,
                      min: 8,
                      max: 256,
                      step: 8,
                      onChanged: (value) => setState(() => _features = value),
                    ),
                    const SizedBox(height: 12),
                    _NumberStepper(
                      label: 'Blocks',
                      value: _blocks,
                      min: 1,
                      max: 64,
                      step: 1,
                      onChanged: (value) => setState(() => _blocks = value),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Model'),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
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
          const SizedBox(width: 16),
          Expanded(child: _ModelList(models: widget.project.models)),
        ],
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({required this.models});

  final List<ModelSummary> models;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return const Center(child: Text('No models yet.'));
    }
    return ListView.separated(
      itemCount: models.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final model = models[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.memory),
            title: Text(model.name),
            subtitle: Text(
              '${model.architecture} · x${model.scale} · ${model.numFeatures} features · ${model.numBlocks} blocks',
            ),
            trailing: Text(model.status),
          ),
        );
      },
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('$label: $value')),
        IconButton.outlined(
          tooltip: 'Decrease $label',
          onPressed: value <= min ? null : () => onChanged(value - step),
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Increase $label',
          onPressed: value >= max ? null : () => onChanged(value + step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
