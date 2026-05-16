## Purpose
Define how sr-tuner derives model scale from dataset at run creation time, enabling any model to train on any dataset regardless of scale.

## ADDED Requirements

### Requirement: Scale derivation from dataset
The system SHALL derive model output scale from the selected dataset at run creation time, not from the model configuration.

#### Scenario: Run is created with dataset
- **WHEN** a user creates a run with a selected dataset
- **THEN** the backend uses the dataset's validated scale as the model output scale for that run

#### Scenario: Dataset has no validated scale
- **WHEN** the selected dataset has not completed validation
- **THEN** run creation fails with error indicating dataset must be validated first

### Requirement: Dynamic model construction at training
The system SHALL construct the complete model (core + input/output layers) at training initialization using the derived scale.

#### Scenario: Training initializes (new training)
- **WHEN** a run starts training with train_mode="new"
- **THEN** the backend builds the model with the derived scale: `build_internal_sr_model(scale=dataset_scale, ...)`
- **AND** all weights are initialized randomly (head, body, tail)

#### Scenario: Training initializes (fine-tuning)
- **WHEN** a run starts training with train_mode="fine_tune" and the model has trained_core_weights_path
- **THEN** the backend builds the model with the new dataset's scale
- **AND** loads core weights into `model_impl.body` only (preserving learned features)
- **AND** head and tail are freshly initialized (random weights) for the new scale
- **AND** optimizer is freshly constructed (no optimizer state carried over)

#### Scenario: Fine-tuning without core weights
- **WHEN** train_mode="fine_tune" but model has no trained_core_weights_path
- **THEN** training fails with error: "Cannot fine-tune untrained model"

#### Scenario: New training on already-trained model
- **WHEN** train_mode="new" but model already has trained_core_weights_path
- **THEN** training proceeds with fresh initialization (overwrites existing core weights on completion)
- **AND** a warning is shown: "Model already has trained weights. This will overwrite them."

### Requirement: Scale display in training tab
The system SHALL display the derived scale in the training tab as inherited from the selected dataset.

#### Scenario: User selects dataset
- **WHEN** the user selects a dataset in Training Setup
- **THEN** the UI displays "Scale: inherited from dataset (x<n>)" instead of a scale selector

#### Scenario: Dataset changes during configuration
- **WHEN** the user changes the selected dataset to one with different scale
- **THEN** the displayed scale updates to reflect the new dataset's scale

### Requirement: Fine-tuning from trained model
The system SHALL support fine-tuning a trained model on a different scale dataset by loading core weights and constructing new input/output layers.

#### Scenario: Fine-tuning a trained model
- **WHEN** the user creates a run using a trained model with a different-scale dataset
- **THEN** the backend loads core weights into body only, builds input/output layers for the new scale, and continues training from the trained core

#### Scenario: Fine-tuning on same scale
- **WHEN** fine-tuning uses the same scale as the original training
- **THEN** behavior is identical to regular fine-tuning from checkpoint (core weights loaded into body, head/tail reinitialized at same scale)

### Requirement: Training worker receives scale as parameter
The system SHALL pass scale as an explicit parameter to the training worker, not read it from model.scale.

#### Scenario: Training worker starts
- **WHEN** `_training_worker()` is invoked
- **THEN** it reads `run.metadata["dataset_scale"]` instead of `model.scale`
- **AND** passes it to `build_internal_sr_model(scale=..., ...)` and `save_checkpoint(scale=...)`

### Requirement: Core weight extraction on training completion
The system SHALL extract core weights from the best checkpoint after every successful training completion.

#### Scenario: Training completes successfully
- **WHEN** the training loop finishes and run state is set to "completed"
- **THEN** the backend finds the best checkpoint (tagged "best_psnr", fallback to "latest")
- **AND** extracts core weights (body only, stripping head and tail)
- **AND** saves to `models/<model_id>/core_weights/best_core.pth`
- **AND** updates `model.trained_core_weights_path` and `model.status = "trained"`
- **AND** packages checkpoints + metrics into a TrainHistoryEntry appended to model.train_history
- **AND** the run is consumed (removed from active run management)

#### Scenario: Training fails
- **WHEN** training fails or is cancelled
- **THEN** no core weight extraction occurs
- **AND** existing core weights (if any) are preserved
- **AND** the run remains visible for debugging