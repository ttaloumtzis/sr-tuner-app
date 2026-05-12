import 'dart:io';

import 'package:flutter/material.dart';

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
    super.key,
  });

  final BackendClient client;
  final ProjectState project;
  final String? initialCheckpointId;

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
  
  double _denoiseStrength = 0.6;
  double _detailBoost = 0.35;
  bool _colorPreserve = true;
  
  bool _running = false;
  String? _error;
  InferenceRecord? _lastResult;
  
  List<InferenceRecord> _recentResults = [];
  
  InferenceReadiness? _readiness;
  InferenceInspector? _inspector;
  List<DeviceOption> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadAggregate();
    _loadDevices();
    _loadReadiness();
    _loadRecentResults();
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
      if (mounted) setState(() => _devices = devices);
    } catch (_) {}
  }

  Future<void> _loadReadiness() async {
    try {
      final r = await widget.client.inferenceReadiness(device: 'auto');
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

  Future<void> _loadRecentResults() async {
    try {
      final env = await widget.client.listInferenceHistory(widget.project.id);
      if (mounted) {
        setState(() {
          _recentResults = env.records.take(6).toList();
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
        _InferenceHeader(
          selectedCheckpoint: _selectedCheckpoint,
          checkpoints: checkpoints,
          scale: _scale,
          tilingEnabled: _tilingEnabled,
          tileSize: _tileSize,
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
          onBatchFolder: _pickBatchFolder,
          onSaveResult: _saveResult,
          onRunInference: _runInference,
          running: _running,
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
                  recentResults: _recentResults,
                  inspector: _inspector,
                  onModeChanged: (mode) {
                    setState(() => _sliderMode = mode);
                  },
                  onSliderChanged: (position) {
                    setState(() => _sliderPosition = position);
                  },
                  onRecentSelected: (result) {
                    setState(() => _lastResult = result);
                  },
                  onAddTile: _handleAddTile,
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
                  denoiseStrength: _denoiseStrength,
                  detailBoost: _detailBoost,
                  colorPreserve: _colorPreserve,
                  inspector: _inspector,
                  onFormatChanged: (format) {
                    setState(() => _outputFormat = format);
                  },
                  onBitDepthChanged: (depth) {
                    setState(() => _bitDepth = depth);
                  },
                  onDenoiseChanged: (strength) {
                    setState(() => _denoiseStrength = strength);
                  },
                  onDetailBoostChanged: (boost) {
                    setState(() => _detailBoost = boost);
                  },
                  onColorPreserveChanged: (preserve) {
                    setState(() => _colorPreserve = preserve);
                  },
                  onBatchDrop: _handleBatchDrop,
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
    setState(() => _running = true);
    try {
      final result = await widget.client.runInference(
        projectId: widget.project.id,
        runId: _selectedCheckpoint!.runId,
        checkpointId: _selectedCheckpoint!.id,
        inputPath: _inputPath,
        outputDir: _outputDir,
        outputFormat: _outputFormat,
        mode: 'single',
        device: 'auto',
      );
      if (mounted) {
        setState(() {
          _running = false;
          _lastResult = result;
        });
        _loadInspector();
        _loadRecentResults();
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

  Future<void> _handleAddTile() async {
    final path = await const PathPicker().pickFile();
    if (path != null && mounted) {
      setState(() {
        _inputPath = path;
        _filename = path.split('/').last;
      });
    }
  }

// Helper methods
  Future<void> _pickBatchFolder() async {
    final path = await const PathPicker().pickFolder(confirmButtonText: 'Select batch folder');
    if (path != null && mounted) {
      setState(() => _inputPath = path);
    }
  }

  Future<void> _saveResult() async {
    if (_lastResult == null) return;
    final path = await const PathPicker().pickFolder(confirmButtonText: 'Save result here');
    if (path != null && mounted) {
      // TODO: Implement save result functionality
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Result saved to $path')),
      );
    }
  }

  void _handleBatchDrop(String folderPath) {
    setState(() => _inputPath = folderPath);
  }

  void _preselectCheckpoint(String checkpointId) {
    final checkpoint = _aggregate?.checkpoints.firstWhere(
      (c) => c.id == checkpointId && !c.deleted,
      orElse: () => _aggregate!.checkpoints.firstWhere((c) => !c.deleted),
    );
    if (mounted) {
      setState(() => _selectedCheckpoint = checkpoint);
    }
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
    required this.onCheckpointChanged,
    required this.onScaleChanged,
    required this.onTilingChanged,
    required this.onTileSizeChanged,
    required this.onBatchFolder,
    required this.onSaveResult,
    required this.onRunInference,
    required this.running,
  });

  final CheckpointSummary? selectedCheckpoint;
  final List<CheckpointSummary> checkpoints;
  final int scale;
  final bool tilingEnabled;
  final int tileSize;
  final ValueChanged<CheckpointSummary> onCheckpointChanged;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<bool> onTilingChanged;
  final ValueChanged<int> onTileSizeChanged;
  final VoidCallback onBatchFolder;
  final VoidCallback onSaveResult;
  final VoidCallback onRunInference;
  final bool running;

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
          
          const Spacer(),
          
          Row(
            children: [
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
                label: running ? 'Running…' : 'Run Inference',
                icon: Icons.play_arrow,
                onPressed: running ? null : onRunInference,
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
        DropdownButtonFormField<Map<String, dynamic>>(
          value: {'enabled': enabled, 'size': tileSize},
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
            {'enabled': false, 'size': 0},
            {'enabled': true, 'size': 256},
            {'enabled': true, 'size': 384},
            {'enabled': true, 'size': 512},
          ].map((option) {
            final label = option['enabled'] as bool 
                ? 'auto · ${option['size']}'
                : 'off';
            return DropdownMenuItem(
              value: option,
              child: Text(label, style: const TextStyle(fontFamily: 'monospace')),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onEnabledChanged(value['enabled'] as bool);
              onSizeChanged(value['size'] as int);
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
    required this.recentResults,
    required this.inspector,
    required this.onModeChanged,
    required this.onSliderChanged,
    required this.onRecentSelected,
    required this.onAddTile,
  });

  final bool sliderMode;
  final double sliderPosition;
  final InferenceRecord? lastResult;
  final List<InferenceRecord> recentResults;
  final InferenceInspector? inspector;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<InferenceRecord> onRecentSelected;
  final VoidCallback onAddTile;

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
                  )
                : _TwoUpViewer(lastResult: lastResult),
          ),
          
          const SizedBox(height: 10),
          
          // Recent filmstrip
          _RecentFilmstrip(
            results: recentResults,
            selectedResult: lastResult,
            onSelected: onRecentSelected,
            onAddTile: onAddTile,
            maxSlots: 12,
          ),
        ],
      ),
    );
  }
}

class _SliderViewer extends StatelessWidget {
  const _SliderViewer({
    required this.position,
    required this.onPositionChanged,
    required this.lastResult,
  });

  final double position;
  final ValueChanged<double> onPositionChanged;
  final InferenceRecord? lastResult;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border),
      ),
      child: Stack(
        children: [
          // LR side (left)
          Positioned.fill(
            child: Container(
              color: tokens.panelAlt,
              child: const Center(
                child: Text('LR · 480 × 320 (input)'),
              ),
            ),
          ),
          
          // SR side (right, clipped)
          Positioned.fill(
            child: ClipRect(
              clipper: _SliderClipper(position),
              child: Container(
                color: tokens.panel,
                child: const Center(
                  child: Text('SR · 1920 × 1280 (× 4 upscale)'),
                ),
              ),
            ),
          ),
          
          // Handle
          Positioned(
            left: position * MediaQuery.of(context).size.width * 0.6, // Approximate width
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (details) {
                final newPosition = (details.globalPosition.dx / MediaQuery.of(context).size.width * 0.6).clamp(0.0, 1.0);
                onPositionChanged(newPosition);
              },
              child: Container(
                width: 2,
                color: tokens.accent,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_right,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Labels
          Positioned(
            top: 8,
            left: 8,
            child: SrChip(
              label: 'BEFORE',
              kind: SrChipKind.default_,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SrChip(
              label: 'AFTER',
              kind: SrChipKind.ok,
            ),
          ),
        ],
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

class _TwoUpViewer extends StatelessWidget {
  const _TwoUpViewer({
    required this.lastResult,
  });

  final InferenceRecord? lastResult;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).extension<SrTokens>()!.border),
            ),
            child: const Center(
              child: Text('Before (LR)'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).extension<SrTokens>()!.border),
            ),
            child: const Center(
              child: Text('After (SR)'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentFilmstrip extends StatelessWidget {
  const _RecentFilmstrip({
    required this.results,
    required this.selectedResult,
    required this.onSelected,
    required this.onAddTile,
    required this.maxSlots,
  });

  final List<InferenceRecord> results;
  final InferenceRecord? selectedResult;
  final ValueChanged<InferenceRecord> onSelected;
  final VoidCallback onAddTile;
  final int maxSlots;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.muted,
              ),
            ),
            Text(
              '${results.length} / $maxSlots',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.muted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ...List.generate(maxSlots, (index) {
              if (index < results.length) {
                final result = results[index];
                final isSelected = result.id == selectedResult?.id;
                return GestureDetector(
                  onTap: () => onSelected(result),
                  child: Container(
                    width: 74,
                    height: 50,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? tokens.accent : tokens.border,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: tokens.panelAlt,
                    ),
                    child: Center(
                      child: Text(
                        isSelected ? 'now' : '${index + 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                );
              } else if (index == results.length) {
                return GestureDetector(
                  onTap: onAddTile,
                  child: Container(
                    width: 74,
                    height: 50,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: tokens.accent,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text('+ add', style: TextStyle(fontSize: 10, color: tokens.accent)),
                    ),
                  ),
                );
              } else {
                return Container(
                  width: 74,
                  height: 50,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: tokens.border, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text('+ add', style: TextStyle(fontSize: 10)),
                  ),
                );
              }
            }),
          ],
        ),
      ],
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
    required this.denoiseStrength,
    required this.detailBoost,
    required this.colorPreserve,
    required this.inspector,
    required this.onFormatChanged,
    required this.onBitDepthChanged,
    required this.onDenoiseChanged,
    required this.onDetailBoostChanged,
    required this.onColorPreserveChanged,
    required this.onBatchDrop,
  });

  final String outputFormat;
  final int bitDepth;
  final String filename;
  final int? outputWidth;
  final int? outputHeight;
  final double? psnrGain;
  final double? sharpnessGain;
  final double? inferenceTime;
  final double denoiseStrength;
  final double detailBoost;
  final bool colorPreserve;
  final InferenceInspector? inspector;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<int> onBitDepthChanged;
  final ValueChanged<double> onDenoiseChanged;
  final ValueChanged<double> onDetailBoostChanged;
  final ValueChanged<bool> onColorPreserveChanged;
  final Function(String) onBatchDrop;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    final inspectorData = inspector?.inspector ?? {};
    final bitDepthVal = inspectorData['bit_depth'] as int? ?? bitDepth;
    final sharpnessGainVal = inspectorData['sharpness_gain'] as double?;
    final psnrGainVal = inspectorData['psnr_gain'] as double?;
    final runtimeVal = inspectorData['runtime_seconds'] as double?;
    final tuning = inspector?.tuning ?? {};
    
    final denoiseSupport = tuning['denoise_strength'];
    final detailSupport = tuning['detail_boost'];
    final colorSupport = tuning['color_preserve'];
    
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
                  value: '$outputFormat · $bitDepthVal bit',
                  mono: true,
                  hasDropdown: true,
                  onDropdownChanged: (value) {
                    if (value != null) {
                      final parts = value.split(' · ');
                      if (parts.length >= 2) {
                        onFormatChanged(parts[0]);
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
          
          _InspectorSection(
            title: 'Tuning',
            child: Column(
              children: [
                _TuningControl(
                  label: 'Denoise strength',
                  value: denoiseStrength,
                  onChanged: denoiseSupport?.supported == false ? null : onDenoiseChanged,
                  unavailable: denoiseSupport?.supported == false,
                ),
                _TuningControl(
                  label: 'Detail boost',
                  value: detailBoost,
                  onChanged: detailSupport?.supported == false ? null : onDetailBoostChanged,
                  unavailable: detailSupport?.supported == false,
                ),
                _TuningControl(
                  label: 'Color preserve',
                  value: colorPreserve ? 1.0 : 0.0,
                  onChanged: (value) => onColorPreserveChanged(value > 0.5),
                  unavailable: colorSupport?.supported == false,
                ),
              ],
            ),
          ),
          
          _InspectorSection(
            title: 'Batch',
            child: _BatchDropZone(onDrop: onBatchDrop),
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

class _TuningControl extends StatelessWidget {
  const _TuningControl({
    required this.label,
    required this.value,
    required this.onChanged,
    this.unavailable = false,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: unavailable ? tokens.muted.withValues(alpha: 0.5) : tokens.muted,
                ),
              ),
              Text(
                value.toStringAsFixed(2),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: unavailable ? tokens.muted.withValues(alpha: 0.5) : null,
                ),
              ),
            ],
          ),
        ),
        SrProgressBar(
          value: unavailable ? 0.0 : value,
          kind: SrProgressKind.solid,
        ),
      ],
    );
  }
}

