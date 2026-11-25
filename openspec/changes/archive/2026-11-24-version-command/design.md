## Context

`ns.version` already holds the TOC version (`Adapter.Version`). Facts need an open run, and a plan reads them from the `facts` log.

## Goals / Non-Goals

**Goals:**
- A plan checks the loaded version with no debug log.

**Non-Goals:**
- Checking the version of another addon.
- Stopping a deploy of two checkouts to one folder (a script outside this repository).

## Decisions

1. **Number, not text.** A fact value is a number or a string, and the only ordered operators are `ge` and `le` on numbers. `major*10000 + minor*100 + patch` keeps 0.17.0 at 1700 and orders versions. An unknown version reports no fact.
2. **Prints always, reports when a run is open.** `Facts.Report` refuses without a run. The chat line still shows.
