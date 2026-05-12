# Graph Report - .  (2026-05-12)

## Corpus Check
- 135 files · ~116,618 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1209 nodes · 2727 edges · 88 communities (80 shown, 8 thin omitted)
- Extraction: 77% EXTRACTED · 23% INFERRED · 0% AMBIGUOUS · INFERRED: 640 edges (avg confidence: 0.54)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Backend API Schemas|Backend API Schemas]]
- [[_COMMUNITY_Backend Core Modules|Backend Core Modules]]
- [[_COMMUNITY_Inference Tab UI|Inference Tab UI]]
- [[_COMMUNITY_Checkpoints Module|Checkpoints Module]]
- [[_COMMUNITY_Flutter Models|Flutter Models]]
- [[_COMMUNITY_API Endpoints|API Endpoints]]
- [[_COMMUNITY_Dataset Tab UI|Dataset Tab UI]]
- [[_COMMUNITY_Test Fixtures|Test Fixtures]]
- [[_COMMUNITY_Inference Module|Inference Module]]
- [[_COMMUNITY_Checkpoints Tab UI|Checkpoints Tab UI]]
- [[_COMMUNITY_Classic Components UI|Classic Components UI]]
- [[_COMMUNITY_Training Tab UI|Training Tab UI]]
- [[_COMMUNITY_Project Tests|Project Tests]]
- [[_COMMUNITY_Live Metrics Tab UI|Live Metrics Tab UI]]
- [[_COMMUNITY_Runs Module|Runs Module]]
- [[_COMMUNITY_Smoke Tests|Smoke Tests]]
- [[_COMMUNITY_Workspace Tabs|Workspace Tabs]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]

## God Nodes (most connected - your core abstractions)
1. `ApiError` - 123 edges
2. `Job` - 69 edges
3. `ProjectState` - 68 edges
4. `open_project()` - 58 edges
5. `_session_project_path()` - 49 edges
6. `DatasetObject` - 46 edges
7. `CheckpointMetadata` - 44 edges
8. `RunObject` - 41 edges
9. `write_project()` - 35 edges
10. `RunSetupRequest` - 32 edges

## Surprising Connections (you probably didn't know these)
- `Training Runs Specification` --semantically_similar_to--> `SrProgressBar (Solid/Striped/Indeterminate)`  [INFERRED] [semantically similar]
  openspec/changes/archive/2026-05-11-port-design-handoff-flutter-ui/specs/training-runs/spec.md → design_handoff_sr_tuner/README.md
- `Live Metrics Specification` --semantically_similar_to--> `SrProgressBar (Solid/Striped/Indeterminate)`  [INFERRED] [semantically similar]
  openspec/changes/archive/2026-05-11-port-design-handoff-flutter-ui/specs/live-metrics/spec.md → design_handoff_sr_tuner/README.md
- `LiveMetricsTab` --conceptually_related_to--> `Overview Tab`  [INFERRED]
  lib/src/workspace/live_metrics_tab.dart → design_handoff_sr_tuner/README.md
- `Overview Tab` --calls--> `BoundedPoller`  [EXTRACTED]
  design_handoff_sr_tuner/README.md → lib/src/polling.dart
- `sr-tuner` --uses--> `Python`  [EXTRACTED]
  pubspec.yaml → README.md

## Communities (88 total, 8 thin omitted)

### Community 0 - "Backend API Schemas"
Cohesion: 0.12
Nodes (107): BaseModel, HTTPException, CheckpointListResponse, CheckpointMetadata, ExportOnnxRequest, ExportPthRequest, OnnxReadinessResponse, ProjectCheckpointIndex (+99 more)

### Community 1 - "Backend Core Modules"
Cohesion: 0.05
Nodes (53): Atomic Project Writes, FastAPI, Flutter, Python, PyTorch, Session Token Protection, sr-tuner, _copy_or_move_dataset() (+45 more)

