## Context

Advisor review of the first build, plus Codex review. The saved logs of KeepThat repeat the same startup block each login, so a "last match of the 3-line tail" lands in the wrong block after reload.

## Decisions

- Boundary: prefer the position equal to the snapshot length if the tail matches there (nothing rolled); else accept a single match; else ambiguous, unverified.
- Evidence label: computed from required assertion count, not from "no failures".
- Absence needs a non-empty window, so debug-off cannot pass it.
- Secure button: parent UIParent, anchored to the card (unprotected anchor target), shown and hidden only out of combat; alpha used in combat.
- Screenshots: player presses Print Screen; time-window match by file mtime; no in-game capture API is called. Default folder is `Screenshots` beside the WTF folder, or `--shots`.
- Classic Era per-character saved variables: the parent copy script uses SharedOnly for Era, so per-character logs (ClosestVendorCharDB) are not copied. Left unchanged; `collect --src` takes the real WTF folder.

## Non-Goals

- Editing the shared copy script; promoting diagnostic assertions; live-client verification.
