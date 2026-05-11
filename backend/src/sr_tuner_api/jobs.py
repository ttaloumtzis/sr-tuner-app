from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Literal

from pydantic import BaseModel, Field

from .errors import ApiError
from .ids import new_id


JobStatus = Literal["queued", "running", "canceling", "canceled", "completed", "failed"]


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class JobError(BaseModel):
    code: str
    message: str
    recoverable: bool = True


class Job(BaseModel):
    id: str = Field(default_factory=lambda: new_id("job"))
    type: str
    project_id: str | None = None
    object_id: str | None = None
    status: JobStatus = "queued"
    progress: float = 0.0
    logs: list[str] = Field(default_factory=list)
    created_at: str = Field(default_factory=utc_now_iso)
    started_at: str | None = None
    finished_at: str | None = None
    cancel_requested: bool = False
    retained_partial_artifacts: bool | None = None
    error: JobError | None = None


class CreateJobRequest(BaseModel):
    type: str
    project_id: str | None = None
    object_id: str | None = None


class JobLogResponse(BaseModel):
    job_id: str
    logs: list[str]


class JobStore:
    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}
        self._lock = Lock()

    def create(self, request: CreateJobRequest) -> Job:
        job = Job(type=request.type, project_id=request.project_id, object_id=request.object_id)
        with self._lock:
            self._jobs[job.id] = job
        return job

    def put(self, job: Job) -> Job:
        with self._lock:
            self._jobs[job.id] = job
        return job

    def get(self, job_id: str) -> Job:
        with self._lock:
            job = self._jobs.get(job_id)
        if job is None:
            raise ApiError(404, "job_not_found", "Job was not found.", details={"job_id": job_id})
        return job

    def cancel(self, job_id: str) -> Job:
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None:
                raise ApiError(404, "job_not_found", "Job was not found.", details={"job_id": job_id})
            if job.status in ("completed", "failed", "canceled"):
                return job
            job.status = "canceling"
            job.cancel_requested = True
            job.logs = [*job.logs[-49:], "Cancellation requested."]
        return job

    def log_tail(self, job_id: str, limit: int = 50) -> JobLogResponse:
        job = self.get(job_id)
        return JobLogResponse(job_id=job.id, logs=job.logs[-limit:])


job_store = JobStore()
