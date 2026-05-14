# Graph Report - .  (2026-05-14)

## Corpus Check
- 169 files · ~136,842 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1560 nodes · 3499 edges · 100 communities (84 shown, 16 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 833 edges (avg confidence: 0.59)
- Token cost: 186,000 input · 6,000 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 95|Community 95]]
- [[_COMMUNITY_Community 96|Community 96]]
- [[_COMMUNITY_Community 97|Community 97]]
- [[_COMMUNITY_Community 98|Community 98]]
- [[_COMMUNITY_Community 99|Community 99]]

## God Nodes (most connected - your core abstractions)
1. `ApiError` - 123 edges
2. `open_project()` - 65 edges
3. `Job` - 63 edges
4. `ProjectState` - 63 edges
5. `_session_project_path()` - 51 edges
6. `DatasetObject` - 46 edges
7. `write_project()` - 44 edges
8. `RunObject` - 43 edges
9. `ModelObject` - 42 edges
10. `CheckpointMetadata` - 41 edges

## Surprising Connections (you probably didn't know these)
- `Live Metrics Specification` --semantically_similar_to--> `SrProgressBar (Solid/Striped/Indeterminate)`  [INFERRED] [semantically similar]
  openspec/changes/archive/2026-05-11-port-design-handoff-flutter-ui/specs/live-metrics/spec.md → design_handoff_sr_tuner/README.md
- `Training Runs Specification` --semantically_similar_to--> `SrProgressBar (Solid/Striped/Indeterminate)`  [INFERRED] [semantically similar]
  openspec/changes/archive/2026-05-11-port-design-handoff-flutter-ui/specs/training-runs/spec.md → design_handoff_sr_tuner/README.md
- `InferenceRequest` --uses--> `CheckpointMetadata`  [INFERRED]
  backend/src/sr_tuner_api/inference.py → /home/theodoros/Documents/sr-tuner/backend/src/sr_tuner_api/checkpoints.py
- `test_dashboard_activity_guidance_and_status()` --calls--> `CheckpointMetadata`  [INFERRED]
  backend/tests/test_classic_workspace.py → /home/theodoros/Documents/sr-tuner/backend/src/sr_tuner_api/checkpoints.py
- `save_checkpoint()` --calls--> `store_asset_path()`  [INFERRED]
  /home/theodoros/Documents/sr-tuner/backend/src/sr_tuner_api/checkpoints.py → backend/src/sr_tuner_api/project_store.py

