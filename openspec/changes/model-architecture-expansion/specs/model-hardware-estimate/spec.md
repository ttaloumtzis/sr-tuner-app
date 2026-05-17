## ADDED Requirements

### Requirement: Hardware estimate panel is available in Create mode
The system SHALL display a hardware estimate panel in the model Create panel showing: total parameter count, bare model memory (params × 4 bytes float32), gradient memory (+params × 4 bytes), optimizer memory (+params × 4 × 2 bytes for Adam), and training peak (sum of all three). All values SHALL update live as the features and blocks sliders change.

#### Scenario: Live update on slider change
- **WHEN** the user moves the features slider from 32 to 64 in Create mode
- **THEN** the parameter count and all memory figures SHALL update immediately without any API call

#### Scenario: Correct math for internal architecture (32f, 4b)
- **WHEN** features=32 and blocks=4 with architecture=internal_residual_pixelshuffle
- **THEN** parameters SHALL be 75,456; bare model SHALL be ~0.29 MB; training peak SHALL be ~1.15 MB

### Requirement: Hardware estimate panel is available in Manage mode
Each model card in the Manage panel SHALL contain a collapsible "Hardware estimate" section that, when expanded, shows the same parameter count and memory breakdown as the Create panel estimate, computed from the model's stored `num_features`, `num_blocks`, and `architecture`.

#### Scenario: Manage panel estimate expands on tap
- **WHEN** the user taps "Hardware estimate" on a model card in Manage mode
- **THEN** the estimate panel SHALL expand showing parameter count and memory rows

#### Scenario: Manage panel uses stored architecture
- **WHEN** a model with `architecture="edsr"`, `num_features=64`, `num_blocks=16` is shown in Manage
- **THEN** the estimate SHALL use the EDSR parameter formula, not the internal formula

### Requirement: Parameter count formula is architecture-aware
The system SHALL use a distinct parameter count formula for each architecture:
- **internal_residual_pixelshuffle**: `(f² × b × 18) + (f × 3 × 18)`
- **EDSR**: head + (blocks × 2 × (f²×9+f)) + end_conv + tail (scale=4 representative)
- **RRDB**: head + (blocks × 3 × dense_block(f, gc=32)) + end_conv + tail (scale=4 representative)

#### Scenario: EDSR estimate differs from internal for same f/b
- **WHEN** features=64, blocks=16, architecture=edsr
- **THEN** the displayed parameter count SHALL differ from `(64² × 16 × 18) + (64 × 3 × 18)`
