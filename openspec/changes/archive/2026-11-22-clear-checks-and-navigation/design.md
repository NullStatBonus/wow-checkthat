## Decisions

- Banner colors: green for TestThat checks, gold for the tester confirms. Icons are the stock ReadyCheck textures (Ready, Waiting, NotReady), so no art is shipped.
- Live check loop: a half-second timer started when the card shows and stopped when it hides; it re-reads logs read-only through Run.Preview.
- Navigation moves `run.current`; verdict advance uses NextPending (after the step, then wrapping).
- A finished step has no open attempt, so viewing it records nothing; Redo calls Begin.

## Non-Goals

- Editing an earlier step's note; per-step undo (Undo stays last-result).
