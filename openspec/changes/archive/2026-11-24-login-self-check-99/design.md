# Design

## Context

See proposal.md. Facts record only while a run is open, so the result cannot be a fact (the open question in #99).

## Goals / Non-Goals

**Goals:** one opt-in line at login.

**Non-Goals:** a slash command to run it on demand; results saved between sessions; mocks (#98).

## Decisions

- **Result lives in chat and the debug log.** No run, no saved state.
- **Reuse the step's own log checks** against the outcome line, so one plan serves the run and the self-check.
- **Takes effect at next login**, said on the settings page.

## Risks / Trade-offs

- Runs addon code at every login for players who turn it on. Off by default; help text says so. Taint is unmeasured (#98).
