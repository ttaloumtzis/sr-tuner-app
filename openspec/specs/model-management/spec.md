## Purpose
Define how sr-tuner creates, configures, validates, and derives status for project model objects.

## Requirements

### Requirement: Model objects
The system SHALL allow users to create model objects with stable IDs, names, architecture, number of features, number of blocks, optimizer settings, scheduler settings, loss weights, status, trained_core_weights_path, and metadata. Scale SHALL NOT be stored in model configuration for new models; scale is derived from dataset at run time.

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

## MODIFIED Requirements

### Requirement: Model objects
The system SHALL allow users to create model objects with stable IDs, names, architecture, number of features, number of blocks, optimizer settings, scheduler settings, loss weights, status, trained_core_weights_path, and metadata. Scale SHALL NOT be stored in model configuration for new models; scale is derived from dataset at run time.

#### Scenario: New model is created
- **WHEN** the user creates a new model from a template
- **THEN** the model does not include a scale field; scale comes from dataset at training time

#### Scenario: Legacy model exists
- **WHEN** an existing model has scale stored in configuration (pre-change format)
- **THEN** the backend maintains backward compatibility and uses the stored scale

### Requirement: Editable training-related model config
The system SHALL allow optimizer, scheduler, and L1, perceptual, and adversarial loss weights to be edited on model objects before training or fine-tuning. Editing of num_features and num_blocks SHALL be blocked for trained models (models with trained_core_weights_path).

#### Scenario: User edits untrained model config
- **WHEN** the user changes num_features or num_blocks on an untrained model
- **THEN** the changes are saved and model remains untrained

#### Scenario: User edits trained model config
- **WHEN** the user attempts to change num_features or num_blocks on a trained model
- **THEN** the UI blocks the edit and shows a message that core architecture is locked after training

#### Scenario: User edits trained model optimizer
- **WHEN** the user changes optimizer or loss weights on a trained model
- **THEN** the changes are saved; this is allowed for fine-tuning preparation

### Requirement: Trained and fine-tune models
The system SHALL track whether a model is untrained or trained based on the presence of trained_core_weights_path. A trained model SHALL be usable for inference and fine-tuning.

#### Scenario: Model completes first training
- **WHEN** a run completes with a best checkpoint and core weights are extracted
- **THEN** the model's trained_core_weights_path is populated and status is "trained"

#### Scenario: Subsequent training completes
- **WHEN** a subsequent training run for the same model completes successfully
- **THEN** the backend extracts core weights from the new best checkpoint and overwrites trained_core_weights_path

#### Scenario: Core weight extraction process
- **WHEN** core weights are extracted from a checkpoint for architecture "internal_residual_pixelshuffle"
- **THEN** the first convolution layer (3 to num_features) and last convolution layer (num_features to num_features*scale*scale with pixel shuffle) are excluded
- **AND** only body layers (residual blocks) are kept in core weights

#### Scenario: No best checkpoint available
- **WHEN** training completes but no checkpoint has the "best_psnr" tag
- **THEN** the backend falls back to the "latest" checkpoint for extraction

#### Scenario: Core weights are stored
- **WHEN** core weights are extracted
- **THEN** they are saved to project_root/models/<model_id>/core_weights/best_core.pth with a metadata JSON sidecar

#### Scenario: Trained model is deleted
- **WHEN** a trained model is deleted
- **THEN** the core weights folder is also deleted

#### Scenario: Model is untrained
- **WHEN** a model has no trained_core_weights_path
- **THEN** the model status is "untrained" and cannot be used for model-based inference

#### Scenario: Trained model is used for inference
- **WHEN** inference is requested with a trained model
- **THEN** core weights are loaded from trained_core_weights_path and the backend constructs input layer (3 to num_features) and output layer (num_features to 3 with specified scale) dynamically
- **AND** the output scale can differ from the training scale

#### Scenario: Core weights file is missing
- **WHEN** inference is requested but trained_core_weights_path is empty or file is missing
- **THEN** inference fails with clear error that model has no trained weights

