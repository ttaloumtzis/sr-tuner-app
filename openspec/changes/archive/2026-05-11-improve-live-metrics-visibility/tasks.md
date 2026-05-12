## 1. Chart Refactoring

- [x] 1.1 Create separate metric chart widget for Loss (single series)
- [x] 1.2 Create separate metric chart widget for PSNR (single series)
- [x] 1.3 Create separate metric chart widget for SSIM (single series)
- [x] 1.4 Stack 3 charts vertically in the UI layout (Loss on top, then PSNR, then SSIM)
- [x] 1.5 Remove the combined `_LineChartPainter` single chart implementation

## 2. Axis Labels and Numbers

- [x] 2.1 Add x-axis rendering with epoch/step numbers to each chart
- [x] 2.2 Add y-axis rendering with metric value ticks (3-5 ticks per chart)
- [x] 2.3 Use dynamic y-axis range based on min/max of each metric
- [x] 2.4 Add axis label text (e.g., "Epoch", "Loss", "PSNR", "SSIM")

## 3. Preview 4-Way Grid

- [x] 3.1 Modify `_ValidationPanel` to use 2x2 grid layout instead of 2-column
- [x] 3.2 Add Input image tile with label
- [x] 3.3 Add Output (predicted) image tile with label
- [x] 3.4 Add Target (ground truth) image tile with label
- [x] 3.5 Add Diff image tile with label
- [x] 3.6 Handle case where Diff is not available (show placeholder)

## 4. Preview Skeleton

- [x] 4.1 Add skeleton/placeholder state to preview panel
- [x] 4.2 Show skeleton immediately when training starts
- [x] 4.3 Replace skeleton with actual images when preview data arrives

## 5. First Image of Epoch

- [x] 5.1 Modify `validationPreview` API call to include `preview_index=0`
- [x] 5.2 Ensure only first validation image is fetched per epoch

## 6. Iteration Counter Display

- [x] 6.1 Verify status strip shows "epoch X · iter Y" format
- [x] 6.2 Confirm iteration counter updates during training (if data available)

## 7. Live Metrics During Epoch

- [x] 7.1 Test if current loss displays during iteration (vs "--")
- [x] 7.2 Note: This may depend on backend iteration-level metrics availability

## 8. Testing and Polish

- [x] 8.1 Verify all 3 charts render correctly with sample data
- [x] 8.2 Verify axis labels are readable and properly positioned
- [x] 8.3 Verify 4-way grid layout on different screen sizes
- [x] 8.4 Test skeleton-to-image transition
- [ ] 8.5 Run lint and typecheck

Note: Focused Flutter widget/model tests pass. `dart analyze` still exits non-zero due to pre-existing warnings in unrelated checkpoint/inference files, so lint/typecheck remains open.
