## ADDED Requirements

### Requirement: The bundle ships CTProbe
The skill bundle, the plugin and the toolkit zip SHALL hold `tools/ctprobe/CTProbe`, the development addon that records what the game answers. It SHALL NOT be packaged for CurseForge or Wago.

#### Scenario: The toolkit holds the probe
- **WHEN** `make build-toolkit` runs
- **THEN** `ct-test-plan/ct/tools/ctprobe/CTProbe/CTProbe.lua` and both of its TOC files are in the zip

### Requirement: CTProbe records one read-only call
`/ctp record <call>` SHALL record one call in `CTProbeDB.fixtures`, with `GetBuildInfo()` when it is not recorded yet. The last part of the function name SHALL start with `Get`, `Is`, `Has`, `Can` or `Num` followed by a capital letter, or with `Unit` followed by a capital letter, and SHALL NOT be on the block list of names that change state (`GetQuestReward`). Each argument SHALL be a number, `true`, `false`, `nil`, quoted text or a bare word read as text; nothing in the command SHALL run as code. A call on a unit that is a player, or a call whose returns hold the character's name, realm, money or GUID, SHALL be recorded by type only. A refused call SHALL record nothing and say why. A later `/ctp record` SHALL keep the calls recorded this way.

#### Scenario: A read-only call
- **WHEN** the player types `/ctp record GetItemInfo(6948)`
- **THEN** `CTProbeDB.fixtures["GetItemInfo(6948)"]` holds the returns with their values, and the arguments

#### Scenario: A call that changes state
- **WHEN** the player types `/ctp record BuyMerchantItem(1)` or `/ctp record GetQuestReward(1)`
- **THEN** nothing is recorded and the probe says the call is not a read-only one

#### Scenario: Code in an argument
- **WHEN** the player types `/ctp record GetItemInfo(loadstring("x"))`
- **THEN** nothing is called and the probe names the argument it cannot read

#### Scenario: A personal value
- **WHEN** the player types `/ctp record UnitLevel(player)` or `/ctp record GetMoney()`
- **THEN** the call is recorded by type only, and `ct recordings` leaves it out as a personal value

### Requirement: Recordings go to the addon's repository
`ct recordings` run from an installed bundle (no `.git` beside the tools) without `-o` SHALL stop with exit 2 and ask for a folder in the addon's repository. From a checkout it SHALL keep writing `tools/recordings` by default. A call stored with its arguments SHALL be left out as a call on the player when an argument is `player`.

#### Scenario: Installed bundle without -o
- **WHEN** `ct recordings --src CTProbe.lua` runs from an installed bundle
- **THEN** it exits 2, writes nothing and names `-o`

### Requirement: Developers can follow the recording steps from the bundle
The steps to record a call (install CTProbe, `/ctp record <call>`, `ct recordings -o`, `offline.recordings`) SHALL be in `docs/authoring-plans.md`, which the bundle ships, with the CTProbe folder's path for each install kind. The plan skill SHALL give the author the full path of `$CT/tools/ctprobe/CTProbe`. `ct recordings` SHALL be a stable command. Every `$CT/` path a skill names SHALL exist in the bundle.

#### Scenario: A skill names a file the bundle lacks
- **WHEN** a skill names `$CT/docs/harvesting.md` and the bundle does not ship it
- **THEN** the toolkit test fails and names the path
