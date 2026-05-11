# Handoff: sr-tuner — Direction B (Classic Workspace)

> **Stack target:** Dart + Flutter (desktop). These design files are **references, not source to copy**. Recreate them as Flutter widgets using the project's existing patterns.

---

## Overview

`sr-tuner` is a desktop application for **image-processing beginners** that lets a user:

1. **Create a dataset** from a video or a folder of images (or import a pre-made LR/HR pair set).
2. **Pick a super-resolution model template** (Real-ESRGAN, SwinIR, HAT-L, BSRGAN, EDSR…).
3. **Train** that template on the dataset.
4. **Tune / fine-tune** a trained checkpoint with more data.
5. **Run inference** — upscale new images with the best checkpoint and compare before/after.

The chosen UI direction is **"Classic Workspace"**: a single project window with a top tab bar (Overview · Dataset · Model · Training · Live · Checkpoints · Inference). Familiar IDE/DAW feel; dense but calm; built around lists + detail panes.

The wireframes in this bundle are **low-fidelity but committed** — typography, spacing, layout, copy, and grey-utility palette are real. Visual finish (icons, photography, motion polish) is intentionally restrained so structure stays the focus.

---

## About the design files

The files in this bundle are **prototypes written in HTML / React / inline JSX**, viewable by opening `Wireframes.html` in a browser. They are **design references** — they describe the intended look, layout, and behavior. The job is to **recreate them as Flutter widgets** in the existing sr-tuner Dart codebase, using its established patterns (state management, navigation, theming, etc.).

If the codebase doesn't yet have those patterns established, **Riverpod** (state) + **go_router** (navigation) + **`ThemeData` + `ColorScheme`** (theming) are reasonable defaults for a Flutter desktop app of this kind.

The HTML is **not pretty source code** — it uses JSX shorthand for layout, a `<DesignCanvas>` wrapper, and React-only helper components (`<Btn>`, `<Chip>`, `<Field>`, `<Section>`, `<Banner>`, `<ImgPh>`, `<Chart>`). Read the markup as a spec of what each screen contains and how it's arranged; don't try to transpile it.

---

## Fidelity

**Low-fidelity wireframes** with committed typography and palette.

| Element | Status |
|---|---|
| Layout / information architecture | **Locked** — implement as drawn |
| Copy / labels | **Locked** — strings can be copied verbatim |
| Typography scale | **Locked** — see Design Tokens below |
| Palette | **Locked** — see Design Tokens below |
| Spacing scale | **Locked** — 4 / 8 / 12 / 16 / 20 / 24 px |
| Icons | **Placeholder** — use Flutter's `Icons.*` or `flutter_lucide` for production; SVG strokes in the mocks are stand-ins |
| Charts | **Placeholder shapes** — wire to real metrics; use `fl_chart` for the production chart widgets |
| Imagery (LR/SR/HR previews) | **Dashed placeholders** — render real `Image.file` / `Image.memory` from the model in production |
| Hover/press/animation polish | **Not specified** — apply Flutter's default `InkWell` / `Material` feedback |

---

## Screens

Each screen is named after its `<DCArtboard id>` in `Wireframes.html`. Open the canvas and double-click an artboard to focus it.

### 1. `start` — Start screen / project picker
- **Purpose:** Open or create a project before anything else.
- **Layout:** Two-column split (≈ 1 : 1.2) inside a desktop window.
  - **Left column** (border-right): branding ("sr-tuner v0.4.2"), large H1 headline, three action buttons stacked vertically — `New project` (primary), `Open project folder…`, `Import from .srtproj archive` (ghost). Bottom-left: "Learn" chips.
  - **Right column** (tinted background): "Recent projects" label + search field + filter icon. Below: scrollable list of project cards. Each card = folder icon + project name + status chip (`training` / `ready` / `no dataset` / `archived`) + secondary line ("Real-ESRGAN x4 · 12,480 pairs · opened 2 hours ago") + chevron-right.
