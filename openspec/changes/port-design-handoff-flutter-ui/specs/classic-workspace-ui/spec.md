## ADDED Requirements

### Requirement: Flutter handoff recreation
The system SHALL recreate the `design_handoff_sr_tuner/` Direction B Classic Workspace screens as Flutter/Dart widgets and SHALL NOT transpile, embed, or execute the JSX/CSS handoff files as product UI.

#### Scenario: Handoff screen is implemented
- **WHEN** a screen from the handoff is built in the app
- **THEN** the screen is implemented with Flutter widgets using app state and backend APIs rather than React, HTML, or CSS runtime code

### Requirement: Locked design tokens
The system SHALL provide Flutter theme tokens matching the handoff's light and dark palettes, IBM Plex typography intent, spacing scale, 4 px component radius, status colors, border styles, and compact density rules.

#### Scenario: Theme is applied
- **WHEN** the app renders a Classic Workspace screen
- **THEN** colors, text styles, spacing, radii, borders, and density follow the handoff tokens

#### Scenario: Interactive state renders
- **WHEN** buttons, chips, fields, tabs, or icon buttons are hovered, pressed, selected, disabled, or focused
- **THEN** the visual state follows the handoff component styling or an explicitly documented Flutter-native equivalent

### Requirement: Shared workspace components
The system SHALL provide reusable Flutter components for buttons, icon buttons, chips, fields, sections, banners, metric cards, solid and striped progress bars, empty states, dashed image placeholders, charts, compare sliders, keyboard hints, and step indicators.

#### Scenario: Tab UI uses repeated primitives
- **WHEN** a tab renders repeated handoff elements
- **THEN** it uses shared Classic Workspace components rather than duplicating local styling

### Requirement: Classic project shell
The system SHALL render project screens inside a Classic Workspace shell with a sticky project header, tab bar, tab body, and bottom status bar.

#### Scenario: Project is open
- **WHEN** the user enters an open project
- **THEN** the shell shows project name, summary, backend/device badges, workflow tabs, active tab state, and bottom status information

#### Scenario: Window chrome is rendered
- **WHEN** the app renders window chrome or titlebar areas
- **THEN** it either uses native desktop chrome or a documented custom chrome implementation without leaving the preview's titlebar expectation ambiguous

### Requirement: Handoff screen states
The system SHALL render all handoff screen states for start, overview, dataset populated, dataset empty, video import modal, model, training, live running, live empty, live error, checkpoints populated, checkpoints empty, inference working, and inference blocked.

#### Scenario: State prerequisites change
- **WHEN** project data makes a handoff state applicable
- **THEN** the corresponding Flutter screen state is displayed with the handoff copy and layout

### Requirement: Responsive desktop layout
The system SHALL keep Classic Workspace layouts usable on desktop windows by using constrained widths, scrollable bodies, stable split panes, and overflow-safe text.

#### Scenario: Window is narrow
- **WHEN** the window is narrower than the ideal artboard width
- **THEN** panels remain accessible through scrolling or responsive stacking without text overlap or clipped controls

### Requirement: Progress semantics
The system SHALL distinguish solid, striped, and indeterminate progress indicators according to the handoff semantics.

#### Scenario: Run progress is shown
- **WHEN** progress is a monotonic fraction of total work
- **THEN** the UI uses a solid progress fill

#### Scenario: Epoch iteration progress is shown
- **WHEN** progress is within an epoch and remaining time varies by step duration
- **THEN** the UI uses a striped progress fill

#### Scenario: Progress is unknowable
- **WHEN** an operation has no measurable fraction yet
- **THEN** the UI uses an indeterminate indicator rather than a fake percentage

### Requirement: Real media previews
The system SHALL render real preview images when paths or bytes are available and SHALL use dashed placeholders only when preview media is unavailable.

#### Scenario: Preview asset is available
- **WHEN** a dataset pair, validation preview, or inference result image can be loaded
- **THEN** the UI displays the real image instead of the dashed placeholder
