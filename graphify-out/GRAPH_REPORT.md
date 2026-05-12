# Graph Report - .  (2026-05-12)

## Corpus Check
- 105 files · ~100,508 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1140 nodes · 2670 edges · 55 communities (52 shown, 3 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 632 edges (avg confidence: 0.54)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Backend Workspace API|Backend Workspace API]]
- [[_COMMUNITY_Backend Workspace API|Backend Workspace API]]
- [[_COMMUNITY_Inference UI|Inference UI]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Inference UI|Inference UI]]
- [[_COMMUNITY_Dataset UI|Dataset UI]]
- [[_COMMUNITY_Inference UI|Inference UI]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Checkpoint API|Checkpoint API]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Training UI|Training UI]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Inference UI|Inference UI]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Backend Workspace API|Backend Workspace API]]
- [[_COMMUNITY_Backend API|Backend API]]
- [[_COMMUNITY_Models & State|Models & State]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Backend API|Backend API]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Models & State|Models & State]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Backend Workspace API|Backend Workspace API]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Design System|Design System]]
- [[_COMMUNITY_Backend API|Backend API]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Tests|Tests]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Tests|Tests]]

## God Nodes (most connected - your core abstractions)
1. `ApiError` - 123 edges
2. `Job` - 69 edges
3. `ProjectState` - 68 edges
4. `open_project()` - 58 edges
5. `_session_project_path()` - 48 edges
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
- `sr-tuner` --uses--> `Python`  [EXTRACTED]
  pubspec.yaml → README.md
- `sr-tuner` --uses--> `PyTorch`  [EXTRACTED]
  pubspec.yaml → README.md
- `sr-tuner` --persists_to--> `sr-tuner.project.json`  [EXTRACTED]
  pubspec.yaml → README.md

## Hyperedges (group relationships)
- **Core Capabilities Form Desktop Workflow** — desktop_project_workflow, dataset_management, model_management, training_runs, live_metrics, checkpoint_management, inference_workflow [EXTRACTED 1.00]
- **Training Depends on Datasets and Models** — dataset_management, model_management, training_runs, checkpoint_management [EXTRACTED 1.00]
- **Inference Uses Checkpoints** — checkpoint_management, inference_workflow, internal_pytorch_sr_model [EXTRACTED 1.00]
- **Classic Workspace UI Implementation** — classic_workspace_ui_spec, flutter_design_system, locked_design_tokens, sr_shared_components, sr_progress_bar, overview_tab [EXTRACTED 1.00]
- **Design Handoff to Flutter Port** — design_handoff_sr_tuner_readme, classic_workspace_ui_spec, port_design_handoff_flutter_ui_proposal, flutter_design_system [EXTRACTED 1.00]
- **Checkpoint Lifecycle Ownership** — training_runs_spec, checkpoint_management_spec, live_metrics_spec, checkpoint_ownership [EXTRACTED 1.00]

## Communities (55 total, 3 thin omitted)

### Community 0 - "Backend Workspace API"
Cohesion: 0.13
Nodes (100): BaseModel, HTTPException, CheckpointListResponse, CheckpointMetadata, ExportOnnxRequest, ExportPthRequest, OnnxReadinessResponse, ProjectCheckpointIndex (+92 more)

### Community 1 - "Backend Workspace API"
Cohesion: 0.07
Nodes (72): _assign_markers(), delete_checkpoint(), derive_project_checkpoints(), export_checkpoint_onnx(), export_checkpoint_pth(), _find_run_raw(), _get_active_checkpoint(), list_run_checkpoints() (+64 more)

### Community 2 - "Inference UI"
Cohesion: 0.03
Nodes (59): _BatchDropZone, _BatchResultSummary, BeforeAfterComparison, _BeforeAfterComparisonState, build, _buildPreview, Card, Center (+51 more)

### Community 3 - "Tests"
Cohesion: 0.07
Nodes (40): Atomic Project Writes, FastAPI, Flutter, Python, PyTorch, Session Token Protection, sr-tuner, _copy_or_move_dataset() (+32 more)

### Community 4 - "Inference UI"
Cohesion: 0.04
Nodes (51): ActionState, ActiveRunStatus, ActivityEvent, ActivityFeedEnvelope, CheckpointAggregate, CheckpointListEnvelope, CheckpointSummary, DashboardSummary (+43 more)

### Community 5 - "Dataset UI"
Cohesion: 0.04
Nodes (45): AlertDialog, ApiException, AspectRatio, build, Column, _DatasetChoiceTile, _DatasetCreationProgressDialog, _DatasetCreationProgressDialogState (+37 more)

### Community 6 - "Inference UI"
Cohesion: 0.04
Nodes (43): ActiveRunStatus, ActivityFeedEnvelope, CheckpointAggregate, DashboardSummary, _dataset, DatasetDetail, DatasetSummary, _FakeBackendClient (+35 more)

