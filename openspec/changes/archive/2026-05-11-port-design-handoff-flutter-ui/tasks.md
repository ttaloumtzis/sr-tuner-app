## 1. Backend View Models And Persistence

- [x] 1.1 Add optional workspace preference fields for theme, density, selected tab, and per-project UI state with migration-safe defaults.
- [x] 1.2 Define endpoint paths, DTO field names, unsupported-state shapes, and ownership boundaries for all new backend view models before implementing screen-specific APIs.
- [x] 1.3 Implement local recent-project storage and APIs for listing, filtering-ready metadata, stale/missing path states, and opening a recent project path.
- [x] 1.4 Add project dashboard summary response with counts, dataset pair total, active model, best PSNR, active run state, backend status, device badge, app version, project path, disk free, and idle/busy state.
- [x] 1.5 Add project activity feed recording and response mapping for dataset, model, run, checkpoint, and inference events.
- [x] 1.6 Add optional VCS branch detection for status bar data with unavailable-state handling.
- [x] 1.7 Add next-step guidance derivation for missing dataset, missing model, ready-to-train, active-training, checkpoint-ready, inference-ready, and loss-plateau states.
- [x] 1.8 Document and enforce project terminology mapping where project folders and `sr-tuner.project.json` are canonical and `.srtproj archive` import/export is disabled future functionality.
- [x] 1.9 Add backend tests for dashboard summary, recent projects including stale/missing paths, workspace preferences, activity feed, plateau guidance, VCS/disk status, manifest terminology assumptions, and disk warning behavior.

## 2. Backend Domain Additions

- [x] 2.1 Extend dataset detail APIs with source rows, source recovery actions, health checks, degradation pipeline summary, preview pair metadata, indexed preview navigation, channel histogram summary, rescan action, and export availability.
- [x] 2.2 Expand video dataset APIs to support wizard-facing source metadata, sampling strategy, estimated yield, output size, and deduplication guidance.
- [x] 2.3 Add generated-dataset re-synthesis backend support that creates a new dataset version linked to the source dataset, or explicit unsupported-state response.
- [x] 2.4 Add model template catalog/detail APIs with support state, filter metadata, import availability, architecture summary, parameter count, VRAM estimate, input crop, architecture steps, hyperparameters, defaults, reset, and save-as-model support.
- [x] 2.5 Add training estimate API and run-setting patch API for clone settings, resume preparation, low-pair guard, unsupported loss rows, run-owned checkpoint retention settings, EMA support state, and suggested fixes.
- [x] 2.6 Add live run detail response fields for epoch progress, run progress, ETA, recent events, log tail/open-log path, validation sample navigation, validation sample metrics, protected crash snapshot state, and classified CUDA OOM error state.
- [x] 2.7 Add snapshot checkpoint endpoint for active runs with unsupported-state handling.
- [x] 2.8 Add aggregate checkpoint index API with best checkpoint, manual/star/protected/crash-snapshot state, PSNR trend/delta, row actions, resume availability, multi-select comparison state, application of run-owned automatic pruning policy, prune availability, and empty-state action support.
- [x] 2.9 Extend inference responses with blocked checklist data, inspector metadata including bit depth and sharpness gain, recent filmstrip records, add-tile action, batch drop-zone readiness, tuning support state, and compare-view dimensions.
- [x] 2.10 Add backend tests for dataset details/recovery/re-synthesis, model templates/import/reset/save, training estimates/fixes/retention/EMA, live OOM/crash-snapshot/open-log/sample navigation, checkpoint aggregate ranking/actions/pruning/manual protection, and inference inspector/checklist/add-tile data.

## 3. Flutter Client Models

- [x] 3.1 Add Dart models and `BackendClient` methods for recent projects, dashboard summary, activity feed, next-step guidance, status bar data, and workspace preferences.
- [x] 3.2 Add Dart models/client methods for dataset detail/recovery/re-synthesis, video wizard metadata, model templates/import/reset/save, training estimates/fixes/retention, live detail/events/open-log/crash snapshot, snapshot, checkpoint aggregate/pruning/comparison, and inference inspector/add-tile data.
- [x] 3.3 Update polling flows to use the richer live/dashboard responses without increasing polling frequency beyond bounded intervals.
- [x] 3.4 Add model parsing tests for new backend response shapes and recoverable error states.

## 4. Flutter Design System

- [x] 4.1 Add Classic Workspace light/dark color tokens, text styles, spacing constants, density handling, and ThemeData wiring.
- [x] 4.2 Add IBM Plex font support or an offline-safe equivalent font path and verify text styles map to the handoff scale.
- [x] 4.3 Implement shared components: buttons, icon buttons, chips, fields, sections, banners, metric cards, keyboard hints, empty states, image placeholders, chart wrappers, step indicator, compare viewer primitives, overflow menus, and disabled/unavailable command states.
- [x] 4.4 Implement `SrProgressBar` with solid, striped, and indeterminate semantics.
- [x] 4.5 Add charting support for line charts and sparklines using real metric data with fallback placeholders when no data exists.
- [x] 4.6 Add widget tests or golden-light structural tests for theme tokens, hover/pressed/selected/disabled states, pulse live dot, progress semantics, overflow-safe text, and core shared components.

## 5. Start Screen And Project Shell

