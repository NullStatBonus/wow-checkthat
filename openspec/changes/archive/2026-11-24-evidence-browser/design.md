# Design

## Context

`ct.py` is the non-interactive core. The viewer sits beside it and reads through the same functions (`latest_runs`, `classify`, `run_model`, `stack_hits`, `status_data`). Codex reviewed the layout.

## Goals / Non-Goals

**Goals:**
- Browse runs, steps and attempts in a terminal; follow the folder; export from it.

**Non-Goals:**
- Collecting from the viewer: it shows the command and the CLI stays the one place.
- Editing evidence or plans.

## Decisions

1. **Plain functions first.** Sorting, filtering, detail text, export and the reload rule live in `ct_tui.py` without Textual. Only `make_app` imports Textual, so the logic is tested without it.
2. **Optional dependency.** `requirements-tui.txt` is a separate file. The viewer checks for a terminal before it imports Textual, and prints the CLI commands when there is none or when Textual is missing.
3. **Reload.** The viewer compares file times and sizes of the run files, the error files and `problems.log` every two seconds. A change reloads after it has held for one more poll, so a write can finish. `latest_runs` keeps the newest readable revision. The cursor stays on the same id.
4. **Text only.** Evidence shows as plain text, never as markup. A detail is cut at 400 lines.
5. **Export asks first.** The dialog shows scope, format, file and whether stacks are in, then writes on Enter. Markdown always has stacks, as `REPORT.md` does; JSON and JUnit leave them out until asked.
6. **Bundle.** `tools/ct_tui.py` and `requirements-tui.txt` join `BUNDLE`. The installed copy runs without Textual.

## Risks / Trade-offs

- [Textual changes its API] → the optional tests drive the real screens, and the logic does not depend on it.
- [`status_data` reads every revision on a reload] → a reload happens only after a change.
