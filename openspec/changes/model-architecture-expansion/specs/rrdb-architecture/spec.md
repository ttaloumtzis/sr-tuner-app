## ADDED Requirements

### Requirement: RRDBNet model class exists in the backend
The system SHALL provide a `RRDBNet` PyTorch `nn.Module` composed of a head Conv2d, a body Sequential of `num_blocks` RRDB blocks (each containing three Residual Dense Blocks with 5 dense layers and growth channels `gc=32`), a trailing end Conv2d, and a PixelShuffle upsampler tail. Each dense layer output is multiplied by 0.2 before the residual addition.

#### Scenario: RRDBNet forward pass produces correct output shape
- **WHEN** a `RRDBNet(scale=4, num_features=64, num_blocks=23)` model receives a `(1, 3, 32, 32)` input tensor
- **THEN** the output shape SHALL be `(1, 3, 128, 128)` and all values SHALL be in `[0, 1]`

#### Scenario: RRDBNet parameter count matches expected magnitude
- **WHEN** `RRDBNet(scale=4, num_features=64, num_blocks=23)` is instantiated
- **THEN** total trainable parameters SHALL be approximately 16.6M (within 5%)

### Requirement: RRDB model can be created from the template catalog
The system SHALL allow a user to select the RRDB (ESRGAN) template, configure features and blocks, and save it as a model. The saved `ModelObject` SHALL store `architecture="rrdb"`.

#### Scenario: Save RRDB model via API
- **WHEN** `POST /projects/{id}/models/from-template` is called with `template_id="rrdb"`, `num_features=64`, `num_blocks=23`
- **THEN** the project SHALL contain a new `ModelObject` with `architecture="rrdb"`, `num_features=64`, `num_blocks=23`

### Requirement: RRDB model is trainable end-to-end
The system SHALL train an RRDB model through the standard training loop with L1 loss, save checkpoints, and extract core weights from `body.*` keys.

#### Scenario: Training run completes for RRDB model
- **WHEN** a training run is started with a model whose `architecture="rrdb"`
- **THEN** the training loop SHALL instantiate `RRDBNet(scale, num_features, num_blocks)`, complete at least one epoch without error, and save a valid checkpoint

### Requirement: RRDB model can perform inference
The system SHALL load an RRDB model from core weights or a full checkpoint and run super-resolution inference.

#### Scenario: Inference with RRDB core weights
- **WHEN** inference is requested with an RRDB model that has `trained_core_weights_path` set
- **THEN** the system SHALL instantiate `RRDBNet` and load core weights into `model.body`, producing a valid output image
