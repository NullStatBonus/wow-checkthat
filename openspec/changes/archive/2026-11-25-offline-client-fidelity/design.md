# Design

## D1. Manifest format (shared by #146 and #147)

`tests/manifests/<client>-<build>.json`, where client is `era` when the interface is below 16000 and `forever` otherwise:

```json
{ "format": 1, "client": "era", "build": "1.15.9.70576", "interface": 11509, "date": "2026-11-25",
  "globals": { "CreateFrame": "function", "MenuUtil": "table", "YES": "string" },
  "tables":  { "C_AddOns": { "GetAddOnMetadata": "function" }, "MenuUtil": { "CreateContextMenu": "function" } },
  "widgets": { "Frame": ["ClearAllPoints", "SetPoint"], "FontString": ["SetText"] },
  "unavailable": ["Cooldown"] }
```

- `globals` holds the top-level names of `_G` that the game itself defines, with their Lua type: only names the game itself defines; a global last written by addon code (`issecurevariable(name)` is false) goes to `insecure` with its type and no members, so another addon's saved variables never contribute members, and a Blizzard name that an addon replaced is not lost (the log line counts them as addon names). When the client lacks `issecurevariable`, or it rejects a table, the census keeps every name and is marked `unfiltered`; only then does `ct.py` drop globals that start with a loaded addon's folder name (`addons`).
- `tables` holds members (name to type) only for API namespaces (`C_*`, `Enum`) and named public tables: a table global whose name starts with an uppercase letter and that is not a frame. One level deep. A frame is a table with a userdata in slot 0 (`rawget`, so no `__index` runs). A member key that is not a string identifier, or that another addon added (`issecurevariable(table, key)`), is skipped. A table is read up to 2000 members; a longer one is cut and its name goes to `truncated`.
- `widgets` maps each sampled widget type to the sorted method names on its metatable `__index`. `unavailable` lists the types that CreateFrame refused.

## D2. Census walk

- Pure logic in `Model/Census.lua` (no game globals; it gets `Adapter.Env()`). It steps with a budget for each frame: about 8 ms, measured with `debugprofilestop` when it exists, otherwise 250 reads. A step is one read (a key of `_G`, a type, a candidate check or one table member, capped at 2000 members for each table), and cursors (`next` with the last key, under `pcall`) carry the key snapshot, the candidate scan and each table across frames. When `next` fails because the table changed, the walk stops, keeps the stored census, logs `[census] failed names unreadable` and says "The client census could not read the game's names. The saved census is unchanged." When the client cannot schedule a timer (`Adapter.After` returns false), the walk runs in one pass and stops at combat, never staying busy. Nothing is sorted in the game (`ct.py` sorts). Each timer belongs to the walk that made it and does nothing once that walk has ended.
- The first steps snapshot the keys of `_G`, one read each. The next steps record types and members. The last step samples widgets: hidden frames with no name, parented to UIParent, plus FontString and Texture from one of them.
- It refuses to start in combat. When combat starts mid-walk, it waits and resumes on `PLAYER_REGEN_ENABLED`, or at the next tick that is out of combat.
- It writes `CheckThatDB.global.census` (one record, the newest of the client) only when the walk completes. It changes no setting and calls no game action; it creates a few hidden sample frames, which disappear at reload.
- Chat lines: start "Client census started. Wait for the completion message before you reload or log out." End "Client census complete. Type /reload or log out to save it." Busy "A client census is already running." Combat "Run /ct census after combat ends."
- Log lines: `[census] started <build>`, `[census] paused for combat`, `[census] failed names unreadable`, `[census] done <build> <n> globals <m> tables <k> widget types <a> addon` (`<a>` counts the globals other addons defined; " unfiltered" follows when the client could not tell, including a member check with no answer for a real key).

## D3. Nil-read recorder (harness)

`H.recordNilReads(prefixes, excludes)` sets an `__index` on `_G` that records string keys read as nil by a function whose source (`debug.getinfo(2, "S").source`) starts with one of the prefixes and holds none of the excludes (`/libs/` and `/libraries/`, matched without regard to case, as the game ignores case). The new metatable copies the earlier one and chains to its `__index`, so an earlier `__newindex` keeps working. `stop()` puts the earlier metatable back exactly and returns the sorted list.

## D4. Hidden globals

The runner compiles every addon file first. Then it saves and removes `io`, `os`, `jit`, `ffi`, `require`, `package`, `loadfile` and `dofile` from `_G`, runs the chunks and steps, and puts every one back with `rawset`, nil included, so an addon that assigns one (such as `ffi`) does not leak it to the host. The body runs under `xpcall`: a throw outside the entry's own `pcall` (for example bad `args`) fails the run with a step of kind `error`, and the globals and the recorder are still restored. A guard such as `if io then` therefore sees nil, and a call fails with Lua's own file and line message.

## D5. Lua 5.1 scanner

`tools/lua51_check.lua` is a module and a command line. It is a small lexer that skips comments and long strings. It reports `file:line: message` for `goto` used as a statement, for `::name::` labels, for `\x`, `\z` and `\u{` inside short strings, for a `[[` inside a level-0 long string or comment (Lua 5.1 rejects the nesting; leveled brackets such as `[=[` are fine), and for a whole numeral with an `LL`, `ULL` or `i` suffix, a hex fraction or `p` exponent, a `0b` prefix or an underscore. `\r\n`, `\n\r` and a lone `\r` count as one line end. `--globals` also catches `_G.io` and `_G["io"]`. Rejected syntax and changed meaning have separate messages, for example "Lua 5.1 reads \x41 differently. Use \065 for this byte." `goto` counts only where a statement can start (after a statement end or a block keyword, followed by a name). `goto` used as a name (such as `local goto = 1` or `local x = goto` followed by a call on the next line, which Lua 5.1 allows) passes. Run on its own: `luajit tools/lua51_check.lua <files or TOC>`.

## D6. Report text

`ct.py offline` prints to stderr, and in JUnit `<system-out>` at suite level:

```
Globals read as nil in this run (interface 11509):
  Present in census for build 1.15.9.70576: C_AddOns UnitFullName
  Set by addon code in census for build 1.15.9.70576: SomeAddonGlobal
  Absent from census for build 1.15.9.70576: InterfaceOptionsFrame
```

With no manifest it prints one sorted list. When the interface matches more than one manifest it prints "Interface 11509 matches multiple builds. Showing unclassified names.", and `--build` picks one among the manifests of that interface (a build of another interface exits 2). JUnit `<properties>` carries `interface` and `build`.

## Non-Goals

- A fake generated from the manifest (rest of #145), lifecycle (#149) and events (#150).
- A TUI view of the report: the TUI shows harvested runs, not offline results.
