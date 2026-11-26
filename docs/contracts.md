# Client and addon contracts

What a client or another addon provides, as measured or source-reviewed. Add a row whenever a probe or source review measures it.

## Measured from saved variables

| Source | Fact | Checked |
| --- | --- | --- |
| KeepThat | `KeepThatDB.global.log` is a list of `"[area] text"` strings. Startup lines repeat at every login. It keeps 300 lines (`Log.MAX = 300`, trimmed at `KeepThat/Debug/Log.lua` lines 6 and 23, commit 7dee68e). | 2026-11-22, cap 2026-11-24 |
| DontDoThat | `DontDoThatDB.global.log.entries` is a list of `{ t, msg }`. It keeps `store.max` lines, 500 by default (`DEFAULT_MAX`, `DontDoThat/Debug/Log.lua` lines 8, 22 and 32, commit 2fc85ce). `Log.SetMax` has no caller in the addon, so only an edit of the saved variable changes the bound. A plan declares `cap: 500`; with a bound set below 500 the log rolls early and the cap overstates how much it holds. | 2026-11-22, cap 2026-11-24 |
| ClosestVendor | `ClosestVendorCharDB.log.entries` is a list of `{ t, msg }`. It is per character. The log records only while `/cvn debug on` is set. With it on, `/cvn debug on` writes `debug log turned on`, and `/cvn test sell` and `/cvn test repair` write `test command: sell` and `test command: repair` (CheckThat `contains` assertions matched all three in game). `/cvn log clear` empties the list. It keeps 300 lines (`L.MAX = 300`, `ClosestVendor/Log.lua` lines 8 and 19; `Core.lua` line 395 passes no other bound; commit 0da925e). | 2026-11-23, cap 2026-11-24 |
| CheckThat | `CheckThatDB.global.log.entries` holds 300 lines (`Log.MAX`, `CheckThat/Debug/Log.lua` line 5, trimmed at line 24). On Forever, the combat state driver `[combat] hide; show` shows the Run button again about five times a second out of combat, also after a script hides it. CheckThat now releases the driver while a step has no commands (not yet measured in game). | 2026-11-23 |

## Public API of CheckThat

What an addon that reports facts can rely on. It only grows: a released name, argument or line format does not change.

