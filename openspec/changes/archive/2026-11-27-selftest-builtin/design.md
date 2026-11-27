## Context

The design was reviewed outside the project and approved on issue #246 (2026-11-27): a pinned entry in the import window's existing dropdown.

## Decisions

- **Data file, not a build step at package time.** `.pkgmeta` packages `CheckThat/` as committed, so the string must be in the repository. `make builtin` writes `Model/BuiltIn.lua` from `build/selftest.ct`. `make build` does not write it: CI runs `make build` before the tests, so a build step that rewrote the file would hide a stale commit. The Python test compiles `plans/selftest.yaml` and compares it with the committed string.
- **Same import path.** The pinned entry passes the shipped string to `App.ImportPlan`, so validation, the digest, the stored copy and `pendingStart` behave as for a pasted string. An open run keeps its progress; the card shows Resume run beside Start run.
- **One entry.** The dropdown leaves out a recent entry whose digest is the one in the shipped string's header (`!CT1!<digest>!`). A digest with a collision suffix (`-2`) is not matched and may list twice; that needs a 32-bit checksum collision with another stored plan.
- **Generic Export code.** `Export.Prompt` still takes any choices list. Only its label changes from "Recent plans" to "Choose a plan". "No recent plans" stays for a list with no entry, which the import window no longer passes while a plan is built in.

## Non-Goals

- The self-test plan text still says to run the harvest script at the end. A CurseForge user can export the results instead. Plan wording is a separate change.
- A "Try self-test" button on the empty card. The review chose the pinned entry, which stays findable after the first import.
