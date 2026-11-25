# Design

## D1. Text, not a tool

The sorting needs judgment (is this pattern too strict, or did the addon change?), so the skill carries the rules and the author decides when it cannot tell. `ct.py show` and `report` already give the evidence (rule, hits, excerpt, stacks).

## D2. Rerun or reimport

`/ct rerun failed` works inside one run, which belongs to one plan digest. An edited plan has a new digest and needs a new import and run, so the skill says which case applies.

## Non-Goals

- A command that classifies faults by itself.
- Editing addon code.
