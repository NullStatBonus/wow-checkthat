# Client and addon contracts

What a client or another addon provides, as measured or source-reviewed. Add a row whenever a probe or source review measures it.

## Measured from saved variables

| Source | Fact | Checked |
| --- | --- | --- |
| KeepThat | `KeepThatDB.global.log` is a list of `"[area] text"` strings. Startup lines repeat at every login. | 2026-11-22 |
| DontDoThat | `DontDoThatDB.global.log.entries` is a list of `{ t, msg }`. | 2026-11-22 |
| ClosestVendor | `ClosestVendorCharDB.log.entries` is a list of `{ t, msg }`. It is per character. The log records only while `/cvn debug on` is set. With it on, `/cvn debug on` writes `debug log turned on`, and `/cvn test sell` and `/cvn test repair` write `test command: sell` and `test command: repair` (CheckThat `contains` assertions matched all three in game). `/cvn log clear` empties the list. | 2026-11-23 |
| CheckThat | `CheckThatDB.global.log.entries` holds 300 lines. On Forever, the combat state driver `[combat] hide; show` shows the Run button again about five times a second out of combat, also after a script hides it. CheckThat now releases the driver while a step has no commands (not yet measured in game). | 2026-11-23 |

## Public API of CheckThat

What an addon that reports facts can rely on. It only grows: a released name, argument or line format does not change.

| Name | Contract | Since |
| --- | --- | --- |
| `CheckThat.API_VERSION` | Number, 1. Rises only when something is added. | 0.9.0 |
| `CheckThat.Report(addon, key, value)` | Returns true when it records `[addon] key=value`, false otherwise. Never raises. Records only while a run is open. Limits: addon 32, key 48, string value 120 characters, 30 facts per addon per second, 300 lines kept. | 0.9.0 |
| `CheckThatDB.global.facts` | Array of the recorded lines, readable as a `strings` log. | 0.9.0 |

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

## Pending in-game

- Macro slot limits per client.
- Card layout at UI scales 100 and 150.
