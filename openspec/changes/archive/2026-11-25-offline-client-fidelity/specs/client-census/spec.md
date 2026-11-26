# Spec Delta

## ADDED Requirements

### Requirement: Census command records the names of the client
`/ct census` SHALL record, in `CheckThatDB.global.census`, every global name that the game itself defines (`issecurevariable(name)` true) with its Lua type, the members (name and type, one level deep, at most 2000 for each table, a cut table named in `truncated`) of each such table global whose name starts with a capital letter and that is not a frame (no userdata in slot 0), and the method names of sample widgets. A global that addon code last wrote SHALL be recorded in `insecure` with its type and no members; a table member that another addon defined SHALL NOT be recorded; the log SHALL count the insecure globals. When the client has no `issecurevariable`, or it does not accept a table, the census SHALL keep every name and be marked `unfiltered`. It SHALL read tables with `rawget` and `next` only. It SHALL NOT change any setting or call any game action. It creates a few hidden sample frames, which disappear at reload. A member key that is not a plain identifier SHALL be left out. A widget type that CreateFrame refuses SHALL be listed as unavailable. It SHALL record the folder names of the loaded addons.

#### Scenario: Names recorded
- **WHEN** the player types `/ct census` out of combat and the walk completes
- **THEN** `census` (with its `build`) holds the globals, the tables, the widget methods, the unavailable types and the loaded addons

#### Scenario: Odd member keys
- **WHEN** a public table has a member keyed by a character name with a hyphen, or by a number
- **THEN** that member is not in the census

### Requirement: Census runs in small steps and waits for combat
The walk SHALL work within a time budget of about 8 ms for each frame, or a fixed number of reads when the client has no clock. It SHALL refuse to start in combat with the line "Run /ct census after combat ends." It SHALL pause while the player is in combat and carry on at PLAYER_REGEN_ENABLED or at the next tick out of combat. A second start while one runs SHALL say "A client census is already running." and start nothing.

#### Scenario: Refused in combat
- **WHEN** the player types `/ct census` in combat
- **THEN** the line says to run it after combat and no walk starts

#### Scenario: Paused by combat
- **WHEN** combat starts during the walk
- **THEN** the walk stops, the log holds `[census] paused for combat` once, and the walk finishes after combat ends

#### Scenario: Several frames
- **WHEN** a walk needs more than one frame of budget
- **THEN** it continues on the next frame and the client is not blocked for the whole walk

### Requirement: Census replaces a build only when complete
The addon SHALL store a census only when the walk has visited every step. A walk that ends early SHALL leave the stored census unchanged. The addon SHALL keep one census for each client, the newest, and a complete walk SHALL replace it whatever its build. A timer of an ended walk SHALL do nothing. It SHALL say "Client census started. Wait for the completion message before you reload or log out." at the start and "Client census complete. Type /reload or log out to save it." at the end, and SHALL log `[census] started <build>` and `[census] done <build> <n> globals <m> tables <k> widget types <a> addon`.

#### Scenario: Unfinished walk
- **WHEN** the older census of a build is stored and a new walk of the same build has not finished
- **THEN** the older census is still the stored one

#### Scenario: Finished walk
- **WHEN** the walk completes
- **THEN** it replaces the saved census, so only the newest one is kept

### Requirement: Census export writes one manifest for the stored census
`ct.py census` SHALL read the saved variables the same way `collect` finds them and write `tests/manifests/<client>-<build>.json` (or into `-o DIR`) for the census of each file, print each path, and exit 0. The client SHALL be `era` for an interface below 16000 and `forever` otherwise. The manifest SHALL hold `format`, `client`, `build`, `interface`, `date`, `addons`, `globals`, `tables`, `widgets` (sorted by the command), `unavailable` and `truncated`. It SHALL leave out the names that start with the folder name of a loaded addon other than a Blizzard one only when the census is marked `unfiltered`. With no census it SHALL exit 1 with "Run /ct census, wait for completion, type /reload, then copy SavedVariables again."

#### Scenario: Manifest written
- **WHEN** the saved variables hold a census of build 1.15.9.70576 with interface 11509
- **THEN** `era-1.15.9.70576.json` is written and its path is printed

#### Scenario: No census
- **WHEN** the saved variables hold no census
- **THEN** the command exits 1 and prints how to make one

### Requirement: Census diff lists changed names
`ct.py census --diff OLD NEW` SHALL print each name only in NEW with `+`, each name only in OLD with `-` and each name whose type changed as `~ name: old -> new`, for globals, table members and widget methods, then a count line. It SHALL exit 1 when a manifest cannot be read.

#### Scenario: Differences
- **WHEN** NEW adds a global, drops one and changes the type of a third
- **THEN** one `+`, one `-` and one `~` line print, followed by "1 added, 1 removed, 1 changed type"
