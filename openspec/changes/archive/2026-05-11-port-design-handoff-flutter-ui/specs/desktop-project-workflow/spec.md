## MODIFIED Requirements

### Requirement: Desktop startup screen
The system SHALL show a Flutter desktop startup screen with the `sr-tuner` app name prominently displayed, actions to create a project or open an existing project, and a recent-project picker.

#### Scenario: User starts the app
- **WHEN** the user launches `sr-tuner`
- **THEN** the app displays the app name, create/open project actions, archive import placeholder state, learn chips, recent project search/filter controls, and recent project cards before entering the workspace

#### Scenario: User opens a recent project
- **WHEN** the user selects a recent project card
- **THEN** the app opens that project folder using the same backend validation as the normal open-project action

### Requirement: Project workspace navigation
The system SHALL present the main project workspace with Overview, Dataset, Model, Training, Live, Checkpoints, and Inference tabs.

#### Scenario: Project enters workspace
- **WHEN** a project is opened successfully
- **THEN** the user can navigate among all seven workflow tabs without leaving the project

#### Scenario: User changes tabs
- **WHEN** the user selects a workspace tab
- **THEN** the app preserves per-tab state such as scroll position and selected item for the active project session

## ADDED Requirements

### Requirement: Overview project home
The system SHALL provide an Overview tab that summarizes project state, recent activity, next recommended action, recent loss trend, and quick actions.

#### Scenario: Overview is selected
- **WHEN** the user selects Overview
- **THEN** the tab shows project metrics, recent activity, next-step guidance, and available actions from backend dashboard data

### Requirement: Project shell header
The system SHALL show a project header above the tab bar with project identity, object counts, backend status, device capability badge, and settings access.

#### Scenario: Project header renders
- **WHEN** a project is open
- **THEN** the header displays project name, project summary, backend status, device badge, and settings action

#### Scenario: User opens project menu
- **WHEN** the user activates the project-name dropdown in the shell header
- **THEN** the app shows available project-level actions or a disabled/unavailable state for actions that are not implemented

### Requirement: Locked tab behavior
The system SHALL allow locked or prerequisite-blocked tabs to be selected and SHALL render their blocked state rather than making navigation fail silently.

#### Scenario: Inference prerequisites are missing
- **WHEN** the user selects Inference without a usable checkpoint
- **THEN** the tab opens to the inference-blocked state with checklist guidance

### Requirement: Theme and density selection
The system SHALL allow users to switch Classic Workspace theme and density where the UI exposes those preferences.

#### Scenario: Theme changes
- **WHEN** the user switches between light and dark theme
- **THEN** the app applies the matching handoff color tokens to Classic Workspace screens

### Requirement: Project manifest naming
The system SHALL reconcile user-facing `.srtproj` language from the handoff with the backend's canonical project save file.

#### Scenario: Project title is rendered
- **WHEN** the UI displays a project title, window title, archive placeholder, or manifest-related copy
- **THEN** it uses documented terminology that maps clearly to project folders and the canonical `sr-tuner.project.json` project file, while treating `.srtproj archive` as disabled future functionality for this change

#### Scenario: Archive import is shown
- **WHEN** the start screen shows Import from `.srtproj archive`
- **THEN** the action is disabled or marked unavailable because archive import/export is out of scope for this change

### Requirement: Locked start-screen copy
The system SHALL preserve the handoff's committed beginner-facing start screen copy where it appears in the preview.

#### Scenario: Start footer renders
- **WHEN** the start screen shows project portability guidance
- **THEN** it includes the message that projects are folders and can be moved while sr-tuner finds the manifest
