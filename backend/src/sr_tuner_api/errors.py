from __future__ import annotations

from typing import Any

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


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


async def api_error_handler(_request: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content=error_payload(**exc.detail))


async def http_error_handler(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
    detail = exc.detail
    if isinstance(detail, dict) and {"code", "message"}.issubset(detail):
        return JSONResponse(status_code=exc.status_code, content=error_payload(**detail))
    return JSONResponse(
        status_code=exc.status_code,
        content=error_payload(
            "http_error",
            str(detail),
            recoverable=exc.status_code < 500,
        ),
    )


async def validation_error_handler(
    _request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content=error_payload(
            "validation_error",
            "Request validation failed.",
            details={"errors": exc.errors()},
            recoverable=True,
        ),
    )
