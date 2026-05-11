## Purpose
Define how sr-tuner creates, configures, validates, and derives status for project model objects.

## Requirements

### Requirement: Model objects
The system SHALL allow users to create model objects with stable IDs, names, architecture, scale, number of features, number of blocks, optimizer settings, scheduler settings, loss weights, status, and metadata.

#### Scenario: Model is created
- **WHEN** the user completes the Create Model form
- **THEN** the project stores a model object that can be selected in Training Setup

### Requirement: Minimal internal model baseline
The system SHALL define the first internal PyTorch model architecture as a configurable residual super-resolution model with pixel-shuffle upsampling.

#### Scenario: Internal baseline model is created
- **WHEN** the user creates the default internal model
- **THEN** the model uses supported scales, configurable feature count, configurable residual block count, and pixel-shuffle upsampling

#### Scenario: Unsupported scale is selected
- **WHEN** the user chooses a scale unsupported by the selected model architecture
- **THEN** model creation or training launch is blocked with a recoverable compatibility error

### Requirement: Model list
The system SHALL show created models and their metadata in the Model tab.

#### Scenario: User views models
- **WHEN** the project contains model objects
- **THEN** the Model tab lists them with architecture, scale, status, and training metadata

### Requirement: Editable training-related model config
The system SHALL allow optimizer, scheduler, and L1, perceptual, and adversarial loss weights to be edited on model objects before training or fine-tuning.

#### Scenario: User edits model config
- **WHEN** the user changes optimizer, scheduler, or loss weight settings
- **THEN** the project persists the updated model configuration

### Requirement: Loss support validation
The system SHALL validate configured loss weights against the selected training path and SHALL not silently ignore unsupported losses.

#### Scenario: Unsupported loss is configured
- **WHEN** a model config enables perceptual or adversarial loss for a training path that does not support it
- **THEN** Training Setup blocks launch or shows the loss as disabled until the user chooses a supported training path or adjusts the weights

#### Scenario: Adversarial loss is enabled
- **WHEN** adversarial loss is supported and enabled
- **THEN** the model or run config includes discriminator settings required by that training path

### Requirement: Trained and fine-tune models
The system SHALL track whether a model is untrained, trained, or available as a fine-tuning source.

#### Scenario: Checkpoint completes training
- **WHEN** a run saves a usable checkpoint for a model
- **THEN** the model metadata is updated so it can be selected for inference or fine-tuning

### Requirement: Derived model training status
The system SHALL derive model training status from usable checkpoint metadata instead of trusting manually edited model status.

#### Scenario: Model has no usable checkpoints
- **WHEN** a model has no completed usable checkpoints
- **THEN** the app shows the model as untrained

#### Scenario: Model has usable checkpoints
- **WHEN** a model has at least one completed usable checkpoint
- **THEN** the app shows the model as trained and allows checkpoint-backed inference

#### Scenario: Model has fine-tune-compatible checkpoints
- **WHEN** a model has at least one checkpoint with compatible training metadata
- **THEN** the app allows that checkpoint to be selected as a fine-tuning source

### Requirement: Dataset model scale compatibility
The system SHALL compare selected dataset scale and model scale before training and prevent incompatible training runs unless the conflict is resolved.

#### Scenario: Scale mismatch occurs
- **WHEN** the user selects a dataset and model with different scale values
- **THEN** Training Setup blocks launch and explains the mismatch