- **Behavior:** Click card → opens that project. `New project` → file-picker dialog for folder location, then dataset-empty Overview.

### 2. `overview` — Project home
- **Purpose:** First view inside a project. Answers "what's going on here?"
- **Layout:** Vertical stack inside the tab content area.
  - **Project header bar** (sticky, above tabs): project icon + name + dropdown + summary line ("datasets · 2 · models · 1 · runs · 3") on the left; CUDA badge + backend status dot + settings cog on the right.
  - **Tab bar** with active "Overview".
  - **H2 + action row** ("Open folder", "Resume training" primary).
  - **4 metric cards** in a row: Dataset pairs, Active model, Best PSNR, Runs.
  - **2-column grid** (≈ 1.4 : 1):
    - Left: "Recent activity" feed — timestamp + colored chip ("Run" / "Ckpt" / "Data" / "Model") + description.
    - Right: "Next step" card (suggested action) above a "Loss · last 24h" mini-chart.
  - **Status bar** at the bottom: version, project path, git branch, disk free, idle state.

### 3. `dataset` — Dataset tab (populated)
- **Purpose:** Manage sources, see what's actually in the dataset, verify it's healthy.
- **Layout:**
  - **Header row** (border-bottom): dataset name + "ready to train" chip + summary line ("12,480 train pairs · 320 val · 96×96 LR / 384×384 HR · degradation: realistic"); right side: `Add source…`, `Re-scan`, `Export .zip`.
  - **Two columns** (≈ 1 : 1.1):
    - **Left**: "Sources" list — each row is a source card with a status border-left (green/amber/red), icon (video/folder), name, pair count, optional note. Then a "Degradation pipeline" section listing the 4 steps (Blur · Noise · JPEG · Down) with parameter ranges in mono.
    - **Right**: "Preview · pair #4,213" — LR / HR image pair side-by-side (dashed placeholders), arrow controls + shuffle. Below: Histogram chart card. Below that: "Health checks" list (✓ pairs aligned, ✓ brightness balanced, ⚠ 84 near-dupes pruned, etc.).

### 4. `dataset-empty` — Dataset tab (no sources)
- **Purpose:** Catch the user on first-launch and make the on-ramps obvious.
- **Layout:** H2 + subtitle. Then a 3-card grid of on-ramps:
  - **Extract from video** (primary CTA "Pick video…")
  - **Folder of images**
  - **Pre-made pairs**
- Below: a large dashed drop zone ("or drop video / folder anywhere on this window").
- Below that: info banner — "What's a good dataset for SR?"

### 5. `dataset-video` — Create dataset from video (modal)
- **Purpose:** Multi-step flow (Source · Sampling · Filters · Review) for turning a video into image pairs.
- **Layout:** Modal centered over a dimmed dataset background.
  - Modal header: "Extract frames from video" + close icon.
  - **Step indicator** at the top: 4 circles connected by lines; step 1 (Source) is complete (filled accent + check), step 2 (Sampling) is current (tinted bg + outline).
  - **Step 2 content** (shown): source file info row ("drone-flight-04.mp4 · 4K · 60 fps · 1m 22s · 4,920 frames"); a "Sampling strategy" 3-card segmented selector (Every N frames · Scene change · Time interval); fields for "N", "Estimated yield", "Output size"; info banner about perceptual-hash deduplication.
  - Footer: Back · "2 of 4" · Cancel · Continue (primary).

