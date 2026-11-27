# Proposal

## Why

Issue #229: when a step gets its result, the card moves on silently. A tester watching the game does not notice that CheckThat passed a step by itself, failed it, or left it unverified, so the card seems to skip ahead. 1.0 should give each result a short cue that is never mistaken for a game sound.

## What Changes

- CheckThat ships five short sounds of its own, generated from a script and committed as `.ogg` files under `CheckThat/Media/Sounds/`:
  - `tick`: a soft blip, for a result the player recorded (Pass, Partial, Fail, Skip).
  - `chime-up`: two rising notes, for a pass CheckThat recorded by itself (one cue for a batch of passes at run start).
  - `chime-down`: two falling notes, for a fail CheckThat recorded by itself.
  - `attention`: two same-pitch blips, for an unverified result (an automatic step at its timeout, or Pass without the evidence).
  - `finish`: a three-note arpeggio, when the last step of the run gets its result.
- One cue at a time: when several results land together, the most important plays once (attention, then chime-down, then chime-up, then tick; finish follows the last).
- Sounds play on the game's SFX channel, also while the card is hidden or collapsed.
- New setting **Play result sounds** (Appearance, on by default), also as `/ct set card.sound on|off`, shown in the debug report.
- A debug log line for each sound played: `sound <name> for <step id>`.
- A developer command `/ct sound <name>` plays one sound, so a tester can learn them before a run.
- A new in-game plan, `plans/sounds.yaml`, produces every result on purpose and checks each sound from the log, with a player check that it was heard. It is replayed in the fake client before a tester runs it.

## Capabilities

### New Capabilities
- `result-sounds`: which result plays which sound, when it plays, the setting, the preview command and the log line.

### Modified Capabilities
- `addon-settings`: Appearance gains the Play result sounds checkbox and the `card.sound` key.

## Impact

`CheckThat/UI/Card.lua` (the cue from `Card.Settled` and run completion), `CheckThat/Core/Adapter.lua` (`PlaySoundFile`, guarded), `CheckThat/Core/Defaults.lua`, `CheckThat/Core/Settings.lua`, `CheckThat/Options/Options.lua`, `CheckThat/Core/Slash.lua`, `CheckThat/Debug/Log.lua`, `CheckThat/Media/Sounds/` (new), `tools/make_sounds.py` (new, needs `soundfile` only to regenerate), `plans/sounds.yaml` (new), tests, README, `docs/features.md`, `docs/test-plan.md`, `docs/listing.md`. Packaging size grows by the five files (under 20 KB each). The version bump follows the release hold.
