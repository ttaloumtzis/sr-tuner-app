## ADDED Requirements

### Requirement: EDSR model class exists in the backend
The system SHALL provide an `EDSR` PyTorch `nn.Module` with a head Conv2d, a body of `num_blocks` residual blocks (each with two Conv2d layers, ReLU, and a `res_scale` multiplier on the residual branch), a trailing end Conv2d, and a PixelShuffle upsampler tail.

#### Scenario: EDSR forward pass produces correct output shape
- **WHEN** an `EDSR(scale=4, num_features=64, num_blocks=16)` model receives a `(1, 3, 32, 32)` input tensor
- **THEN** the output shape SHALL be `(1, 3, 128, 128)` and all values SHALL be in `[0, 1]`

#### Scenario: res_scale controls residual magnitude
- **WHEN** `res_scale=0.0` is set
- **THEN** the body contributes zero to the residual path and only the head passes through to the tail

### Requirement: EDSR model can be created from the template catalog
The system SHALL allow a user to select the EDSR template, configure features and blocks, set a `res_scale` value (0.01–1.0), and save it as a model. The saved `ModelObject` SHALL store `architecture="edsr"` and `res_scale`.

#### Scenario: Save EDSR model via API
- **WHEN** `POST /projects/{id}/models/from-template` is called with `template_id="edsr"`, `num_features=64`, `num_blocks=16`, `res_scale=0.1`
- **THEN** the project SHALL contain a new `ModelObject` with `architecture="edsr"`, `num_features=64`, `num_blocks=16`, `res_scale=0.1`

### Requirement: EDSR model is trainable end-to-end
The system SHALL train an EDSR model through the standard training loop, save checkpoints, extract core weights from `body.*` keys, and complete successfully.

#### Scenario: Training run completes for EDSR model
- **WHEN** a training run is started against a dataset with a model whose `architecture="edsr"`
- **THEN** the training loop SHALL instantiate `EDSR(scale, num_features, num_blocks, res_scale)`, run forward/backward passes, save a checkpoint, and extract core weights

### Requirement: EDSR model can perform inference
The system SHALL load an EDSR model from core weights or a full checkpoint and run super-resolution inference.

#### Scenario: Inference with EDSR core weights
- **WHEN** inference is requested with an EDSR model that has `trained_core_weights_path` set
- **THEN** the system SHALL instantiate `EDSR` and load the core weights into `model.body`, producing a valid output image
