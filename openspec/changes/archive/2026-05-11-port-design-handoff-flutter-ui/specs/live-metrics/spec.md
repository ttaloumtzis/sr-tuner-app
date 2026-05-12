## ADDED Requirements

### Requirement: Live tab status badge
The system SHALL show a live status badge in the tab strip or shell when a run is actively training.

#### Scenario: Run is active
- **WHEN** the active run is running
- **THEN** the Live tab displays a live dot and LIVE badge using accent styling, with pulse animation when motion is enabled

### Requirement: Separate epoch and run progress
The system SHALL expose enough active-run data to render within-epoch striped progress separately from total run solid progress.

#### Scenario: Active run status updates
- **WHEN** the backend reports current epoch, total epochs, current iteration, and iterations per epoch
- **THEN** the Live tab renders striped epoch progress and solid run progress with ETA text

### Requirement: Snapshot checkpoint action
The system SHALL allow users to request a snapshot checkpoint for an active run when supported.

#### Scenario: User requests snapshot
- **WHEN** the user chooses Snapshot during a running training job
- **THEN** the backend saves a timestamped run-owned checkpoint without stopping the run or reports that snapshots are unavailable

### Requirement: Live event log
The system SHALL expose recent live events and log-tail lines for the active or most recent run.

#### Scenario: Recent events exist
- **WHEN** the Live tab renders a running or failed run
- **THEN** it shows recent events and log-tail data without requiring Flutter to read run files directly

#### Scenario: User opens log
- **WHEN** the user chooses Open log from a live or error state
- **THEN** the app opens or reveals the log file when platform support is available, or reports that the action is unavailable

### Requirement: CUDA OOM error state
The system SHALL render a dedicated CUDA out-of-memory error state with raw error summary, GPU stats, ranked suggested fixes, log tail, and retry actions when the backend classifies a run failure as OOM.

#### Scenario: Run fails with CUDA OOM
- **WHEN** a training run fails with a classified CUDA out-of-memory error
- **THEN** Live shows the handoff error banner, suggested fixes, log tail, and retry/open-settings actions

#### Scenario: Run fails and crash snapshot is possible
- **WHEN** a training run fails after producing recoverable weights or optimizer state
- **THEN** the backend attempts to save a run-owned checkpoint tagged `crash-snapshot`, marks it protected from automatic pruning, and records whether the snapshot was written

### Requirement: Validation samples panel
The system SHALL render validation samples in a fixed inspector panel with LR, SR, HR, and diff previews plus PSNR, SSIM, and LPIPS values when available.

#### Scenario: Validation preview updates
- **WHEN** a new validation preview is generated
- **THEN** the Live tab updates the samples panel with preview images and metric readouts

#### Scenario: User navigates validation samples
- **WHEN** multiple validation samples are available
- **THEN** the user can move between samples and the UI updates the displayed LR, SR, HR, diff, and metric readouts