## Hyperedges (group relationships)
- **Design Handoff to Flutter Port** — design_handoff_sr_tuner_readme, classic_workspace_ui_spec, port_design_handoff_flutter_ui_proposal, flutter_design_system [EXTRACTED 1.00]
- **Core Capabilities Form Desktop Workflow** — desktop_project_workflow, dataset_management, model_management, training_runs, live_metrics, checkpoint_management, inference_workflow [EXTRACTED 1.00]
- **Checkpoint Lifecycle Ownership** — training_runs_spec, checkpoint_management_spec, live_metrics_spec, checkpoint_ownership [EXTRACTED 1.00]
- **Classic Workspace UI Implementation** — classic_workspace_ui_spec, flutter_design_system, locked_design_tokens, sr_shared_components, sr_progress_bar, overview_tab [EXTRACTED 1.00]
- **Inference Uses Checkpoints** — checkpoint_management, inference_workflow, internal_pytorch_sr_model [EXTRACTED 1.00]
- **Flutter Platform Channel System** — fl_binary_messenger, fl_basic_message_channel, fl_method_channel, fl_event_channel, fl_method_call, fl_method_response [INFERRED 0.90]
- **Flutter Linux Codec Type Hierarchy** — fl_message_codec, fl_method_codec, fl_binary_codec, fl_string_codec, fl_standard_message_codec, fl_json_message_codec, fl_json_method_codec, fl_standard_method_codec [INFERRED 0.90]
- **Flutter Plugin Registration Architecture** — fl_plugin_registry, fl_plugin_registrar, fl_application, generated_plugin_registrant_cc, generated_plugin_registrant_h [INFERRED 0.85]
- **Training Pipeline** — sr_tuner_api_main, sr_tuner_api_runs, sr_tuner_api_checkpoints, sr_tuner_api_metrics [EXTRACTED 0.95]
- **Structured Logging Subsystem** — sr_tuner_api_logging_schema, sr_tuner_api_diagnostic_logger, sr_tuner_api_logging_middleware, sr_tuner_api_cause_codes [EXTRACTED 1.00]
- **Workspace Facade — Aggregates Business Logic for UI** — sr_tuner_api_classic_workspace, sr_tuner_api_checkpoints, sr_tuner_api_metrics, sr_tuner_api_datasets, sr_tuner_api_inference, sr_tuner_api_models [INFERRED 0.85]
- **Shell composition pattern for wireframes** — wf_b_shell_chrome, wf_common_primitives, wf_b_rest_components, wf_b_train_components, wf_start_screen [EXTRACTED 1.00]
- **Diagnostic logging and correlation ID infrastructure** — test_diagnostic_logging_logging_schema, test_correlation_errors_correlation, test_job_logs_readable_job_logs [INFERRED 0.80]
- **Project lifecycle test suite spanning multiple test files** — test_classic_workspace_workspace_prefs, test_projects_project_lifecycle, test_smoke_end_to_end_flow, conftest_fixture_paired_dataset_4x [INFERRED 0.75]
- **Workspace Tab Architecture Pattern** — workspace_dataset_tab_DatasetTab, workspace_inference_tab_InferenceTab, workspace_live_metrics_tab_LiveMetricsTab, workspace_model_tab_ModelTab, workspace_training_tab_TrainingTab, backend_client_BackendClient, project_models_ProjectState [EXTRACTED 1.00]
- **Live Metrics Polling Data Flow** — workspace_live_metrics_tab_LiveMetricsTab, polling_BoundedPoller, project_models_LiveRunDetail, project_models_MetricsEnvelope, project_models_ActiveRunStatus, workspace_live_metrics_tab_LiveSnapshot [EXTRACTED 1.00]
- **Backend Communication Layer** — backend_client_BackendClient, backend_process_BackendProcess, app_config_AppConfig, backend_client_ApiException, project_controller_ProjectController [EXTRACTED 1.00]
- **Logging and Diagnostics Infrastructure** — diagnostic_logger_DiagnosticLogger, logging_schema_LogLevel, logging_schema_EventNames, logging_schema_Components, logging_schema_LogEvent, cause_codes_CauseCodes, debug_session_DebugSession [EXTRACTED 1.00]
- **Shared UI Component Library** — classic_components_SrSection, classic_components_SrBanner, classic_components_SrChip, classic_components_SrMetricCard, classic_components_SrProgressBar, classic_components_SrEmptyState, classic_components_SrSparkline, classic_components_SrCompareViewer, classic_theme_SrTokens, shared_widgets_ApiErrorBanner, shared_widgets_JobProgressPanel [EXTRACTED 1.00]
- **Dev Workflow Scripts** — cpu_backend_setup, backend_dev_launcher, frontend_dev_launcher, backend_stop_script, cleanup_script [INFERRED 0.85]
- **Dart Test Suite (Chunk 5)** — workspace_ui_tests, project_model_tests, app_widget_tests, logging_schema_tests [INFERRED 0.90]
- **Test Mocking of Backend** — fake_backend_client, backend_client_lib, workspace_ui_tests, backend_uvicorn_app [INFERRED 0.80]
- **sr-tuner Core Training and Inference Workflow** — dataset_management_system, model_management_system, training_run_system, checkpoint_management_system, inference_system, live_metrics_system [EXTRACTED 1.00]
- **Live Metrics Visibility Improvement Components** — split_metric_charts, validation_preview_4way, live_metrics_visibility_spec, improve_live_metrics_tasks [EXTRACTED 1.00]
- **Debug Observability Foundation Blocks** — debug_observability_system, structured_logging_schema, correlation_id_tracing [EXTRACTED 1.00]
- **Texture Rendering Pipeline** — fl_texture_FlTexture, fl_texture_gl_FlTextureGL, fl_texture_registrar_FlTextureRegistrar [INFERRED 0.85]
- **Debug Logging Instrumentation Scope** — debug-observability, inference-workflow, live-metrics, desktop-project-workflow [EXTRACTED 1.00]
- **Scale Agnostic Models Scope** — trained-core-model, scale-agnostic-training, model-import-with-weights, model-management, training-runs, inference-workflow [EXTRACTED 1.00]
- **Core Model Lifecycle** — model-management, training-runs, scale-agnostic-training, trained-core-model, inference-workflow [INFERRED 0.85]

