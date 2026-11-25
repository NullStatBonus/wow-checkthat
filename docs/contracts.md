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
| `CheckThat.API_VERSION` | Number, 1. Rises only when something is added. | 0.9.0 |
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

## Pending in-game

- **Error capture on a real client.** That the handler is set on Era and Forever without BugGrabber (`handler: current`), that an error raised by another addon is recorded in both cases, and what `geterrorhandler()` returns before any addon sets one. With BugGrabber, `handler: blocked`, a recorded self-test error and its kept stack are measured on Forever (above). `debugstack(4, 20, 0)` inside our own handler works on Forever with BugGrabber disabled (2026-11-24). The first frames it returned were our own handler frames, so `Errors.lua` drops them (unit-tested, not yet confirmed in the game). No slowdown was reported. With BugGrabber disabled and `seterrorhandler` replaced by a no-op, the amber warning showed on a step that reads the error list. Era is unmeasured. Check with section 5 of `docs/test-plan.md`, check 3.
- **Tracker on a real client.** The card draws the tracker with plain textures and the start screen with `CheckButton` and `UICheckButtonTemplate`. How they look at the card's scale and opacity, and whether the Categories list opens through `MenuUtil` on Era. Check with section 5, checks 1, 4 and 5.
