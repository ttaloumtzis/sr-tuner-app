from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Literal

from pydantic import BaseModel, Field

from .diagnostic_logger import create_component_logger
from .errors import ApiError
from .ids import new_id
from . import logging_schema as log_schema

_log = create_component_logger(log_schema.COMPONENT_JOB)


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
        _log.info(log_schema.EventNames.JOB_QUEUED, f"Job {job.id} created.", context={
            "job_id": job.id, "type": job.type, "project_id": job.project_id,
        })
        return job

    def put(self, job: Job) -> Job:
        prev_status = self._jobs[job.id].status if job.id in self._jobs else None
        with self._lock:
            self._jobs[job.id] = job
        if prev_status != job.status and job.status != "queued":
            event = {
                "running": log_schema.EventNames.JOB_RUNNING,
                "canceling": log_schema.EventNames.JOB_CANCELING,
                "canceled": log_schema.EventNames.JOB_CANCELED,
                "completed": log_schema.EventNames.JOB_COMPLETED,
                "failed": log_schema.EventNames.JOB_FAILED,
            }.get(job.status)
            if event:
                _log.info(event, f"Job {job.id} -> {job.status}", context={
                    "job_id": job.id, "status": job.status, "progress": job.progress,
                    "type": job.type, "prev_status": prev_status,
                })
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
        _log.info(log_schema.EventNames.JOB_CANCELING, f"Job {job.id} cancel requested.", context={
            "job_id": job.id, "type": job.type,
        })
        return job

    def log_tail(self, job_id: str, limit: int = 50) -> JobLogResponse:
        job = self.get(job_id)
        return JobLogResponse(job_id=job.id, logs=job.logs[-limit:])


job_store = JobStore()
