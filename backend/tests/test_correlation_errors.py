"""Tests proving structured API errors expose correlation identifiers to callers."""
from __future__ import annotations

import os

from fastapi.testclient import TestClient

from sr_tuner_api.main import app

client = TestClient(app)
TOKEN = "test-corr-token"


def setup_module() -> None:
    os.environ["SR_TUNER_SESSION_TOKEN"] = TOKEN


def test_correlation_header_in_error_response() -> None:
    cid = "error-corr-flow-001"
    resp = client.get(
        "/projects/nonexistent/datasets",
        headers={
            "x-sr-tuner-token": TOKEN,
            "x-correlation-id": cid,
        },
    )
    assert resp.status_code == 404
    assert resp.headers.get("x-correlation-id") == cid


def test_correlation_id_in_validation_error_response() -> None:
    cid = "validation-corr-003"
    resp = client.post(
        "/projects",
        json={"parent_path": "", "name": ""},
        headers={
            "x-sr-tuner-token": TOKEN,
            "x-correlation-id": cid,
        },
    )
    assert resp.status_code == 422
    assert resp.headers.get("x-correlation-id") == cid
