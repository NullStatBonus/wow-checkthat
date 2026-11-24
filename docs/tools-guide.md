# Which tool to use with CheckThat

Written 2026-11-24. Tool details change: check the page before you rely on a row.

CheckThat is for what only a person in the live client can show: a window opens, a vendor sells, a bag sorts. Have your addon report facts with `CheckThat.Report` and write a debug log that the plan can read.

## What CheckThat does not do

- It never runs plan text as code.
- It does not replace API calls with fakes.
- It never sends input. Every protected action is a real click or key press by the player.

## Better with: optional addons

CheckThat needs no other addon. These make it better when they are installed. None is a dependency, and every path that reads them works when they are missing.

- **BugGrabber.** When it holds the error handler, CheckThat reads its error counts and its stored stack instead of setting its own handler. Without it, CheckThat sets its own. See the Lua errors item in [Feature reference](features.md).
- **The addon under test.** Its debug log and its facts are the evidence. A plan for one of them needs that addon. CheckThat itself loads without any of them: the TOC has no required dependency and lists only KeepThat, DontDoThat and ClosestVendor under `OptionalDeps`.

## Sources read

- BugGrabber: WowAce project page (version 12.1.1), read 2026-11-24.
