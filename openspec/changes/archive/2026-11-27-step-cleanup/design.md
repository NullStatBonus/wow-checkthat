## Decisions

- **Show, not deprecate.** A step that changes state (a setting, a window) needs a way to tell the tester to undo it, and plans already carry the key.
- **Where.** A player's Pass moves the card on at once, so the text has to reach the next step. It shows there until that step has a result; a held automatic result also shows it under the result. Amber, as it asks for an action the tester could miss.
- **State.** `App.db.ui.cleanup = { run, step }`, set by every final result (cleared by a result on a step without cleanup). `App.Cleanup()` shows it only while that run is current and open and the step still has a final result, so Undo, Redo and a new run hide it.
- **No stricter checks.** The game does not reject a cleanup that is not text or holds Markdown: plans imported before stay importable, and a non-string cleanup is simply not shown. `ct.py validate` warns about Markdown instead of failing.
