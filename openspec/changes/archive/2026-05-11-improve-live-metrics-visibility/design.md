## Context

The Live Metrics tab (`live_metrics_tab.dart`) currently:
- Polls every 2 seconds for `liveRunDetail`, `activeRunStatus`, `runMetrics`, `hardwareTelemetry`, and `validationPreview`
- Displays a single `_LineChartPainter` that draws Loss, PSNR, and SSIM on one chart
- Shows the `_ValidationPanel` which only displays when `preview.assets` has data

Current layout:
```
┌─────────────────────────────────────────────────┐
│ Status Strip (epoch/iteration/progress)         │
├───────────────────────┬─────────────────────────┤
│ Metric Cards          │ Hardware Panel          │
│ (5 key metrics)       │ (GPU stats)             │
├───────────────────────┴─────────────────────────┤
│ Combined Chart (Loss + PSNR + SSIM)            │
├─────────────────────────────────────────────────┤
│ Recent Events + Log Tail                       │
├─────────────────────────────────────────────────┤
│ Validation Preview (images)                    │
└─────────────────────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**
- Split combined chart into 3 separate charts (Loss, PSNR, SSIM) stacked vertically
- Add axis labels and tick numbers to all charts
- Create 4-way image preview grid (Input → Output, Target, Diff)
- Show preview skeleton immediately when training starts
- First epoch image shown quickly (poll for it specifically)

**Non-Goals:**
- Full 1:1 Live artboard port from `design_handoff_sr_tuner/` (separate UI composition pass)
- Changing the polling interval
- Adding new metric types
- Modifying the metric card display

## Design Handoff Gap Analysis

The handoff Live artboard is still the broader target for the Classic Workspace. This change closes the highest-impact visibility gaps while avoiding a full layout rewrite.

| Handoff Area | Current Gap | This Change |
|---|---|---|
| Chart readability | Loss, PSNR, and SSIM share one custom painter and one visual area | Split into 3 single-metric charts with independent scaling |
| Axis semantics | Existing painter draws axis lines only | Add x/y tick numbers and axis labels |
| Validation preview | Existing grid renders arbitrary returned assets | Render deterministic Input, Output, Target, Diff slots |
| Loading feedback | Empty preview can look like missing UI | Show placeholder slots immediately while waiting |
| First preview sample | Run preview request has no explicit index | Add `preview_index=0` to frontend/backend contract |
| Full handoff fidelity | Handoff places charts above metric cards and uses right-rail events | Deferred to a future 1:1 Live layout pass |

## Decisions

### 1. Chart Implementation
- **Decision**: Refactor `_LineChartPainter` into separate widget components per metric
- **Alternatives considered**:
  - Keep one painter with toggle/dropdown → rejected, user wants stacked
  - Use existing chart library → rejected, current custom painter works, just needs enhancement
- **Rationale**: User explicitly wants 3 stacked charts, not a combined view

### 2. Axis Labels
- **Decision**: Add axis rendering to the existing custom painter approach
- **Implementation**:
  - X-axis: epoch numbers (or iteration if available)
  - Y-axis: dynamic range based on metric min/max with 3-5 tick marks
- **Rationale**: Matches existing code style, avoids adding new dependencies

### 3. Preview 4-Way Grid
- **Decision**: Modify `_ValidationPanel` to use a 2x2 grid instead of 2-column layout
- **Layout**:
  ```
  ┌─────────┬─────────┐
  │  Input  │  Output │
  ├─────────┼─────────┤
  │ Target  │  Diff   │
  └─────────┴─────────┘
  ```
- **Rationale**: Matches what user requested - 4 images showing the progression

### 4. Preview Skeleton
- **Decision**: Show `SrImagePlaceholder` with skeleton state BEFORE first preview arrives
- **Implementation**: 
  - Add a "loading" or "waiting" state to preview panel
  - Display placeholder immediately when training starts
  - Replace with actual images once first `validationPreview` returns data
- **Rationale**: User wants to see skeleton, not empty space

### 5. First Image of Epoch
- **Decision**: Request only index 0 from the backend `validationPreview` endpoint
- **Implementation**: Pass `preview_index=0` explicitly in the API call
- **Rationale**: The dataset preview endpoint already uses this query pattern; the run preview endpoint needs matching support for API consistency

## Risks / Trade-offs

- **[Risk]**: Backend may not have iteration-level metrics → **Mitigation**: UI will show the latest available epoch/iteration values until the backend emits per-iteration records
- **[Risk]**: Preview images may not arrive quickly → **Mitigation**: Show skeleton immediately, update when data arrives
- **[Risk]**: Diff calculation may not be available → **Mitigation**: Show placeholder if diff not in assets

## Open Questions

- Should a future handoff-fidelity change move Recent Events into the Live right rail and reorder metric cards below charts?
- Should LPIPS/best-metric cards be added as a separate metric capability?
