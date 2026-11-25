# Design

## D1. Bundle the addon folder

The harness loads `CheckThat/*.lua` relative to the working folder. The bundle therefore copies the whole `CheckThat/` folder (about 1 MB with libraries) and runs the Lua tools with the bundle root as the working folder (`cwd=ROOT` in `ct.py`). Every plan path is made absolute first. A bundle test installs into a temp folder and runs the tools from another folder.

## D2. Derive the evidence, and say so

For a step's log assertion with a literal line, a pattern or a sequence, the replay writes a line into the plan's own log source (`global`, `path`, `format`). A pattern becomes the shortest string it matches (`Replay.sample`); a pattern with a back-reference or frontier has none and is reported, not guessed. The replay always warns "evidence assumed" when it wrote a line, so a pass is never read as proof that the addon logs it.

## D3. Check the lines against the source

`ct.py lines` takes the longest plain part of each asserted line. A line shaped `[tag] message` is two strings in the code, so it needs the tag in quotes and the message or any word of four letters of it. A miss is a warning, not a failure, unless `--strict`.

## D4. Launcher

`tools/ct` is a shell script that picks the skill's private Python, then a checkout `.venv`, then `python3`. `BIN_DIR` is opt-in because it writes outside the skill folder.

## D5. Step ids

`validate` has no history, so the rename check lives in `diff`: it compares the stored plans of both runs with the id left out of each step's fingerprint.

## Non-Goals

- #105, #131, #133, #132 (see the proposal).
- A replay that proves the addon writes a line. Only the game, the offline block or `replay --sv` proves that.
