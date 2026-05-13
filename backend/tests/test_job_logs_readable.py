"""Tests proving user-facing job log tails remain concise while diagnostic job events remain structured."""
from __future__ import annotations

from sr_tuner_api.jobs import Job, job_store, CreateJobRequest


def test_job_logs_are_concise_text() -> None:
    job = job_store.create(CreateJobRequest(type="test_readable"))
    job.logs.append("Epoch 1/10 complete.")
    job.logs.append("Epoch 2/10 complete.")
    job.logs.append("Inference finished in 5.2s. 10/10 succeeded.")
    job_store.put(job)

    tail = job_store.log_tail(job.id)
    for line in tail.logs:
        assert isinstance(line, str)
        assert not line.startswith("{")
        assert not line.startswith("sr.")


def test_job_logs_are_bounded() -> None:
    job = job_store.create(CreateJobRequest(type="test_bounded"))
    for i in range(100):
        job.logs.append(f"Log line {i}")
    job_store.put(job)

    tail = job_store.log_tail(job.id)
    assert len(tail.logs) <= 50


def test_job_logs_coexist_with_diagnostic_events() -> None:
    job = job_store.create(CreateJobRequest(type="test_coexist"))
    job.logs.append("Epoch 5/10 complete.")
    job.status = "running"
    job_store.put(job)
    job.status = "completed"
    job.logs.append("Training completed in 30.0s.")
    job_store.put(job)

    final = job_store.get(job.id)
    assert "Epoch 5/10 complete." in final.logs
    assert "Training completed in 30.0s." in final.logs
    assert final.status == "completed"
