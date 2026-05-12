## Context

`design_handoff_sr_tuner/` contains the committed Direction B Classic Workspace handoff as HTML/React JSX/CSS reference files. The README states that the target stack is Dart + Flutter desktop, the JSX is not source to copy or transpile, and layout, copy, typography, palette, spacing, progress semantics, and major screen states are locked.

The current product already has a working Flutter desktop shell and FastAPI backend for project create/open, datasets, models, runs, live metrics, checkpoints, and inference. The current UI is functional but scaffold-like: dark-only Material styling, six tabs without Overview, simpler forms, limited start screen state, and several handoff-visible concepts missing from backend responses.

This change crosses Flutter UI, backend API schemas, project persistence, and tests. It should preserve the existing local project model and API identity rules while adding view-oriented data needed by the handoff.

## Goals / Non-Goals

**Goals:**
- Recreate the handoff screens as Flutter/Dart widgets using the existing app's state flow and backend client.
- Introduce a small reusable Flutter design system that encodes the handoff tokens and components.
- Add the Overview tab and update the shell to `Overview · Dataset · Model · Training · Live · Checkpoints · Inference`.
- Render every handoff state: populated, empty, blocked, modal, and CUDA OOM error.
- Add backend view-model endpoints and persisted metadata required for the upgraded shell, Overview, recent projects, dataset health/source details, model templates, training estimates/fixes, live events, checkpoint aggregates, and inference inspector data.
- Keep existing workflows working: project create/open, paired/video datasets, model creation, run lifecycle, metrics polling, checkpoint export/delete, and inference.

**Non-Goals:**
- Transpile or embed the JSX/CSS files in the Flutter app.
- Implement full BasicSR, Real-ESRGAN, SwinIR, HAT-L, BSRGAN, or EDSR training internals unless already supported by the backend.
- Replace FastAPI/local HTTP with another IPC mechanism.
- Implement production archive import/export if `.srtproj archive` support is not already defined; the UI may expose a disabled or placeholder action with clear state.
- Build custom OS window chrome unless needed by the existing Flutter desktop setup.

## Decisions

### Recreate the handoff as a Flutter design system

Create handoff-specific primitives under the existing `lib/src` structure, for example theme tokens, `SrChip`, `SrBanner`, `SrField`, `SrMetricCard`, `SrProgressBar`, `EmptyState`, `ImagePlaceholder`, `ChartCard`, `CompareViewer`, and `StepIndicator`. Existing screens should be rebuilt around these primitives rather than copying CSS values into every tab.

Alternatives considered:
- Direct JSX transpilation: rejected because the handoff explicitly forbids it and it would fight Flutter layout/state patterns.
- A large one-off rewrite per screen: faster initially but would duplicate locked tokens and make compact/dark support brittle.

### Keep current state management and routing until complexity demands a new package

The current app uses `StatefulWidget`, controller callbacks, polling helpers, and a `BackendClient`. This change should extend that pattern first. Add Riverpod or go_router only if implementation pressure makes the existing flow unmaintainable; do not introduce them just because the handoff mentions them as defaults for greenfield apps.

Alternatives considered:
- Migrate the app to Riverpod/go_router up front: useful long-term, but it increases blast radius for a UI port whose backend/client flow already works.

### Add backend-backed dashboard/view endpoints instead of deriving everything in widgets

The shell, Overview, recent project cards, status bar, dataset panels, training estimates, live error remediation, checkpoint aggregate strip, and inference inspector need data from multiple existing domains. Add focused response models and endpoints such as project dashboard summary, recent projects, dataset detail/preview, model templates, training estimate/fixes, active run detail/events, checkpoint aggregate index, and inference summary.

Flutter should not read project files directly. It should continue using project-scoped APIs and bounded polling.

Alternatives considered:
- Compute all view state in Flutter from the project envelope: simple for counts, but weak for disk space, device status, derived health, logs, and checkpoint ranking.
- Persist every dashboard field permanently: rejected where data is derived, volatile, or expensive to keep in sync.

