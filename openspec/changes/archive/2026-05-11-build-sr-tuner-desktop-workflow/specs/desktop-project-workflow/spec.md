## ADDED Requirements

### Requirement: Desktop startup screen
The system SHALL show a Flutter desktop startup screen with the `sr-tuner` app name prominently displayed and actions to create a project or open an existing project.

#### Scenario: User starts the app
- **WHEN** the user launches `sr-tuner`
- **THEN** the app displays the app name and create/open project actions before entering the workspace

### Requirement: Backend process lifecycle
The system SHALL start the local Python FastAPI backend automatically when the desktop app needs project functionality and SHALL wait for a healthy backend before issuing API requests.

#### Scenario: Backend starts successfully
- **WHEN** the user creates or opens a project
- **THEN** the Flutter app starts the backend process, confirms the health endpoint is ready, and continues to the workspace

#### Scenario: Backend fails to start
- **WHEN** the backend process cannot become healthy
- **THEN** the Flutter app displays a recoverable error with backend status details

### Requirement: Project create and open
The system SHALL allow users to create new project folders and open existing project folders that contain a valid `sr-tuner.project.json` file.

#### Scenario: New project is created
- **WHEN** the user chooses a folder and project name
- **THEN** the system creates the project save file and required project subfolders for datasets, models, runs, inference, and cache

#### Scenario: Existing project is opened
- **WHEN** the user selects a folder containing `sr-tuner.project.json`
- **THEN** the system loads persisted datasets, models, runs, checkpoints, inference history, and workspace state

#### Scenario: Target project folder already exists and is non-empty
- **WHEN** the user creates a project in a folder that already exists, is non-empty, and does not contain `sr-tuner.project.json`
- **THEN** the system refuses by default and requires an explicit create-here confirmation before writing project metadata

### Requirement: Project schema versioning
The system SHALL version `sr-tuner.project.json` and SHALL handle supported, older, newer, and invalid schema versions predictably.

#### Scenario: Project schema is current
- **WHEN** the user opens a project with the current supported schema version
- **THEN** the backend opens the project normally

#### Scenario: Project schema is older but supported
- **WHEN** the user opens a project with an older supported schema version
- **THEN** the backend migrates the project, writes a backup of the original project file, and saves the upgraded project file

#### Scenario: Project schema is newer than supported
- **WHEN** the user opens a project created by a newer unsupported app version
- **THEN** the backend refuses to open it and explains that the app must be upgraded

#### Scenario: Project schema is missing or invalid
- **WHEN** the user opens a project with missing or invalid schema metadata
- **THEN** the backend refuses to open it and reports repair guidance without modifying the project

### Requirement: Project workspace navigation
The system SHALL present the main project workspace with Dataset, Model, Training Setup, Live Metrics, Checkpoints, and Inference tabs.

#### Scenario: Project enters workspace
- **WHEN** a project is opened successfully
- **THEN** the user can navigate among all six workflow tabs without leaving the project

### Requirement: Project persistence
The system SHALL persist project metadata in `sr-tuner.project.json` and use project-relative paths for copied or generated assets.

#### Scenario: Project state changes
- **WHEN** the user creates or updates datasets, models, runs, checkpoints, or inference records
- **THEN** the project save file is updated so reopening the project restores the state

### Requirement: Atomic project file writes
The system SHALL write project metadata atomically and retain a backup so interrupted writes do not corrupt the only project save file.

#### Scenario: Project metadata is saved
- **WHEN** the backend writes `sr-tuner.project.json`
- **THEN** it writes a temporary file, completes the write, renames it into place atomically, and retains the previous valid save file as a backup

#### Scenario: Project save file is corrupt but backup exists
- **WHEN** the user opens a project with an unreadable project file and a valid backup exists
- **THEN** the backend reports the corruption and offers recovery from the backup rather than silently replacing user data

### Requirement: Portable project metadata
The system SHALL avoid relying on the saved project root path as durable identity and SHALL resolve the active root path from the folder selected at open time.

#### Scenario: Project folder is moved
- **WHEN** the user opens a project from a different filesystem location than before
- **THEN** the backend uses the newly selected folder as the active project root and resolves project-relative paths against it

