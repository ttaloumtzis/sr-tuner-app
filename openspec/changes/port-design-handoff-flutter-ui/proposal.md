## Why

The delivered design handoff in `design_handoff_sr_tuner/` defines a committed Classic Workspace UI for sr-tuner, but it is written as JSX/CSS reference material while the product frontend is Flutter/Dart. Porting it now turns the existing functional desktop workflow into the intended beginner-friendly workspace and captures backend contract gaps the current implementation does not yet expose.

## What Changes

- Recreate the handoff screens as Flutter/Dart widgets using the existing desktop app structure rather than copying or transpiling JSX.
- Replace the current dark-only Material look with the handoff's locked design tokens: cool-grey light/dark palette, IBM Plex typography, compact spacing scale, 4 px component radius, status colors, banners, metric cards, chips, fields, dashed previews, and solid/striped progress semantics.
- Upgrade the startup experience to the two-column project picker with recent projects, status chips, search/filter affordances, create/open actions, and archive import placeholder behavior.
- Add an Overview tab and update the project shell to `Overview · Dataset · Model · Training · Live · Checkpoints · Inference`, with a sticky project header, backend/GPU/status badges, tab preservation, and bottom status bar.
- Rebuild Dataset, Model, Training, Live, Checkpoints, and Inference tab layouts to match the handoff's dense workspace panels, populated states, empty states, blocked states, and error states.
- Add backend/project-state support for handoff features not already covered: recent projects, project summary/status, activity feed, disk status, dataset source metadata and health checks, model template catalog/detail metadata, training estimates and suggested fixes, snapshot checkpoint action, richer active-run progress/ETA/log events, checkpoint aggregate ranking, and inference inspector/recent-result data.
- Preserve existing project, dataset, model, run, checkpoint, and inference workflows while adding the new UI contract and API responses needed to render them.

## Capabilities

### New Capabilities
- `classic-workspace-ui`: Defines the Flutter recreation of the design handoff, shared design system widgets, shell layout, Overview tab, start screen, tab layouts, responsive desktop behavior, and visual state requirements.
- `project-dashboard-state`: Defines backend/project summary state required by the upgraded shell and Overview: recent projects, project status, activity feed, next-step guidance, disk/status bar data, backend/device badges, and workspace preferences.

### Modified Capabilities
- `desktop-project-workflow`: Adds the Overview tab, upgraded start screen behavior, recent project access, theme/density preferences, status bar requirements, and shell-level navigation/state preservation.
- `dataset-management`: Adds source-list metadata, health checks, preview/histogram data, degradation pipeline display data, dataset rescanning/export affordances, drag/drop onboarding, and video-import wizard requirements.
- `model-management`: Adds model template catalog/detail behavior, selected-template presentation, template metadata, architecture diagram data, and non-destructive template switching.
- `training-runs`: Adds Classic Workspace training layout requirements, richer schedule/optimizer/loss/validation/checkpoint settings, estimates, clone/resume actions, low-pair blocking, and applyable suggested training fixes.
- `live-metrics`: Adds live badge behavior, separate epoch/run progress semantics, snapshot action, ETA/events/log-tail data, and CUDA OOM remediation state.
- `checkpoint-management`: Adds aggregate checkpoint view behavior, best-checkpoint ranking strip, row-level actions, continue-from-best, import placeholder, comparison/prune affordances, and richer checkpoint table metadata.
- `inference-workflow`: Adds locked inference checklist behavior, result inspector, recent filmstrip, batch drop zone, tuning controls, output summary, and before/after viewer requirements aligned to the handoff.

## Impact

- Flutter UI: `lib/src/app.dart`, `lib/src/startup_screen.dart`, `lib/src/workspace/*`, shared widgets, theme setup, project models, backend client, polling, and likely new UI support modules.
- Backend API: FastAPI routes and response schemas for project dashboard data, recent projects, dataset health/source details, model templates, training estimates/fixes, snapshot checkpoints, richer live status/events, checkpoint aggregates, and inference summaries.
- Project persistence: `sr-tuner.project.json` workspace/preferences metadata and optional derived dashboard/activity state while keeping existing object IDs and project-relative asset rules.
- Dependencies: likely add Flutter font support for IBM Plex, charting support if not already present, and optional desktop drag/drop support; backend dependencies should stay optional/readiness-gated.
- Tests: backend schema/API tests, Flutter widget/model tests, analyzer coverage, and visual/behavior checks for populated, empty, blocked, and error states.
