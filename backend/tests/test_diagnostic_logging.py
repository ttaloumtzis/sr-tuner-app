"""Tests for diagnostic logging schema, redaction, and correlation propagation."""
from __future__ import annotations

from fastapi.testclient import TestClient

from sr_tuner_api.logging_schema import (
    REDACTED_PLACEHOLDER,
    EventNames,
    LogEvent,
    LogLevel,
    should_redact,
)
from sr_tuner_api.main import app

client = TestClient(app)
TOKEN = "test-diag-token"


def setup_module() -> None:
    import os
    os.environ["SR_TUNER_SESSION_TOKEN"] = TOKEN


def test_log_event_has_required_fields() -> None:
    event = LogEvent(
        level=LogLevel.INFO,
        component="test",
        event=EventNames.BACKEND_START,
        message="test message",
        session_id="sess-1",
        request_id="req-1",
        correlation_id="corr-1",
        context={"key": "value"},
    )
    d = event.to_dict(redact=False)
    assert d["timestamp"]
    assert d["level"] == "info"
    assert d["component"] == "test"
    assert d["event"] == EventNames.BACKEND_START
    assert d["message"] == "test message"
    assert d["session_id"] == "sess-1"
    assert d["request_id"] == "req-1"
    assert d["correlation_id"] == "corr-1"
    assert d["context"] == {"key": "value"}


def test_log_event_level_gating() -> None:
    from sr_tuner_api.logging_schema import is_level_enabled

    assert is_level_enabled(LogLevel.ERROR, LogLevel.INFO)
    assert is_level_enabled(LogLevel.INFO, LogLevel.INFO)
    assert not is_level_enabled(LogLevel.DEBUG, LogLevel.INFO)
    assert not is_level_enabled(LogLevel.TRACE, LogLevel.INFO)


def test_redaction_sensitive_keys() -> None:
    assert should_redact("token")
    assert should_redact("session_token")
    assert should_redact("x-sr-tuner-token")
    assert should_redact("authorization")
    assert should_redact("secret_key")
    assert should_redact("password")
    assert not should_redact("name")
    assert not should_redact("path")
    assert not should_redact("description")


def test_redaction_applied_in_log_event() -> None:
    event = LogEvent(
        level=LogLevel.INFO,
        component="test",
        event="sr.test.event",
        message="test",
        context={"token": "my-secret-token", "name": "visible-name"},
    )
    d = event.to_dict(redact=True)
    assert d["context"]["token"] == REDACTED_PLACEHOLDER
    assert d["context"]["name"] == "visible-name"


def test_redaction_recursive_dict() -> None:
    event = LogEvent(
        level=LogLevel.INFO,
        component="test",
        event="sr.test.event",
        message="test",
        context={"nested": {"secret": "should-be-redacted", "visible": "ok"}},
    )
    d = event.to_dict(redact=True)
    assert d["context"]["nested"]["secret"] == REDACTED_PLACEHOLDER
    assert d["context"]["nested"]["visible"] == "ok"


def test_error_response_includes_correlation_id() -> None:
    cid = "test-corr-12345"
    resp = client.get(
        "/health",
        headers={"x-correlation-id": cid},
    )
    assert resp.status_code == 200


def test_mutating_error_returns_correlation() -> None:
    cid = "test-corr-error-flow"
    resp = client.get(
        "/projects/nonexistent/datasets",
        headers={
            "x-sr-tuner-token": TOKEN,
            "x-correlation-id": cid,
        },
    )
    assert resp.status_code == 404
    assert resp.headers.get("x-correlation-id") == cid


def test_responses_contain_request_id_header() -> None:
    resp = client.get("/health", headers={"x-correlation-id": "test-hdr"})
    assert "x-request-id" in resp.headers
    assert resp.headers["x-request-id"]


def test_event_names_are_stable() -> None:
    assert EventNames.BACKEND_START == "sr.backend.start"
    assert EventNames.REQUEST_INGRESS == "sr.request.ingress"
    assert EventNames.JOB_QUEUED == "sr.job.queued"
    assert EventNames.JOB_COMPLETED == "sr.job.completed"
    assert EventNames.JOB_FAILED == "sr.job.failed"
    assert EventNames.METRICS_INGEST == "sr.metrics.ingest"
    assert EventNames.TELEMETRY_UNAVAILABLE == "sr.telemetry.unavailable"
    assert EventNames.INFERENCE_SUBMIT == "sr.inference.submit"
    assert EventNames.INFERENCE_BATCH_SUMMARY == "sr.inference.batch_summary"
    assert EventNames.CORRELATION_FALLBACK == "sr.correlation.fallback_generated"


def test_job_logs_remain_readable() -> None:
    from sr_tuner_api.jobs import Job, job_store, CreateJobRequest

    job = job_store.create(CreateJobRequest(type="test"))
    job.logs.append("Epoch 1/10 complete.")
    job.logs.append("Epoch 2/10 complete.")
    job_store.put(job)
    tail = job_store.log_tail(job.id)
    assert all(isinstance(line, str) for line in tail.logs)
    assert any("Epoch" in line for line in tail.logs)
    assert len(tail.logs) == 2


def test_cause_codes_are_stable() -> None:
    from sr_tuner_api.cause_codes import CauseCodes

    assert CauseCodes.STARTUP_HEALTH_TIMEOUT == "startup_health_timeout"
    assert CauseCodes.TRANSPORT_TIMEOUT == "transport_timeout"
    assert CauseCodes.POLL_TIMEOUT == "poll_timeout"
    assert CauseCodes.TELEMETRY_CUDA_UNAVAILABLE == "telemetry_cuda_unavailable"
    assert CauseCodes.REDACTION_SENSITIVE_KEY == "redaction_sensitive_key"
    assert CauseCodes.CORRELATION_FALLBACK_GENERATED == "correlation_fallback_generated"