### Requirement: Project-scoped API session
The system SHALL return a project ID when opening or creating a project and SHALL use that ID for subsequent project-scoped local API calls.

#### Scenario: Project API calls follow open
- **WHEN** the frontend opens or creates a project
- **THEN** the backend records the local project root for the returned project ID and the frontend uses that project ID for dataset, model, run, checkpoint, inference, and workspace calls

### Requirement: Stable object identifiers
The system SHALL assign stable opaque IDs to datasets, models, runs, checkpoints, inference records, and backend jobs and SHALL avoid using display names as identity.

#### Scenario: Object is created
- **WHEN** the backend creates a dataset, model, run, checkpoint, inference record, or job
- **THEN** it assigns an ID that remains stable across project reopen and can be used in project-scoped API routes

#### Scenario: Duplicate display name is entered
- **WHEN** the user creates an object with a display name already used by another object of the same type
- **THEN** the backend keeps IDs distinct and either rejects the duplicate name with a clear error or generates a unique folder-safe slug according to that object's workflow

### Requirement: Standard API errors
The system SHALL return local API errors in a consistent structured shape that the Flutter UI can render as actionable messages.

#### Scenario: API request fails
- **WHEN** the backend rejects a request
- **THEN** it returns an error object containing a stable code, human-readable message, optional details, and whether the error is recoverable

### Requirement: Local API request protection
The system SHALL bind the local backend to loopback and SHALL protect project-mutating API requests with a per-session token once the frontend starts or connects to the backend.

#### Scenario: Frontend launches local backend
- **WHEN** the Flutter frontend starts the development or packaged local backend process
- **THEN** it generates a random session token, passes it to the backend process through environment or launch arguments, and stores it only in frontend process memory

#### Scenario: Frontend connects to an already healthy local backend
- **WHEN** the Flutter frontend detects a backend that is already healthy
- **THEN** it only uses that backend for non-mutating health/version checks unless a valid session token handshake is available

#### Scenario: Frontend sends a mutating request
- **WHEN** the frontend calls a project-mutating endpoint
- **THEN** it includes the session token and the backend rejects missing or invalid tokens

### Requirement: Shared backend jobs
The system SHALL represent long-running backend operations as jobs with consistent progress, cancellation, logs, timing, and error metadata.

#### Scenario: Long-running operation starts
- **WHEN** the backend starts dataset copy, video dataset generation, training, checkpoint export, ONNX export, single-image inference, or batch inference
- **THEN** it creates a job with ID, type, project ID, associated object ID where available, status, progress, log tail, started time, and optional error details

#### Scenario: Job status is queried
- **WHEN** the frontend requests a job status
- **THEN** the backend returns status using `queued`, `running`, `canceling`, `canceled`, `completed`, or `failed`

#### Scenario: Job or metrics polling runs
- **WHEN** the frontend polls job status, active run status, metrics, or hardware telemetry
- **THEN** it uses a bounded default polling interval and the backend returns incremental state without requiring clients to read project files directly

#### Scenario: Job cancellation is requested
- **WHEN** the user cancels a cancelable job
- **THEN** the backend marks it canceling, stops work at a safe boundary, records whether partial artifacts were removed or retained, and returns the final job status

### Requirement: Native desktop file selection
The system SHALL provide native desktop file and folder pickers for project, dataset, video, checkpoint export, and inference path selection while keeping typed path fields available as an advanced fallback.

#### Scenario: User selects a folder
- **WHEN** a workflow asks for a filesystem folder
- **THEN** the frontend offers a native folder picker and fills the corresponding path field from the selected folder

### Requirement: Workspace prerequisite states
The system SHALL show clear empty, blocked, and ready states in each project tab according to available project objects.

#### Scenario: Training prerequisites are missing
- **WHEN** no usable dataset or no compatible model exists
- **THEN** the Training Setup tab explains the missing prerequisite and disables launch actions

#### Scenario: No run is active
- **WHEN** the project has no active or recent run
- **THEN** the Live Metrics tab shows an empty state instead of stale metrics

#### Scenario: No checkpoint exists
- **WHEN** the project has no usable checkpoints
- **THEN** the Checkpoints and Inference tabs show blocked states that guide the user back to training
