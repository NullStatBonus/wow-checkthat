## Context

The goal is fewer in-game runs. Prior art that already takes WoW API behavior from public sources:

- **wowless** (MIT): a headless client. Its per-product YAML gives each function's inputs and outputs with `nilable`, `oneornil` (the legacy 1-or-nil booleans) and `stub` values. A separate overlay holds corrections to Blizzard's docs. A tool feeds failures from an in-game test addon back into the YAML.
- **vscode-wow-api** (MIT): editor annotations. They come from Blizzard's generated documentation, warcraft.wiki.gg wikitext (`{{apisig}}` and `{{apitype|T?}}`) and hand-written files. Existence per client comes from per-branch name lists.
- **Game data**: DB2 tables (`ItemSparse`, `Item`, `SpellName`, `SkillLineAbility`) give item prices and spell data. Vendor stock and trainer costs are server-side, so only private-server world databases (GPL) list them.

No code is reused. The ideas are re-implemented in CheckThat's own format.

## Decisions

- **Signatures as data, checked by a test** (from wowless's typed outputs). One JSON file is keyed by api and then client. It lists return names, types, `nilable` and `oneornil`, with a Blizzard source `ref`. A function's existence stays with the census (`tools/clients/`). The Forever source never calls `GetTrainerServiceLevelReq`, yet Forever has it.
- **Provenance per call** (wowless records only the build). `source` is optional, and a call without it was recorded in game. This is additive, and the runner copies only `args`, `returns` and `n`.
- **A run confirms** (from wowless's failure-to-YAML loop). `ct.py recordings` reports `confirmed`, `changed` and `differs from signature` instead of silently replacing data. People edit the file; nothing is rewritten automatically.
- **Authored rows are honest about it.** The class trainer rows use the signature's shape, and their source says which values are made up. A plan can mock them now. A later run confirms them.
- **The probe follows Blizzard's own reads.** It reads booleans for truth (1 or nil), skips header rows, reads ids through `GetMerchantItemID`, and waits for complete auction rows (hasAllInfo).

## Non-Goals

- Fetching wiki or DB2 data from `ct.py`. Network access and the size of the tables are not worth it for the few calls a plan mocks. A `database` entry is typed in with its `ref`.
- Forever auction and `C_MerchantFrame.GetItemInfo` table returns (#234).
