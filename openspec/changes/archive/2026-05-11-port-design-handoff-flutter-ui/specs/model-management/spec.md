## ADDED Requirements

### Requirement: Model template catalog
The system SHALL expose a model template catalog with template ID, display name, architecture summary, best-for label, speed label, supported scale, parameter count, VRAM estimate, input crop, and support state.

#### Scenario: Model tab opens
- **WHEN** the Model tab is selected
- **THEN** the UI displays template cards from the backend catalog with unsupported templates disabled or marked unavailable

#### Scenario: User filters templates
- **WHEN** the user uses template filter controls
- **THEN** the catalog view filters templates locally or from the backend without changing project model state

#### Scenario: User imports template
- **WHEN** the user chooses Import template
- **THEN** the app validates backend support for imported template metadata or displays a clear unavailable placeholder state

### Requirement: Template selection is non-destructive
The system SHALL allow selecting a model template for configuration without deleting existing datasets, runs, checkpoints, or inference history.

#### Scenario: User switches selected template
- **WHEN** the user selects another model template
- **THEN** the app updates the draft or selected model configuration without removing existing project artifacts

### Requirement: Model template detail panel
The system SHALL show selected-template details including metric cards, architecture flow, hyperparameter fields, and a non-destructive switching banner.

#### Scenario: Template is selected
- **WHEN** a model template is selected
- **THEN** the detail panel shows scale, parameters, VRAM estimate, crop size, architecture steps, and hyperparameters

#### Scenario: User resets template settings
- **WHEN** the user chooses Reset to defaults
- **THEN** the draft template configuration returns to backend-provided defaults without changing saved models

#### Scenario: User saves template as model
- **WHEN** the user chooses Save as model for a supported template
- **THEN** the app creates or updates a project model object using the selected template configuration

### Requirement: Unsupported template guard
The system SHALL prevent creating or training a model template that the backend does not support.

#### Scenario: Unsupported template is selected
- **WHEN** the user selects a visible but unsupported template
- **THEN** create/train actions remain disabled and the UI explains the missing backend support
