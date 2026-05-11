from __future__ import annotations

import os
from secrets import compare_digest

from fastapi import Header

from .errors import ApiError


TOKEN_ENV = "SR_TUNER_SESSION_TOKEN"


def expected_session_token() -> str | None:
    token = os.environ.get(TOKEN_ENV, "").strip()
    return token or None


def require_session_token(x_sr_tuner_token: str | None = Header(default=None)) -> None:
    expected = expected_session_token()
    if expected is None:
        raise ApiError(
            403,
            "session_token_unavailable",
            "This backend was not launched with a project mutation session token.",
            recoverable=True,
        )
    if x_sr_tuner_token is None or not compare_digest(x_sr_tuner_token, expected):
        raise ApiError(
            401,
            "invalid_session_token",
            "Missing or invalid local API session token.",
            recoverable=True,
        )