### 6. `model` — Model tab
- **Purpose:** Pick / configure the model template.
- **Layout:** Two columns (≈ 1 : 1.1).
  - **Left**: "Model templates" list — each card has the model name, architecture line ("RRDB · 23 blocks · 16.7 M params"), best-for chip, speed chip. Selected template (`Real-ESRGAN x4`) gets a thick accent border and tinted background and a "selected" chip; others show a "Use" button.
  - **Right**: detail panel for the selected template.
    - H2 + subtitle.
    - **4 metric cards** (Scale, Params, VRAM train, Input crop).
    - **Architecture diagram** — a horizontal flow of small boxes: `conv in` → `RRDB #1` → `RRDB #2` … `… 17 more …` → `upsample ×4` → `conv out`. Boxes connected by chevron-right icons.
    - **"Hyperparameters · advanced"** — 3-col grid of mono field cards (num blocks, growth channels, features, upsampler, activation, init).
    - Info banner: "Swapping templates is non-destructive."

### 7. `training` — Training setup tab
- **Purpose:** Configure the next run.
- **Layout:**
  - **Header**: run name + status chip + dataset/model summary + actions (`All runs`, `Clone settings`, `Resume training` primary).
  - **3-column grid** below, columns separated by `border-right`:
    1. **Basics** (Run name, Dataset disabled, Model disabled, Mode dropdown) + **Schedule** (Max epochs, Batch size, Crop size, Workers).
    2. **Optimizer** (Type dropdown, Learning rate, Betas, Weight decay) + **Loss** (rows for L1, VGG perceptual, GAN, FFT — each with an enabled dot and a weight value, disabled ones dimmed).
    3. **Validation** (Every, Metrics, Sample previews) + **Checkpoints** (Save every, Keep best, EMA) + **Estimate** card (Time to ep 100, Iters/epoch, VRAM peak, Disk per ckpt).

### 8. `live` — Live tab (training running)
- **Purpose:** Watch a training run as it happens. Pause / Stop / Snapshot.
- **Layout:**
  - **Tab-bar trailing badge**: live-dot + "LIVE" in accent.
  - **Top status strip**: run name chip + "epoch 42 of 100 · iter 32,840 / 78,000"; right: Snapshot, Pause, Stop (danger).
  - **Progress section** (two bars):
    - **Epoch progress** — striped fill at 82 % ("iter 640 / 780 · this epoch finishes in 2m 14s"). Striped = within-epoch ticks, which aren't truly linear.
    - **Run progress** — solid fill at 42 % ("epoch 42 / 100 · ETA Tue 04:18 (≈ 9h 12m)").
  - **Body — two columns**:
    - **Left (growing)**: Loss chart (train solid + val dashed); PSNR chart; row of 5 metric cards (step/s, LR, GPU temp/VRAM, best PSNR, best LPIPS).
    - **Right (340 px fixed)**: "Validation samples · ep 42" — 2×2 grid of placeholders (LR / SR / HR / diff ×4); PSNR/SSIM/LPIPS readouts; "Recent events" mini-log.

### 9. `live-empty` — Live (no run started)
- Centered empty state card. Icon in circle + "No active training run" + explanation + two CTAs (`Start a run from Training →` primary, `Resume run-003`).

### 10. `live-error` — Live (CUDA OOM)
- **Error banner** at the top (danger, left-accent): "Training stopped — CUDA out of memory at epoch 12, iter 480" with the raw `torch.cuda.OutOfMemoryError` line and GPU stats.
- **"Suggested fixes"** card: 4 rows, each with title + explanation + Apply button (Lower batch size, Lower crop size, Enable AMP, Gradient checkpointing).
- **"Log tail"** card: monospace log block, the error line in danger color.
- **Footer actions**: `Apply all suggested · retry` (primary), `Open training settings`, `Read GPU memory guide` (ghost).

