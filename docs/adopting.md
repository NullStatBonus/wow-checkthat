# Adopt CheckThat in an addon repository

Install the skills once: the Claude Code plugin from the marketplace, the toolkit zip from a GitHub release, or `make install-skill BIN_DIR=$HOME/bin` in a CheckThat checkout (see [skills](skills.md#install)). With the plugin or the zip, run `python3 <tools>/ct.py setup` once ([skills](skills.md#install) says where `<tools>` is). With the plugin, the skills are `/checkthat:plan` and `/checkthat:verify`; the section below names them `/ct-test-plan` and `/ct-verify`, as the zip and `make install-skill` install them. Call the installed `ct-test-plan/ct/tools/ct` (in the plugin, `skills/plan/ct/tools/ct`), or the `ct` that `BIN_DIR` links, so `ct <command>` works from any folder. `ct doctor` checks Python and LuaJIT. Never point an addon's files at a CheckThat checkout.

Paste this section into the addon's AGENTS.md and adjust the names:

```
## CheckThat

CheckThat runs the in-game test plan. Write plans with the /ct-test-plan skill and read finished runs with /ct-verify.

- **The plan lives here.** plans/<addon>.yaml is the plan of record. Change it in the same change as the log line, fact or entry it matches. Its first step checks the version under test. Never renumber or rename a step id.
- **Prefer automatic steps.** A check proven by a log line, a fact or an entry is an auto step. Keep a player step for what the log cannot show.
- **Log lines.** Each behavior a plan checks writes one line at its decision point with the values that prove it. Keep the wording stable: a reworded line is a plan change. Never log character names or chat text.
- **One integration file.** All CheckThat calls sit in one file, each guarded, so the addon works without CheckThat.
- **Declare the slash commands.** In the integration file, call CheckThat.Commands("<Addon>", { "/<prefix>" }) once at load, and list the same prefixes in the plan's commands, so the card offers them as Run buttons.
- **Before a tester runs a plan:** ct validate, ct compile, ct replay-flow, ct lines --addon-src <folder>, ct offline, then a review of the plan against what the card shows. Fix every finding.
- **Stay in this repository.** Run the tools; do not edit, create or leave files in CheckThat's. Write temporary copies only to the session scratchpad and delete them. When CheckThat lacks something, file an issue in the CheckThat repository (gh issue create -R <owner>/<repo>) and note it in the change, instead of patching locally.
```
