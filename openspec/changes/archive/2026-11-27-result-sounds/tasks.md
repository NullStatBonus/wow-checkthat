# Tasks

## 1. Sounds

- [x] 1.1 `tools/make_sounds.py`: generate `tick`, `chime-up`, `chime-down`, `attention` and `finish` (sine notes, short attack and decay, 44.1 kHz mono, level-matched) as `.ogg` into `CheckThat/Media/Sounds/`; commit the files. Needs `soundfile` only to regenerate (documented in the script).
- [x] 1.2 Test (Python): each file exists, decodes, lasts 80 to 450 ms and is under 20 KB.

## 2. Player and hooks

- [x] 2.1 `Adapter.PlaySoundFile(path, channel)`: guarded, `pcall`, nil when missing.
- [x] 2.2 `UI/Sound.lua` (both TOCs, same order): cue map, `Sound.Cue(name, stepId)`, setting check, log line `sound <name> for <step id>`.
- [x] 2.3 `Card.Settled`: cue on every path, including unverified and a hidden or collapsed card; `finish` when no open step remains. Remove the `Card.ResultCue` stub from `Card.Hold`.
- [x] 2.4 `App.JudgeAtStart` passes: one `chime-up` for the batch.
- [x] 2.5 Unit tests with a stubbed `PlaySoundFile`: each path once; batch once; finish on the last result; hidden card plays; setting off plays and logs nothing; missing `PlaySoundFile` raises nothing. Break each behavior once and see its test fail.

## 3. Setting and command

- [x] 3.1 `profile.card.sound = true`; Appearance checkbox "Play result sounds"; `card.sound` in `Settings.lua` (`/ct set`, `/ct get`); `sound=on|off` in the debug report. Tests in `test_options.lua`, `test_settings.lua`, `test_log.lua`.
- [x] 3.2 `/ct sound <name>`: plays one sound, logs `sound <name> for preview`; an unknown name lists the five. Test in `test_slash.lua`.

## 4. In-game plan

- [x] 4.1 `plans/sounds.yaml` from the outline in design.md (version step first; one result per step; a heard step after each with a run-scoped log assertion and one player question). Validate and compile in `make build`.
- [x] 4.2 `tests/replay/sounds.lua` hooks; replay the plan in the fake client (`tests/test_replay.lua`).
- [x] 4.3 Review the plan (one agent review) and fix every finding before a tester runs it.

## 5. Docs

- [x] 5.1 README (feature line, setting, `/ct sound` in the developer table), `docs/features.md` (cue map and log line), `docs/listing.md`, `docs/test-plan.md` (one check per sound, pointing at the plan), `docs/contracts.md` (Pending in-game: `.ogg` on both clients).
- [x] 5.2 `make test` and `make check`.

## Workflow follow-up

- Run `plans/sounds.yaml` on Era and Forever; read the saved variables; record `.ogg` playback per client in `docs/contracts.md`.
- Archive the change; the version bump follows the release hold.
