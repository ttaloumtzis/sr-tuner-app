## Purpose
Define how sr-tuner configures, launches, monitors, pauses, resumes, and records local training runs.

## Requirements

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

## MODIFIED Requirements

### Requirement: Run setup
The system SHALL allow users to configure a training run with run name, selected dataset, selected model or fine-tune source, output folder, device, epochs, checkpoint cadence, validation split, logging, mixed precision, compile toggle, warmup, and scheduler-specific options. Scale SHALL be derived from the selected dataset, not from the model configuration.

#### Scenario: User configures run with dataset
- **WHEN** the user selects a dataset in Training Setup
- **THEN** the backend derives the run's output scale from the dataset's validated scale

#### Scenario: Dataset has no validated scale
- **WHEN** the selected dataset has not completed validation
- **THEN** run creation fails with error indicating dataset must be validated first

#### Scenario: Scale display in training tab
- **WHEN** the user selects a dataset in Training Setup
- **THEN** the UI displays "Scale: inherited from dataset (x<n>)" instead of a scale selector

#### Scenario: Dataset changes during configuration
- **WHEN** the user changes the selected dataset to one with different scale
- **THEN** the displayed scale updates to reflect the new dataset's scale

#### Scenario: Run with trained model
- **WHEN** the user creates a run using a trained model (with core weights)
- **THEN** the backend loads core weights from the model's trained_core_weights_path and constructs new input/output layers with the dataset's scale

#### Scenario: Fine-tuning from trained model
- **WHEN** fine-tuning uses a trained model on a dataset with different scale
- **THEN** the backend loads core weights and builds input/output layers for the new scale

### Requirement: Dynamic model construction at training
The system SHALL construct the complete model (core + input/output layers) at training initialization using the derived scale, with behavior varying by train_mode.

#### Scenario: New training
- **WHEN** a run starts training with train_mode="new"
- **THEN** the backend builds the model with the derived scale: build_internal_sr_model(scale=dataset_scale, ...)
- **AND** all weights are initialized randomly (head, body, tail)

#### Scenario: Fine-tuning with core weights
- **WHEN** a run starts training with train_mode="fine_tune" and the model has trained_core_weights_path
- **THEN** the backend builds the model with the new dataset's scale
- **AND** loads core weights into model_impl.body only (preserving learned features)
- **AND** head and tail are freshly initialized (random weights) for the new scale
- **AND** optimizer is freshly constructed (no optimizer state carried over)

#### Scenario: Fine-tuning without core weights
- **WHEN** train_mode="fine_tune" but model has no trained_core_weights_path
- **THEN** training fails with error: "Cannot fine-tune untrained model"

#### Scenario: New training on already-trained model
- **WHEN** train_mode="new" but model already has trained_core_weights_path
- **THEN** training proceeds with fresh initialization (overwrites existing core weights on completion)
- **AND** a warning is shown: "Model already has trained weights. This will overwrite them."

### Requirement: Training worker receives scale as parameter
The system SHALL pass scale as an explicit parameter to the training worker, not read it from model.scale.

#### Scenario: Training worker starts
- **WHEN** the training worker is invoked
- **THEN** it reads run.metadata["dataset_scale"] instead of model.scale
- **AND** passes it to build_internal_sr_model(scale=...) and save_checkpoint(scale=...)

### Requirement: Core weight extraction on training completion
The system SHALL extract core weights from the best checkpoint after every successful training completion.

#### Scenario: Training completes successfully
- **WHEN** the training loop finishes and run state is set to "completed"
- **THEN** the backend finds the best checkpoint (tagged "best_psnr", fallback to "latest")
- **AND** extracts core weights (body only, stripping head and tail)
- **AND** saves to models/<model_id>/core_weights/best_core.pth
- **AND** updates model.trained_core_weights_path and model.status = "trained"
- **AND** packages checkpoints + metrics into a TrainHistoryEntry appended to model.train_history
- **AND** the run is consumed (removed from active run management)

#### Scenario: Training fails
- **WHEN** training fails or is cancelled
- **THEN** no core weight extraction occurs
- **AND** existing core weights (if any) are preserved
- **AND** the run remains visible for debugging
