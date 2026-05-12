## 1. Inference Tab Stability

- [ ] 1.1 Audit all `DropdownButtonFormField` widgets in `inference_tab.dart`
- [ ] 1.2 Change checkpoint/model dropdown selection to use stable checkpoint IDs instead of object identity
- [ ] 1.3 Change tiling option dropdown selection to use a stable scalar option key instead of map values
- [ ] 1.4 Guard run, checkpoint, device, padding, format, and mode selections so stale values become `null` or a valid fallback
- [ ] 1.5 Add or update Flutter tests covering Inference tab render with async/empty/changed dropdown item lists

## 2. Persistent Preview Storage

- [ ] 2.1 Create epoch preview folder helper using `runs/<run_id>/previews/epoch_0001`
- [ ] 2.2 Save preview assets with names `input.png`, `output.png`, `target.png`, `diff_absolute.png`, and/or `diff_heatmap.png`
- [ ] 2.3 Generate preview from the first validation sample when validation is enabled and validation samples exist
- [ ] 2.4 Fall back to the first training sample when validation is disabled, split is `0.0`, or validation has no samples
- [ ] 2.5 Save only the diff files required by `diff_mode`
- [ ] 2.6 Store latest preview metadata with epoch, source, generated timestamp, and stable asset URLs

## 3. Preview API and Frontend Loading

- [ ] 3.1 Update preview metadata response parsing to include epoch/source if returned
- [ ] 3.2 Return stable URLs for saved epoch preview files
- [ ] 3.3 Update the Live tab to display the renamed preview asset kinds
- [ ] 3.4 Keep frontend preview refresh tied to epoch changes, not every metrics poll
- [ ] 3.5 Preserve skeleton behavior when no saved preview exists yet

## 4. Verification

- [ ] 4.1 Add backend tests for preview folder structure and diff-mode-specific files
- [ ] 4.2 Add backend tests for validation-disabled training-sample fallback
- [ ] 4.3 Add Flutter tests for preview metadata parsing and image slot mapping
- [ ] 4.4 Run targeted Dart analyzer checks
- [ ] 4.5 Run targeted Flutter tests
- [ ] 4.6 Run targeted backend compile/API tests
