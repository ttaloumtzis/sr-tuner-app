## 1. Chart Refactoring

- [ ] 1.1 Create separate metric chart widget for Loss (single series)
- [ ] 1.2 Create separate metric chart widget for PSNR (single series)
- [ ] 1.3 Create separate metric chart widget for SSIM (single series)
- [ ] 1.4 Stack 3 charts vertically in the UI layout (Loss on top, then PSNR, then SSIM)
- [ ] 1.5 Remove the combined `_LineChartPainter` single chart implementation

## 2. Axis Labels and Numbers

- [ ] 2.1 Add x-axis rendering with epoch/step numbers to each chart
- [ ] 2.2 Add y-axis rendering with metric value ticks (3-5 ticks per chart)
- [ ] 2.3 Use dynamic y-axis range based on min/max of each metric
- [ ] 2.4 Add axis label text (e.g., "Epoch", "Loss", "PSNR", "SSIM")

## 3. Preview 4-Way Grid

- [ ] 3.1 Modify `_ValidationPanel` to use 2x2 grid layout instead of 2-column
- [ ] 3.2 Add Input image tile with label
- [ ] 3.3 Add Output (predicted) image tile with label
- [ ] 3.4 Add Target (ground truth) image tile with label
- [ ] 3.5 Add Diff image tile with label
- [ ] 3.6 Handle case where Diff is not available (show placeholder)

## 4. Preview Skeleton

- [ ] 4.1 Add skeleton/placeholder state to preview panel
- [ ] 4.2 Show skeleton immediately when training starts
- [ ] 4.3 Replace skeleton with actual images when preview data arrives

## 5. First Image of Epoch

- [ ] 5.1 Modify `validationPreview` API call to include `preview_index=0`
- [ ] 5.2 Ensure only first validation image is fetched per epoch

## 6. Iteration Counter Display

- [ ] 6.1 Verify status strip shows "epoch X · iter Y" format
- [ ] 6.2 Confirm iteration counter updates during training (if data available)

## 7. Live Metrics During Epoch

- [ ] 7.1 Test if current loss displays during iteration (vs "--")
- [ ] 7.2 Note: This may depend on backend iteration-level metrics availability

## 8. Testing and Polish

- [ ] 8.1 Verify all 3 charts render correctly with sample data
- [ ] 8.2 Verify axis labels are readable and properly positioned
- [ ] 8.3 Verify 4-way grid layout on different screen sizes
- [ ] 8.4 Test skeleton-to-image transition
- [ ] 8.5 Run lint and typecheck