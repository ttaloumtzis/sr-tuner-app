import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;

import '../backend_client.dart';
import '../classic_components.dart' hide SrChip;
import '../classic_theme.dart';
import '../design_system/sr_button.dart';
import '../design_system/sr_chip.dart';
import '../path_picker.dart' show PathPicker;
import '../project_models.dart';

class InferenceTab extends StatefulWidget {
  const InferenceTab({
    required this.client,
    required this.project,
    this.initialCheckpointId,
    this.onHandoffConsumed,
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final String? initialCheckpointId;
  final VoidCallback? onHandoffConsumed;

  @override
  State<InferenceTab> createState() => _InferenceTabState();
}

class _InferenceTabState extends State<InferenceTab> {
  CheckpointAggregate? _aggregate;
  CheckpointSummary? _selectedCheckpoint;
  String _inputPath = '';
  String? _outputDir;
  int _scale = 4;
  bool _tilingEnabled = true;
  int _tileSize = 384;
  
  bool _sliderMode = true;
  double _sliderPosition = 0.5;
  
  String _outputFormat = 'png';
  int _bitDepth = 16;
  String _filename = '';
  
  double? _psnrGain;
  double? _sharpnessGain;
  double? _inferenceTime;
  int? _outputWidth;
  int? _outputHeight;
  
  bool _running = false;
  String? _error;
  InferenceRecord? _lastResult;
  
  InferenceReadiness? _readiness;
  InferenceInspector? _inspector;
  List<DeviceOption> _devices = [];
  String _device = 'cpu';

  String? _jobId;
  double _jobProgress = 0.0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAggregate();
    _loadDevices();
    _loadReadiness();
    _loadInspector();
    if (widget.initialCheckpointId != null) {
      _preselectCheckpoint(widget.initialCheckpointId!);
    }
  }

  Future<void> _loadInspector() async {
    try {
      final inspector = await widget.client.inferenceInspector(widget.project.id);
      if (mounted) setState(() => _inspector = inspector);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(InferenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCheckpointId != widget.initialCheckpointId &&
        widget.initialCheckpointId != null) {
      _preselectCheckpoint(widget.initialCheckpointId!);
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.client.devices();
      if (mounted) {
        setState(() {
          _devices = devices;
          if (_device == 'auto') {
            final preferred = devices
                .where((d) => d.id != 'cpu' && d.available)
                .firstOrNull
                ?.id;
            _device = preferred ?? devices.first.id;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadReadiness() async {
    try {
      final r = await widget.client.inferenceReadiness(device: _device);
      if (mounted) setState(() => _readiness = r);
    } catch (_) {}
  }

  Future<void> _loadAggregate() async {
    try {
      final aggregate = await widget.client.checkpointAggregate(widget.project.id);
      if (mounted) {
        setState(() {
          _aggregate = aggregate;
          // Auto-select best checkpoint if none selected
          if (_selectedCheckpoint == null && aggregate.bestCheckpoint != null) {
            _selectedCheckpoint = aggregate.bestCheckpoint;
          }
        });
      }
    } catch (_) {}
  }



  
  
  
  @override
  Widget build(BuildContext context) {
    final checkpoints = _aggregate?.checkpoints.where((c) => !c.deleted).toList() ?? [];
    if (checkpoints.isEmpty) {
      return _InferenceBlockedTab(
        readiness: _readiness,
        project: widget.project,
        onNavigateToTab: _navigateToTab,
      );
    }

    return Column(
      children: [
        if (_error != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _error = null),
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        if (_readiness != null && !_readiness!.available)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _readiness!.message,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _InferenceHeader(
          selectedCheckpoint: _selectedCheckpoint,
          checkpoints: checkpoints,
          scale: _scale,
          tilingEnabled: _tilingEnabled,
          tileSize: _tileSize,
          device: _device,
          devices: _devices,
          onCheckpointChanged: (checkpoint) {
            setState(() => _selectedCheckpoint = checkpoint);
          },
          onScaleChanged: (scale) {
            setState(() => _scale = scale);
          },
          onTilingChanged: (enabled) {
            setState(() => _tilingEnabled = enabled);
          },
          onTileSizeChanged: (size) {
            setState(() => _tileSize = size);
          },
          onDeviceChanged: (value) {
            setState(() => _device = value);
          },
          onBatchFolder: _pickBatchFolder,
          onSelectImage: _selectImage,
          onSaveResult: _saveResult,
          onRunInference: _runInference,
          running: _running,
          jobProgress: _jobProgress,
          onCancel: _cancelInference,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _CompareViewer(
                  sliderMode: _sliderMode,
                  sliderPosition: _sliderPosition,
                  lastResult: _lastResult,
                  inputPath: _inputPath,
                  inspector: _inspector,
                  onModeChanged: (mode) {
                    setState(() => _sliderMode = mode);
                  },
                  onSliderChanged: (position) {
                    setState(() => _sliderPosition = position);
                  },

                ),
              ),
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).extension<SrTokens>()!.border,
                    ),
                  ),
                ),
                child: _OutputInspector(
                  outputFormat: _outputFormat,
                  bitDepth: _bitDepth,
                  filename: _filename,
                  outputWidth: _outputWidth,
                  outputHeight: _outputHeight,
                  psnrGain: _psnrGain,
                  sharpnessGain: _sharpnessGain,
                  inferenceTime: _inferenceTime,
                  inspector: _inspector,
                  hasOutput: _lastResult?.outputPath != null,
                  onFormatChanged: (format) {
                    setState(() => _outputFormat = format);
                  },
                  onBitDepthChanged: (depth) {
                    setState(() => _bitDepth = depth);
                  },
                  onSaveOutput: _saveResult,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToTab(int tabIndex) {
    // Handled by parent via tab change
  }

  Future<void> _runInference() async {
    if (_selectedCheckpoint == null || _inputPath.isEmpty) return;
    _stopPolling();
    setState(() {
      _running = true;
      _jobId = null;
      _jobProgress = 0.0;
    });
    try {
      final result = await widget.client.runInference(
        projectId: widget.project.id,
        runId: _selectedCheckpoint!.runId,
        checkpointId: _selectedCheckpoint!.id,
        inputPath: _inputPath,
        outputDir: _outputDir,
        outputFormat: _outputFormat,
        mode: 'single',
        device: _device,
      );
      if (mounted) {
        setState(() {
          _running = false;
          _jobProgress = 1.0;
          _lastResult = result;
        });
        _startPolling(result.jobId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = e.toString();
        });
      }
    }
  }

  void _startPolling(String? jobId) {
    if (jobId == null || jobId.isEmpty) return;
    _jobId = jobId;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final job = await widget.client.getJob(jobId);
        if (!mounted) { _stopPolling(); return; }
        setState(() => _jobProgress = job.progress);
        if (job.isTerminal) _stopPolling();
      } catch (_) { _stopPolling(); }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _cancelInference() async {
    final jobId = _jobId;
    if (jobId == null) return;
    try { await widget.client.cancelJob(jobId); } catch (_) {}
  }

  Future<void> _selectImage() async {
    final path = await const PathPicker().pickFile();
    if (path != null && mounted) {
      setState(() {
        _inputPath = path;
        _filename = path.split('/').last;
      });
    }
  }

  Future<void> _pickBatchFolder() async {
    final path = await const PathPicker().pickFolder(confirmButtonText: 'Select batch folder');
    if (path != null && mounted) {
      setState(() => _inputPath = path);
    }
  }

  Future<void> _saveResult() async {
    final result = _lastResult;
    if (result == null || result.outputPath == null || result.outputPath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No result to save.')),
        );
      }
      return;
    }
    final destDir = await const PathPicker().pickFolder(confirmButtonText: 'Save result here');
    if (destDir == null || !mounted) return;
    try {
      final src = File(result.outputPath!);
      final filename = result.outputPath!.split('/').last;
      final dest = '$destDir/$filename';
      await src.copy(dest);
      if (mounted) {
        setState(() {
          _inputPath = '';
          _filename = '';
          _lastResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $dest')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _preselectCheckpoint(String checkpointId) {
    final checkpoint = _aggregate?.checkpoints.firstWhere(
      (c) => c.id == checkpointId && !c.deleted,
      orElse: () => _aggregate!.checkpoints.firstWhere((c) => !c.deleted),
    );
    if (mounted) {
      setState(() => _selectedCheckpoint = checkpoint);
      widget.onHandoffConsumed?.call();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

// ── Widget Classes ─────────────────────────────────────────────────────────────

class _InferenceHeader extends StatelessWidget {
  const _InferenceHeader({
    required this.selectedCheckpoint,
    required this.checkpoints,
    required this.scale,
    required this.tilingEnabled,
    required this.tileSize,
    required this.device,
    required this.devices,
    required this.onCheckpointChanged,
    required this.onScaleChanged,
    required this.onTilingChanged,
    required this.onTileSizeChanged,
    required this.onDeviceChanged,
    required this.onBatchFolder,
    required this.onSelectImage,
    required this.onSaveResult,
    required this.onRunInference,
    required this.running,
    required this.jobProgress,
    required this.onCancel,
  });

  final CheckpointSummary? selectedCheckpoint;
  final List<CheckpointSummary> checkpoints;
  final int scale;
  final bool tilingEnabled;
  final int tileSize;
  final String device;
  final List<DeviceOption> devices;
  final ValueChanged<CheckpointSummary> onCheckpointChanged;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<bool> onTilingChanged;
  final ValueChanged<int> onTileSizeChanged;
  final ValueChanged<String> onDeviceChanged;
  final VoidCallback onBatchFolder;
  final VoidCallback onSelectImage;
  final VoidCallback onSaveResult;
  final VoidCallback onRunInference;
  final bool running;
  final double jobProgress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: _ModelField(
              selectedCheckpoint: selectedCheckpoint,
              checkpoints: checkpoints,
              onChanged: onCheckpointChanged,
            ),
          ),
          const SizedBox(width: 12),
          
          SizedBox(
            width: 80,
            child: _ScaleField(
              scale: scale,
              onChanged: onScaleChanged,
            ),
          ),
          const SizedBox(width: 12),
          
          SizedBox(
            width: 140,
            child: _TileField(
              enabled: tilingEnabled,
              tileSize: tileSize,
              onEnabledChanged: onTilingChanged,
              onSizeChanged: onTileSizeChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: device,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelText: 'Device',
              ),
              items: [
                for (final d in devices)
                  DropdownMenuItem(value: d.id, child: Text(d.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) { if (v != null) onDeviceChanged(v); },
            ),
          ),
          
          const Spacer(),
          
          if (running)
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: SrProgressBar(
                    value: jobProgress,
                    kind: SrProgressKind.solid,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(jobProgress * 100).toInt()}%',
                  style: TextStyle(fontFamily: 'monospace', color: tokens.muted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                SrButton(
                  label: 'Cancel',
                  icon: Icons.stop,
                  onPressed: onCancel,
                  size: SrButtonSize.sm,
                ),
              ],
            )
          else
            Row(
              children: [
                SrButton(
                  label: 'Select image…',
                  icon: Icons.image,
                  onPressed: onSelectImage,
                  size: SrButtonSize.sm,
                ),
                const SizedBox(width: 6),
                SrButton(
                  label: 'Batch folder…',
                  icon: Icons.folder,
                  onPressed: onBatchFolder,
                  size: SrButtonSize.sm,
                ),
                const SizedBox(width: 6),
                SrButton(
                  label: 'Save result',
                  icon: Icons.download,
                  onPressed: onSaveResult,
                  size: SrButtonSize.sm,
                ),
                const SizedBox(width: 6),
                SrButton(
                  label: 'Run Inference',
                  icon: Icons.play_arrow,
                  onPressed: onRunInference,
                  size: SrButtonSize.sm,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.selectedCheckpoint,
    required this.checkpoints,
    required this.onChanged,
  });

  final CheckpointSummary? selectedCheckpoint;
  final List<CheckpointSummary> checkpoints;
  final ValueChanged<CheckpointSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<CheckpointSummary>(
          value: selectedCheckpoint,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
          items: checkpoints.map((checkpoint) {
            final isBest = checkpoint.tags.contains('best_psnr');
            return DropdownMenuItem(
              value: checkpoint,
              child: Text(
                '${checkpoint.path.split('/').last}${isBest ? ' · best' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (checkpoint) {
            if (checkpoint != null) onChanged(checkpoint);
          },
        ),
      ],
    );
  }
}

class _ScaleField extends StatelessWidget {
  const _ScaleField({
    required this.scale,
    required this.onChanged,
  });

  final int scale;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scale',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: scale,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
          items: [2, 3, 4, 6, 8].map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text('× $s', style: const TextStyle(fontFamily: 'monospace')),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

class _TileField extends StatelessWidget {
  const _TileField({
    required this.enabled,
    required this.tileSize,
    required this.onEnabledChanged,
    required this.onSizeChanged,
  });

  final bool enabled;
  final int tileSize;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tile',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: enabled ? tileSize : 0,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
          items: [
            DropdownMenuItem(value: 0, child: Text('off', style: const TextStyle(fontFamily: 'monospace'))),
            for (final size in [256, 384, 512])
              DropdownMenuItem(value: size, child: Text('auto · $size', style: const TextStyle(fontFamily: 'monospace'))),
          ],
          onChanged: (value) {
            if (value != null) {
              onEnabledChanged(value != 0);
              if (value != 0) onSizeChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _CompareViewer extends StatelessWidget {
  const _CompareViewer({
    required this.sliderMode,
    required this.sliderPosition,
    required this.lastResult,
    required this.inputPath,
    required this.inspector,
    required this.onModeChanged,
    required this.onSliderChanged,
  });

  final bool sliderMode;
  final double sliderPosition;
  final InferenceRecord? lastResult;
  final String inputPath;
  final InferenceInspector? inspector;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Before/after chips and mode controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SrChip(
                    label: 'before · 480 × 320',
                    kind: SrChipKind.default_,
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_right, size: 12, color: tokens.muted),
                  const SizedBox(width: 6),
                  SrChip(
                    label: 'after · 1920 × 1280',
                    kind: SrChipKind.ok,
                  ),
                ],
              ),
              Row(
                children: [
                  SrButton(
                    label: '2-up',
                    icon: Icons.grid_view,
                    onPressed: () => onModeChanged(false),
                    style: sliderMode ? SrButtonStyle.ghost : SrButtonStyle.primary,
                    size: SrButtonSize.sm,
                  ),
                  const SizedBox(width: 4),
                  SrButton(
                    label: 'Slider',
                    icon: Icons.compare_arrows,
                    onPressed: () => onModeChanged(true),
                    style: sliderMode ? SrButtonStyle.primary : SrButtonStyle.ghost,
                    size: SrButtonSize.sm,
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // The viewer
          Expanded(
            child: sliderMode
                ? _SliderViewer(
                    position: sliderPosition,
                    onPositionChanged: onSliderChanged,
                    lastResult: lastResult,
                    inputPath: inputPath,
                  )
                : _TwoUpViewer(lastResult: lastResult, inputPath: inputPath),
          ),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SliderViewer extends StatefulWidget {
  const _SliderViewer({
    required this.position,
    required this.onPositionChanged,
    required this.lastResult,
    required this.inputPath,
  });

  final double position;
  final ValueChanged<double> onPositionChanged;
  final InferenceRecord? lastResult;
  final String inputPath;

  @override
  State<_SliderViewer> createState() => _SliderViewerState();
}

class _SliderViewerState extends State<_SliderViewer> {
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final hasInput = widget.inputPath.isNotEmpty || (widget.lastResult?.inputPath.isNotEmpty ?? false);
    final hasOutput = widget.lastResult?.outputPath != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                widget.onPositionChanged((details.localPosition.dx / width).clamp(0.0, 1.0));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasInput)
                    Image.file(
                      File(widget.lastResult?.inputPath ?? widget.inputPath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text('Input not found', style: TextStyle(color: tokens.muted)),
                      ),
                    )
                  else
                    Center(
                      child: Text('Select an image', style: TextStyle(color: tokens.muted)),
                    ),
                  if (hasOutput)
                    ClipRect(
                      clipper: _SliderClipper(widget.position),
                      child: Image.file(
                        File(widget.lastResult!.outputPath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  if (hasOutput)
                    Positioned(
                      left: widget.position * width - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: Container(color: tokens.accent),
                    ),
                  if (hasOutput) ...[
                    Positioned(top: 6, left: 6, child: SrChip(label: 'BEFORE', kind: SrChipKind.default_)),
                    Positioned(top: 6, right: 6, child: SrChip(label: 'AFTER', kind: SrChipKind.ok)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  const _SliderClipper(this.position);
  
  final double position;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      size.width * position,
      0,
      size.width * (1 - position),
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => true;
}

class _TwoUpViewer extends StatefulWidget {
  const _TwoUpViewer({
    required this.lastResult,
    required this.inputPath,
  });

  final InferenceRecord? lastResult;
  final String inputPath;

  @override
  State<_TwoUpViewer> createState() => _TwoUpViewerState();
}

class _TwoUpViewerState extends State<_TwoUpViewer> {
  final _transform = TransformationController();
  bool _ctrlPressed = false;

  void _onScale(double scale) {
    final current = _transform.value;
    final newScale = (current.getMaxScaleOnAxis() * scale).clamp(1.0, 16.0);
    _transform.value = Matrix4.diagonal3Values(newScale, newScale, 1);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    final hasInput = widget.inputPath.isNotEmpty || (widget.lastResult?.inputPath.isNotEmpty ?? false);
    final hasOutput = widget.lastResult?.outputPath != null;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
            event.logicalKey == LogicalKeyboardKey.controlRight) {
          setState(() => _ctrlPressed = event is KeyDownEvent);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && _ctrlPressed) {
            _onScale(event.scrollDelta.dy < 0 ? 1.1 : 0.9);
          }
        },
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1.0,
          maxScale: 16.0,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radius),
                    border: Border.all(color: tokens.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasInput
                      ? Image.file(
                          File(widget.lastResult?.inputPath ?? widget.inputPath),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text('Input not found', style: TextStyle(color: tokens.muted)),
                          ),
                        )
                      : Center(
                          child: Text('Select an image', style: TextStyle(color: tokens.muted)),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radius),
                    border: Border.all(color: tokens.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasOutput
                      ? Image.file(
                          File(widget.lastResult!.outputPath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text('Output not found', style: TextStyle(color: tokens.muted)),
                          ),
                        )
                      : Center(
                          child: Text('No output yet', style: TextStyle(color: tokens.muted)),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputInspector extends StatelessWidget {
  const _OutputInspector({
    required this.outputFormat,
    required this.bitDepth,
    required this.filename,
    required this.outputWidth,
    required this.outputHeight,
    required this.psnrGain,
    required this.sharpnessGain,
    required this.inferenceTime,
    required this.inspector,
    required this.hasOutput,
    required this.onFormatChanged,
    required this.onBitDepthChanged,
    required this.onSaveOutput,
  });

  final String outputFormat;
  final int bitDepth;
  final String filename;
  final int? outputWidth;
  final int? outputHeight;
  final double? psnrGain;
  final double? sharpnessGain;
  final double? inferenceTime;
  final InferenceInspector? inspector;
  final bool hasOutput;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<int> onBitDepthChanged;
  final VoidCallback onSaveOutput;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    final inspectorData = inspector?.inspector ?? {};
    final bitDepthVal = inspectorData['bit_depth'] as int? ?? bitDepth;
    final sharpnessGainVal = inspectorData['sharpness_gain'] as double?;
    final psnrGainVal = inspectorData['psnr_gain'] as double?;
    final runtimeVal = inspectorData['runtime_seconds'] as double?;
    
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _InspectorSection(
            title: 'Output',
            child: Column(
              children: [
                _Field(
                  label: 'Resolution',
                  value: outputWidth != null && outputHeight != null
                      ? '$outputWidth × $outputHeight'
                      : '— × —',
                  mono: true,
                ),
                _Field(
                  label: 'Format',
                  value: '${outputFormat.toUpperCase()} · $bitDepthVal bit',
                  mono: true,
                  hasDropdown: true,
                  onDropdownChanged: (value) {
                    if (value != null) {
                      final parts = value.split(' · ');
                      if (parts.length >= 2) {
                        onFormatChanged(parts[0].toLowerCase());
                        onBitDepthChanged(int.parse(parts[1].split(' ')[0]));
                      }
                    }
                  },
                ),
                _Field(
                  label: 'Filename',
                  value: filename.isEmpty ? '—' : filename,
                  mono: true,
                ),
                const SizedBox(height: 8),
                SrButton(
                  label: 'Save output',
                  icon: Icons.download,
                  onPressed: hasOutput ? onSaveOutput : null,
                  size: SrButtonSize.sm,
                ),
              ],
            ),
          ),
          
          _InspectorSection(
            title: 'Estimated quality',
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.panelAlt,
                borderRadius: BorderRadius.circular(tokens.radius),
              ),
              child: Column(
                children: [
                  _QualityRow(
                    label: 'vs. bicubic',
                    value: psnrGainVal != null ? '+ ${psnrGainVal.toStringAsFixed(1)} dB PSNR' : '--',
                    valueColor: tokens.accent,
                  ),
                  _QualityRow(
                    label: 'Sharpness gain',
                    value: sharpnessGainVal != null ? '+ ${(sharpnessGainVal * 100).toInt()} %' : '--',
                  ),
                  _QualityRow(
                    label: 'Inference time',
                    value: runtimeVal != null ? '${runtimeVal.toStringAsFixed(1)} s · GPU' : '--',
                  ),
                ],
              ),
            ),
          ),
          

          

        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.mono = false,
    this.hasDropdown = false,
    this.onDropdownChanged,
  });

  final String label;
  final String value;
  final bool mono;
  final bool hasDropdown;
  final ValueChanged<String?>? onDropdownChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.muted,
              ),
            ),
          ),
          Expanded(
            child: hasDropdown
                ? DropdownButtonFormField<String>(
                    value: value,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                        borderSide: BorderSide(color: tokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                        borderSide: BorderSide(color: tokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radius),
                        borderSide: BorderSide(color: tokens.accent),
                      ),
                    ),
                    items: [
                      'PNG · 16 bit',
                      'PNG · 8 bit',
                      'JPEG · 8 bit',
                      'TIFF · 16 bit',
                    ].map((format) {
                      return DropdownMenuItem(
                        value: format,
                        child: Text(
                          format,
                          style: TextStyle(
                            fontFamily: mono ? 'monospace' : null,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: onDropdownChanged,
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontFamily: mono ? 'monospace' : null,
                    ),
                  ),
          ),
          if (hasDropdown)
            Icon(
              Icons.keyboard_arrow_down,
              size: 12,
              color: tokens.muted,
            ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InferenceBlockedTab extends StatelessWidget {
  const _InferenceBlockedTab({
    required this.readiness,
    required this.project,
    required this.onNavigateToTab,
  });

  final InferenceReadiness? readiness;
  final ProjectState project;
  final void Function(int) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    final dataset = project.datasets.isNotEmpty ? project.datasets.first : null;
    final model = project.models.isNotEmpty ? project.models.first : null;
    final hasTraining = project.runs.isNotEmpty;
    final hasCheckpoint = false;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(tokens.radius),
              border: Border.all(color: tokens.warning),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: tokens.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inference is locked until you have a trained checkpoint',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tokens.warning,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Models need at least one saved checkpoint before they can upscale an image.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What you need',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _PrerequisiteItem(
                icon: Icons.check,
                label: 'A dataset',
                value: dataset != null ? '${dataset.name} · ${dataset.pairCount} pairs' : '—',
                completed: dataset != null,
                onGo: dataset == null ? () => onNavigateToTab(1) : null,
              ),
              _PrerequisiteItem(
                icon: Icons.check,
                label: 'A model',
                value: model != null ? model.name : '—',
                completed: model != null,
                onGo: model == null ? () => onNavigateToTab(2) : null,
              ),
              _PrerequisiteItem(
                icon: hasTraining ? Icons.check : Icons.lock,
                label: 'A training run that reached at least 5 epochs',
                value: hasTraining ? 'ready' : 'no run yet',
                completed: hasTraining,
                onGo: !hasTraining ? () => onNavigateToTab(4) : null,
              ),
              _PrerequisiteItem(
                icon: hasCheckpoint ? Icons.check : Icons.lock,
                label: 'A saved checkpoint',
                value: hasCheckpoint ? '1 / 1' : '0 / 1',
                completed: hasCheckpoint,
                onGo: !hasCheckpoint && hasTraining ? () => onNavigateToTab(4) : null,
              ),
            ],
          ),
          
          const Spacer(),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.panelAlt,
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, size: 14, color: tokens.muted),
                    const SizedBox(width: 8),
                    const Text('Why this gate?', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'An untrained model would just produce noise. We keep this tab inert until something useful exists — so you can\'t accidentally ship a broken result.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrerequisiteItem extends StatelessWidget {
  const _PrerequisiteItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.completed,
    this.onGo,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool completed;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(4),
        color: completed ? tokens.success.withValues(alpha: 0.1) : tokens.panelAlt,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
            color: completed ? tokens.success : tokens.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.muted,
            ),
          ),
          if (!completed && onGo != null) ...[
            const SizedBox(width: 8),
            SrButton(
              label: 'Go',
              icon: Icons.arrow_right,
              onPressed: onGo,
              size: SrButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Settings panel ─────────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.runs,
    required this.selectedRunId,
    required this.selectedCheckpoint,
    required this.checkpoints,
    required this.onRunSelected,
    required this.onCheckpointSelected,
    required this.inputPath,
    required this.onPickInput,
    required this.outputDir,
    required this.onPickOutput,
    required this.mode,
    required this.onModeChanged,
    required this.device,
    required this.devices,
    required this.onDeviceChanged,
    required this.outputFormat,
    required this.onFormatChanged,
    required this.tilingEnabled,
    required this.onTilingChanged,
    required this.tileSize,
    required this.onTileSizeChanged,
    required this.tileOverlap,
    required this.onTileOverlapChanged,
    required this.paddingMode,
    required this.onPaddingModeChanged,
    required this.blendStrategy,
    required this.onBlendStrategyChanged,
    required this.readiness,
    required this.running,
    required this.onRun,
  });

  final List<RunSummary> runs;
  final String? selectedRunId;
  final CheckpointSummary? selectedCheckpoint;
  final List<CheckpointSummary> checkpoints;
  final ValueChanged<String> onRunSelected;
  final ValueChanged<CheckpointSummary> onCheckpointSelected;
  final String inputPath;
  final VoidCallback onPickInput;
  final String? outputDir;
  final VoidCallback onPickOutput;
  final String mode;
  final ValueChanged<String> onModeChanged;
  final String device;
  final List<DeviceOption> devices;
  final ValueChanged<String> onDeviceChanged;
  final String outputFormat;
  final ValueChanged<String> onFormatChanged;
  final bool tilingEnabled;
  final ValueChanged<bool> onTilingChanged;
  final int tileSize;
  final ValueChanged<int> onTileSizeChanged;
  final int tileOverlap;
  final ValueChanged<int> onTileOverlapChanged;
  final String paddingMode;
  final ValueChanged<String> onPaddingModeChanged;
  final String blendStrategy;
  final ValueChanged<String> onBlendStrategyChanged;
  final InferenceReadiness? readiness;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final ready = readiness?.available ?? false;

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Inference Settings', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _sectionLabel('Run', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedRunId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final run in runs)
                  DropdownMenuItem(value: run.id, child: Text(run.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) { if (v != null) onRunSelected(v); },
            ),
            const SizedBox(height: 10),
            _sectionLabel('Checkpoint', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedCheckpoint?.id,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final c in checkpoints)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text('Epoch ${c.epoch}${c.tags.isNotEmpty ? " (${c.tags.join(', ')})" : ""}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  final match = checkpoints.firstWhere((c) => c.id == v);
                  onCheckpointSelected(match);
                }
              },
            ),
            if (selectedCheckpoint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Scale: ×${selectedCheckpoint!.scale}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            const SizedBox(height: 10),
            _sectionLabel('Mode', context),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'single', label: Text('Single')),
                ButtonSegment(value: 'batch', label: Text('Batch')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
            const SizedBox(height: 10),
            _sectionLabel(mode == 'single' ? 'Input image' : 'Input folder', context),
            Row(
              children: [
                Expanded(
                  child: Text(
                    inputPath.isEmpty ? 'None selected' : inputPath.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: onPickInput,
                  child: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _sectionLabel('Output folder (optional)', context),
            Row(
              children: [
                Expanded(
                  child: Text(
                    outputDir ?? 'Default (project/inference/)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(onPressed: onPickOutput, child: const Text('Browse')),
              ],
            ),
            const SizedBox(height: 10),
            _sectionLabel('Device', context),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: device,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              items: [
                for (final d in devices)
                  DropdownMenuItem(value: d.id, child: Text(d.label)),
              ],
              onChanged: (v) { if (v != null) onDeviceChanged(v); },
            ),
            const SizedBox(height: 10),
            _sectionLabel('Output format', context),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'png', label: Text('PNG')),
                ButtonSegment(value: 'jpg', label: Text('JPG')),
              ],
              selected: {outputFormat},
              onSelectionChanged: (s) => onFormatChanged(s.first),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _sectionLabel('Tiling', context),
                const Spacer(),
                Switch(value: tilingEnabled, onChanged: onTilingChanged),
              ],
            ),
            if (tilingEnabled) ...[
              _labeledSlider('Tile size', tileSize, 64, 1024, (v) => onTileSizeChanged(v.round()), context),
              _labeledSlider('Overlap', tileOverlap, 0, 256, (v) => onTileOverlapChanged(v.round()), context),
              _sectionLabel('Padding', context),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: paddingMode,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                items: const [
                  DropdownMenuItem(value: 'reflect', child: Text('Reflect')),
                  DropdownMenuItem(value: 'replicate', child: Text('Replicate')),
                  DropdownMenuItem(value: 'constant', child: Text('Zero')),
                ],
                onChanged: (v) { if (v != null) onPaddingModeChanged(v); },
              ),
              const SizedBox(height: 8),
              _sectionLabel('Blending', context),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'average', label: Text('Average')),
                  ButtonSegment(value: 'linear', label: Text('Linear')),
                ],
                selected: {blendStrategy},
                onSelectionChanged: (s) => onBlendStrategyChanged(s.first),
              ),
            ],
            const SizedBox(height: 12),
            if (readiness != null && !readiness!.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  readiness!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            FilledButton.icon(
              onPressed: running || !ready ? null : onRun,
              icon: running
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(running ? 'Running…' : 'Run Inference'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }

  Widget _labeledSlider(String label, int value, int min, int max, ValueChanged<double> onChanged, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _sectionLabel(label, context),
          const Spacer(),
          Text('$value', style: const TextStyle(fontSize: 12)),
        ]),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 32,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Result / preview panel ─────────────────────────────────────────────────────
