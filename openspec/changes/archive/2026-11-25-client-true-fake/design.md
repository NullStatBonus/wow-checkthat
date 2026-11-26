# Design

## Context

The census from #146 records each client's game-defined names. The raw manifests also hold the tester's addon list and the globals addons set, so they stay local. Offline levels 1 to 4 decide by hand which APIs exist.

## Goals / Non-Goals

**Goals:** a fake client that has exactly the functions, `C_` functions and widget methods of one client, opt-in so that existing plans and tests keep their results.

**Non-Goals:**
- Template methods and child keys (#169). A frame from a template takes any method.
- Running a block on both clients and reporting each, and a `--client` flag (#170). Making that the default would change existing plans' results.
- What a function returns. A stub returns nothing; the hand-written behaviour stays where the fake client already models it.
- Types without a census list (`AnimationGroup`, `Line`, `MaskTexture` and others) take any method.

## Decisions

### D1. A reviewed slice, not the manifest

`tools/client_slice.py` keeps the global names of type `function`, the function members of `C_` tables and the widget method lists. It leaves out every other table, because both censuses say `unfiltered`, so a table may hold members an addon wrote. A function the census filed as set by addon code is kept when Blizzard's source names it: an addon replaced a real function in the census session (3 on Era, 8 on Forever). The user reviewed the slice and the lists of names the published source does not name, and approved all of them. The output has one name per line, so a later build diffs cleanly.

### D2. Absent becomes nil, present but not modelled becomes a stub

Every global function the client lacks is removed, also one an earlier fake client in the same process left. Lua's base functions stay, except the five the game lacks too: `dofile`, `load`, `loadfile`, `module` and `require`. The harness keeps its own `loadfile`. A listed function the fake client does not model returns nothing (`st.generated` names them), so the Adapter takes the "present" path, as in the game. A Lua alias (`strsub`, `tinsert`, `mod`, `floor`) is the Lua function, because addons depend on its result. The trig functions work in degrees, as the game's do. Plain helpers the game defines in Lua get a working version: `Mixin`, `CreateFromMixins`, `CopyTable`, `tContains`, `strtrim`, `strjoin`, `tostringall`, `date`, `debugstack`, `GetTimePreciseSec` and `debugprofilestop`. A `C_` table is rebuilt as a new table, so one an earlier fake client made is not changed and `H.snapshot` puts it back as it was.

### D3. Frames

A frame records its widget type (`CreateFrame`'s first argument, `FontString` for `CreateFontString`, `Texture` for `CreateTexture`). With a surface, a frame of a listed type without a template reads nil for any name its type lacks. The type is matched without regard to case, as `CreateFrame("frame")` works in the game. Objects other calls return (`GetParent`, `GetNormalTexture`, `CreateAnimationGroup`) take any method. Raw fields (`scripts`, `events`, the runner's `RegisterEvent`) are unaffected.

### D4. Level 5 and mocks

Level 5 picks the surface by the TOC's interface, as level 4 picks the event list. A mock of a function the surface lacks fails the load step: it would hide exactly the gap level 5 exists to show.

### D5. The slice tool's safeguards

`tools/client_slice.py` refuses a manifest marked `unfiltered` unless `--unfiltered-ok` says its review lists were read, and `--review FILE` writes them. `ct.py census` now writes `unfiltered: true` into such a manifest, an added key. An addon-replaced function is kept only when Blizzard's source calls, assigns or documents it, not when it merely names it. Both committed slices regenerate byte for byte.

## Risks / Trade-offs

- A slice is one build. A rebuilt census needs a new slice and a new review.
- A stub that returns nothing can send code down a "no data" path the game does not take. The nil-read report no longer lists such names.