### 11. `checkpoints` — Checkpoints tab (populated)
- **Purpose:** Pick which checkpoint becomes "the model".
- **Layout:**
  - Header: "8 checkpoints" + "best ckpt-ep42.pt" chip; actions: `Show in folder`, `Export best…`, `Continue from best` (primary).
  - **PSNR strip**: small line chart of PSNR across saved checkpoints + the "24.05 → 28.94 dB · +4.89" delta on the right.
  - **Table**: column headers (uppercase, muted) — star · name · epoch · psnr · ssim · lpips · tags · saved · size · row actions.
    - Row icons: starred = warn-yellow star.
    - Best PSNR row gets a tinted background + bold accent PSNR cell.
    - Tags column shows chips: "best psnr", "best perceptual", "manual".
    - Row actions: wand (inference), play (resume from), more.
  - Footer: kbd hint "⌘ click to compare" + `Prune older` (ghost) + `Compare side-by-side`.

### 12. `checkpoints-empty` — Checkpoints (no run yet)
- Centered empty state. Icon + "No checkpoints yet" + explanation + CTAs (`Start training →` primary, `Import .pt file`).

### 13. `inference` — Inference tab (working)
- **Purpose:** Upscale a single image (or batch) and inspect the result.
- **Layout:**
  - **Header**: Model dropdown, Scale field, Tile field; right: `Batch folder…`, `Save result`.
  - **Body — two columns** (grow + 320 px):
    - **Left (viewer)**: chip row showing "before · 480 × 320" → "after · 1920 × 1280" + view-mode buttons (`2-up`, `Slider`). Big compare viewer below: a single image area split by a vertical accent-color handle with a circular grip in the middle; left half = LR placeholder, right half = SR placeholder, clipped via `clip-path: inset(0 0 0 52%)`. "BEFORE" / "AFTER" corner chips. Below the viewer: a "Recent" filmstrip of 6 thumbnails + a dashed "+ add" tile.
    - **Right (inspector)**: "Output" (Resolution / Format / Filename) → "Estimated quality" card (vs. bicubic +5.2 dB, sharpness, inference time) → "Tuning" (three sliders rendered as progress bars: Denoise strength, Detail boost, Color preserve) → "Batch" drop zone.

### 14. `inference-blocked` — Inference (no usable checkpoint)
- **Warn banner**: lock icon + "Inference is locked until you have a trained checkpoint."
- **"What you need" checklist**: 4 rows (Dataset · Model · Training run that reached at least 5 epochs · Saved checkpoint). Done rows have a check icon and tinted-green background; todo rows have a lock icon, neutral background, and a `Go` button on the right.
- **Footer explainer card**: "Why this gate? — an untrained model would just produce noise."

---

## Interactions & behavior

| Interaction | Behavior |
|---|---|
| Click tab | Switch tab content; preserve scroll position per tab. |
| Drop video/folder onto window | Open the "Extract frames" modal (video) or "Folder of images" mapping (folder). |
| Click `New project` | Native folder picker → create `<folder>/.srtproj` manifest → land in Overview. |
| Click `Open project folder…` | Native folder picker → load manifest → land in Overview. |
| Click recent project card | Same as Open, but skip the picker. |
| Sources status border-left | `accent-2 = ok`, `warn = warning`, `danger = error`. Click row to inspect. |
| Pause / Stop in Live | `Pause` keeps state, can resume; `Stop` (danger) ends run, writes final ckpt. Confirm `Stop` with a dialog. |
| `Stop` confirm dialog | "Stop run-003? Last checkpoint saved 4 min ago. Loss: 0.86." → Cancel / Stop (danger). |
| Snapshot now | Force-save a checkpoint with timestamp suffix without interrupting training. |
| Inference slider drag | Drag the circular handle horizontally → updates `clip-path: inset(0 0 0 X%)` on the SR layer. |
| Inference 2-up button | Swaps slider viewer for two equal panes side-by-side. |
| Training: Apply suggested fix | Writes the fix into the run's config and re-enables the Resume button. |
| Locked tab (e.g. Inference w/o ckpt) | Tab text muted; clicking it lands on the blocked state, not an empty pane. |
| Resume run / Continue from best | Loads ckpt weights + optimizer state from the chosen `.pt` and starts Live with run name reused. |

