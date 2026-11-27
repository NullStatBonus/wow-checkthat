## Why

Settings had two scopes: the shared Default profile, or one profile for this character through a checkbox in Advanced. Players who run several characters could not share one set of settings between some of them, copy settings, or reset a profile. DontDoThat already offers the standard Ace profile control on a Profiles page. CheckThat should match it.

## What Changes

- Ship AceDBOptions-3.0 from the same Ace3 commit as the other libraries, unchanged.
- New **Profiles** page, the last page in the tree and in the game's Settings list. It names the profile in use and holds the standard AceDBOptions control (choose, create, copy, reset, delete), shown inline as "Manage profiles". `/ct settings profiles` opens it.
- The "Use separate settings for this character" checkbox leaves Advanced. A character profile made with it is an ordinary profile in the list.
- A switch to another profile prints "Profile changed. Profile in use: <name>." and logs `profile changed to <name>`. The debug switch keeps its value across the switch.
- `/ct status` and the debug report name the profile in use instead of the scope.

## Capabilities

### Modified Capabilities
- `addon-settings`: the page list, the profile scope, and a new Profiles page requirement.

## Impact

`CheckThat/Libs/AceDBOptions-3.0`, `embeds.xml`, `Libs/VERSIONS.txt`, `Options/Options.lua`, `Core/Settings.lua`, `Core/Addon.lua`, `Core/Slash.lua`, `Debug/Log.lua`, tests, README, `DESIGN.md`, `features.md`, `listing.md`, `test-plan.md`, `CHANGELOG.md` (1.0.0, untagged). Saved data is unchanged: existing profiles and profile keys stay.
