# ADR 0004 — Board implementations behind narrow Zlyme contracts

Status: Accepted

## Context

The current implementation has several Miyoo Flip assumptions in otherwise global locations: Linux/U-Boot hooks, NextUI platform selection, update prefix/DTB checks, and RK817-specific helpers.

## Decision

Use three boundaries:

1. Build-time board directory and board make integration.
2. Immutable runtime device metadata.
3. Stable semantic runtime commands for hardware policy.

Examples of semantic commands include `zlyme-audio`, `zlyme-governor`, and `zlyme-led`.

## Consequences

Generic code does not need to understand RK817, VOP2, DMC, GPIO, or other board details.

Future devices can replace implementations without changing callers.

We avoid designing a plugin framework beyond these narrow contracts until a second device exists.
