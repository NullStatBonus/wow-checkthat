# Plan skills

Two skills help addon developers write plans and read finished runs back. They are plain `SKILL.md` folders and developer tools. They are separate from the in-game `/ct` commands.

- **`ct-test-plan`** interviews you one question at a time and drafts a plan one step at a time.
  - By default each step has one action and one expected result. Ask for a compound step when you need one.
  - A check that needs several characters becomes one plan for each character role, named `<name>.<role>.yaml`. Each preamble names every partner plan.
  - Examples: `skills/ct-test-plan/keepthat-tally.bank.yaml` and `keepthat-tally.alt.yaml`.
- **`ct-verify`** reads a finished run back against its plan.
  - It collects the saved variables (or reads an `/ct export` string), matches each step to its recorded result and evidence, and compares runs across characters.
  - It reports pass, fail, unverified and contradicted steps.
  - It never edits a plan and never runs the game.
  - Collected evidence goes to a folder you name, `evidence/` by default. Keep it out of Git.

Ask in plain words: "write a CheckThat test plan for this branch", or "verify my CheckThat run".

## Install

Run this in the CheckThat checkout:

```
make install-skill                              # Claude Code: ~/.claude/skills/
make install-skill SKILL_DIR=~/.codex/skills    # Codex: its skills folder
make install-skill SKILL_DIR=<folder>           # any other agent that reads SKILL.md folders
```

- Each run installs both skills into `<folder>/ct-test-plan` and `<folder>/ct-verify` and replaces an earlier copy. Run it once for each agent you use.
- `SKILL_DIR` must be outside the checkout.
- The install includes a copy of the plan tools, the decoder files that `collect` needs, and a private Python with PyYAML and jsonschema. The skills then work in any addon repository with no checkout.
- It needs Python 3 with `venv`, and network access once.
- `ct-verify` also needs `luajit` on your PATH to read saved variables. `collect` exits with an error and names the file when it cannot decode one.
- The two skills must sit in the same folder, because `ct-verify` finds the tools in `../ct-test-plan/ct`.
- Run the install again after the tools change. Each skill reports the tools version it uses.

Tested with Claude Code only. Codex and other agents read the same `SKILL.md` format, but each one picks its own skills folder. Check its documentation for the folder it reads and pass that folder as `SKILL_DIR`.

## Claude Code plugin

`make build-plugin` builds a Claude Code plugin in `build/plugin/` (`PLUGIN_DIR=<dir>` changes the target) with both skills, the plan tools and the version stamp.

- Load it for one session with `claude --plugin-dir build/plugin`.
- Its commands are `/checkthat:plan` and `/checkthat:verify`. The installed skills run as `/ct-test-plan` and `/ct-verify`.
- A plugin has no private Python. The skills use `python3` when it imports PyYAML and jsonschema, and print the command that creates an environment when it does not.
- The plugin is not published yet (#53). `make install-skill` is the install for other repositories.