### Loading / progress
- **Within-epoch progress** = striped fill (signals "ongoing, not linear in wall-clock time"). Recompute every iter.
- **Run progress** = solid fill (signals "% complete"). Recompute on epoch boundary.
- **ETA** = derived from rolling step/s average over last 60 s.

### Errors that beginners hit
- **CUDA OOM** → `live-error` screen with 4 ranked fixes.
- **Dataset has < 100 pairs** → blocking modal on `Start training` with "this won't generalize, add more data" warning.
- **Source files unreadable** → red border-left on the source row + note + "Remove source" in the row's `more` menu.
- **Disk < 1 GB free** → status-bar pill turns warn; new ckpts pause until cleared.

### State management
Per project (one open at a time):
- `project` — `{ path, name, manifestVersion, createdAt }`
- `dataset` — `{ id, sources[], pairCount, valCount, lrSize, hrSize, degradationConfig, healthChecks }`
- `model` — `{ templateId, params, vramEstimate }`
- `runs` — list of `{ id, status: 'queued' | 'running' | 'paused' | 'done' | 'error', currentEpoch, currentIter, metrics: { loss[], psnr[], ssim[], lpips[] }, startedAt, endedAt }`
- `checkpoints` — list of `{ runId, epoch, path, sizeBytes, metrics, tags: ['best-psnr' | 'best-lpips' | 'manual'][] }`
- `activeRun` — id of the current run (drives Live tab content)
- `inference` — `{ ckptId, inputPath, outputPath, params, beforeAfterSlider }`
- `theme` — `'light' | 'dark'`
- `density` — `'comfortable' | 'compact'`

Training itself runs in a Python sidecar (PyTorch). Flutter UI streams metrics + log lines over IPC (stdio, gRPC, or local websocket — pick whatever the existing codebase uses).

---

## Design tokens

Authoritative source: `styles.css`. Tokens are duplicated below in Dart-friendly form.

### Colors — Light

| Token | Hex | Flutter `ColorScheme` mapping |
|---|---|---|
| `--bg` | `#EEF0F3` | `surface` (page background) |
| `--surface` | `#FFFFFF` | `surfaceContainer` / cards |
| `--surface-2` | `#F7F8FA` | `surfaceContainerLow` (tinted panels, status bar) |
| `--line` | `#C8CCD2` | `outline` |
| `--line-2` | `#DEE1E6` | `outlineVariant` |
| `--ink` | `#1A1D22` | `onSurface` |
| `--ink-2` | `#3A4049` | `onSurface` (80 %) |
| `--muted` | `#6B7280` | `onSurfaceVariant` |
| `--faint` | `#9AA1AB` | `onSurfaceVariant` (60 %) |
| `--accent` | `#2F6BD6` | `primary` |
| `--accent-2` | `#1F8A5B` | success / ok status |
| `--warn` | `#B06320` | warning status |
| `--danger` | `#B3382F` | `error` |
| `--tint` | `#E7EEF9` | `primaryContainer` (accent backgrounds) |
| `--tint-ok` | `#E2EFE7` | `successContainer` |
| `--tint-warn` | `#F4EBDD` | `warningContainer` |
| `--tint-err` | `#F4DEDB` | `errorContainer` |

### Colors — Dark

| Token | Hex |
|---|---|
| `--bg` | `#0D1016` |
| `--surface` | `#161A21` |
| `--surface-2` | `#1C2028` |
| `--line` | `#2A2F38` |
| `--line-2` | `#20242C` |
| `--ink` | `#E6E9EE` |
| `--ink-2` | `#B8BDC6` |
| `--muted` | `#8B929C` |
| `--faint` | `#5A616B` |
| `--accent` | `#5B8DF0` |
| `--accent-2` | `#5FBF8A` |
| `--warn` | `#D99A55` |
| `--danger` | `#DF6A5E` |
| `--tint` | `#1A2436` |
| `--tint-ok` | `#15281F` |
| `--tint-warn` | `#2A2118` |
| `--tint-err` | `#2A1814` |