### Community 2 - "Inference Tab UI"
Cohesion: 0.03
Nodes (59): _BatchDropZone, _BatchResultSummary, BeforeAfterComparison, _BeforeAfterComparisonState, build, _buildPreview, Card, Center (+51 more)

### Community 3 - "Checkpoints Module"
Cohesion: 0.1
Nodes (51): _assign_markers(), delete_checkpoint(), derive_project_checkpoints(), export_checkpoint_onnx(), export_checkpoint_pth(), _find_run_raw(), _get_active_checkpoint(), list_run_checkpoints() (+43 more)

### Community 4 - "Flutter Models"
Cohesion: 0.04
Nodes (51): ActionState, ActiveRunStatus, ActivityEvent, ActivityFeedEnvelope, CheckpointAggregate, CheckpointListEnvelope, CheckpointSummary, DashboardSummary (+43 more)

### Community 5 - "API Endpoints"
Cohesion: 0.08
Nodes (41): active_run_endpoint(), activity_endpoint(), checkpoint_aggregate_endpoint(), compatibility_endpoint(), create_job_endpoint(), dashboard_endpoint(), dataset_detail_endpoint(), dataset_resynthesis_endpoint() (+33 more)

### Community 6 - "Dataset Tab UI"
Cohesion: 0.04
Nodes (45): AlertDialog, ApiException, AspectRatio, build, Column, _DatasetChoiceTile, _DatasetCreationProgressDialog, _DatasetCreationProgressDialogState (+37 more)

### Community 7 - "Test Fixtures"
Cohesion: 0.04
Nodes (43): ActiveRunStatus, ActivityFeedEnvelope, CheckpointAggregate, DashboardSummary, _dataset, DatasetDetail, DatasetSummary, _FakeBackendClient (+35 more)

### Community 8 - "Inference Module"
Cohesion: 0.14
Nodes (40): _handle_oom_or_raise(), _infer_single(), inference_readiness(), InferenceRequest, _is_oom(), _linear_blend_mask(), _list_images(), list_inference_history() (+32 more)

### Community 9 - "Checkpoints Tab UI"
Cohesion: 0.06
Nodes (33): ../design_system/sr_button.dart, ../design_system/sr_chart.dart, ../design_system/sr_chip.dart, _AggregateHeader, BlockedState, build, Center, _CheckpointRow (+25 more)

### Community 10 - "Classic Components UI"
Cohesion: 0.06
Nodes (32): AspectRatio, build, Card, Center, Container, CustomPaint, _DashedBorderPainter, didUpdateWidget (+24 more)

### Community 11 - "Training Tab UI"
Cohesion: 0.06
Nodes (32): _BasicsSection, BlockedState, build, Column, _DependencyRow, didUpdateWidget, dispose, _EstimateSection (+24 more)

### Community 12 - "Project Tests"
Cohesion: 0.16
Nodes (28): auth_headers(), make_dataset_and_model(), make_paired_dataset(), make_project(), test_atomic_write_keeps_backup(), test_corrupt_project_reports_backup_recovery(), test_create_and_open_project(), test_create_refuses_non_empty_non_project_folder() (+20 more)

### Community 13 - "Live Metrics Tab UI"
Cohesion: 0.06
Nodes (30): build, Column, didUpdateWidget, dispose, _drawSeries, _EventsPanel, _fetchSnapshot, _formatMetric (+22 more)

### Community 14 - "Runs Module"
Cohesion: 0.14
Nodes (28): create_run_endpoint(), delete_run_endpoint(), devices_endpoint(), training_readiness_endpoint(), _active_run(), _apply_job_state(), available_devices(), build_internal_sr_model() (+20 more)

### Community 15 - "Smoke Tests"
Cohesion: 0.18
Nodes (27): _add_dataset(), auth_headers(), _create_model(), _create_run(), _inject_checkpoint(), _make_project(), _make_pth(), Phase 10 smoke tests: end-to-end flow, project reopen, and job infrastructure. (+19 more)

