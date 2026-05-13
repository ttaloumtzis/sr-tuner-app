## Purpose
Define how sr-tuner imports trained model configurations along with their core weights, enabling immediate use of imported models for inference.

## ADDED Requirements

### Requirement: Import template with weights
The system SHALL allow importing a model template that copies both configuration and trained core weights to create a new usable model.

#### Scenario: User imports trained model
- **WHEN** the user uses the import template feature on a trained model
- **THEN** a new model is created with copied configuration and core weights copied to the new model's folder

#### Scenario: Import source has no core weights
- **WHEN** the import source model has no trained_core_weights_path
- **THEN** import creates a new model with only the configuration (untrained), same as before

### Requirement: Import preserves core weights
The system SHALL copy core weight files during import, not reference the original location.

#### Scenario: Core weights are copied
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