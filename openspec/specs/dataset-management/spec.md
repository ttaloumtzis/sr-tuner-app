## Purpose
Define how sr-tuner registers, generates, validates, stores, and presents project datasets for training.

## Requirements

### Requirement: Multiple dataset objects
The system SHALL allow each project to contain multiple dataset objects with stable IDs, names, type, scale, storage mode, paths, validation status, and metadata.

#### Scenario: Dataset is created
- **WHEN** the user registers or generates a dataset
- **THEN** the project stores a dataset object that can be selected by training runs

### Requirement: Type 1 paired dataset registration
The system SHALL support existing paired datasets with the folder structure `dataset/HR/` and `dataset/LR/`.

#### Scenario: Valid paired dataset is registered
- **WHEN** the user selects a dataset folder containing `HR/` and `LR/` subfolders
- **THEN** the system validates matching pairs and stores the dataset metadata

#### Scenario: Invalid paired dataset is registered
- **WHEN** the selected dataset is missing folders, pairs, or compatible image dimensions
- **THEN** the system reports validation errors and does not mark the dataset usable for training

### Requirement: Type 1 pair matching rules
The system SHALL validate Type 1 datasets using deterministic v1 pair matching rules.

#### Scenario: Paired files are matched
- **WHEN** the backend scans `HR/` and `LR/` folders
- **THEN** it ignores hidden files, accepts `png`, `jpg`, `jpeg`, `webp`, `tif`, and `tiff` files, treats v1 folders as flat, and matches HR/LR pairs by filename stem even when extensions differ

#### Scenario: Pair matching finds mismatches
- **WHEN** any supported HR or LR image file has no matching stem in the opposite folder
- **THEN** validation records the unmatched files and marks the dataset unusable until the mismatch is resolved

### Requirement: Dataset scale validation
The system SHALL validate dataset scale from image dimensions and SHALL store declared and validated scale metadata.

#### Scenario: Type 1 scale is validated
- **WHEN** the user declares a Type 1 dataset scale
- **THEN** the backend samples matched pairs and verifies that HR dimensions equal LR dimensions multiplied by the declared scale

#### Scenario: Type 1 scale mismatch is found
- **WHEN** sampled pair dimensions do not match the declared scale
- **THEN** validation records the mismatch, stores no validated scale, and prevents training selection until corrected

#### Scenario: Type 2 scale is created by the app
- **WHEN** the backend generates a Type 2 dataset from video
- **THEN** the configured generation scale is stored as both declared and validated scale after generated HR/LR outputs pass dimension checks

### Requirement: Dataset validation depth
The system SHALL support quick and full dataset validation modes so large datasets can be registered without forcing an expensive full image scan.

#### Scenario: Quick validation runs
- **WHEN** a dataset is registered with quick validation
- **THEN** the backend validates folder structure, pair matching across filenames, and dimensions for a bounded sample of matched pairs

#### Scenario: Full validation runs
- **WHEN** the user requests full validation
- **THEN** the backend validates dimensions and readability for every matched pair and stores validation mode metadata

### Requirement: Dataset image normalization policy
The system SHALL define how supported image modes and bit depths are handled before training.

#### Scenario: RGB image is loaded
- **WHEN** a dataset image is RGB with supported bit depth
- **THEN** the backend accepts it for validation and training

#### Scenario: Grayscale image is loaded
- **WHEN** a dataset image is grayscale
- **THEN** the backend converts it to RGB for training and records a validation warning

#### Scenario: Unsupported alpha or bit depth is loaded
- **WHEN** a dataset image uses unsupported alpha channels, color modes, or bit depths for the selected training path
- **THEN** validation reports the file and prevents training unless a supported conversion policy is selected

### Requirement: Type 1 dataset storage modes
The system SHALL let users either copy or move a Type 1 dataset into the project or reference it externally by absolute path.

#### Scenario: Dataset is stored inside project
- **WHEN** the user chooses project storage for a Type 1 dataset
- **THEN** the system stores project-relative dataset paths

#### Scenario: Dataset remains external
- **WHEN** the user chooses external storage for a Type 1 dataset
- **THEN** the system stores absolute dataset paths and marks the storage mode as external

### Requirement: Dataset storage operation safety
The system SHALL estimate, stage, validate, and commit Type 1 copy or move operations without silently overwriting existing project data.

#### Scenario: User prepares copy or move
- **WHEN** the user chooses to copy or move a Type 1 dataset into the project
- **THEN** the backend estimates file count and size and the frontend asks for confirmation before executing the operation

#### Scenario: Destination already exists
- **WHEN** the requested project dataset destination already exists
- **THEN** the backend refuses by default unless the user explicitly chooses a replace operation

#### Scenario: Copy or move executes
- **WHEN** the backend copies or moves a dataset into project storage
- **THEN** it writes into a staging folder, validates the staged dataset, and commits it to the final dataset folder only after validation passes

#### Scenario: Move completes
- **WHEN** a move operation finishes copying, verifying, and committing project storage
- **THEN** the backend deletes the source only after successful verification and records the final project-relative paths

### Requirement: Type 2 video dataset generation
The system SHALL generate paired `HR/` and `LR/` datasets inside the project from a source video using user-configured extraction and degradation settings.

#### Scenario: Video dataset is generated
- **WHEN** the user selects a video and generation settings
- **THEN** the backend extracts HR frames, creates LR frames using the configured scale and degradation, and stores a dataset object

### Requirement: Video generation configuration
The system SHALL provide beginner presets and advanced controls for FPS extraction, scale, output format, downscale method, blur, noise, JPEG compression, and frame limits.

#### Scenario: User uses a preset
- **WHEN** the user selects a video generation preset
- **THEN** the app fills generation settings that can be accepted or adjusted before creation

### Requirement: Dataset immutability for Type 1 and Type 2
The system SHALL prevent editing Type 1 and Type 2 dataset contents after creation, while allowing move or relink operations.

#### Scenario: Dataset was already created
- **WHEN** the user views a Type 1 or Type 2 dataset
- **THEN** the app allows metadata review and move/relink actions but not image-level editing
