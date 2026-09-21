# ADR 0003 — BusyBox init with explicit early/late boot classes

Status: Accepted

## Context

Zlyme has a small, appliance-like service graph and optimizes for time to first frontend frame.

## Decision

Use BusyBox init.

Keep frontend-critical boot work in the early path and start independent optional services asynchronously after the frontend first-frame gate.

## Consequences

Boot is simple and fast.

Dependencies must be explicit because BusyBox init does not provide systemd-style dependency graphs.

Do not compensate with arbitrary sleeps. Use real readiness conditions.