### Treat the model template catalog as metadata-first

The handoff includes production model names, but the current backend only guarantees the internal residual pixel-shuffle path. The UI should show a catalog whose unsupported templates are clearly unavailable or marked future/disabled unless the backend reports support. Selecting a supported template creates or updates model config non-destructively.

Alternatives considered:
- Pretend all templates are trainable: misleading for beginners and likely to create broken runs.
- Hide all future templates: simpler but loses the educational model-picker shape in the handoff.

### Preserve existing project schema and add optional metadata

Project files should remain portable JSON with stable object IDs. Add optional workspace preferences (`theme`, `density`, selected tab, per-tab scroll/selection state), recent/dashboard metadata where needed, and migration defaults. Derived values like disk free, backend status, active device, best checkpoint, and recent metrics should be computed at response time.

The preview uses `.srtproj` in title and archive copy while the implemented backend persists `sr-tuner.project.json`. For this change, project folders remain canonical, `sr-tuner.project.json` remains the only project manifest/save file, and `.srtproj archive` is explicitly a disabled future import/export container. The UI may show the archive action only as disabled/unavailable copy; no archive read/write behavior is implemented in this change.

Alternatives considered:
- Bump to a completely new project manifest format: unnecessary and risky given the completed foundation.

### Use chart and font dependencies deliberately

Add charting support for real line/spark charts and font support for IBM Plex if package availability is acceptable. Prefer bundled font assets for deterministic desktop appearance; `google_fonts` is acceptable only if the app caches or packages fonts for offline desktop use. Keep `flutter_lucide` optional; Material icons are acceptable when they match the handoff intent.

Alternatives considered:
- Keep custom-painted placeholder charts only: acceptable for early scaffolding, but the handoff requires charts wired to real metrics.
- Fetch fonts at runtime: poor desktop/offline behavior.

### Implement progress semantics as shared UI behavior

The design specifically distinguishes solid progress, striped progress, and indeterminate progress. Implement these as shared progress components so Live, dataset jobs, inference jobs, and training progress cannot accidentally use misleading bars.

Alternatives considered:
- Use default `LinearProgressIndicator` everywhere: visually simple but violates the handoff semantics.

### Make drag/drop and filesystem reveal optional by platform

The handoff expects drop zones and folder-opening actions. Implement drag/drop through a desktop package when available and guard platform-specific "show in folder" behavior behind capability checks. Typed path fields and native pickers remain fallbacks.

Alternatives considered:
- Block the UI until drag/drop is implemented on every platform: unnecessary for Linux-first development.

### Treat preview-only actions as explicit supported or unavailable states

Several preview controls imply backend behavior beyond the first proposal pass: dataset source overflow menus, source removal/relinking, degradation re-synthesis, model template import, template reset/save, checkpoint multi-select comparison, checkpoint pruning, open-log, and inference add-tile flows. Each must either be implemented end to end or rendered disabled with a clear unavailable state. No visible command should be a no-op.

Alternatives considered:
- Leave controls visually present until later: rejected because beginner-facing tools need to avoid dead controls.
- Remove all future controls: safer, but it would drift from the committed handoff layout.

### Define cross-domain ownership before UI work

The following ownership rules are part of this implementation plan:

- Training runs own checkpoint retention policy. The run config stores save cadence, keep-best metric, maximum retained automatic checkpoints, EMA support state, and manual-save protection intent.
- Checkpoint management executes and displays retention policy. It derives aggregate views from run-owned metadata, applies pruning only to automatic checkpoints, and preserves manual, crash-snapshot, exported, or otherwise protected checkpoints.
- Live metrics can request or report snapshots, but every snapshot is persisted as run-owned checkpoint metadata. Crash snapshots use tag `crash-snapshot`, include `protected: true`, and are displayed in checkpoint aggregates when valid.
- Dataset re-synthesis never mutates the dataset object used by existing runs. If implemented, it creates a new dataset version/object linked to the source dataset and original source metadata. If not implemented in this change, the Re-synthesize action is disabled with an unavailable explanation.
- Imported model templates are metadata-only unless backend support is available. Unsupported imports do not create trainable model objects.

