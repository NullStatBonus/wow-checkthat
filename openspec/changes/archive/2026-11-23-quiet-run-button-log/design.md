# Design

## Context

`Card.EnsureSecure` hooks `OnShow` on the Run button. The button has a state driver (`[combat] hide; show`). Out of combat the driver shows the button again after each hide, about five times a second (measured in a saved run). The hook hides it and logged every time.

## Goals / Non-Goals

**Goals:**
- One log line for each screen where the game shows the button and CheckThat hides it.

**Non-Goals:**
- Stopping the game from showing the button. The hide stays as the guard; changing the driver cannot be tested without a client.

## Decisions

1. **Remember the last logged text.** The hook keeps `card.hiddenLogged` and skips a line equal to it. `setMacro` clears it when the button is wanted, so the next hide logs again. Alternative: a time throttle. Rejected: a timer makes the test depend on time and still logs a line each interval.

## Risks / Trade-offs

- [The same screen shown again later logs nothing new] → accepted; the line says the guard works, and one line per screen is enough.