#### Scenario: Output scale is set at inference
- **WHEN** inference request includes output_scale parameter
- **THEN** the output layer is constructed with that scale regardless of training scale

#### Scenario: Trained model is used for fine-tuning
- **WHEN** a run is created using a trained model
- **THEN** core weights are loaded as starting point and new input/output layers are constructed for the dataset's scale

### Requirement: Dataset model scale compatibility
The system SHALL derive model scale from the selected dataset, not from the model configuration. For legacy models with stored scale, the dataset scale must still match the model's stored scale.

#### Scenario: New model with dataset
- **WHEN** a user creates a run with a new model (no scale field)
- **THEN** the dataset scale is automatically used for that run

#### Scenario: Legacy model with dataset
- **WHEN** a user creates a run with a legacy model (has scale in config)
- **THEN** the dataset scale must match the model's stored scale (backward compatible check)

### Requirement: Importing models with weights
The system SHALL allow importing a model template that copies both configuration and trained core weights to create a new usable model.

#### Scenario: User imports trained model
- **WHEN** the user imports a trained model
- **THEN** a new model is created with copied configuration and core weights copied to the new model's folder

#### Scenario: Import source has no core weights
- **WHEN** the import source model has no trained_core_weights_path
- **THEN** import creates a new model with only the configuration (untrained), same as before

#### Scenario: Core weights are copied (not referenced)
- **WHEN** import copies a trained model
- **THEN** the core weights file is duplicated to the new model's folder, not symlinked

#### Scenario: Imported model is used
- **WHEN** inference runs on an imported trained model
- **THEN** the inference uses the copied core weights in the new project's folder

### Requirement: Import metadata tracking
The system SHALL track the original model ID when importing to maintain provenance.

#### Scenario: Import completes
- **WHEN** a model is imported with weights
- **THEN** the new model's metadata includes original_model_id pointing to the source model

### Requirement: Import UI feedback
The system SHALL indicate in the UI whether an import will include weights or be configuration-only.

#### Scenario: Importing trained model
- **WHEN** user clicks import on a trained model
- **THEN** the UI shows "Import with trained weights" or similar indicator

#### Scenario: Importing untrained model
- **WHEN** user clicks import on an untrained model
- **THEN** the UI shows "Import configuration only" since no weights exist

### Requirement: Same-project import only (Phase 1)
The system SHALL support importing models within the same project only. Cross-project import is deferred.

#### Scenario: Import within same project
- **WHEN** the user imports a model within the same project
- **THEN** the model is duplicated with a new ID, and core weights are copied to the new model's folder

#### Scenario: Cross-project import attempted
- **WHEN** a cross-project import is attempted
- **THEN** the system returns an error: "Cross-project import is not yet supported"

### Requirement: Training session consumed into model history
The system SHALL consume successful training runs into the model's train_history, preserving all checkpoints and metrics under the model.

#### Scenario: Training completes successfully
- **WHEN** a training run completes successfully
- **THEN** the run's checkpoints, metrics, and dataset info are packaged into a TrainHistoryEntry
- **AND** appended to model.train_history
- **AND** the run is removed from active run management (only failed/interrupted runs remain visible)

#### Scenario: Training fails
- **WHEN** training fails or is cancelled
- **THEN** no TrainHistoryEntry is created
- **AND** the run remains visible for debugging

### Requirement: Checkpoint-based inference retained
The system SHALL retain the existing checkpoint-based inference path for version comparison across training runs.

#### Scenario: User compares old vs new weights
- **WHEN** the user selects a specific checkpoint (not the model-based path)
- **THEN** the backend loads the full state_dict from the checkpoint (old behavior)
- **AND** the scale is fixed to the checkpoint's training scale
- **AND** the inference result is comparable to model-based inference at the same scale

#### Scenario: Checkpoint tab shows extraction status
- **WHEN** a checkpoint is the one that was auto-extracted for core weights
- **THEN** the checkpoint tab shows a badge: "Core weights extracted" or "★ Best"
