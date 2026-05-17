## ADDED Requirements

### Requirement: Extended validation statistics
The system SHALL collect format counts, resolution range, aspect ratio consistency, and near-black pair count during dataset validation and store them on the `DatasetValidation` object alongside existing fields.

#### Scenario: Validation collects format counts
- **WHEN** a dataset is validated (quick or full mode)
- **THEN** the system counts how many HR image files use each file extension and stores the result as `format_counts` (e.g. `{"png": 1479}`)

#### Scenario: Validation collects resolution range
- **WHEN** a dataset is validated and at least one pair is sampled
- **THEN** the system stores the smallest sampled HR resolution as `min_hr_resolution` and the largest as `max_hr_resolution`, each as `[width, height]`

#### Scenario: Validation detects inconsistent aspect ratios
- **WHEN** sampled HR images do not all share the same width-to-height ratio (within a 1% tolerance)
- **THEN** `consistent_aspect_ratio` is set to `false`

#### Scenario: Validation confirms consistent aspect ratios
- **WHEN** all sampled HR images share the same aspect ratio within tolerance
- **THEN** `consistent_aspect_ratio` is set to `true`

#### Scenario: Quick mode black image sampling
- **WHEN** a dataset is validated in quick mode
- **THEN** the system checks 1 in 4 sampled pairs for near-black content (HR mean pixel value < 8) and records the count in `black_pair_count`

#### Scenario: Full mode black image detection
- **WHEN** a dataset is validated in full mode
- **THEN** the system checks every pair for near-black content and records the total count in `black_pair_count`

### Requirement: Health check rows for extended stats
The system SHALL expose extended validation statistics as named health check rows in the dataset detail response, appended after the existing scale-alignment check.

#### Scenario: Pair count quality warning shown
- **WHEN** the dataset has fewer than 100 matched pairs
- **THEN** a health check row with id `pair_count_quality`, severity `warning`, and a message recommending 200+ pairs SHALL be included

#### Scenario: Pair count quality passes
- **WHEN** the dataset has 100 or more matched pairs
- **THEN** a health check row with id `pair_count_quality` and severity `success` SHALL be included showing the pair count

#### Scenario: Format consistency warning shown
- **WHEN** `format_counts` contains more than one extension
- **THEN** a health check row with id `format_consistency`, severity `warning`, listing the mixed formats SHALL be included

#### Scenario: Format consistency passes
- **WHEN** `format_counts` contains exactly one extension
- **THEN** a health check row with id `format_consistency`, severity `success`, showing the detected format SHALL be included

#### Scenario: Resolution check warning shown
- **WHEN** `min_hr_resolution` has a width or height below 128 pixels
- **THEN** a health check row with id `resolution`, severity `warning`, stating the minimum resolution SHALL be included

#### Scenario: Resolution check passes
- **WHEN** `min_hr_resolution` is 128×128 or larger
- **THEN** a health check row with id `resolution`, severity `success`, showing min and max resolutions SHALL be included

#### Scenario: Aspect ratio warning shown
- **WHEN** `consistent_aspect_ratio` is `false`
- **THEN** a health check row with id `aspect_ratio`, severity `warning`, noting inconsistent ratios SHALL be included

#### Scenario: Aspect ratio passes
- **WHEN** `consistent_aspect_ratio` is `true`
- **THEN** a health check row with id `aspect_ratio`, severity `success` SHALL be included

#### Scenario: Black image warning shown
- **WHEN** `black_pair_count` is greater than zero
- **THEN** a health check row with id `black_images`, severity `warning`, stating the count and recommending removal SHALL be included

#### Scenario: Extended stats not yet collected
- **WHEN** a dataset was created before this feature was deployed and has no extended stats
- **THEN** the extended health check rows SHALL be omitted, and the existing rows SHALL render normally