### Typography

Both families are free + permissively licensed. Add them to `pubspec.yaml` (or use `google_fonts: ^6.x`).

- **Sans**: IBM Plex Sans — 400, 500, 600, 700
- **Mono**: IBM Plex Mono — 400, 500, 600

Use mono for: numbers (PSNR/SSIM/LPIPS, loss values, file sizes, percentages, paths, hyperparameters, run/checkpoint names).

| Style | Family | Size | Weight | Line-height | Letter-spacing |
|---|---|---|---|---|---|
| `h1` | Plex Sans | 28 | 600 | 1.15 | -0.01em |
| `h2` | Plex Sans | 20 | 600 | 1.20 | -0.005em |
| `h3` | Plex Sans | 14 | 600 | 1.25 | 0 |
| `body` | Plex Sans | 13 | 400 | 1.45 | 0 |
| `body-sm` | Plex Sans | 12 | 400 | 1.45 | 0 |
| `caption` | Plex Sans | 11 | 400 | 1.4 | 0 |
| `label` (uppercase eyebrows) | Plex Sans | 10 | 600 | 1.4 | 0.08em |
| `mono` | Plex Mono | 11.5 | 400 | 1.4 | 0 |
| `metric.val` | Plex Mono | 20 (compact: 17) | 500 | 1.1 | 0 |
| `kbd` | Plex Mono | 10 | 400 | 1.4 | 0 |
| `button` | Plex Sans | 12 (sm 11, lg 13) | 500 | 1 | 0 |

### Spacing

4-step linear: `4, 6, 8, 12, 14, 16, 20, 24` px.

Compact density (Tweaks): swap `12 → 8`, `16 → 12`, `20 → 14`, and shrink metric card values.

### Radii

- Field / button / card / chip-square: **4 px** (`--radius`)
- Window chrome: **6 px**
- Chip / dot indicator: **999 px** (pill)
- Avatar / circle button: **50 %**

### Borders

- Default: `1 px solid --line`.
- Dashed (drop zones, placeholders): `1 px dashed --line`.
- Banner: `1 px solid --line` + `3 px solid <accent variant>` on the left.
- Selected card: `2 px solid --accent` + `--tint` background.
- Source-row status: `3 px solid <accent-2|warn|danger>` on the left.

### Shadows

```
--shadow (light): 0 1px 0 rgba(20,25,35,0.04), 0 2px 6px rgba(20,25,35,0.06)
--shadow (dark):  0 1px 0 rgba(0,0,0,0.5),     0 2px 8px rgba(0,0,0,0.45)
```

Use sparingly — only the window chrome and elevated modals.

### Component sizing

- Tab cell: 32 px tall, 12 px horizontal padding, 2 px accent underline on active.
- Field: 28 px min height, 4 / 8 px padding.
- Button (default): 24 px height, 10 px horizontal; `sm` = 20 px / 8 px; `lg` = 30 px / 14 px.
- Chip: ≈ 20 px height, 7 px horizontal, pill radius.
- Metric card: 10 / 12 px padding, value 20 px mono (compact: 17 px).
- Progress bar: 6 px tall, 999 px radius, `--line-2` track.

### Progress-bar semantics (important!)

This was a specific pain point in the brief. Apply consistently:

- **Solid fill** = a percent-complete that's monotonic in wall-clock time. Use for run progress (epoch / total epochs), batch inference progress.
- **Striped fill** (`repeating-linear-gradient(-45deg, accent 0 6px, rgba(255,255,255,0.35) 6px 10px)`) = an in-progress value whose remaining time is variable (e.g. iters within an epoch — step time fluctuates). Implies "ongoing, ETA approximate".
- **Indeterminate / undulating bar** = use only when no progress is knowable yet (e.g. CUDA init, dataset scan first pass).
- Never use a progress bar for a category that isn't actually a fraction of something.

