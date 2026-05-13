from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class LogLevel(str, Enum):
    TRACE = "trace"
    DEBUG = "debug"
    INFO = "info"
    WARN = "warn"
    ERROR = "error"
    FATAL = "fatal"


_LOG_LEVEL_ORDER = {level: i for i, level in enumerate(LogLevel)}
_ACTIVE_MINIMUM = _LOG_LEVEL_ORDER[LogLevel.INFO]


def is_level_enabled(level: LogLevel, minimum: LogLevel | None = None) -> bool:
    return _LOG_LEVEL_ORDER[level] >= _LOG_LEVEL_ORDER[minimum or _ACTIVE_MINIMUM]


EVENT_PREFIX = "sr."


def event_name(category: str, action: str) -> str:
    return f"{EVENT_PREFIX}{category}.{action}"


class EventNames:
    BACKEND_START = event_name("backend", "start")
    BACKEND_HEALTH_CHECK = event_name("backend", "health_check")
    BACKEND_STARTUP_FAILURE = event_name("backend", "startup_failure")
    BACKEND_SHUTDOWN = event_name("backend", "shutdown")

    REQUEST_INGRESS = event_name("request", "ingress")
    REQUEST_COMPLETE = event_name("request", "complete")
    REQUEST_VALIDATION_FAILURE = event_name("request", "validation_failure")
    REQUEST_SERVICE_ERROR = event_name("request", "service_error")

    JOB_QUEUED = event_name("job", "queued")
    JOB_RUNNING = event_name("job", "running")
    JOB_CANCELING = event_name("job", "canceling")
    JOB_CANCELED = event_name("job", "canceled")
    JOB_COMPLETED = event_name("job", "completed")
    JOB_FAILED = event_name("job", "failed")

    METRICS_INGEST = event_name("metrics", "ingest")
    METRICS_POLL_START = event_name("metrics", "poll_start")
    METRICS_POLL_COMPLETE = event_name("metrics", "poll_complete")
    METRICS_POLL_INTERRUPTED = event_name("metrics", "poll_interrupted")
    METRICS_RENDER_LATENCY = event_name("metrics", "render_latency")

    INFERENCE_SUBMIT = event_name("inference", "submit")
    INFERENCE_START = event_name("inference", "start")
    INFERENCE_COMPLETE = event_name("inference", "complete")
    INFERENCE_FAILED = event_name("inference", "failed")
    INFERENCE_BATCH_SUMMARY = event_name("inference", "batch_summary")

    TELEMETRY_UPDATE = event_name("telemetry", "update")
    TELEMETRY_UNAVAILABLE = event_name("telemetry", "unavailable")

    CORRELATION_FALLBACK = event_name("correlation", "fallback_generated")

    REDACTION_APPLIED = event_name("redaction", "applied")

    ASSET_LOAD_START = event_name("asset", "load_start")
    ASSET_LOAD_COMPLETE = event_name("asset", "load_complete")
    ASSET_LOAD_FAILED = event_name("asset", "load_failed")

    WORKFLOW_ACTION = event_name("workflow", "action")
    WORKFLOW_ERROR = event_name("workflow", "error")

    PARENT_WATCHDOG = event_name("watchdog", "parent_process_check")


COMPONENT_FRONTEND = "frontend"
COMPONENT_BACKEND = "backend"
COMPONENT_API = "api"
COMPONENT_JOB = "job"
COMPONENT_INFERENCE = "inference"
COMPONENT_METRICS = "metrics"
COMPONENT_TELEMETRY = "telemetry"
COMPONENT_WATCHDOG = "watchdog"
COMPONENT_STARTUP = "startup"


REDACTED_PLACEHOLDER = "[REDACTED]"

SENSITIVE_KEYS = frozenset({
    "token",
    "secret",
    "password",
    "credential",
    "authorization",
    "x-sr-tuner-token",
    "session_token",
    "private_key",
})


def should_redact(key: str) -> bool:
    lower = key.lower().replace("-", "_").replace(" ", "_")
    return any(s in lower for s in SENSITIVE_KEYS)


@dataclass
class LogEvent:
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    level: LogLevel = LogLevel.INFO
    component: str = ""
    event: str = ""
    message: str = ""
    session_id: str = ""
    request_id: str = ""
    correlation_id: str = ""
    context: dict[str, Any] = field(default_factory=dict)

    def to_dict(self, *, redact: bool = True) -> dict[str, Any]:
        ctx = self.context
        if redact:
            ctx = _redact_dict(ctx)
        return {
            "timestamp": self.timestamp,
            "level": self.level.value,
            "component": self.component,
            "event": self.event,
            "message": self.message,
            "session_id": self.session_id,
            "request_id": self.request_id,
            "correlation_id": self.correlation_id,
            "context": ctx,
        }


def _redact_dict(d: dict[str, Any], _parent_key: str = "") -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in d.items():
        combined = f"{_parent_key}.{key}" if _parent_key else key
        if should_redact(combined):
            result[key] = REDACTED_PLACEHOLDER
        elif isinstance(value, dict):
            result[key] = _redact_dict(value, combined)
        elif isinstance(value, bytes) or (isinstance(value, str) and _is_binary_like(value)):
            result[key] = _redact_binary(value)
        else:
            result[key] = value
    return result


def _is_binary_like(value: str) -> bool:
    if len(value) < 1024:
        return False
    control_count = sum(1 for c in value if ord(c) < 32 and c not in "\n\r\t")
    return control_count > len(value) * 0.1


def _redact_binary(value: bytes | str) -> str:
    if isinstance(value, bytes):
        return f"[BINARY {len(value)} bytes]"
    return f"[TEXT {len(value)} chars]"
