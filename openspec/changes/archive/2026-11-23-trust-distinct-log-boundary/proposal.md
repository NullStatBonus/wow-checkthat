# Proposal

## Why

A run of the 0.8 plan showed that every "must not appear" check came back unverified. The debug log holds 300 lines and stays full, so every new line pushes an old one out. CheckThat then treated the boundary of every attempt as found by search and refused to show an absence. The checks can never pass on a full log.

## What Changes

- A boundary found by search is exact when the saved tail is distinctive (at least half of its lines differ). An absence check can then pass.
- A tail of one repeated line (a flood) stays inexact, so the false pass found in review stays closed.
- The plan step for the Runs to keep slider lists only `/ct status`, because the Run button runs all listed commands at once and the drag comes between them.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: the rolled-log rule applies only to a tail that cannot prove a boundary.

## Impact

- Code: `CheckThat/Model/Evidence.lua`. Tests: `tests/test_evidence.lua`. Docs: `README.md`, `CHANGELOG.md` (0.8.0, not yet released). Plan: `plans/checkthat-0.8.yaml`.
