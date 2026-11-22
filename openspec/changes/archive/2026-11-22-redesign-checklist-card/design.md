## Context

Codex design review of the first live run. Stock Blizzard fonts only; pure black fill; text opacity independent.

## Decisions

- Fonts: GameFontHighlightLarge for the step title, GameFontHighlight (#DDDDDD) for Do and Expect, GameFontHighlightSmall (#AAAAAA) for header, labels and hints. Amber is for missing evidence only.
- Sizes: card 380 wide, 12 unit insets, 62 unit label column, copy boxes 226 wide, buttons 24 high (Pass, Fail, Skip 64 wide, Undo 56).
- Progress: 3 unit bar, filled by resolved steps.
- Mini mode: 280 wide strip.
- The secure Run all button stays a separate top-level frame.

## Non-Goals

- Keybindings for verdicts (suggested by Codex; deferred, optional); layout screenshots (needs a live client).