### Community 16 - "Workspace Tabs"
Cohesion: 0.07
Nodes (26): checkpoints_tab.dart, dataset_tab.dart, build, Container, didUpdateWidget, dispose, Icon, initState (+18 more)

### Community 17 - "Community 17"
Cohesion: 0.13
Nodes (23): Checkpoint Management Specification, Checkpoint Ownership Policy, Classic Workspace UI Specification, Dataset Management Specification, Design Handoff SR Tuner README, Desktop Project Workflow Specification, Flutter Design System, IBM Plex Typography (+15 more)

### Community 18 - "Community 18"
Cohesion: 0.09
Nodes (21): build, Column, _CreateOpenColumn, dispose, _Header, initState, InkWell, ListView (+13 more)

### Community 19 - "Community 19"
Cohesion: 0.1
Nodes (20): _ActivityCard, build, Center, Column, didUpdateWidget, dispose, initState, ListView (+12 more)

### Community 20 - "Community 20"
Cohesion: 0.23
Nodes (19): active_run_status(), _definition_path(), generate_validation_preview(), hardware_telemetry(), hardware_telemetry_for_project(), initialize_run_metrics(), latest_preview(), _latest_speed() (+11 more)

### Community 21 - "Community 21"
Cohesion: 0.18
Nodes (19): Checkpoint-Derived Model Status, Checkpoint Management, Dataset Management, Desktop Project Workflow, Index-Based Validation Split, Inference Workflow, Internal PyTorch SR Model, Job Model (+11 more)

### Community 22 - "Community 22"
Cohesion: 0.25
Nodes (14): update_workspace(), create_model_endpoint(), create_model(), backup_file(), create_project(), ensure_project_folders(), load_project(), migrate_project() (+6 more)

### Community 23 - "Community 23"
Cohesion: 0.12
Nodes (15): ../classic_components.dart, build, dispose, _formatCount, initState, _KeyValue, ListView, ModelTab (+7 more)

### Community 24 - "Community 24"
Cohesion: 0.19
Nodes (16): record_activity(), save_template_as_model(), create_project_endpoint(), generate_video_dataset_endpoint(), launch_run_endpoint(), open_project_endpoint(), open_recent_project_endpoint(), _project_response() (+8 more)

### Community 25 - "Community 25"
Cohesion: 0.13
Nodes (14): backend_process.dart, action, build, didChangeAppLifecycleState, dispose, initState, ProjectController, _ProjectControllerState (+6 more)

### Community 27 - "Community 27"
Cohesion: 0.15
Nodes (12): dart:convert, dart:io, ApiException, BackendClient, close, _get, _post, _readJson (+4 more)

### Community 28 - "Community 28"
Cohesion: 0.14
Nodes (12): main, ClassicTheme, copyWith, dark, lerp, lerpDouble, light, SrTokens (+4 more)

### Community 29 - "Community 29"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 30 - "Community 30"
Cohesion: 0.15
Nodes (3): DC, DCCtx, s

### Community 32 - "Community 32"
Cohesion: 0.18
Nodes (10): ../backend_client.dart, dart:math, ApiException, _BackendCommand, BackendProcess, _command, Duration, _generateSessionToken (+2 more)

### Community 33 - "Community 33"
Cohesion: 0.33
Nodes (10): model_defaults_endpoint(), check_dataset_model_compatibility(), CompatibilityResponse, default_model_config(), _derive_status(), _find_model(), get_model(), list_models() (+2 more)

### Community 34 - "Community 34"
Cohesion: 0.2
Nodes (9): ApiErrorBanner, BlockedState, build, Card, JobProgressPanel, MaterialBanner, Padding, SizedBox (+1 more)

### Community 35 - "Community 35"
Cohesion: 0.24
Nodes (10): BackendClient, BackendProcess, CheckpointsTab, SrSection, InferenceTab, ProjectController, ProjectState, ProjectWorkspace (+2 more)

