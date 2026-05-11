from __future__ import annotations

from pathlib import Path

import pytest


FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="session")
def fixture_paired_dataset_4x() -> Path:
    """Tiny CPU smoke-test dataset: 16×16 HR / 4×4 LR, one PNG pair, scale 4."""
    path = FIXTURES_DIR / "paired_4x"
    assert (path / "HR" / "frame_001.png").exists(), "Fixture PNG missing – regenerate with scripts/gen_fixtures.py"
    assert (path / "LR" / "frame_001.png").exists(), "Fixture PNG missing – regenerate with scripts/gen_fixtures.py"
    return path
