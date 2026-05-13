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

#### Scenario: Training initializes
- **WHEN** a run starts training
- **THEN** the backend loads model core configuration and constructs input conv (3→num_features) and output conv+pixel shuffle (num_features→3 with derived scale)

#### Scenario: Model has trained core weights
- **WHEN** training starts with a trained model that has trained_core_weights_path
- **THEN** the core weights are loaded from the stored path instead of initialized randomly

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
- **THEN** the backend loads core weights and builds input/output layers for the new scale, continuing from the trained core

#### Scenario: Fine-tuning on same scale
- **WHEN** fine-tuning uses the same scale as the original training
- **THEN** behavior is identical to regular fine-tuning from checkpoint

### Requirement: Legacy model compatibility
The system SHALL continue to work with models created before this change that have scale stored in their configuration.

#### Scenario: Legacy model is used
- **WHEN** a model has scale stored in config (pre-change format)
- **THEN** the backend uses the model's stored scale and treats it as scale-locked for compatibility

#### Scenario: Legacy model trains
- **WHEN** a legacy model runs training
- **THEN** the dataset scale must still match the model's stored scale (backward compatible check)