### Community 7 - "Tests"
Cohesion: 0.14
Nodes (40): _handle_oom_or_raise(), _infer_single(), inference_readiness(), InferenceRequest, _is_oom(), _linear_blend_mask(), _list_images(), list_inference_history() (+32 more)

### Community 8 - "Checkpoint API"
Cohesion: 0.09
Nodes (35): active_run_endpoint(), activity_endpoint(), checkpoint_aggregate_endpoint(), compatibility_endpoint(), create_job_endpoint(), dashboard_endpoint(), dataset_detail_endpoint(), dataset_resynthesis_endpoint() (+27 more)

### Community 9 - "Design System"
Cohesion: 0.06
Nodes (33): ../design_system/sr_button.dart, ../design_system/sr_chart.dart, ../design_system/sr_chip.dart, _AggregateHeader, BlockedState, build, Center, _CheckpointRow (+25 more)

### Community 10 - "Training UI"
Cohesion: 0.06
Nodes (32): _BasicsSection, BlockedState, build, Column, _DependencyRow, didUpdateWidget, dispose, _EstimateSection (+24 more)

### Community 11 - "Community 11"
Cohesion: 0.06
Nodes (30): build, Column, didUpdateWidget, dispose, _drawSeries, _EventsPanel, _fetchSnapshot, _formatMetric (+22 more)

### Community 12 - "Tests"
Cohesion: 0.16
Nodes (27): auth_headers(), make_dataset_and_model(), make_paired_dataset(), make_project(), test_atomic_write_keeps_backup(), test_corrupt_project_reports_backup_recovery(), test_create_and_open_project(), test_create_refuses_non_empty_non_project_folder() (+19 more)

### Community 13 - "Community 13"
Cohesion: 0.07
Nodes (29): AspectRatio, build, Card, Center, Container, CustomPaint, _DashedBorderPainter, dispose (+21 more)

### Community 14 - "Tests"
Cohesion: 0.18
Nodes (27): _add_dataset(), auth_headers(), _create_model(), _create_run(), _inject_checkpoint(), _make_project(), _make_pth(), Phase 10 smoke tests: end-to-end flow, project reopen, and job infrastructure. (+19 more)

### Community 15 - "Inference UI"
Cohesion: 0.07
Nodes (26): checkpoints_tab.dart, dataset_tab.dart, build, Container, didUpdateWidget, dispose, Icon, initState (+18 more)

### Community 16 - "Tests"
Cohesion: 0.15
Nodes (25): devices_endpoint(), training_readiness_endpoint(), _active_run(), _apply_job_state(), available_devices(), build_internal_sr_model(), build_paired_sr_dataset(), create_run() (+17 more)

### Community 17 - "Tests"
Cohesion: 0.18
Nodes (23): active_run_status(), _definition_path(), generate_validation_preview(), hardware_telemetry(), hardware_telemetry_for_project(), initialize_run_metrics(), latest_preview(), _latest_speed() (+15 more)

### Community 18 - "Community 18"
Cohesion: 0.09
Nodes (21): build, Column, _CreateOpenColumn, dispose, _Header, initState, InkWell, ListView (+13 more)

### Community 19 - "Community 19"
Cohesion: 0.1
Nodes (20): _ActivityCard, build, Center, Column, didUpdateWidget, dispose, initState, ListView (+12 more)

### Community 20 - "Community 20"
Cohesion: 0.1
Nodes (19): backend_process.dart, dart:async, BoundedPoller, Function, start, stop, action, build (+11 more)

### Community 21 - "Design System"
Cohesion: 0.14
Nodes (21): Checkpoint Management Specification, Checkpoint Ownership Policy, Classic Workspace UI Specification, Dataset Management Specification, Design Handoff SR Tuner README, Desktop Project Workflow Specification, Flutter Design System, IBM Plex Typography (+13 more)

### Community 22 - "Backend Workspace API"
Cohesion: 0.15
Nodes (20): record_activity(), create_model_endpoint(), create_project_endpoint(), create_run_endpoint(), generate_video_dataset_endpoint(), launch_run_endpoint(), open_project_endpoint(), open_recent_project_endpoint() (+12 more)

### Community 23 - "Backend API"
Cohesion: 0.18
Nodes (19): Checkpoint-Derived Model Status, Checkpoint Management, Dataset Management, Desktop Project Workflow, Index-Based Validation Split, Inference Workflow, Internal PyTorch SR Model, Job Model (+11 more)

### Community 24 - "Models & State"
Cohesion: 0.12
Nodes (15): ../classic_components.dart, build, dispose, _formatCount, initState, _KeyValue, ListView, ModelTab (+7 more)

### Community 26 - "Community 26"
Cohesion: 0.15
Nodes (12): dart:convert, dart:io, ApiException, BackendClient, close, _get, _post, _readJson (+4 more)

### Community 27 - "Community 27"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 28 - "Backend API"
Cohesion: 0.15
Nodes (10): health(), version(), ApiErrorResponse, ApiErrorShape, CreateProjectRequest, HealthResponse, OpenProjectRequest, ProjectResponse (+2 more)