## Communities (100 total, 16 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.09
Nodes (124): BaseModel, HTTPException, CauseCodes, CheckpointMetadata, ActionState, _active_model_name(), activity_feed(), ActivityEvent (+116 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (61): SrTunerApp Widget, AppConfig Constants and URI Builder, ApiException Error Type, BackendClient, BackendProcess Lifecycle Manager, CauseCodes Error Cause String Constants, SrBanner, SrChip Label Badge Component (+53 more)

### Community 2 - "Community 2"
Cohesion: 0.03
Nodes (59): _BatchDropZone, _BatchResultSummary, BeforeAfterComparison, _BeforeAfterComparisonState, build, _buildPreview, Card, Center (+51 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (25): BaseHTTPMiddleware, Enum, create_component_logger(), _default_sink(), DiagnosticLogger, emit_event(), StructuredLogHandler, CreateJobRequest (+17 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (51): ActionState, ActiveRunStatus, ActivityEvent, ActivityFeedEnvelope, CheckpointAggregate, CheckpointListEnvelope, CheckpointSummary, DashboardSummary (+43 more)

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (45): active_run_endpoint(), activity_endpoint(), checkpoint_aggregate_endpoint(), compatibility_endpoint(), create_job_endpoint(), dashboard_endpoint(), dataset_detail_endpoint(), dataset_resynthesis_endpoint() (+37 more)

### Community 6 - "Community 6"
Cohesion: 0.06
Nodes (50): Build Desktop Workflow Tasks, Checkpoint Management Specification, Checkpoint Management System, Checkpoint Management Spec, Checkpoint Ownership Policy, Classic Workspace UI Specification, Correlation ID Tracing, Dataset Management Specification (+42 more)

### Community 7 - "Community 7"
Cohesion: 0.04
Nodes (47): ../diagnostic_image.dart, build, Column, DiagnosticNetworkImage, didUpdateWidget, dispose, _drawText, _EventsPanel (+39 more)

### Community 8 - "Community 8"
Cohesion: 0.04
Nodes (45): AlertDialog, ApiException, AspectRatio, build, Column, _DatasetChoiceTile, _DatasetCreationProgressDialog, _DatasetCreationProgressDialogState (+37 more)

### Community 9 - "Community 9"
Cohesion: 0.14
Nodes (40): _handle_oom_or_raise(), _infer_single(), inference_readiness(), InferenceRequest, _is_oom(), _linear_blend_mask(), _list_images(), list_inference_history() (+32 more)

### Community 10 - "Community 10"
Cohesion: 0.08
Nodes (21): FlApplication - Flutter GTK Application, FlBasicMessageChannel, FlBinaryCodec, FlBinaryMessenger, FlDartProject, FlEngine - Flutter Engine, FlEventChannel, FlJsonMessageCodec (+13 more)

### Community 11 - "Community 11"
Cohesion: 0.13
Nodes (38): _generate_training_preview(), active_run_status(), _amd_gpu_utilization_temperature(), cause_for_device(), _cpu_telemetry(), _cuda_telemetry(), _definition_path(), _extract_first_number() (+30 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (37): ActiveRunStatus, ActivityFeedEnvelope, CheckpointAggregate, DashboardSummary, _dataset, DatasetDetail, DatasetSummary, _FakeBackendClient (+29 more)

### Community 13 - "Community 13"
Cohesion: 0.16
Nodes (33): ID & Slug Generation, store_asset_path(), str, auth_headers(), make_dataset_and_model(), make_paired_dataset(), make_project(), test_atomic_write_keeps_backup() (+25 more)

### Community 14 - "Community 14"
Cohesion: 0.06
Nodes (35): _BasicsSection, BlockedState, build, Column, _DependencyRow, didUpdateWidget, dispose, _EstimateSection (+27 more)

### Community 15 - "Community 15"
Cohesion: 0.1
Nodes (36): Backend Process Lifecycle, Checkpoint-Derived Model Status, Checkpoint Management, Comprehensive Debug Logging Change, Correlation ID, Dataset Management, Debug Observability, Debug Troubleshooting Guide (+28 more)

### Community 16 - "Community 16"
Cohesion: 0.06
Nodes (33): ../design_system/sr_button.dart, ../design_system/sr_chart.dart, ../design_system/sr_chip.dart, _AggregateHeader, BlockedState, build, Center, _CheckpointRow (+25 more)

### Community 17 - "Community 17"
Cohesion: 0.06
Nodes (32): AspectRatio, build, Card, Center, Container, CustomPaint, _DashedBorderPainter, didUpdateWidget (+24 more)

### Community 18 - "Community 18"
Cohesion: 0.18
Nodes (27): _add_dataset(), auth_headers(), _create_model(), _create_run(), _inject_checkpoint(), _make_project(), _make_pth(), Phase 10 smoke tests: end-to-end flow, project reopen, and job infrastructure. (+19 more)

### Community 19 - "Community 19"
Cohesion: 0.15
Nodes (25): create_run_endpoint(), devices_endpoint(), training_readiness_endpoint(), _active_run(), _apply_job_state(), available_devices(), build_internal_sr_model(), build_paired_sr_dataset() (+17 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (26): checkpoints_tab.dart, dataset_tab.dart, build, Container, didUpdateWidget, dispose, Icon, initState (+18 more)

### Community 21 - "Community 21"
Cohesion: 0.22
Nodes (24): _assign_markers(), delete_checkpoint(), auth_headers(), _inject_checkpoint(), _make_project(), _make_run(), Directly inject a fake checkpoint record into a run without real files., Create a minimal dataset+model+run and return the run_id. (+16 more)

### Community 22 - "Community 22"
Cohesion: 0.14
Nodes (23): CheckpointListResponse, derive_project_checkpoints(), export_checkpoint_onnx(), export_checkpoint_pth(), ExportOnnxRequest, ExportPthRequest, _find_run_raw(), _get_active_checkpoint() (+15 more)

### Community 23 - "Community 23"
Cohesion: 0.09
Nodes (21): build, Column, _CreateOpenColumn, dispose, _Header, initState, InkWell, ListView (+13 more)

### Community 24 - "Community 24"
Cohesion: 0.1
Nodes (20): _ActivityCard, build, Center, Column, didUpdateWidget, dispose, initState, ListView (+12 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (18): cause_codes.dart, dart:async, diagnostic_logger.dart, activate, deactivate, DebugSession, effectiveMinimum, build (+10 more)

### Community 26 - "Community 26"
Cohesion: 0.23
Nodes (18): update_workspace(), delete_dataset(), _resolve_dataset_folder(), delete_dataset_endpoint(), delete_run_endpoint(), _persist_run_metadata(), backup_file(), create_project() (+10 more)

### Community 27 - "Community 27"
Cohesion: 0.36
Nodes (19): Error Cause Code Constants, Checkpoint Management, Workspace View Models, App Configuration Constants, Dataset Management, Structured Diagnostic Logger, Error Handling & HTTP Exception Handlers, Image Format Probing (+11 more)

### Community 28 - "Community 28"
Cohesion: 0.12
Nodes (14): new_id(), slugify(), health(), version(), ApiErrorResponse, ApiErrorShape, CreateProjectRequest, HealthResponse (+6 more)

### Community 29 - "Community 29"
Cohesion: 0.19
Nodes (15): FastAPI, Flutter, Python, PyTorch, sr-tuner, api_error_handler(), _clean_validation_errors(), _correlation_id() (+7 more)

### Community 30 - "Community 30"
Cohesion: 0.12
Nodes (16): dart:convert, dart:io, File, WorkspaceStore, _addCommonHeaders, ApiException, BackendClient, beginCorrelatedAction (+8 more)

### Community 31 - "Community 31"
Cohesion: 0.12
Nodes (15): ../classic_components.dart, build, dispose, _formatCount, initState, _KeyValue, ListView, ModelTab (+7 more)

### Community 32 - "Community 32"
Cohesion: 0.23
Nodes (15): record_activity(), create_model_endpoint(), create_project_endpoint(), delete_model_endpoint(), generate_video_dataset_endpoint(), launch_run_endpoint(), open_project_endpoint(), open_recent_project_endpoint() (+7 more)

### Community 34 - "Community 34"
Cohesion: 0.13
Nodes (14): backend_process.dart, action, build, didChangeAppLifecycleState, dispose, initState, ProjectController, _ProjectControllerState (+6 more)

### Community 35 - "Community 35"
Cohesion: 0.14
Nodes (12): ../classic_theme.dart, main, build, Container, _getColor, SizedBox, SrChip, build (+4 more)

### Community 36 - "Community 36"
Cohesion: 0.14
Nodes (13): addLogSink, createComponentLogger, debug, DiagnosticLogger, error, fatal, info, _log (+5 more)

### Community 37 - "Community 37"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 38 - "Community 38"
Cohesion: 0.16
Nodes (14): App Config Library, App Widget Smoke Test, Backend Client Library, Backend Dev Launcher, Backend Stop Script, Backend Uvicorn Server, Cleanup Script, CPU Backend Setup Script (+6 more)

### Community 39 - "Community 39"
Cohesion: 0.28
Nodes (12): model_defaults_endpoint(), check_dataset_model_compatibility(), CompatibilityResponse, create_model(), default_model_config(), delete_model(), _derive_status(), _find_model() (+4 more)

### Community 40 - "Community 40"
Cohesion: 0.17
Nodes (13): _build_scheduler(), _combined_training_loss(), _detail_loss(), _evaluate_training_pass(), _finalize_training_cancel(), _perceptual_features(), _set_run_state(), stop_run_endpoint() (+5 more)

### Community 41 - "Community 41"
Cohesion: 0.15
Nodes (3): DC, DCCtx, s

### Community 43 - "Community 43"
Cohesion: 0.17
Nodes (11): ../backend_client.dart, dart:math, ApiException, _BackendCommand, BackendProcess, _command, Duration, _generateSessionToken (+3 more)

### Community 44 - "Community 44"
Cohesion: 0.2
Nodes (9): ApiErrorBanner, BlockedState, build, Card, JobProgressPanel, MaterialBanner, Padding, SizedBox (+1 more)

### Community 45 - "Community 45"
Cohesion: 0.2
Nodes (9): Components, eventName, EventNames, _isBinaryLike, isEnabled, LogEvent, LogLevel, _redactBinary (+1 more)

### Community 46 - "Community 46"
Cohesion: 0.2
Nodes (9): ClassicTheme, copyWith, dark, lerp, lerpDouble, light, SrTokens, _theme (+1 more)

### Community 47 - "Community 47"
Cohesion: 0.53
Nodes (8): _add_dataset_model_run(), auth_headers(), make_paired_dataset(), _make_project(), test_backend_domain_view_endpoints_return_supported_or_unavailable_states(), test_dashboard_activity_guidance_and_status(), test_workspace_preferences_and_recent_projects(), _write_png()

### Community 48 - "Community 48"
Cohesion: 0.28
Nodes (9): Load and validate a checkpoint payload. Raises ApiError on any failure., validate_checkpoint_payload(), _make_pth_file(), test_validate_payload_architecture_mismatch(), test_validate_payload_bad_schema_version(), test_validate_payload_missing_fields(), test_validate_payload_missing_file(), test_validate_payload_ok() (+1 more)

### Community 49 - "Community 49"
Cohesion: 0.25
Nodes (6): main, main, package:flutter_test/flutter_test.dart, package:sr_tuner/main.dart, package:sr_tuner/src/cause_codes.dart, package:sr_tuner/src/logging_schema.dart

### Community 50 - "Community 50"
Cohesion: 0.5
Nodes (8): DesignCanvas: Figma-like canvas component, TweaksPanel: interactive prototyping controls, wf-b-rest: Checkpoints + Inference tabs, wf-b-shell: Shell chrome + Overview + Dataset tabs, wf-b-train: Model + Training + Live tabs, wf-common: shared UI primitives (Icon, Win, Btn, etc.), wf-start: Start screen / project picker, Wireframes.html: main orchestrating document

### Community 51 - "Community 51"
Cohesion: 0.5
Nodes (8): FlTexture Interface, FlTextureGL OpenGL Texture, FlTextureRegistrar Texture Lifecycle, FlValue Platform Channel Data Types, FlView GTK Widget, Flutter Linux SDK Umbrella Header, Linux Runner Main Entry Point, MyApplication GTK App

### Community 52 - "Community 52"
Cohesion: 0.67
Nodes (6): ImageInfo, probe_image(), _probe_jpeg(), _probe_png(), _probe_tiff(), _probe_webp()

### Community 53 - "Community 53"
Cohesion: 0.29
Nodes (6): build, paint, shouldRepaint, SizedBox, _SparkChartPainter, SrSparkChart

### Community 54 - "Community 54"
Cohesion: 0.29
Nodes (6): build, ConstrainedBox, FilledButton, _getIconSize, SizedBox, SrButton

### Community 57 - "Community 57"
Cohesion: 0.33
Nodes (5): ../app_config.dart, build, MaterialApp, SrTunerApp, project_controller.dart

### Community 60 - "Community 60"
Cohesion: 0.5
Nodes (3): apiUri, AppConfig, Uri

### Community 61 - "Community 61"
Cohesion: 0.5
Nodes (3): getDirectoryPath, PathPicker, package:file_selector/file_selector.dart

### Community 62 - "Community 62"
Cohesion: 0.5
Nodes (3): main, package:sr_tuner/src/app_config.dart, package:sr_tuner/src/project_models.dart

### Community 63 - "Community 63"
Cohesion: 0.5
Nodes (4): conftest fixture_paired_dataset_4x, test_classic_workspace: workspace & dashboard tests, test_projects: project lifecycle tests, test_smoke: end-to-end & project reopen

### Community 66 - "Community 66"
Cohesion: 0.67
Nodes (3): Flutter CMakeLists.txt, Linux CMakeLists.txt, Runner CMakeLists.txt

### Community 67 - "Community 67"
Cohesion: 0.67
Nodes (3): test_correlation_errors: correlation ID in errors, test_diagnostic_logging: logging schema & redaction, test_job_logs_readable: job log formatting

### Community 68 - "Community 68"
Cohesion: 0.67
Nodes (3): Cause Codes Library, Logging Schema Library, Logging Schema Tests

## Knowledge Gaps
- **653 isolated node(s):** `Local API package for sr-tuner.`, `Write a checkpoint file and record metadata on the run. Returns the new metadata`, `Load and validate a checkpoint payload. Raises ApiError on any failure.`, `Estimate CPU system RAM needed for training.      Covers model parameters in CPU`, `EventNames` (+648 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 35` to `Community 34`, `Community 2`, `Community 7`, `Community 8`, `Community 44`, `Community 12`, `Community 46`, `Community 14`, `Community 16`, `Community 17`, `Community 20`, `Community 53`, `Community 54`, `Community 23`, `Community 24`, `Community 57`, `Community 25`, `Community 31`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `ApiError` connect `Community 0` to `Community 32`, `Community 3`, `Community 5`, `Community 39`, `Community 40`, `Community 9`, `Community 11`, `Community 48`, `Community 19`, `Community 52`, `Community 21`, `Community 22`, `Community 26`, `Community 29`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `open_project()` connect `Community 26` to `Community 0`, `Community 32`, `Community 5`, `Community 39`, `Community 40`, `Community 9`, `Community 11`, `Community 13`, `Community 47`, `Community 18`, `Community 19`, `Community 21`, `Community 22`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Are the 82 inferred relationships involving `ApiError` (e.g. with `UnsupportedState` and `ActionState`) actually correct?**
  _`ApiError` has 82 INFERRED edges - model-reasoned connections that need verification._
- **Are the 82 inferred relationships involving `str` (e.g. with `export_checkpoint_onnx()` and `_write_payload_json()`) actually correct?**
  _`str` has 82 INFERRED edges - model-reasoned connections that need verification._
- **Are the 16 inferred relationships involving `open_project()` (e.g. with `save_checkpoint()` and `list_run_checkpoints()`) actually correct?**
  _`open_project()` has 16 INFERRED edges - model-reasoned connections that need verification._
- **Are the 54 inferred relationships involving `Job` (e.g. with `UnsupportedState` and `ActionState`) actually correct?**
  _`Job` has 54 INFERRED edges - model-reasoned connections that need verification._