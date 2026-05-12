## Why

The Live Metrics tab in sr-tuner has usability issues that make it difficult to monitor training in real-time:
1. Metrics only appear after an epoch completes, leaving the UI empty during training
2. The combined chart with Loss/PSNR/SSIM on one axis makes it hard to read individual metrics
3. The validation preview panel doesn't show any skeleton or placeholder before images are available

## What Changes

### UI Improvements
- Split the single combined metric chart into **3 separate stacked charts** (Loss, PSNR, SSIM)
- Add **axis numbers and labels** to all charts (x-axis: epoch/step, y-axis: metric value)
- Add a **4-way image preview panel** showing: Input, Output (predicted), Target, Diff
- Show only the **first image of each epoch** (not all validation samples)
- Display a **skeleton/placeholder** in the preview panel immediately when training starts

### Data Improvements (Backend)
- Requires backend to provide **iteration-level metrics** during training (not just epoch-level)
- Current backend only sends metrics after epoch completes

## Capabilities

### New Capabilities
- `live-metrics-visibility`: Enhanced real-time visibility into training progress with separate charts, axis labels, and immediate preview feedback

### Modified Capabilities
- (none - this is pure UI work)

## Impact

- **Frontend**: `lib/src/workspace/live_metrics_tab.dart` - major refactor of `_LineChartPainter` and `_ValidationPanel`
- **Models**: `lib/src/project_models.dart` - may need new preview data structure for 4-way grid
- **Backend dependency**: Requires backend iteration-level metrics (separate workstream)