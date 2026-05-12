## ADDED Requirements

### Requirement: Split metric charts into 3 separate stacked charts
The Live Metrics tab SHALL display Loss, PSNR, and SSIM metrics in **3 separate charts stacked vertically** instead of a single combined chart.

#### Scenario: Charts display during active training
- **WHEN** a run is active and metrics data exists
- **THEN** three distinct chart areas are visible, each showing one metric type (Loss, PSNR, SSIM)

#### Scenario: Each chart has independent y-axis scaling
- **WHEN** metrics are displayed across different value ranges
- **THEN** each chart scales its y-axis based on its own metric range (Loss ~0-10, PSNR ~20-40, SSIM ~0-1)

### Requirement: Charts display axis labels and tick numbers
All metric charts SHALL display numeric values on both x-axis (epochs/steps) and y-axis (metric values).

#### Scenario: X-axis shows epoch numbers
- **WHEN** chart renders with historical data
- **THEN** x-axis shows epoch numbers as labels (e.g., "0", "1", "2", "3")

#### Scenario: Y-axis shows metric values with 3-5 ticks
- **WHEN** chart renders metric data
- **THEN** y-axis displays 3-5 numeric tick marks appropriate to the metric range

### Requirement: 4-way image preview grid
The validation preview panel SHALL display a 2x2 grid showing: Input, Output (predicted), Target (ground truth), and Diff images.

#### Scenario: Preview grid layout is 2x2
- **WHEN** validation preview data is available
- **THEN** four images are displayed in a 2x2 arrangement with labels (Input, Output, Target, Diff)

#### Scenario: Each image has label overlay
- **WHEN** preview grid displays images
- **THEN** each image has a text label indicating its type (input/output/target/diff)

### Requirement: Show first epoch image only
The validation preview SHALL request and display only the **first image** (index 0) of each epoch, not all validation samples.

#### Scenario: Request first image explicitly
- **WHEN** fetching validation preview during active training
- **THEN** the API call includes `preview_index=0` to get only the first image

### Requirement: Preview panel shows skeleton immediately
The validation preview panel SHALL display a placeholder/skeleton **immediately** when training starts, before any images arrive.

#### Scenario: No preview data yet
- **WHEN** training has started but no validation preview has arrived
- **THEN** a placeholder skeleton is displayed in the preview panel area

#### Scenario: Skeleton replaced by actual images
- **WHEN** first validation preview images arrive
- **THEN** the skeleton is replaced with the actual preview images

### Requirement: Metrics display iteration counter
The Live Metrics tab SHALL display the current iteration number alongside epoch in the status strip.

#### Scenario: Active training shows iteration
- **WHEN** a run is active
- **THEN** the status strip shows "epoch X · iter Y" format

### Requirement: Live metrics show current loss value
The metric cards SHALL display the current training loss value updating in real-time, not just epoch-level values.

#### Scenario: Training in progress shows live loss
- **WHEN** iterations are executing within an epoch
- **THEN** the loss metric card displays the current loss value (not "--" or empty)

**Note**: This requirement depends on backend providing iteration-level metrics. If backend only provides epoch-level data, the UI will show "--" until epoch completes.