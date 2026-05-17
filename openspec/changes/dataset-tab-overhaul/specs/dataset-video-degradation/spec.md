## ADDED Requirements

### Requirement: Downscale method selection
The system SHALL allow users to select the ffmpeg scale filter algorithm when creating a video-generated dataset, with a default of `bicubic`.

#### Scenario: User selects downscale method
- **WHEN** the user creates a video dataset and selects a downscale method from the options `bicubic`, `bilinear`, `lanczos`, `nearest`, or `area`
- **THEN** the selected method is passed as the `downscale_method` field in the video generation request and applied as the `flags` parameter of the ffmpeg scale filter

#### Scenario: Default downscale method applied
- **WHEN** the user does not change the downscale method
- **THEN** `bicubic` is used

### Requirement: Optical pre-blur (pre-downscale Gaussian blur)
The system SHALL support an optional Gaussian blur applied to each HR frame before downscaling, controlled by a `pre_blur` sigma parameter (0.0 = disabled).

#### Scenario: Pre-blur applied before downscale
- **WHEN** `pre_blur` is greater than 0.0
- **THEN** a `gblur=sigma={pre_blur}` filter is inserted into the LR ffmpeg filter chain before the scale step

#### Scenario: Pre-blur disabled
- **WHEN** `pre_blur` equals 0.0
- **THEN** no pre-blur filter is added and the pipeline is unchanged from before this feature

#### Scenario: Pre-blur displayed in degradation pipeline
- **WHEN** a dataset has `pre_blur > 0` stored in its generation metadata
- **THEN** the degradation pipeline display includes a "Pre-blur (optical): σ=X" step before the downscale step

### Requirement: Video output format selection
The system SHALL allow users to choose between PNG and JPEG output when generating a video dataset.

#### Scenario: PNG output selected
- **WHEN** the user selects PNG output format
- **THEN** both HR and LR frames are extracted as `.png` files and no JPEG quality parameter is applied

#### Scenario: JPEG output selected
- **WHEN** the user selects JPEG output format
- **THEN** both HR and LR frames are extracted as `.jpg` files with the configured JPEG quality (1–100, default 95)

#### Scenario: JPEG quality slider visible
- **WHEN** the user selects JPEG as the output format in the video wizard
- **THEN** a JPEG quality slider (1–100) becomes visible in the form

#### Scenario: JPEG quality slider hidden
- **WHEN** the output format is PNG
- **THEN** the JPEG quality slider is hidden

### Requirement: Dataset re-synthesis
The system SHALL allow users of video-generated datasets to change degradation settings and regenerate LR frames without recreating the dataset from scratch.

#### Scenario: Re-synthesis with new settings
- **WHEN** the user modifies any degradation parameter (downscale method, pre_blur, blur, noise, JPEG quality, output format) in the pipeline card and clicks "Re-synthesize"
- **THEN** the system deletes existing LR frames, re-runs the ffmpeg LR pipeline with the new settings against the stored source video, re-validates the dataset, and updates the generation metadata

#### Scenario: Re-synthesis leaves HR frames untouched
- **WHEN** re-synthesis runs
- **THEN** the HR frames folder is not modified

#### Scenario: Re-synthesis blocked during active run
- **WHEN** a training run using this dataset is in an active state (running, pausing, paused, resuming, stopping)
- **THEN** the re-synthesis request returns a 409 error with code `dataset_in_active_run`

#### Scenario: Source video missing at re-synthesis time
- **WHEN** the stored source video path no longer exists on disk at re-synthesis time
- **THEN** the request returns a 422 error with code `source_video_missing`

#### Scenario: Pipeline card shows editable controls for video datasets
- **WHEN** the selected dataset has type `video_generated`
- **THEN** the pipeline card shows interactive controls (dropdowns for downscale method and output format; sliders for pre_blur, blur, noise, JPEG quality) with values pre-filled from stored generation metadata

#### Scenario: Pipeline card is read-only for paired datasets
- **WHEN** the selected dataset has type `paired`
- **THEN** the pipeline card shows a static message indicating no generation metadata is available