### Community 36 - "Community 36"
Cohesion: 0.53
Nodes (8): _add_dataset_model_run(), auth_headers(), make_paired_dataset(), _make_project(), test_backend_domain_view_endpoints_return_supported_or_unavailable_states(), test_dashboard_activity_guidance_and_status(), test_workspace_preferences_and_recent_projects(), _write_png()

### Community 37 - "Community 37"
Cohesion: 0.29
Nodes (8): _build_scheduler(), _evaluate_training_pass(), _finalize_training_cancel(), _set_run_state(), stop_run_endpoint(), sync_run_job_endpoint(), _training_worker(), get_run()

### Community 38 - "Community 38"
Cohesion: 0.29
Nodes (6): build, paint, shouldRepaint, SizedBox, _SparkChartPainter, SrSparkChart

### Community 39 - "Community 39"
Cohesion: 0.29
Nodes (6): ../classic_theme.dart, build, Container, _getColor, SizedBox, SrChip

### Community 40 - "Community 40"
Cohesion: 0.29
Nodes (6): build, ConstrainedBox, FilledButton, _getIconSize, SizedBox, SrButton

### Community 41 - "Community 41"
Cohesion: 0.33
Nodes (5): ../app_config.dart, build, MaterialApp, SrTunerApp, project_controller.dart

### Community 42 - "Community 42"
Cohesion: 0.33
Nodes (5): dart:async, BoundedPoller, Function, start, stop

### Community 43 - "Community 43"
Cohesion: 0.33
Nodes (5): build, LinearGradient, SizedBox, SrProgressBar, _stripedGradient

### Community 47 - "Community 47"
Cohesion: 0.5
Nodes (3): apiUri, AppConfig, Uri

### Community 48 - "Community 48"
Cohesion: 0.5
Nodes (3): getDirectoryPath, PathPicker, package:file_selector/file_selector.dart

### Community 51 - "Community 51"
Cohesion: 0.67
Nodes (3): Flutter CMakeLists.txt, Linux CMakeLists.txt, Runner CMakeLists.txt

### Community 52 - "Community 52"
Cohesion: 0.67
Nodes (3): SrProgressKind, SrButton, SrProgressBar (design system)

## Knowledge Gaps
- **539 isolated node(s):** `main`, `src/app.dart`, `AppConfig`, `apiUri`, `Uri` (+534 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 28` to `Community 34`, `Inference Tab UI`, `Test Fixtures`, `Dataset Tab UI`, `Community 39`, `Community 40`, `Community 41`, `Classic Components UI`, `Checkpoints Tab UI`, `Training Tab UI`, `Live Metrics Tab UI`, `Community 43`, `Community 38`, `Workspace Tabs`, `Community 18`, `Community 19`, `Community 23`, `Community 25`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `ApiError` connect `Backend API Schemas` to `Backend Core Modules`, `Community 33`, `Checkpoints Module`, `API Endpoints`, `Inference Module`, `Runs Module`, `Community 20`, `Community 22`, `Community 24`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Why does `../backend_client.dart` connect `Community 32` to `Community 34`, `Inference Tab UI`, `Dataset Tab UI`, `Checkpoints Tab UI`, `Training Tab UI`, `Live Metrics Tab UI`, `Workspace Tabs`, `Community 18`, `Community 19`, `Community 23`, `Community 25`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Are the 78 inferred relationships involving `ApiError` (e.g. with `JobError` and `Job`) actually correct?**
  _`ApiError` has 78 INFERRED edges - model-reasoned connections that need verification._
- **Are the 58 inferred relationships involving `Job` (e.g. with `ApiError` and `DatasetPaths`) actually correct?**
  _`Job` has 58 INFERRED edges - model-reasoned connections that need verification._
- **Are the 66 inferred relationships involving `ProjectState` (e.g. with `DatasetPaths` and `DatasetValidation`) actually correct?**
  _`ProjectState` has 66 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `open_project()` (e.g. with `_inject_checkpoint()` and `test_checkpoint_metadata_is_run_owned()`) actually correct?**
  _`open_project()` has 9 INFERRED edges - model-reasoned connections that need verification._