Alternatives considered:
- Let each tab own its own policy: rejected because retention, snapshots, and dataset versions cross backend domains.
- Mutate generated datasets in place: rejected because existing runs/checkpoints must remain reproducible.

### Establish backend DTO contracts before screen implementation

Before rebuilding tabs, create an internal backend/UI contract document or typed schema module for the new view models. The contract must name endpoint paths, response DTOs, unsupported-state shapes, and ownership boundaries for dashboard summary, dataset detail, model templates, training estimates/fixes, live detail, checkpoint aggregate, and inference inspector. Flutter client models should be generated or manually mirrored from this contract before tab UI depends on them.

Alternatives considered:
- Add endpoints opportunistically while building each screen: faster locally, but likely to create incompatible shapes across tabs.

## Risks / Trade-offs

- [Risk] The UI port can become a broad rewrite across every screen. Mitigation: build shared primitives first, then migrate shell/start/Overview before tab-by-tab changes.
- [Risk] Handoff model names imply capabilities the backend does not support. Mitigation: represent unsupported templates as disabled/future until backend support exists.
- [Risk] New dashboard endpoints may duplicate existing response data. Mitigation: keep them as derived view models backed by existing project objects and tests.
- [Risk] Chart/font/drag-drop dependencies can add packaging friction. Mitigation: add them one at a time, keep graceful fallbacks, and verify Linux desktop builds.
- [Risk] Visual fidelity can regress on small windows. Mitigation: set minimum useful desktop constraints, responsive split panes, scrollable tab bodies, and widget tests for overflow-prone states.
- [Risk] CUDA OOM suggested fixes may not map perfectly to all run configs. Mitigation: backend returns only applicable fixes with patch payloads it can validate before applying.
- [Risk] Crash snapshots and automatic checkpoint pruning can delete or preserve large files incorrectly. Mitigation: training owns retention policy, checkpoint management applies it, and checkpoint metadata preserves manual/protected/crash-snapshot tags.
- [Risk] Manifest naming confusion can make users think project folders and archives are different persistence systems. Mitigation: keep copy explicit: projects are folders, `sr-tuner.project.json` is the manifest, and `.srtproj archive` is disabled future functionality in this change.
- [Risk] Backend view-model contracts drift while screens are implemented. Mitigation: define endpoint paths and DTO shapes before tab implementation and test backend/client parsing against fixtures.

## Migration Plan

1. Add optional project/workspace fields with defaults for theme, density, selected tab, and recent view state; existing projects open without manual migration.
2. Add backend view-model endpoints while keeping existing endpoints stable.
3. Add Flutter models/client methods for the new endpoints.
4. Introduce theme and shared widgets without changing behavior.
5. Rebuild start screen, shell, and Overview.
6. Migrate Dataset, Model, Training, Live, Checkpoints, and Inference tabs in slices, preserving existing actions.
7. Run backend tests, Flutter analyzer/tests, and manual desktop smoke checks.

Rollback is straightforward while the old endpoints remain: revert Flutter screens to prior widgets and ignore optional metadata. Project files with new optional fields should still be readable by the upgraded backend; older builds may ignore unknown JSON fields where schema allows extra metadata.

## Open Questions

- Should IBM Plex fonts be bundled as local assets or pulled through a Flutter font package with offline packaging verification?
- Which future model templates should be visible but disabled in the first implementation?
- What exact threshold should mark disk space as warning or blocking beyond the handoff's `< 1 GB` warning?
- Should tab scroll positions be persisted only in memory per project session, or written into workspace metadata?
- Should checkpoint comparison be implemented now or kept as a disabled affordance matching the handoff?