- [x] 5.1 Rebuild the start screen as the handoff two-column project picker with New project, Open project folder, disabled/archive-placeholder import, Learn chips, recent search/filter controls, recent project cards, manifest portability footer copy, and documented project/archive terminology.
- [x] 5.2 Rebuild the project shell with sticky project header, project dropdown menu/unavailable states, project summary, backend/device badges, settings action, `Overview · Dataset · Model · Training · Live · Checkpoints · Inference` tabs, live/error tab badges, and bottom status bar with optional VCS branch.
- [x] 5.3 Decide and implement native chrome or documented custom chrome behavior for the Classic Workspace shell.
- [x] 5.4 Add Overview tab with metric cards, recent activity feed, next-step card, loss sparkline, plateau/Tune LR guidance, and quick actions.
- [x] 5.5 Preserve tab selection and per-tab scroll/selection state for the active project session.
- [x] 5.6 Add widget tests for start screen states/copy, shell tab navigation, project menu, locked-tab routing, Overview rendering, VCS/status bar warnings, and chrome decision behavior.

## 6. Dataset And Model Tabs

- [x] 6.1 Rebuild Dataset populated state with header summary, source list, source more-menu recovery actions, degradation pipeline, Re-synthesize support/unavailable state, indexed LR/HR preview pane, channel histogram card, health checks, Add source, Re-scan, and Export actions.
- [x] 6.2 Rebuild Dataset empty state with Extract from video, Folder of images, Pre-made pairs, drop zone, and beginner info banner.
- [x] 6.3 Implement the video import modal/wizard with Source, Sampling, Filters, Review steps and backend estimate/readiness data.
- [x] 6.4 Add desktop drag/drop support for video/folder onboarding where platform support is available, with native picker fallback.
- [x] 6.5 Rebuild Model tab with template list, filter/import controls, selected template styling, support-state guards, detail panel, metric cards, architecture flow, hyperparameters, Reset to defaults, Save as model, and non-destructive switching banner.
- [x] 6.6 Add widget tests for dataset populated/empty/video-modal states, dataset source severity/recovery styling, preview navigation, histogram channels, re-synthesis unavailable/supported states, and model template filter/import/reset/save states.

## 7. Training And Live Tabs

- [x] 7.1 Rebuild Training tab as the handoff three-column layout with Basics, Schedule, Optimizer, Loss including unsupported FFT/perceptual/GAN rows, Validation, Checkpoints including keep-best/manual/EMA states, Estimate, All runs, Clone settings, and Resume training actions.
- [x] 7.2 Implement low-pair warning/blocking modal and training estimate updates from selected dataset/model/device/settings.
- [x] 7.3 Rebuild Live running state with status strip, Snapshot/Pause/Stop controls, striped epoch progress, solid run progress, loss/PSNR charts, metric cards, validation sample navigation, validation samples, and recent events.
- [x] 7.4 Implement Stop confirmation with latest checkpoint and loss context.
- [x] 7.5 Implement Live empty state with Start a run and Resume run actions when available.
- [x] 7.6 Implement Live CUDA OOM error state with error banner, GPU stats, ranked suggested fixes, Apply buttons, log tail, Open log, crash snapshot display, Apply all suggested retry, Open training settings, and guide action placeholder.
- [x] 7.7 Add widget tests for training prerequisites, unsupported losses, retention/EMA settings, estimate display, live progress semantics, validation sample navigation, snapshot/stop controls, empty state, crash snapshot, open-log unavailable state, and OOM suggested-fix flow.

## 8. Checkpoints And Inference Tabs

- [x] 8.1 Rebuild Checkpoints populated state with aggregate header, best checkpoint chip, PSNR strip, table columns, star/manual state, best-row styling, tags, row actions, command-click/multi-select comparison affordance, footer hints, prune/compare availability, export best, and continue-from-best.
- [x] 8.2 Rebuild Checkpoints empty state with Start training and Import `.pt` placeholder/action state.
- [x] 8.3 Rebuild Inference working state with model/checkpoint header, scale/tile fields, batch folder, save result, compare viewer, two-up/slider controls, recent filmstrip with add tile, output inspector including bit depth and sharpness gain when available, quality estimate, tuning controls, and batch drop zone.
- [x] 8.4 Rebuild Inference blocked state with warning banner, prerequisite checklist, Go actions, and explainer card.
- [x] 8.5 Ensure deleted or unsupported checkpoints disable dependent inference/resume/export actions with clear messages.
- [x] 8.6 Add widget tests for checkpoint aggregate actions, manual/star protection, multi-select comparison, pruning unavailable/supported states, best-row styling, inference blocked checklist, compare mode switching, recent filmstrip selection/add tile, inspector bit-depth/sharpness fields, and tuning support states.

## 9. Verification And Documentation

- [x] 9.1 Run backend tests and add fixtures for dashboard, dataset detail, template catalog, live OOM, checkpoint aggregate, and inference inspector responses.
- [x] 9.2 Run Flutter analyzer and widget tests.
- [x] 9.3 Perform manual Linux desktop smoke test for create project, open recent project, dataset onboarding, model selection, training setup, live empty/error/running states, checkpoints, and inference.
- [x] 9.4 Verify no screen has text overflow or incoherent overlap at common desktop window sizes and compact density.
- [x] 9.5 Update README or development docs with new UI dependencies, dashboard endpoints, optional platform capabilities, and known unsupported placeholder actions.