---

## Component catalog

These map 1 : 1 to Flutter widgets you'll want to build (or pull from Material with theming).

| Mock helper | Flutter equivalent | Notes |
|---|---|---|
| `Win` | Custom `Scaffold` w/ `TitleBar` + `AppBar(bottom: TabBar)` | Window chrome is OS-native on desktop — replace traffic lights with `WindowButtonGroup` (use `bitsdojo_window`). |
| `Shell` | `Scaffold` w/ project header + `TabBar` + tab body + status bar | The repeating frame on every artboard. |
| Tab cell (`.tab`) | `Tab` with custom underline indicator | Locked tabs use `Tab(child: Opacity(0.5, ...))` and disable taps. |
| `Btn` | `FilledButton.tonal`, `OutlinedButton`, `TextButton` | `primary` → `FilledButton`; default → `OutlinedButton`; `ghost` → `TextButton`. |
| `IconBtn` | `IconButton` | Sized 24 / 20 (sm). |
| `Chip` | `Chip` w/ custom shapes per kind | Kinds map to color schemes: tint/ok/warn/err/solid. |
| `Field` | `InputDecorator` over a stub (or `TextField` for real input) | Eyebrow label above, value inside a 1-px border, optional suffix. |
| `Section` | `Column` with a label + child | Label uses the `label` text style. |
| `Banner` | Container with left accent border | Kinds: info / ok / warn / err. |
| `ImgPh` | `Container` with dashed border + diagonal cross pattern | Replace with `Image` in production. |
| `Chart` | `fl_chart` `LineChart` | Use `LineChartBarData` with `belowBarData` for filled area; dashed for val series. |
| `Spark` | `fl_chart` mini `LineChart` | No grid, no axis labels. |
| `.metric` | Custom `MetricCard` widget | Key (label) + value (mono) + optional sub. |
| `.bar` | `LinearProgressIndicator` w/ themed track + striped option | Striped variant = custom painter or `CustomPaint`. |
| `.empty` | Custom `EmptyState` widget | Icon-in-circle + headline + body + actions. |
| `.kbd` | Small `Container` w/ bottom-thick border | For "⌘ click to compare" hints. |
| Compare slider (inference) | Custom widget using `Stack` + `ClipPath` + `GestureDetector` | Drag handle updates clip inset. |
| Step indicator (video modal) | Custom row of circles + connectors | 4 states: done / current / upcoming. |
| Dropdown field | `DropdownButtonFormField` w/ themed border | Match field height of 28 px. |
| Top window status badge (`badge` prop on `Shell`) | `Align(alignment: topRight)` widget in the tab strip | Shows "LIVE" pulse or "ERROR" dot. |

### Pulse dot (`.dot.live`)
- Solid 6 × 6 accent circle.
- Outer box-shadow expands from `0 0 0 0 accent@60%` → `0 0 0 6px accent@0%` over 1.6 s, loops.
- Flutter: `AnimatedContainer` + `BoxShadow.spreadRadius` tween, or `flutter_animate`.

---

## Suggested project layout

