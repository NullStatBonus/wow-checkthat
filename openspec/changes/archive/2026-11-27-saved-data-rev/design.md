## Decisions

- **Revision 0 means "before the stamp".** It has the same shape as revision 1, so the first load only writes the number. A test checks that nothing else changes.
- **Not an AceDB default.** AceDB removes saved values that equal their defaults when it saves, so a default of `dbRev = 1` would never reach disk. `App.Migrate` writes it.
- **Never lower a newer revision.** An older CheckThat after a downgrade reads what it can, as it already does for runs from a newer version (`App.SplitFuture`), and leaves the number alone. The next load of the newer version then sees its own revision.
- **One step per revision.** `MIGRATIONS[n]` takes revision n - 1 to n, and `dbRev` is written after each step. A failure part way through leaves the last revision that completed.

## Non-Goals

- Any real migration. There is none yet.