### Community 29 - "Community 29"
Cohesion: 0.15
Nodes (3): DC, DCCtx, s

### Community 31 - "Community 31"
Cohesion: 0.18
Nodes (10): ../backend_client.dart, dart:math, ApiException, _BackendCommand, BackendProcess, _command, Duration, _generateSessionToken (+2 more)

### Community 32 - "Models & State"
Cohesion: 0.2
Nodes (9): ApiErrorBanner, BlockedState, build, Card, JobProgressPanel, MaterialBanner, Padding, SizedBox (+1 more)

### Community 33 - "Community 33"
Cohesion: 0.2
Nodes (9): ClassicTheme, copyWith, dark, lerp, lerpDouble, light, SrTokens, _theme (+1 more)

### Community 34 - "Community 34"
Cohesion: 0.2
Nodes (8): ../app_config.dart, main, build, MaterialApp, SrTunerApp, package:flutter/material.dart, project_controller.dart, src/app.dart

### Community 35 - "Tests"
Cohesion: 0.53
Nodes (8): _add_dataset_model_run(), auth_headers(), make_paired_dataset(), _make_project(), test_backend_domain_view_endpoints_return_supported_or_unavailable_states(), test_dashboard_activity_guidance_and_status(), test_workspace_preferences_and_recent_projects(), _write_png()

### Community 36 - "Backend Workspace API"
Cohesion: 0.36
Nodes (8): forget_recent_project(), list_recent_projects(), _read_recent_records(), _recent_projects_path(), remember_recent_project(), _write_recent_records(), forget_recent_project_endpoint(), recent_projects_endpoint()

### Community 37 - "Design System"
Cohesion: 0.29
Nodes (6): ../classic_theme.dart, build, LinearGradient, SizedBox, SrProgressBar, _stripedGradient

### Community 38 - "Design System"
Cohesion: 0.29
Nodes (6): build, ConstrainedBox, FilledButton, _getIconSize, SizedBox, SrButton

### Community 39 - "Design System"
Cohesion: 0.29
Nodes (6): build, paint, shouldRepaint, SizedBox, _SparkChartPainter, SrSparkChart

### Community 40 - "Design System"
Cohesion: 0.33
Nodes (5): build, Container, _getColor, SizedBox, SrChip

### Community 41 - "Backend API"
Cohesion: 0.2
Nodes (3): Local API package for sr-tuner., model_defaults_endpoint(), default_model_config()

### Community 45 - "Community 45"
Cohesion: 0.5
Nodes (3): apiUri, AppConfig, Uri

### Community 46 - "Community 46"
Cohesion: 0.5
Nodes (3): getDirectoryPath, PathPicker, package:file_selector/file_selector.dart

### Community 48 - "Community 48"
Cohesion: 0.67
Nodes (3): _parent_process_alive(), _terminate_process(), _watch_parent_process()

### Community 50 - "Community 50"
Cohesion: 0.67
Nodes (3): Flutter CMakeLists.txt, Linux CMakeLists.txt, Runner CMakeLists.txt

## Knowledge Gaps
- **526 isolated node(s):** `main`, `src/app.dart`, `AppConfig`, `apiUri`, `Uri` (+521 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 34` to `Models & State`, `Community 33`, `Inference UI`, `Dataset UI`, `Design System`, `Design System`, `Design System`, `Design System`, `Training UI`, `Community 11`, `Design System`, `Community 13`, `Inference UI`, `Inference UI`, `Community 18`, `Community 19`, `Community 20`, `Models & State`?**
  _High betweenness centrality (0.103) - this node is a cross-community bridge._
- **Why does `ApiError` connect `Backend Workspace API` to `Backend Workspace API`, `Tests`, `Tests`, `Checkpoint API`, `Tests`, `Tests`, `Backend Workspace API`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `../backend_client.dart` connect `Community 31` to `Models & State`, `Inference UI`, `Dataset UI`, `Design System`, `Training UI`, `Community 11`, `Inference UI`, `Community 18`, `Community 19`, `Community 20`, `Models & State`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Are the 78 inferred relationships involving `ApiError` (e.g. with `JobError` and `Job`) actually correct?**
  _`ApiError` has 78 INFERRED edges - model-reasoned connections that need verification._
- **Are the 58 inferred relationships involving `Job` (e.g. with `ApiError` and `DatasetPaths`) actually correct?**
  _`Job` has 58 INFERRED edges - model-reasoned connections that need verification._
- **Are the 66 inferred relationships involving `ProjectState` (e.g. with `DatasetPaths` and `DatasetValidation`) actually correct?**
  _`ProjectState` has 66 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `open_project()` (e.g. with `_inject_checkpoint()` and `test_checkpoint_metadata_is_run_owned()`) actually correct?**
  _`open_project()` has 9 INFERRED edges - model-reasoned connections that need verification._