| Name | Contract | Since |
| --- | --- | --- |
| `CheckThat.API_VERSION` | Number, 2. Rises only when something is added. | 0.9.0 |
| `CheckThat.Entry(addon, name, fn)` | Returns true when it stores the entry, false otherwise. Never raises. An auto step with `call` runs it at step open, outside combat, and records `[addon] entry.<name>=<result>`. | 0.18.0 |
| `CheckThat.Report(addon, key, value)` | Returns true when it records `[addon] key=value`, false otherwise. Never raises. Records only while a run is open. Limits: addon 32, key 48, string value 120 characters, 30 facts per addon per second, 300 lines kept. | 0.9.0 |
| `CheckThatDB.global.facts` | Array of the recorded lines, readable as a `strings` log. | 0.9.0 |
| `CheckThatDB.global.errors` | Array of Lua error lines recorded while a run is open, each `<time>.<counter> [<addon>] <message>` with the message cut to 200 characters, 100 kept, 30 a second. `<addon>` is read from `AddOns\<Name>\` in the message, else `?` (lines CheckThat adds itself say `CheckThat`). Readable as a quiet `strings` log. | 0.10.0, tag 0.12.0 |
| `CheckThatDB.global.errorStacks` | Array of up to 20 lines, each `<time>.<counter> <stack>` with the stack on one line, cut to 600 characters. The key matches the error line. The first error of a step only. No locals. | 0.12.0 |
| `CheckThatDB.global.runs[id].steps[sid].attempts[n].excerpt` | Table of source name to an array of at most 20 lines, each cut to 200 characters: the new lines of the log while a failed or unverified attempt was open. Added to the results string too. `ct` stays 1. | 0.13.0 |
| Fact values | A fact value reads as `true` or `false` (boolean), a number when the text is a plain decimal or exponent number, else text. `0x10`, `nan` and `inf` stay text. | 0.10.0 |
| `CheckThatDB.global.runs[id]` | Adds `categories` (list of id and title), `cat` (step id to category id) and `selected` (set of picked ids). A run without them reads as every section picked. Step verdict `deselected` is new. `ct` stays 1. | 0.10.0 |

## Measured in game

| Area | Fact | Checked |
| --- | --- | --- |
| WoW Forever 1.60.1.71037 | `SecureActionButtonTemplate:SetPoint` to the card's command box fails: "Cannot anchor protected frames to regions". The Run button is anchored to UIParent only, at coordinates read after layout. | 2026-11-22 |
| WoW Forever 1.60.1.71037 | Self-test steps 1 to 4 passed with matched evidence, including resume after `/reload`. | 2026-11-22 |

## Source-reviewed

| Area | Fact | Source |
| --- | --- | --- |
| Era 11509 | `SecureActionButtonTemplate` with `type=macro` and `macrotext`; `useOnKeyDown` false makes a key-up click work. | Blizzard UI source 1.15.9 (`SecureTemplates.lua`) |
| Both clients | LibDeflate 1.0.2 `DecompressDeflate` has no output limit and builds the whole result. CheckThat patches it: `DecompressDeflate(str, max_out)` returns `nil, -20` once flushed output passes `max_out`, checked every 32768 bytes. | LibDeflate source review and `tests/test_codec.lua` |
| Both clients | Protected frames cannot be shown, hidden or re-anchored in combat. The secure button is a separate top-level frame. | Blizzard UI documentation |
| Test harness | `tests/harness.lua` models these rules for a frame made from a `Secure*Template`: `SetAttribute`, `Show`, `Hide`, `SetShown`, `SetPoint`, `ClearAllPoints`, `SetSize`, `SetWidth`, `SetHeight`, `SetParent` and `SetScale` raise in combat. `SetPoint` to anything but the screen raises. A `visibility` state driver (`[combat] hide; show`) shows and hides the frame, also in combat, and again on each `st.tick()`. `Show` and `Hide` run OnShow and OnHide on each real change. The client may block these calls without raising a Lua error; the harness raises so a test cannot miss one. | `tests/test_combat.lua`, `tests/test_smoke.lua` |

## Measured in game for categories (2026-11-24)

| Area | Fact | Source |
| --- | --- | --- |
| WoW Forever 1.60.1.71037, with !BugGrabber and BugSack installed | The debug log read `[errors] handler blocked`: CheckThat's `seterrorhandler` call had no effect, as the BugGrabber source predicts. CheckThat then recorded the self-test error from BugGrabber's counters (`[errors] recorded an error`), and the steps "No Lua error" and "Record a Lua error" passed with matched evidence. | `CheckThatDB.global.log` and `global.errors` of run `CheckThat-1795491197-4ec0` |
| WoW Forever 1.60.1.71037 | An automatic step with an absence check and a 10 second timeout ("No Lua error") passed by itself at the timeout (evidence matched) once the plan declared `cap: 100` on the error list. A step that needs exactly two reports recorded fail by itself the moment a third and fourth fact arrived (two Run clicks): `step self.exact fail auto evidence contradicts: 4 matched, at most 2 allowed`. "Export results" settled itself on the line `[ct] run exported <id>`. | run `CheckThat-1795493572-4ec0` |

Not measured yet: the handler path with BugGrabber disabled (`handler current`), and the Categories window, colors and rerun on screen.

## Source-reviewed for categories (2026-11-24)

| Area | Fact | Source |
| --- | --- | --- |
| Error handler | `geterrorhandler()` returns the current handler, a function that receives the error message as one argument. `seterrorhandler(fn)` sets it. | https://warcraft.wiki.gg/wiki/API_geterrorhandler, https://warcraft.wiki.gg/wiki/API_seterrorhandler |
| BugGrabber | At load it saves the real `seterrorhandler`, calls `real_seterrorhandler(grabError)`, then replaces the global with `function seterrorhandler() end`. A later `seterrorhandler` call from another addon does nothing and raises no error. `grabError` does not call a previous handler. | `BugGrabber.lua` lines 28, 573 and 574, trunk at https://repos.wowace.com/wow/bug-grabber/trunk/BugGrabber.lua. This trunk uses retail APIs (`issecretvalue`, `EventRegistry`), so the Classic package may differ. |
| BugGrabber | An error already in `BugGrabberDB.errors` (same message) is not added again: its `counter` goes up. Only a new message adds an entry. After 10 seconds an old entry moves to the end of the list. The standalone addon is named `!BugGrabber`. | `BugGrabber.lua` lines 20, 346 to 377, same file |
| Era UI | `UICheckButtonTemplate` is a `CheckButton` that inherits `UICheckButtonArtTemplate`. `MenuUtil.CreateContextMenu` is used by Blizzard_RaidUI and Blizzard_GroupFinder (Classic) on Era, and `UIDropDownMenu_Initialize` and `UIDropDownMenu_CreateInfo` are defined in `Blizzard_SharedXML/Classic/UIDropDownMenu.lua`. `StatusBar` with `SetStatusBarColor` is used by Blizzard_UnitFrame (`CompactUnitFrame.lua`). | https://github.com/Gethe/wow-ui-source, branch `classic_era`: `Interface/AddOns/Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:50`, `Interface/AddOns/Blizzard_RaidUI/Blizzard_RaidUI.lua`, `Interface/AddOns/Blizzard_GroupFinder/Classic/LFGList.lua`, `Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua` |

| BugGrabber | A new error entry in `BugGrabberDB.errors` gets `stack` (a string from `debugstack`, or the text `debugstack() returned secrets.` or `debugstack() returned nil.`) and `locals` right after it is stored. A repeated error keeps the first entry's stack. CheckThat reads `stack` and never `locals`. Measured on Forever 1.60.1.71037 (2026-11-24): the kept stack read `[C]: in function 'pcall' / [Interface/AddOns/CheckThat/Core/Adapter.lua]:74: …`, and CheckThat cut it at 600 characters. | `BugGrabber.lua` lines 271 to 294 and 371 to 374, same file |
| `debugstack` | Not measured in the Classic Era or Forever clients yet. CheckThat calls `debugstack(4, 12, 0)` inside `pcall` and keeps nothing when it raises or is missing. Check 9 of the test plan measures it. | |
| Esc | `CloseSpecialWindows()` hides every frame named in `UISpecialFrames` that is shown, all of them in one press, and returns whether it found one. | https://github.com/Gethe/wow-ui-source, branch `classic_era`: `Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:1041` |
| Keyboard | A frame with `EnableKeyboard(true)` that calls `SetPropagateKeyboardInput(false)` in its `OnKeyDown` keeps that key from reaching the key bindings. CheckThat's item list uses this to take Esc, so the Categories window behind it stays open. Documented API behavior, not measured in the game: Era never shows the list, because both menu APIs exist there. | https://warcraft.wiki.gg/wiki/API_Frame_SetPropagateKeyboardInput |
| Menus | Era has `MenuUtil` and `UIDropDownMenu` (the Era UI row above; Forever is not measured), so the item list of the Categories window appears only when both are missing or fail. `Adapter.ContextMenu` tries the dropdown when `MenuUtil` raises. No standard control exists for a client with neither, so the list is a plain button column. | the Era UI row above; `tests/test_tracker.lua` removes both APIs |

What follows for CheckThat: when BugGrabber is loaded, CheckThat cannot set its own handler and cannot see its errors through one. CheckThat reads BugGrabber's counters instead and records an error for each rise (`Errors.Sample`). The debug report shows `handler: blocked`. Without BugGrabber, CheckThat sets its handler and chains to the one before it.

## Offline mocks and entry points (issue 94, 2026-11-24)

Prototype: `tools/entry_runner.lua` with `tests/fixtures/MockAddon/` and `tests/test_entries.lua`. It reads its own spec file, not a plan field, and changes nothing under `CheckThat/`.

| Question | Result | How measured |
| --- | --- | --- |
| Does a mock reach a game function an addon captured in a file-scope local? | Yes when the mock is set before the addon loads. No when it is set after load: the local keeps the earlier function, and a call-time lookup (`_G.Name`) sees the mock. | `test_entries`: "a mock set before load…" and "…after load misses the capture" |
| How often do our addons capture game functions in file-scope locals? | 0 in all four (KeepThat, DontDoThat, ClosestVendor, CheckThat). The only file-scope `local x = Capital…` lines name Ace libraries and the addon's own tables. Game calls happen inside functions, and KeepThat and CheckThat route them through an adapter that looks the name up at call time. | Static search for top-level `local a = <Name>`, `C_x.y` and `_G.x` over each addon folder without `Libs/` (2026-11-24). It does not see captures inside `do` blocks or another addon's code |
| Can an entry be called with literal arguments and checked for returns, throws and mock call counts? | Yes. An unregistered name fails the step. A step result says whether mocks were set. | `test_entries` |
| Can a fake event reach the addon's handlers? | Yes, at every frame that registered it and has an `OnEvent` script. A name nobody registered fails the step. | `test_entries` |
| Are mocks restored? | Yes, also for a dotted name such as `C_Item.GetItemCount`. | `test_entries` |
| What did the shared fake client lack? | A record of which events a frame registered (`RegisterEvent` was a no-op), a global `CheckThat` with `Entry`, and a hook that sets the "real" values a mock replaces. Nothing else: `H.stubClient()` loaded the fixture addon unchanged. | Runner source |
| Do sibling addons have their own harness? | Yes, each has `tests/harness.lua` (KeepThat, DontDoThat, ClosestVendor). A shared runner must take the addon's harness as an option or accept the CheckThat one. Not compared line by line. | `ls` of each `tests/` |
| Does replacing a global in game taint secure code? (Era 11509, build 1.15.9.70576, 2026-11-24) | **Yes, and restoring does not clear it (measured).** The same three readings as Forever: `secure=true`, then `secure=false by=CTProbe` after replacing, then still `secure=false by=CTProbe` after the addon put the original back. No protected action was tried. Blizzard code reads `GetMoney` as a global in `classic_era` source too (`Blizzard_MoneyFrame/Shared/MoneyFrame.lua:242`, `Blizzard_UIPanels_Game/Vanilla/MerchantFrame.lua:590`). | CTProbe v2 `/ctp taint run`, `CTProbeDB.log`; Blizzard source (wow-api, `classic_era`) |
| Does replacing a global in game taint secure code? (Forever, build 1.60.1.71091, 2026-11-24) | **Yes, and restoring does not clear it (measured).** `issecurevariable("GetMoney")` read `secure=true` before, `secure=false by=CTProbe` after the addon replaced it, and still `secure=false by=CTProbe` after the addon put the original back. No protected action was tried, so no `ADDON_ACTION_BLOCKED` was possible. The same two files read `GetMoney` in `forever` source. | CTProbe v2 `/ctp taint run`, `CTProbeDB.log`; Blizzard source (wow-api, `forever`) |
| Which Lua differences between LuaJIT (the tests) and the game's Lua 5.1 does the scanner check? (source-reviewed, 2026-11-25) | The game compiles Lua 5.1. `tools/lua51_check.lua` checks the differences that load or change meaning: `goto` and `::label::` (LuaJIT accepts, Lua 5.1 rejects); `\x`, `\z` and `\u{` in a short string (LuaJIT reads an escape, Lua 5.1 reads the letter); the `LL`, `ULL` and `i` number suffixes (LuaJIT reads 64-bit or imaginary numbers, Lua 5.1 rejects them). `goto` as a name is valid Lua 5.1. Not checked: LuaJIT's `bit`, `ffi` and `jit` libraries (the runner hides `ffi` and `jit`), and integer or float formatting. | Lua 5.1 manual (lexical conventions), LuaJIT extensions page; not measured in game |
| Does calling an addon entry from CheckThat taint? | **No new taint from the dispatcher itself (source-reviewed).** CheckThat is addon code, so its handler already runs tainted, and the dispatcher calls the entry outside combat in `pcall`. What an entry does is the entry's own risk and is **not** covered: a third-party entry that changes shared state Blizzard code reads later can taint it, with or without a protected call. The built-in `CheckThat selftest.add` only adds two numbers. **Measured on Era and Forever (same run):** after an addon called its own registered function from insecure code, `GetMoney` and `GetTime` still read `secure=true`. Only the global the function wrote itself read `secure=false by=CTProbe`. That rules out new tainted globals only. | CTProbe v2, `CTProbeDB.log`; warcraft.wiki.gg "Secure Execution and Tainting" |
| In what order does the game load an addon and its saved variables, and what does `/reload` fire? (source-reviewed, 2026-11-25) | The TOC files run, then the saved-variables file runs (before the files with `## LoadSavedVariablesFirst: 1`), then ADDON_LOADED (folder name), PLAYER_LOGIN and PLAYER_ENTERING_WORLD (`isInitialLogin, isReloadingUi`). The saved-variables file assigns only the names it holds, so it replaces a file-scope default and keeps it on a first login. Only strings, numbers, booleans and tables are saved, and a shared table comes back as two. Before a reload: PLAYER_LEAVING_WORLD, PLAYER_LOGOUT, ADDONS_UNLOADING (the wiki marks the last two as unconfirmed). Offline level 3 follows this. Not measured in game: confirm the logout order and the PLAYER_ENTERING_WORLD arguments with CTProbe. | warcraft.wiki.gg "AddOn loading process" and "Saving variables between game sessions" |

Decisions, by part (the follow-up issues carry the build work):
- **Mocks offline: build.** Proven, no client needed. Next step is the plan format (mocks, entry calls, expectations) with schema, `Plan.lua`, `ct.py` and the format spec together.
- **Entry points and throws: built in 0.18.0 (#97).** Needed `CheckThat.Entry` in the public API (`API_VERSION` 2, a version bump) and an `auto` step that calls entries.
- **Fake events: build, offline only.** The real client cannot be made to fire arbitrary events.
- **Mocks in game: drop.** Local capture is not the blocker (0 captures), taint is. Measured on Era and Forever: a global that addon code replaces stays tainted after the original goes back, until `/reload`, and Blizzard money and vendor code reads those globals. Mocks stay offline.
- **Entry calls in game: allow with limits.** Registered entries only, outside combat, in `pcall`, with literal arguments. An entry must not call a protected function.
- **Setup and teardown: build with the plan format.** Mocks restore after the run today; per-step and per-category setup needs plan fields.
- **Login self-check: defer.** A separate, opt-in setting.

## Pending in-game

- **Protected actions with a tainted global (#98).** Not tried: the probe only reads `issecurevariable`. No `ADDON_ACTION_BLOCKED` was observed because none was provoked. Measuring whether a tainted `GetMoney` blocks a vendor purchase needs a Blizzard path that reads it and then calls a protected function. It does not change the decision, which already drops in-game mocks.

- **Error capture on a real client.** That the handler is set on Era and Forever without BugGrabber (`handler: current`), that an error raised by another addon is recorded in both cases, and what `geterrorhandler()` returns before any addon sets one. With BugGrabber, `handler: blocked`, a recorded self-test error and its kept stack are measured on Forever (above). `debugstack(4, 20, 0)` inside our own handler works on Forever with BugGrabber disabled (2026-11-24). The first frames it returned were our own handler frames, so `Errors.lua` drops them (unit-tested, not yet confirmed in the game). No slowdown was reported. With BugGrabber disabled and `seterrorhandler` replaced by a no-op, the amber warning showed on a step that reads the error list. Era is unmeasured. Check with section 5 of `docs/test-plan.md`, check 3.
- **Tracker on a real client.** The card draws the tracker with plain textures and the start screen with `CheckButton` and `UICheckButtonTemplate`. How they look at the card's scale and opacity, and whether the Categories list opens through `MenuUtil` on Era. Check with section 5, checks 1, 4 and 5.

- **Screenshot file times on an SMB mount (#95).** Measured 2026-11-25 on a game folder mounted over SMB: 191 screenshots in the Era and Forever folders. File modification time minus the time in the file name (the game computer clock) was 0 s for 19 files and 1 s for 172 files. The 1 s comes from the name dropping fractions of a second. The file times agree with the game clock, so the default slack of 2 s in collect holds.
