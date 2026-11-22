# Client and addon contracts

What a client or another addon provides, as measured or source-reviewed. Add a row whenever a probe or source review measures it.

## Measured from saved variables

| Source | Fact | Checked |
| --- | --- | --- |
| KeepThat | `KeepThatDB.global.log` is a list of `"[area] text"` strings. Startup lines repeat at every login. | 2026-11-22 |
| DontDoThat | `DontDoThatDB.global.log.entries` is a list of `{ t, msg }`. | 2026-11-22 |
| ClosestVendor | `ClosestVendorCharDB.log.entries` is a list of `{ t, msg }`. It is per character. | 2026-11-22 |

## Measured in game

| Area | Fact | Checked |
| --- | --- | --- |
| WoW Forever 1.60.1.71037 | `SecureActionButtonTemplate:SetPoint` to the card's command box fails: "Cannot anchor protected frames to regions". The Run all button is anchored to UIParent only, at coordinates read after layout. | 2026-11-22 |
| WoW Forever 1.60.1.71037 | Self-test steps 1 to 4 passed with matched evidence, including resume after `/reload`. | 2026-11-22 |

## Source-reviewed

| Area | Fact | Source |
| --- | --- | --- |
| Era 11509 | `SecureActionButtonTemplate` with `type=macro` and `macrotext`; `useOnKeyDown` false makes a key-up click work. | Blizzard UI source 1.15.9 (`SecureTemplates.lua`) |
| Both clients | Protected frames cannot be shown, hidden or re-anchored in combat. The secure button is a separate top-level frame. | Blizzard UI documentation |

## Pending in-game

- Macro slot limits per client.
- `SecureActionButtonTemplate` behavior on WoW Forever.
- Card layout at UI scales 100 and 150.
