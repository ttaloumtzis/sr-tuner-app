## Purpose
Define how sr-tuner extracts, stores, and uses core model weights (excluding scale-specific input/output layers) after training completes. Core weights are auto-extracted from the best checkpoint on every successful training completion. Checkpoints remain as full state_dict snapshots for version comparison.

## ADDED Requirements

### Requirement: Core weight extraction
The system SHALL extract core model weights from the best checkpoint after every successful training completion, excluding only the scale-specific input and output layers.

#### Scenario: First training completes successfully
- **WHEN** the first training run for a model reaches completed state with a checkpoint tagged "best_psnr"
- **THEN** the backend extracts core weights (excluding first conv and last conv/pixel shuffle) and stores them in the model's trained_core_weights_path
- **AND** the model status is set to "trained"

#### Scenario: Subsequent training completes successfully
- **WHEN** a subsequent training run for the same model completes successfully
- **THEN** the backend extracts core weights from the new best checkpoint
- **AND** overwrites the model's trained_core_weights_path with the new extraction

#### Scenario: Architecture has scale-specific layers
- **WHEN** the model architecture is "internal_residual_pixelshuffle"
- **THEN** the first convolution layer (3→num_features) and last convolution layer (num_features→num_features*scale*scale with pixel shuffle) are excluded from core weights

#### Scenario: No best checkpoint available
- **WHEN** training completes but no checkpoint has the "best_psnr" tag
- **THEN** the backend falls back to the "latest" checkpoint for extraction

### Requirement: Core weights storage
The system SHALL store core weights in a dedicated model folder within the project, separate from run checkpoints.

#### Scenario: Core weights are saved
- **WHEN** core weights are extracted
- **THEN** they are saved to project_root/models/<model_id>/core_weights/best_core.pth with a metadata JSON sidecar

#### Scenario: Model is deleted
- **WHEN** a trained model is deleted
- **THEN** the core weights folder is also deleted

### Requirement: Model status tracking
The system SHALL track model status as either "untrained" or "trained", where "trained" indicates core weights are available.

#### Scenario: Model becomes trained
- **WHEN** core weights are successfully extracted and stored
- **THEN** the model status is set to "trained" and trained_core_weights_path is populated

#### Scenario: Model is untrained
- **WHEN** a model has no trained_core_weights_path
- **THEN** the model status is "untrained" and cannot be used for model-based inference

### Requirement: Model-based inference (convenience shortcut)
The system SHALL load core weights and dynamically construct input/output layers for inference using a trained model.

#### Scenario: Trained model is selected for inference
- **WHEN** the user selects a trained model and specifies output scale
- **THEN** the backend loads core weights from trained_core_weights_path, constructs input layer (3→num_features) and output layer (num_features→3 with specified scale), and performs inference

#### Scenario: Core weights file is missing
- **WHEN** inference is requested but trained_core_weights_path is empty or file is missing
- **THEN** inference fails with clear error that model has no trained weights

### Requirement: Scale-agnostic inference output
The system SHALL allow inference output scale to differ from training scale when using trained core weights.

#### Scenario: User specifies different output scale
- **WHEN** the user selects a trained model and sets output scale different from training
- **THEN** the backend constructs output layer with the user-specified scale using the trained core

#### Scenario: Output scale is set at inference
- **WHEN** inference request includes output_scale parameter
- **THEN** the output layer is constructed with that scale regardless of training scale

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

### Requirement: Checkpoint-based inference (version comparison)
The system SHALL retain the existing checkpoint-based inference path for version comparison across training runs.

#### Scenario: User compares old vs new weights
- **WHEN** the user selects a specific checkpoint (not the model-based path)
- **THEN** the backend loads the full state_dict from the checkpoint (old behavior)
- **AND** the scale is fixed to the checkpoint's training scale
- **AND** the inference result is comparable to model-based inference at the same scale

#### Scenario: Checkpoint tab shows extraction status
- **WHEN** a checkpoint is the one that was auto-extracted for core weights
- **THEN** the checkpoint tab shows a badge: "Core weights extracted" or "★ Best"

#### Scenario: User compares old vs new weights
- **WHEN** the user selects a specific checkpoint (not the model-based path)
- **THEN** the backend loads the full state_dict from the checkpoint (old behavior)
- **AND** the scale is fixed to the checkpoint's training scale
- **AND** the inference result is comparable to model-based inference at the same scale

#### Scenario: Checkpoint tab shows extraction status
- **WHEN** a checkpoint is the one that was auto-extracted for core weights
- **THEN** the checkpoint tab shows a badge: "Core weights extracted" or "★ Best"

### Requirement: Checkpoint-based inference (version comparison)
The system SHALL retain the existing checkpoint-based inference path for version comparison across training runs.

#### Scenario: User compares old vs new weights
- **WHEN** the user selects a specific checkpoint (not the model-based path)
- **THEN** the backend loads the full state_dict from the checkpoint (old behavior)
- **AND** the scale is fixed to the checkpoint's training scale
- **AND** the inference result is comparable to model-based inference at the same scale

#### Scenario: Checkpoint tab shows extraction status
- **WHEN** a checkpoint is the one that was auto-extracted for core weights
- **THEN** the checkpoint tab shows a badge: "Core weights extracted" or "★ Best"