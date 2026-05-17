## ADDED Requirements

### Requirement: Empty state direct routing
The system SHALL route each empty-state onboarding card directly to its respective creation wizard, bypassing the intermediate type-choice modal.

#### Scenario: Type 1 card opens paired wizard directly
- **WHEN** the dataset list is empty and the user clicks the Type 1 onboarding card's action button
- **THEN** the Type 1 paired folder creation dialog opens immediately without an intermediate choice modal

#### Scenario: Type 2 card opens video wizard directly
- **WHEN** the dataset list is empty and the user clicks the Type 2 onboarding card's action button
- **THEN** the Type 2 video extraction wizard opens immediately without an intermediate choice modal

#### Scenario: Type-choice modal retained for populated state
- **WHEN** the dataset list has at least one dataset and the user clicks "+ Create dataset"
- **THEN** the type-choice modal is shown as before

### Requirement: Empty state type descriptions
The system SHALL display structured descriptions on each empty-state onboarding card that help users distinguish the two dataset types.

#### Scenario: Type 1 card shows use-case guidance
- **WHEN** the empty state is rendered
- **THEN** the Type 1 card displays a subtitle indicating it is for users who already have matched HR/LR image folders, and lists supported formats

#### Scenario: Type 2 card shows use-case guidance
- **WHEN** the empty state is rendered
- **THEN** the Type 2 card displays a subtitle indicating it generates pairs from a video file and shows the ffmpeg availability status

### Requirement: Type 1 wizard folder structure hint
The system SHALL display the expected folder structure (`dataset/HR/` and `dataset/LR/`) inside the Type 1 creation dialog to reduce setup errors.

#### Scenario: Folder structure hint shown
- **WHEN** the Type 1 creation dialog is open
- **THEN** a visual or text hint showing the required `HR/` and `LR/` subfolder structure is displayed alongside or below the folder picker

### Requirement: Type 2 wizard FPS guidance
The system SHALL display inline guidance text in the Type 2 wizard explaining the trade-off between frames-per-second values and pair diversity.

#### Scenario: FPS guidance visible
- **WHEN** the Type 2 video extraction wizard is open
- **THEN** a helper note near the FPS field explains that low values (1–5 fps) extract distinct frames while higher values may produce near-duplicate pairs
