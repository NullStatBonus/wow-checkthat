# Plan skills

Two skills help addon developers write plans and read finished runs back. They are plain `SKILL.md` folders and developer tools. They are separate from the in-game `/ct` commands.

- **`ct-test-plan`** interviews you one question at a time and drafts a plan one step at a time. For an offline block it prefers a mock replayed from a call recorded in game (`tools/recordings/`, or the addon's own folder recorded with CTProbe's `/ctp record <call>`, see [Harvesting](authoring-plans.md#record-your-own-calls)) to a hand-written return value.
  - It scopes first: a plan checks only what a fake game cannot prove, so a check a unit test proves gets no step. It drafts the essential steps first, never a one-for-one conversion of a manual document.
  - It asks first what the plan is for. A foundation plan is the release gate: one step per pillar, about 8 to 12 steps, for one character of any class in one place. A feature plan goes deep on one feature and runs when that feature changes. It sets `purpose` on the plan.
  - Steps are in player language: commands only behind Run, and Expect says what is on screen, never what is logged.
  - A plan has at most 25 steps and a section at most 10. A larger feature scope becomes a plan set by area, run one plan at a time.
  - A plan that depends on the addon's settings uses a test-settings mode in the addon (see [Test settings](authoring-plans.md#test-settings)).
  - By default each step has one action and one expected result. Ask for a compound step when you need one.
  - Before a plan goes to a tester it runs a gate: `validate`, `compile`, `ct.py replay-flow`, `ct.py lines`, the `offline` block, and a review against what the card shows, with every finding fixed.
  - After a run it revises the plan: it sorts each failing step into plan fault, addon fault or unknown, edits only plan faults, and says whether to `/ct rerun failed` or import the new plan.
  - A step id is a key: never renumber or rename one. `ct.py diff` marks a step that kept its text but changed its id as renamed.
  - A check that needs several characters becomes one plan for each character role, named `<name>.<role>.yaml`. Each preamble names every partner plan.
  - Examples: `skills/ct-test-plan/keepthat-tally.bank.yaml` and `keepthat-tally.alt.yaml`.
- **`ct-verify`** reads a finished run back against its plan.
  - It collects the saved variables (or reads an `/ct export` string), matches each step to its recorded result and evidence, and compares runs across characters.
  - It checks the evidence folder first (`ct.py status`), then reports pass, fail, unverified and contradicted steps, with earlier failed or unverified attempts and error stacks.
  - `ct.py browse` opens a read-only terminal viewer of the collected evidence. It is optional and needs Textual.
  - `ct.py coverage <plan> --addon-src <folder> --evidence` shows which subcommands, settings and spec requirements the plans and the unit tests (`-- covers:` comments) cover, and whether the newest run passed them.
  - `ct.py drift <plan> --dest evidence` compares what a plan's offline block predicted for each step with the collected runs, for each client, and lists the wrong predictions (see [Drift ledger](harvesting.md#drift-ledger)).
  - `ct.py diff <run A> <run B>` shows which steps regressed, were fixed or are no longer comparable between two runs. `ct.py trend` shows many runs and marks flaky steps.
  - `ct.py report --format json` or `--format junit`, with `--strict`, gives results to a script or a CI job.
  - `ct.py report --addon-src <addon folder> --plan <plan file>` (or `--expect-version <addon version>`) warns about a run of another addon version, a run written by another CheckThat version than the tools, and a run made from an older plan file.
  - It never edits a plan and never runs the game.
  - Collected evidence goes to a folder you name, `evidence/` by default. Keep it out of Git.

Ask in plain words: "write a CheckThat test plan for this branch", or "verify my CheckThat run".

## Install

Pick one. None needs a CheckThat checkout except the last.

- **Claude Code plugin.** Run `claude plugin marketplace add NullStatBonus/wow-checkthat`, then `claude plugin install checkthat@checkthat` (or `/plugin install checkthat@checkthat` in a session). The commands are `/checkthat:plan` and `/checkthat:verify`. Updates come with each publish. The plugin version is the CheckThat version plus the commit, such as `1.0.0+3f9c2a1b7d4e`.
- **Toolkit zip, for any agent.** Download `CheckThat-toolkit-<version>.zip` from a GitHub release and unzip it into your agent's skills folder: `~/.claude/skills` for Claude Code, `~/.codex/skills` for Codex, or the folder your agent reads. It holds `ct-test-plan` and `ct-verify`, side by side. If the extractor drops the exec bit, run the launcher as `sh ct-test-plan/ct/tools/ct`.
- **From a checkout.** `make install-skill`, below.

The plugin and the zip have no private Python. Run `python3 <tools>/ct.py setup` once, where `<tools>` is the folder that holds `ct.py`: `ct-test-plan/ct/tools` in the zip, `skills/plan/ct/tools` in the plugin (under `~/.claude/plugins/cache/checkthat/checkthat/<version>/`). It creates a Python with PyYAML and jsonschema in your user data folder (`~/.local/share/checkthat/venv`, or `%LOCALAPPDATA%\checkthat\venv` on Windows), and a plugin update keeps it. It needs Python 3 with `venv`, and network access once. The `ct` launcher and the skills use it when no private Python is beside the skill.

`<tools>/ct doctor` (or `ct doctor` when the launcher is on your `PATH`) ends with a tools section: the tools version, the Python in use and its packages, and whether `luajit` is on the path, with the install command for each missing one. `replay`, `replay-flow`, `offline`, `drift` and `coverage --harness` need LuaJIT. The rest of the tools do not.

The bundle's `tests/` files serve the plan commands (`replay-flow`, `offline`). They are internal and not a contract for your addon's own tests. The public part is the `ctx` of offline hook steps ([Lua hooks](authoring-plans.md#lua-hooks-level-5-and-later)); a full fake-client library is #273.

### From a checkout

Run this in the CheckThat checkout:

```
make install-skill                              # Claude Code: ~/.claude/skills/
make install-skill SKILL_DIR=~/.codex/skills    # Codex: its skills folder
make install-skill SKILL_DIR=<folder>           # any other agent that reads SKILL.md folders
```

- `make install-skill BIN_DIR=<folder on PATH>` also links a `ct` launcher there (a folder outside the checkout; write `$HOME/bin`, not `~/bin`), so you can type `ct validate plans/x.yaml`. `tools/ct` inside the install does the same without it: it picks the skill's Python, then `python3`.
- The bundle holds the whole addon folder, the fake-client harness, the replay and the offline runner, so `ct.py replay-flow`, `ct.py lines` and `ct.py offline` run with no CheckThat checkout.
- Each run installs both skills into `<folder>/ct-test-plan` and `<folder>/ct-verify` and replaces an earlier copy. Run it once for each agent you use.
- `SKILL_DIR` must be outside the checkout.
- The install includes a copy of the plan tools, the decoder files that `collect` needs, and a private Python with PyYAML and jsonschema. The skills then work in any addon repository with no checkout.
- It needs Python 3 with `venv`, and network access once.
- `ct.py replay` (see [Check a plan against saved variables](authoring-plans.md#check-a-plan-against-saved-variables)) also needs `luajit`.
- `ct-verify` reads saved variables with a Python reader and needs no `luajit`. `collect` exits with an error and names the file when it cannot decode one. `collect --plan <plan>` collects the files the plan's logs read, for any addon.
- The two skills must sit in the same folder, because `ct-verify` finds the tools in `../ct-test-plan/ct`.
- Run the install again after the tools change. Each skill reports the tools version it uses.

Tested with Claude Code only. Codex and other agents read the same `SKILL.md` format, but each one picks its own skills folder. Check its documentation for the folder it reads and pass that folder as `SKILL_DIR`.

[Adopt CheckThat in an addon repository](adopting.md) has the AGENTS.md section to paste into an addon that uses the skills.

## Build the plugin and the toolkit

`make build-plugin` builds the Claude Code plugin in `build/plugin/` (`PLUGIN_DIR=<dir>` changes the target) with both skills, the plan tools and the version stamp. `make build-toolkit` builds the toolkit zip as `build/CheckThat-toolkit-<version>.zip` (`TOOLKIT_DIR=<dir>` changes the folder, and the zip goes beside it). `make install-skill`, `build-plugin` and `build-toolkit` copy the bundle with one script (`tools/bundle.sh`), so the three hold the same files.

- Load the built plugin for one session with `claude --plugin-dir build/plugin`.
- Its commands are `/checkthat:plan` and `/checkthat:verify`. The installed skills run as `/ct-test-plan` and `/ct-verify`.
- A tag, or a manual publish run with no tag, publishes both: the plugin to the `plugin` branch, which `.claude-plugin/marketplace.json` names, and the zip on the GitHub release ([Publishing](publishing.md)).
