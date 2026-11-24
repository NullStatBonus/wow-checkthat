# Which tool to use with CheckThat

Written 2026-11-24 from the pages named under each row. Tool details change: check the page before you rely on a row.

An addon author usually needs three levels of checking. Use each tool for what it does best, and use CheckThat for what only a person in the live client can show.

| Level | Tool | What it does | What it cannot do |
| --- | --- | --- | --- |
| Logic outside the game | [wowless](https://github.com/wowless/wowless) | A headless interpreter for the game's Lua and FrameXML, meant for addon testing. | Its README calls it pre-alpha, and it needs Docker for development. It cannot show how the real client behaves. |
| Logic outside the game | WoWBench ([forum post](https://www.wowinterface.com/forums/showthread.php?t=5237), [SourceForge](https://sourceforge.net/projects/wowbench/)) | An old offline emulator of the Vanilla (1.12) API. | It is alpha and was last updated in 2013. Treat it as history. |
| Unit tests in the game | [WoWUnit](https://github.com/Jaliborc/WoWUnit) | Test groups run at startup or on game events, with asserts and temporary replacement of functions. Add it as an optional dependency and wrap the tests in `if WoWUnit then`. | It needs a running client. Its pages describe test groups and results, not a guided run for a person. |
| Error capture | [BugGrabber](https://www.wowace.com/projects/bug-grabber) and [BugSack](https://github.com/funkydude/BugSack) | BugGrabber captures Lua errors. BugSack shows them with the stack. | Neither says whether a step passed. BugGrabber is not meant to silence errors. |
| Debug logs of your addon | [Alluneve-Debug](https://github.com/Alluneve/Alluneve-Debug) | A logging API for Retail addons with rolling logs and error reports sent to BugGrabber. Attribution of an error to an addon is best effort. | It targets Retail and records only what addons give it. |
| A guided run in the live client | CheckThat | Shows each step, reads your addon's debug log, saved facts and Lua errors, and records the result with evidence. | See below. |

## What CheckThat does not do

- It never runs plan text as code.
- It does not replace API calls with fakes.
- It never sends input. Every protected action is a real click or key press by the player.

## Use them together

1. **Logic.** Test pure logic with a tool that runs outside the game. A failure there costs seconds.
2. **In-game unit tests.** Use WoWUnit for checks of code that needs the client. Today CheckThat cannot read WoWUnit results: see [issue 61](https://github.com/NullStatBonus/wow-checkthat/issues/61).
3. **A run with a person.** Use CheckThat for what a person must see or do: a window opens, a vendor sells, a bag sorts. Have your addon report facts with `CheckThat.Report` and write a debug log that the plan can read.

## Better with: optional addons

CheckThat needs no other addon. These make it better when they are installed. None is a dependency, and every path that reads them works when they are missing.

- **BugGrabber.** When it holds the error handler, CheckThat reads its error counts and its stored stack instead of setting its own handler. Without it, CheckThat sets its own. See the Lua errors item in [Feature reference](features.md).
- **BugSack.** Shows the same errors with the full stack and locals. CheckThat keeps only a short stack and never the locals.
- **The addon under test.** Its debug log and its facts are the evidence. A plan for one of them needs that addon. CheckThat itself loads without any of them: the TOC has no required dependency and lists only KeepThat, DontDoThat and ClosestVendor under `OptionalDeps`.

## Sources read

- WoWUnit: GitHub page and the CurseForge page (version 12.1.0, September 2026), read 2026-11-24.
- wowless: GitHub README, read 2026-11-24.
- WoWBench: forum post of 2006-06-25 and the SourceForge page (alpha, 2013-04-24), read 2026-11-24.
- BugGrabber: WowAce project page (version 12.1.1), read 2026-11-24. BugSack: GitHub page, read 2026-11-24.
- Alluneve-Debug: GitHub README, read 2026-11-24.
