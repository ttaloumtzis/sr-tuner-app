## ADDED Requirements

### Requirement: Run setup
The system SHALL allow users to configure a training run with run name, selected dataset, selected model or fine-tune source, output folder, device, epochs, checkpoint cadence, validation split, logging, mixed precision, compile toggle, warmup, and scheduler-specific options.

#### Scenario: User configures run
- **WHEN** the user fills Training Setup with compatible dataset and model choices
- **THEN** the app creates a run configuration under the project run folder

### Requirement: TensorBoard logging
The system SHALL support TensorBoard logging as an optional run setting and SHALL make logging output paths explicit.

#### Scenario: TensorBoard logging is enabled
- **WHEN** the user enables TensorBoard logging for a run
- **THEN** the backend writes event files under the run log directory and stores the relative log path in run metadata

#### Scenario: TensorBoard dependency is unavailable
- **WHEN** TensorBoard logging is enabled but the required logging dependency is unavailable
- **THEN** Training Setup reports the missing dependency and blocks launch or disables the toggle before launch

### Requirement: Run folder naming
The system SHALL create stable folder-safe run folders from run IDs and SHALL treat run display names as editable metadata rather than filesystem identity.

#### Scenario: Run is created
- **WHEN** the backend creates a run
- **THEN** it creates a run folder based on the run ID and stores the user-facing run name in metadata

### Requirement: One active training run
The system SHALL support only one active local training run at a time.

#### Scenario: Training is already active
- **WHEN** the user attempts to start another run
- **THEN** the system prevents the launch and identifies the active run

### Requirement: Training run lifecycle
The system SHALL model training runs with explicit lifecycle states: `draft`, `configured`, `running`, `pausing`, `paused`, `resuming`, `stopping`, `stopped`, `completed`, `failed`, and `interrupted`.

#### Scenario: Active state blocks another run
- **WHEN** any run is in `running`, `pausing`, `paused`, `resuming`, or `stopping`
- **THEN** the backend treats it as the one active run and blocks launching another run

#### Scenario: Backend restarts during a run
- **WHEN** the backend opens a project containing a run marked `running` but no owned live process exists
- **THEN** the backend marks that run as `interrupted` and preserves existing metrics and checkpoints

#### Scenario: Run reaches terminal state
- **WHEN** training finishes, fails, or is stopped
- **THEN** the backend writes a terminal state of `completed`, `failed`, or `stopped` and clears the active-run lock

### Requirement: Training job state mapping
The system SHALL map the shared backend training job status to run lifecycle state deterministically.

#### Scenario: Training job starts
- **WHEN** a training job moves from `queued` to `running`
- **THEN** the associated run moves from `configured` to `running`

#### Scenario: Training job is canceling
- **WHEN** a training job is `canceling`
- **THEN** the associated run is `stopping`

#### Scenario: Training job is canceled
- **WHEN** a training job finishes as `canceled`
- **THEN** the associated run is `stopped`

#### Scenario: Training job completes
- **WHEN** a training job finishes as `completed`
- **THEN** the associated run is `completed`

#### Scenario: Training job fails
- **WHEN** a training job finishes as `failed`
- **THEN** the associated run is `failed` and stores the structured job error

### Requirement: Index-based validation split
The system SHALL split training and validation by dataset indexes using validation percentage, seed, and shuffle settings without moving image files.

#### Scenario: Validation split is configured
- **WHEN** the user starts a run with a validation percentage
- **THEN** the backend derives train and validation indexes and leaves the dataset folders unchanged

### Requirement: Local PyTorch training path
The system SHALL provide a minimal internal PyTorch super-resolution training path before requiring BasicSR.

#### Scenario: First milestone training starts
- **WHEN** the user launches a valid run
- **THEN** the backend trains a simple internal PyTorch SR model using the selected dataset and model config

### Requirement: Training dependency availability
The system SHALL detect required and optional ML dependencies and SHALL report missing capabilities before launch.

#### Scenario: Required training dependency is missing
- **WHEN** PyTorch or required image loading dependencies are unavailable
- **THEN** Training Setup disables launch and reports the missing dependency

#### Scenario: Optional accelerator dependency is missing
- **WHEN** CUDA, ROCm, DirectML, or another accelerator is unavailable in the packaged environment
- **THEN** the backend still exposes CPU and omits unsupported accelerator devices

### Requirement: Video and export dependency availability
The system SHALL detect optional video generation and export dependencies before exposing the related workflow actions.

#### Scenario: Video dependency is missing
- **WHEN** ffmpeg or the configured video decoding backend is unavailable
- **THEN** Type 2 video dataset generation is disabled and the Dataset tab reports the missing dependency

#### Scenario: ONNX export dependency is missing
- **WHEN** ONNX export dependencies are unavailable for the selected model/checkpoint
- **THEN** the Checkpoints tab hides or disables ONNX export and reports that only `.pth` export is available

### Requirement: Device detection and selection
The system SHALL default to CPU and expose additional devices only when the packaged PyTorch environment supports them.

#### Scenario: Devices are loaded
- **WHEN** Training Setup requests available devices
- **THEN** the backend returns CPU and any supported CUDA, ROCm, or other devices available in the current build

### Requirement: Training controls
The system SHALL expose launch, pause, resume, and stop controls for the active local run.

#### Scenario: User stops training
- **WHEN** the user stops an active run
- **THEN** the backend updates run state and preserves metrics and checkpoints already written

### Requirement: Resume and fine-tune semantics
The system SHALL distinguish live-process pause/resume, interrupted run resume, and fine-tuning from a checkpoint.

#### Scenario: User resumes a paused live run
- **WHEN** the run is paused and the backend still owns the live process
- **THEN** resume continues the same run process

#### Scenario: User resumes an interrupted or stopped run
- **WHEN** the user resumes a non-live run from an existing checkpoint
- **THEN** the backend starts a new process using the selected checkpoint while preserving the run lineage metadata

#### Scenario: User fine-tunes a model
- **WHEN** the user starts fine-tuning from a checkpoint
- **THEN** the backend creates a new run linked to the source checkpoint rather than overwriting the source run
