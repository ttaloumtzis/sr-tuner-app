## ADDED Requirements

### Requirement: Inference dropdown values remain valid
The Inference tab SHALL keep all dropdown selected values synchronized with their available item lists.

#### Scenario: Checkpoints load asynchronously
- **WHEN** checkpoint data loads after the Inference tab first renders
- **THEN** the selected checkpoint value is either `null` or exactly one checkpoint ID from the loaded list

#### Scenario: Selected checkpoint disappears
- **WHEN** the previously selected checkpoint is deleted, filtered out, or replaced by refreshed data
- **THEN** the Inference tab clears the stale selection or selects a valid fallback without throwing a Flutter dropdown assertion

#### Scenario: Device list changes
- **WHEN** available inference devices load or change
- **THEN** the selected device value is either `null` or exactly one device ID from the loaded list

#### Scenario: Tiling option changes
- **WHEN** the user changes tiling settings
- **THEN** the tiling dropdown uses stable scalar option values and does not rely on `Map` object equality

#### Scenario: Inference tab has no valid checkpoint
- **WHEN** no usable checkpoint is available
- **THEN** the Inference tab shows its blocked or empty state instead of rendering an invalid dropdown value