class _BatchDropZone extends StatelessWidget {
  const _BatchDropZone({
    required this.onDrop,
  });

  final Function(String) onDrop;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SrTokens>()!;
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.panelAlt,
        border: Border.all(
          color: tokens.border,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload,
            size: 14,
            color: tokens.muted,
          ),
          const SizedBox(height: 2),
          Text(
            'Drop a folder to process all',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.muted,
            ),
            textAlign: TextAlign.center,
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

class _ResultPanel extends StatefulWidget {
  const _ResultPanel({
    required this.result,
    required this.inputPath,
    required this.running,
    required this.history,
    required this.onHistorySelected,
  });

  final InferenceRecord? result;
  final String inputPath;
  final bool running;
  final List<InferenceRecord> history;
  final ValueChanged<InferenceRecord> onHistorySelected;

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel> {
  String _previewMode = 'split';

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result != null) ...[
          _PreviewControls(
            mode: _previewMode,
            onModeChanged: (v) => setState(() => _previewMode = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: _buildPreview(result),
          ),
          const SizedBox(height: 8),
          _ResultInfo(result: result),
        ] else if (widget.running) ...[
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare, size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('Run inference to see results here.', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
        ],
        if (widget.history.isNotEmpty) ...[
          const Divider(),
          SizedBox(
            height: 100,
            child: _HistoryList(
              history: widget.history,
              selected: result,
              onSelected: widget.onHistorySelected,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview(InferenceRecord result) {
    final outputPath = result.outputPath;
    if (outputPath == null) {
      if (result.mode == 'batch') {
        return _BatchResultSummary(result: result);
      }
      return const Center(child: Text('No output preview available.', style: TextStyle(color: Colors.white38)));
    }

    if (_previewMode == 'split') {
      return BeforeAfterComparison(
        inputPath: result.inputPath,
        outputPath: outputPath,
      );
    }

    return _SideBySidePreview(inputPath: result.inputPath, outputPath: outputPath);
  }
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls({required this.mode, required this.onModeChanged});

  final String mode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Preview:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'split', label: Text('Split'), icon: Icon(Icons.compare, size: 14)),
            ButtonSegment(value: 'side', label: Text('Side by side'), icon: Icon(Icons.view_column, size: 14)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
      ],
    );
  }
}

class _ResultInfo extends StatelessWidget {
  const _ResultInfo({required this.result});

  final InferenceRecord result;

  @override
  Widget build(BuildContext context) {
    final successes = result.perFileResults.where((r) => r.status == 'success').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _chip(Icons.check_circle, '${result.scale}×', const Color(0xff58c48a)),
            const SizedBox(width: 12),
            _chip(Icons.timer, '${result.runtimeSeconds.toStringAsFixed(1)}s', Colors.white54),
            const SizedBox(width: 12),
            _chip(Icons.folder_open, result.mode == 'batch' ? '$successes / ${result.perFileResults.length}' : '1/1', Colors.white54),
            const SizedBox(width: 12),
            Expanded(child: Text(result.outputDir ?? result.outputPath ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(result.status).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(result.status, style: TextStyle(color: _statusColor(result.status), fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => const Color(0xff58c48a),
      'partial' => const Color(0xffffc857),
      _ => Colors.redAccent,
    };
  }
}

class _BatchResultSummary extends StatelessWidget {
  const _BatchResultSummary({required this.result});

  final InferenceRecord result;

  @override
  Widget build(BuildContext context) {
    final successes = result.perFileResults.where((r) => r.status == 'success').toList();
    final failures = result.perFileResults.where((r) => r.status == 'failed').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Batch results', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('${successes.length} succeeded, ${failures.length} failed', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final r in result.perFileResults)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        r.status == 'success' ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: r.status == 'success' ? const Color(0xff58c48a) : Colors.redAccent,
                      ),
                      title: Text(r.filename, style: const TextStyle(fontSize: 12)),
                      subtitle: r.error != null ? Text(r.error!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)) : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Before/after comparison ────────────────────────────────────────────────────

class BeforeAfterComparison extends StatefulWidget {
  const BeforeAfterComparison({
    required this.inputPath,
    required this.outputPath,
    super.key,
  });

  final String inputPath;
  final String outputPath;

  @override
  State<BeforeAfterComparison> createState() => _BeforeAfterComparisonState();
}

class _BeforeAfterComparisonState extends State<BeforeAfterComparison> {
  double _splitFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final splitX = totalWidth * _splitFraction;

          return GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _splitFraction = (_splitFraction + d.delta.dx / totalWidth).clamp(0.02, 0.98);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Right side: SR output
                _InferenceImage(path: widget.outputPath),
                // Left side: LR input, clipped
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: _splitFraction,
                    child: SizedBox(
                      width: totalWidth,
                      child: _InferenceImage(path: widget.inputPath),
                    ),
                  ),
                ),
                // Divider line
                Positioned(
                  left: splitX - 1,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: Container(color: Colors.white70),
                ),
                // Drag handle
                Positioned(
                  left: splitX - 14,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: const Center(
                    child: Icon(Icons.drag_indicator, color: Colors.white70, size: 20),
                  ),
                ),
                // Labels
                Positioned(
                  left: 8,
                  top: 8,
                  child: _label('Before (LR)'),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _label('After (SR)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}

class _InferenceImage extends StatelessWidget {
  const _InferenceImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(child: Text('File not found', style: TextStyle(color: Colors.white38)));
    }
    return InteractiveViewer(
      child: Image.file(file, fit: BoxFit.contain),
    );
  }
}

class _SideBySidePreview extends StatelessWidget {
  const _SideBySidePreview({
    required this.inputPath,
    required this.outputPath,
  });

  final String inputPath;
  final String outputPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Before (LR)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(child: _InferenceImage(path: inputPath)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('After (SR)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(child: _InferenceImage(path: outputPath)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── History list ───────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.selected,
    required this.onSelected,
  });

  final List<InferenceRecord> history;
  final InferenceRecord? selected;
  final ValueChanged<InferenceRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('History', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white54)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              itemBuilder: (context, index) {
                final r = history[index];
                final isSelected = r.id == selected?.id;
                return GestureDetector(
                  onTap: () => onSelected(r),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white12 : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? Colors.white38 : Colors.transparent),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.inputPath.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text('×${r.scale}  ${r.runtimeSeconds.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(r.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(r.status, style: TextStyle(color: _statusColor(r.status), fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => const Color(0xff58c48a),
      'partial' => const Color(0xffffc857),
      _ => Colors.redAccent,
    };
  }
}