```
lib/
  main.dart
  app.dart                    // MaterialApp.router, theme wiring
  router.dart                 // go_router routes (/start, /project/:id/overview, ...)
  theme/
    colors.dart               // tokens above as Color constants
    text_styles.dart
    sr_theme.dart             // ThemeData light + dark
  widgets/
    sr_button.dart
    sr_chip.dart
    sr_field.dart
    sr_section.dart
    sr_banner.dart
    sr_metric_card.dart
    sr_progress_bar.dart      // solid + striped variants
    empty_state.dart
    image_placeholder.dart
    chart_card.dart
    compare_slider.dart
    step_indicator.dart
    window_chrome.dart
  features/
    start/
      start_screen.dart
      recent_projects_list.dart
    project/
      project_shell.dart      // Shell equivalent: header + tabs + status bar
      overview/
      dataset/
        dataset_tab.dart
        dataset_empty.dart
        video_import_modal.dart
        sources_list.dart
        degradation_pipeline_card.dart
        preview_pane.dart
      model/
      training/
      live/
        live_tab.dart
        live_empty.dart
        live_error.dart
        progress_strip.dart
        loss_chart.dart
        psnr_chart.dart
        validation_samples_panel.dart
      checkpoints/
      inference/
        inference_tab.dart
        inference_blocked.dart
        compare_viewer.dart
  state/                       // Riverpod providers per domain
    project_provider.dart
    dataset_provider.dart
    training_provider.dart
    checkpoints_provider.dart
    inference_provider.dart
    theme_provider.dart
  services/
    python_bridge.dart         // talks to the training sidecar
    project_storage.dart       // reads/writes .srtproj manifest
```

---

## Notable copy strings

Pulled verbatim from the wireframes — beginners are the audience, so the friendly framing matters:

- Start headline: "Train a super-resolution model on your own data."
- Start sub: "Pull frames from a video, tune a template, and watch it learn — no Python required."
- Dataset-empty card 1: "Extract from video — Sample frames from any .mp4, .mov, .mkv. Auto-prune blur and dupes."
- Video modal banner: "We'll skip frames that are too similar to ones we already kept (perceptual hash, threshold 4)."
- Model tab banner: "Swapping templates is non-destructive — your dataset and runs are untouched."
- Inference blocked: "An untrained model would just produce noise. We keep this tab inert until something useful exists — so you can't accidentally ship a broken result."
- Live OOM banner: "Training stopped — CUDA out of memory at epoch 12, iter 480"
- Start footer: "Projects are folders. Move them anywhere — sr-tuner finds the manifest."

---

## Files in this bundle

| File | Purpose |
|---|---|
| `Wireframes.html` | Open this in a browser to see all artboards in the design canvas. |
| `styles.css` | Authoritative source for tokens — colors, type, spacing, shadows, component classes. |
| `wf-common.jsx` | Shared primitives (`Icon`, `Win`, `Btn`, `IconBtn`, `Chip`, `Field`, `Section`, `Banner`, `ImgPh`, `Chart`, `Spark`). Read this first to know what each helper does. |
| `wf-start.jsx` | Start screen. |
| `wf-b-shell.jsx` | `Shell` chrome + Overview tab + Dataset (populated, empty, video-import modal). |
| `wf-b-train.jsx` | Model tab + Training tab + Live (populated, empty, error). |
| `wf-b-rest.jsx` | Checkpoints (populated, empty) + Inference (working, blocked). |
| `design-canvas.jsx` | The canvas/zoom/pan presentation wrapper. Not part of the product — only here so the HTML renders. |
| `tweaks-panel.jsx` | The Tweaks panel (theme / density). Not part of the product. |

---

## Open questions to flag with the product owner before building

1. **Python sidecar:** does the existing codebase already bundle PyTorch via `flutter_python` / `dart_python` / a separate process? Inference and training need it; UI doesn't.
2. **Live metrics IPC:** how does the Python process push loss/PSNR back? (stdio JSON lines is simplest; gRPC or local WS if metrics get chatty.)
3. **GPU detection:** show CUDA / Metal / CPU in the status bar. Decide what to do when no GPU is present — block training? Allow CPU with a warning?
4. **Project manifest format:** is `.srtproj` already defined? If not, suggest a single JSON file at the project root listing dataset sources, model template, runs, checkpoints.
5. **Drag-drop on Flutter desktop:** `desktop_drop` covers Windows/macOS/Linux — confirm it's already in `pubspec.yaml`.
6. **Image preview decoding:** SR outputs are big (4× resolution). Decode on a background isolate or stream tile by tile to avoid jank on the inference compare slider.
