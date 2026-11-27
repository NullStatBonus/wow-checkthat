## Decisions

- **Two ways in, one rule.** The command list of an addon is the built-in list, plus what the addon declared, plus the plan's prefixes that the game says the addon owns. The addon's own code is trusted, since it can run any command itself. An imported plan is not trusted: its prefixes are checked against the game's record of who registered them.
- **Ownership through `issecurevariable`.** For a `SLASH_<KEY><n>` global, it returns the addon that last wrote it, and true for one the game defined. CTProbe measured that an addon's own global reads `secure=false by=<addon>` on both clients. `Adapter.SlashOwner` walks `SlashCmdList` keys and their numbered globals, which is bounded. The result is kept per plan until the next start.
- **Import checks shape; run time checks ownership.** At import, the plan's listed prefixes count, so a plan can be imported before its addon is loaded. Every Run button and CT macro body goes through `App.MacroText`, which uses the ownership-checked list, so an unowned command is never offered.
- **Tools require listing.** `ct.py` cannot see what an addon declares, so for an addon outside the built-in list a step command must use a listed prefix. The error says so.
- **Revision 2 only with `commands`.** A plan for a new addon that lists no commands is revision 1. An older CheckThat refuses it as "addon not supported", which is the right reason.

## Non-Goals

- Changing the four built-in lists, or reading another addon's options.
- The TOC and listing wording for any addon (#249).
