from __future__ import annotations

import time
import uuid
from typing import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from . import logging_schema as schema
from .diagnostic_logger import DiagnosticLogger

_logger = DiagnosticLogger(component=schema.COMPONENT_API)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        request_id = str(uuid.uuid4())
        correlation_id = request.headers.get("x-correlation-id", "")
        if not correlation_id:
            correlation_id = str(uuid.uuid4())
            _logger.info(
                schema.EventNames.CORRELATION_FALLBACK,
                "Generated fallback correlation ID for inbound request.",
                context={"path": request.url.path, "method": request.method, "fallback_correlation_id": correlation_id},
            )

        scoped = _logger.scoped(request_id=request_id, correlation_id=correlation_id)

        scoped.info(
            schema.EventNames.REQUEST_INGRESS,
            f"{request.method} {request.url.path}",
            context={"path": request.url.path, "method": request.method, "query": str(request.url.query)},
        )

        start = time.monotonic()
        try:
            response = await call_next(request)
            elapsed = time.monotonic() - start
            scoped.info(
                schema.EventNames.REQUEST_COMPLETE,
                f"{request.method} {request.url.path} -> {response.status_code}",
                context={
                    "path": request.url.path,
                    "method": request.method,
                    "status_code": response.status_code,
                    "elapsed_seconds": round(elapsed, 4),
                },
            )
            response.headers["x-request-id"] = request_id
            if correlation_id:
                response.headers["x-correlation-id"] = correlation_id
            return response
        except Exception as exc:
            elapsed = time.monotonic() - start
            scoped.error(
                schema.EventNames.REQUEST_SERVICE_ERROR,
                f"{request.method} {request.url.path} failed: {exc}",
                context={
                    "path": request.url.path,
                    "method": request.method,
                    "elapsed_seconds": round(elapsed, 4),
                    "error_type": type(exc).__name__,
                },
            )
            raise
