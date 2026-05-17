## MODIFIED Requirements

### Requirement: Dataset validation depth
The system SHALL support quick and full dataset validation modes so large datasets can be registered without forcing an expensive full image scan. Quick mode validates a bounded sample of pairs and performs lightweight statistical collection; full mode validates every pair and performs complete statistical collection including black-image detection on all pairs.

#### Scenario: Quick validation runs
- **WHEN** a dataset is registered with quick validation
- **THEN** the backend validates folder structure, pair matching across filenames, and dimensions for a bounded sample of matched pairs, and collects format counts, resolution range, aspect ratio consistency, and black-image count (sampling 1 in 4 pairs for black detection)

#### Scenario: Full validation runs
- **WHEN** the user requests full validation
- **THEN** the backend validates dimensions and readability for every matched pair, collects complete format counts, resolution range, aspect ratio consistency, and black-image count for all pairs, and stores validation mode metadata

### Requirement: Video generation configuration
The system SHALL store the complete video generation configuration on the dataset object and SHALL support the following configurable parameters: scale, frames per second, frame limit, output format (png or jpg), downscale method (any valid ffmpeg scale filter flag), Gaussian pre-downscale blur sigma (`pre_blur`), post-downscale Gaussian blur sigma (`blur`), noise amount (`noise`), and JPEG quality (1–100).

#### Scenario: Video dataset is generated with full config
- **WHEN** the user submits a video generation request with any combination of supported parameters
- **THEN** the system applies all parameters in the ffmpeg pipeline in the order: pre-blur → downscale → post-blur → noise → JPEG compression (if applicable), and stores the full config as the dataset's generation metadata

#### Scenario: Pre-blur applied before downscale
- **WHEN** `pre_blur` is greater than 0.0
- **THEN** a Gaussian blur of sigma `pre_blur` is applied to each frame before the scale filter

#### Scenario: Default configuration used when parameters omitted
- **WHEN** the user does not specify optional parameters
- **THEN** defaults are applied: `downscale_method=bicubic`, `pre_blur=0.0`, `blur=0.0`, `noise=0.0`, `jpeg_quality=95`, `output_format=png`
