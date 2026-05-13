from __future__ import annotations

import json
import logging
import sys
from typing import Any, Callable

from .logging_schema import (
    COMPONENT_BACKEND,
    EVENT_PREFIX,
    LogEvent,
    LogLevel,
    is_level_enabled,
    _LOG_LEVEL_ORDER,
)

_LOG_LEVEL_MAP: dict[LogLevel, int] = {
    LogLevel.TRACE: logging.DEBUG - 5,
    LogLevel.DEBUG: logging.DEBUG,
    LogLevel.INFO: logging.INFO,
    LogLevel.WARN: logging.WARNING,
    LogLevel.ERROR: logging.ERROR,
    LogLevel.FATAL: logging.CRITICAL,
}


class StructuredLogHandler(logging.Handler):
    def __init__(self, sink: Callable[[dict[str, Any]], None] | None = None) -> None:
        super().__init__()
        self._sink = sink or _default_sink

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            self._sink({"message": msg, "level": record.levelname.lower(), "logger": record.name, "timestamp": self.formatTime(record)})
        except Exception:
            self.handleError(record)


def _default_sink(event: dict[str, Any]) -> None:
    print(json.dumps(event, default=str), file=sys.stderr)


_sinks: list[Callable[[dict[str, Any]], None]] = []

# Event sink strategy:
# - Default sink: structured JSON to stderr (visible in both dev and packaged runs)
# - Additional in-memory sinks can be registered via add_diagnostic_sink() for
#   scoped debug sessions or troubleshooting tooling
# - Retention bounds: sinks decide retention; no event is buffered indefinitely
#   in the logger itself
# - No file rotation in this phase (deferred to follow-up; see design.md Open Questions)
# - Desktop-packaged runs inherit the same stderr sink; Flutter captures the
#   backend subprocess stderr via BackendProcess._log


def add_diagnostic_sink(sink: Callable[[dict[str, Any]], None]) -> None:
    _sinks.append(sink)


def emit_event(event: LogEvent) -> None:
    data = event.to_dict(redact=True)
    for sink in _sinks:
        sink(data)
    _default_sink(data)


class DiagnosticLogger:
    def __init__(
        self,
        component: str = COMPONENT_BACKEND,
        *,
        session_id: str = "",
        request_id: str = "",
        correlation_id: str = "",
        minimum_level: LogLevel = LogLevel.INFO,
    ) -> None:
        self.component = component
        self.session_id = session_id
        self.request_id = request_id
        self.correlation_id = correlation_id
        self.minimum_level = minimum_level

    def scoped(
        self,
        *,
        request_id: str | None = None,
        correlation_id: str | None = None,
    ) -> DiagnosticLogger:
        return DiagnosticLogger(
            component=self.component,
            session_id=self.session_id,
            request_id=request_id or self.request_id,
            correlation_id=correlation_id or self.correlation_id,
            minimum_level=self.minimum_level,
        )

    def with_correlation(self, correlation_id: str) -> DiagnosticLogger:
        return DiagnosticLogger(
            component=self.component,
            session_id=self.session_id,
            request_id=self.request_id,
            correlation_id=correlation_id,
            minimum_level=self.minimum_level,
        )

    def _log(self, level: LogLevel, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        if not is_level_enabled(level, self.minimum_level):
            return
        log_event = LogEvent(
            level=level,
            component=self.component,
            event=event,
            message=message,
            session_id=self.session_id,
            request_id=self.request_id,
            correlation_id=self.correlation_id,
            context=context or {},
        )
        emit_event(log_event)

    def trace(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.TRACE, event, message, context)

    def debug(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.DEBUG, event, message, context)

    def info(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.INFO, event, message, context)

    def warn(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.WARN, event, message, context)

    def error(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.ERROR, event, message, context)

    def fatal(self, event: str, message: str, context: dict[str, Any] | None = None) -> None:
        self._log(LogLevel.FATAL, event, message, context)


def create_component_logger(component: str, *, session_id: str = "") -> DiagnosticLogger:
    return DiagnosticLogger(component=component, session_id=session_id)
