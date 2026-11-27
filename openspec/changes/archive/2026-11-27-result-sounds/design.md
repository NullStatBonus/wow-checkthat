# Design

## Context

`Card.Settled(step, verdict, by)` is the one place both result paths meet: `Card.Verdict` (buttons, keys, `/ct pass`) and `Card.AutoSettle` (automatic steps). Today it returns early for `unverified` and only calls `Card.Hold`, whose empty `Card.ResultCue` stub runs only when the card is shown, expanded and the run moved on. Run completion has no hook; the card just draws "Run complete". Async steps that pass at run start are judged in `App.JudgeAtStart` and never reach `Card.Settled`. CheckThat plays no sound today. `PlaySoundFile` exists on Era and Forever (census).

## Goals / Non-Goals

**Goals:**
- One cue per result moment, on every path, whether the card is shown, hidden or collapsed.
- Sounds that cannot be mistaken for game sounds, short and level.
- Every cue provable from the debug log, so the sounds plan and `ct-verify` can check them.

**Non-Goals:**
- Per-result volume or choice of sounds. The game's SFX volume applies.
- Sounds for anything other than step results and run completion (errors, blocked actions, imports).
- A sound pack format or LibSharedMedia registration.

## Decisions

- **Packaged tones, not `SOUNDKIT`.** Stock sounds (quest complete, ready check, whisper) mean something in the game, and the tester is playing the game. Generated tones are CheckThat's alone, 80 to 450 ms, at one loudness. Alternative considered: stock kits 856/878/846/3081/8960, which exist on both clients but are uneven in length and ambiguous.
- **Generated, committed.** `tools/make_sounds.py` writes the five `.ogg` files from note lists (sine plus a short attack and decay envelope, 44.1 kHz mono). It needs `soundfile` only to regenerate; the files are committed, so `make test`, `make check` and packaging need nothing new. A test checks that each sound the code names exists and is under 20 KB.
- **One player module.** `UI/Sound.lua` owns the map from cue to file and `Sound.Cue(name, stepId)`: it checks the setting, calls `Adapter.PlaySoundFile(path, "SFX")` (guarded, `pcall`, nil when missing) and logs `sound <name> for <step id>`. The path is built from the addon folder name the TOC loads under.
- **Hook in `Card.Settled`, not `Card.Hold`.** `Card.Settled` gains the unverified case and always cues; `Card.Hold` keeps only the visual pause. Mapping: `by == "player"` and a final verdict: tick. `by == "auto"`: pass chime-up, fail chime-down. Unverified from either path: attention.
- **One cue per result, one for the start batch.** Results reach `Card.Settled` one at a time, so each plays at once. The only moment with several results is the run start: `App.JudgeAtStart` calls `App.OnStartPasses(n, firstId)` once, and one chime-up plays for the batch. A per-frame queue was dropped: it needed a timer for every result, and a result is never followed by another in the same frame.
- **Finish replaces the last cue.** When a result leaves the run with no open step, `finish` plays instead of that result's cue (one sound, not two). An unverified last step is not finished, so it plays attention.
- **Setting.** `profile.card.sound = true`, a checkbox in Appearance ("Play result sounds"), the key `card.sound` for `/ct set`, and `sound=on|off` in the debug report. Off plays nothing and logs nothing.
- **Preview command.** `/ct sound <name>` plays one sound regardless of a run and logs `sound <name> for preview`. It is a developer command (not stable), listed in the README's developer table.

## Testing approach

Unit tests (harness, stubbed `PlaySoundFile`): each path plays its cue once; the setting off plays none; a missing `PlaySoundFile` raises nothing; a batch plays once; the last result plays finish; a hidden or collapsed card still plays.

In-game plan `plans/sounds.yaml` (addon CheckThat), one result on purpose per step, each followed by a short "heard it" step that checks the log with a run-scoped assertion (`sound <name> for <step id>`) and asks the player one question. Outline:

```
snd.version        version fact (first step)              -> chime-up
snd.start/start2   two async steps                        -> one chime-up at run start
snd.auto           /ct fact                               -> chime-up
snd.hidden         close the card, paste /ct fact         -> chime-up, no card hold logged
snd.partial        press Partial                          -> tick
snd.failpress      press Fail                             -> tick
snd.slashpass      /ct pass                               -> tick (the chat path)
snd.fail           Run reports hit twice, count max 1     -> chime-down at once
snd.timeout        nothing comes, timeout 15, then Skip   -> attention, then tick
snd.nopass         Pass without evidence, then Skip       -> attention, then tick
snd.off            Run: /ct set card.sound off, /ct fact  -> silence (no sound line)
snd.silent         Run: /ct set card.sound on             -> tick on its own Pass
snd.last           Pass on the last step                  -> finish (read after the run)
```

A heard step after each group checks the run-scoped log lines and asks the player one question. `Settings.Set` logs `setting <key> = <value>`, so the plan proves sounds were turned off and on again.

The plan was reviewed by one agent; its five defects and two missing paths (Partial and Fail ticks, one chime for several start passes) were fixed. The plan gets a replay hooks file and is replayed in the fake client, and reviewed, before a tester runs it.

## Risks / Trade-offs

- [A tester with SFX muted hears nothing] -> the heard steps say to check the game's sound settings first; the log still proves the cue.
- [`.ogg` support differs by client] -> both clients play `.ogg` through `PlaySoundFile`; the first plan run on each client confirms it, and `docs/contracts.md` records the result.
- [Rapid auto passes sound busy] -> one cue per frame; the 3 s card hold already spaces automatic results.
- [Folder renamed by a packager] -> the path uses the loaded folder name, not a literal.
