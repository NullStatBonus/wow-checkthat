## Decisions

- **The standard control, as DontDoThat has it.** `AceDBOptions-3.0:GetOptionsTable(db)` is placed inline in the Profiles page under "Manage profiles", read through `LibStub(..., true)` and `pcall`, so a missing library leaves the page with its purpose and the profile line only. Its own texts come from the library's locale.
- **Profiles is its own page, last.** Same place as DontDoThat. Advanced loses its Profile section; its heading becomes "Runs, macro and troubleshooting".
- **The checkbox goes.** It was a second way to do one thing the control does. Its character profile is named for the character (`Name - Realm`), so it shows in the list and stays selected for that character. Nothing is migrated.
- **Chat at login and on a switch, as DontDoThat does.** Each login prints "Profile in use: <name>." A profile can change without the player of this character choosing it: Delete on another character removes it, and AceDB moves this character to Default. `OnProfileChanged` prints "Profile changed. Profile in use: <name>." Names are escaped for chat and for the page.
- **Debug kept across a switch, a copy and a reset.** `OnProfileShutdown` records `debug` before a switch. Reset and copy have no callback before the change, so the db's own `ResetProfile` and `CopyProfile` are wrapped to record it; every caller goes through them. The callbacks write it back, so recording does not stop in the middle of a problem report and the log lines `profile reset` and `profile copied from <name>` are written.
- **Redraw.** Changed, Copied, Reset and Deleted notify the options registry, so the other pages show the new profile's values. The card re-applies its appearance and the CT macro (`Card.FollowMacro(true)`) on Changed, Copied and Reset. Delete logs `profile deleted <name>`.

## Non-Goals

- Test settings (a temporary profile during a run). CheckThat is the runner and has no settings that change what a plan checks.
- Per-spec profiles (LibDualSpec).
