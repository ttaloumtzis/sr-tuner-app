from __future__ import annotations

from typing import Any

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .cause_codes import CauseCodes
from .diagnostic_logger import create_component_logger
from . import logging_schema as log_schema

_log = create_component_logger(log_schema.COMPONENT_API)


class ApiError(HTTPException):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        *,
        details: dict[str, Any] | None = None,
        recoverable: bool = True,
    ) -> None:
        super().__init__(
            status_code=status_code,
            detail={
                "code": code,
                "message": message,
                "details": details or {},
                "recoverable": recoverable,
            },
        )


def error_payload(
    code: str,
    message: str,
    *,
    details: dict[str, Any] | None = None,
    recoverable: bool = True,
) -> dict[str, Any]:
    return {
        "error": {
            "code": code,
            "message": message,
            "details": details or {},
            "recoverable": recoverable,
        }
    }


def _correlation_id(request: Request) -> str:
    return request.headers.get("x-correlation-id", "")


def _enrich_with_correlation(payload: dict[str, Any], request: Request) -> dict[str, Any]:
    cid = _correlation_id(request)
    if cid:
        payload["error"]["correlation_id"] = cid
    return payload


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    payload = error_payload(**exc.detail)
    payload = _enrich_with_correlation(payload, request)
    cid = _correlation_id(request)
    _log.error(
        log_schema.EventNames.REQUEST_SERVICE_ERROR,
        f"ApiError: {exc.detail.get('code', 'unknown')} - {exc.detail.get('message', '')}",
        context={"status_code": exc.status_code, "code": exc.detail.get("code"), "correlation_id": cid or None},
    )
    return JSONResponse(status_code=exc.status_code, content=payload)


async def http_error_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    detail = exc.detail
    if isinstance(detail, dict) and {"code", "message"}.issubset(detail):
        payload = error_payload(**detail)
    else:
        payload = error_payload(
            "http_error",
            str(detail),
            recoverable=exc.status_code < 500,
        )
    payload = _enrich_with_correlation(payload, request)
    cid = _correlation_id(request)
    _log.error(
        log_schema.EventNames.REQUEST_SERVICE_ERROR,
        f"HTTP error {exc.status_code}: {str(detail)[:200]}",
        context={"status_code": exc.status_code, "correlation_id": cid or None},
    )
    return JSONResponse(status_code=exc.status_code, content=payload)


def _clean_validation_errors(errors: list[Any]) -> list[dict[str, Any]]:
    cleaned: list[dict[str, Any]] = []
    for err in errors:
        entry: dict[str, Any] = {"loc": list(err.get("loc", [])), "msg": str(err.get("msg", "")), "type": str(err.get("type", ""))}
        ctx = err.get("ctx")
        if ctx is not None:
            entry["ctx"] = {k: str(v) if not isinstance(v, (str, int, float, bool, type(None))) else v for k, v in ctx.items()}
        cleaned.append(entry)
    return cleaned


async def validation_error_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    payload = error_payload(
        "validation_error",
        "Request validation failed.",
        details={"errors": _clean_validation_errors(exc.errors())},
        recoverable=True,
    )
    payload = _enrich_with_correlation(payload, request)
    cid = _correlation_id(request)
    _log.warn(
        log_schema.EventNames.REQUEST_VALIDATION_FAILURE,
        "Request validation failed.",
        context={"correlation_id": cid or None, "error_count": len(exc.errors())},
    )
    return JSONResponse(status_code=422, content=payload)
