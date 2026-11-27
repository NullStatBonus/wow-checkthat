## Decisions

- **Own listener, not BugGrabber's list.** The events carry `addonName, addonFunc` (a macro event carries the function only), so CheckThat needs nothing from BugGrabber to record them. The listener is the same on every install.
- **No stack from BugGrabber.** The issue suggested taking BugGrabber's stack for these entries. BugGrabber records the stack at event dispatch, which is no deeper than CheckThat's own event handler would see, so it adds nothing a plan can use. Left out.
- **Attribution from the payload.** The addon is the name the game gave, not one read from a file path, so these lines never get `?`. Taint can name another addon than the one whose code ran, and the docs say so.
- **Quiet source, like errors.** Silence is the pass for an absence check. A plan opts in by naming the source, and nothing changes for plans that do not.

## Non-Goals

- An in-game probe that triggers a blocked action on demand. A player cannot do that safely, so the listener is covered through AceEvent in the smoke test, and the first real sighting goes in `docs/contracts.md`.
