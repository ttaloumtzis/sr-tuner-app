## ADDED Requirements

### Requirement: Scrubber slider for pair navigation
The system SHALL provide a full-width scrubber slider in the LR/HR preview pane that maps to the pair index range, allowing users to jump to any pair in the dataset by dragging.

#### Scenario: Slider position reflects current pair
- **WHEN** the preview pane is showing pair N of M
- **THEN** the scrubber slider thumb is positioned at N-1 (zero-indexed) on a range of 0 to M-1

#### Scenario: User drags slider to new position
- **WHEN** the user drags the scrubber slider to a new position
- **THEN** the system loads the pair at that index after a 200 ms debounce and displays it in the preview pane

#### Scenario: Scrubber hidden when no pairs available
- **WHEN** the dataset has zero matched pairs
- **THEN** the scrubber slider is not shown

### Requirement: Index jump field for direct pair access
The system SHALL provide an editable index field in the LR/HR preview pane header that shows the current pair number (1-based) and allows the user to type a number and press Enter to jump directly to that pair.

#### Scenario: Index field shows current pair
- **WHEN** the preview pane is showing pair N of M
- **THEN** the index field displays N (1-based)

#### Scenario: User types a valid pair number and presses Enter
- **WHEN** the user enters a number between 1 and the total pair count and presses Enter
- **THEN** the system loads and displays that pair

#### Scenario: User types an out-of-range number
- **WHEN** the user enters a number less than 1 or greater than the total pair count
- **THEN** the system clamps to the nearest valid index (1 or total) and loads that pair

#### Scenario: Previous/next buttons retained
- **WHEN** the preview pane is rendered
- **THEN** the existing previous and next buttons remain available for ±1 navigation alongside the scrubber and index field
