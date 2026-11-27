# Collect evidence

After a run, `/reload` or log out so the game writes the saved variables. Then read them on your computer with `tools/ct.py` (Python, on Windows, macOS and Linux: [Set up the tools](setup.md); the commands below use the macOS and Linux form `.venv/bin/python`).

`collect`, `status` and `report` decode saved variables with a Python reader. They do not need LuaJIT (a test checks that the reader gives the same JSON as `tools/sv2json.lua` on every fixture). `replay` and `offline` still need `luajit`. To judge a plan against a saved-variables fixture without the game, see [Check a plan against saved variables](authoring-plans.md#check-a-plan-against-saved-variables).

## Collect, check and report

```
.venv/bin/python tools/ct.py collect     # copy saved variables, runs, error stacks and screenshots into evidence/
.venv/bin/python tools/ct.py status      # is the evidence readable and complete?
.venv/bin/python tools/ct.py report      # write evidence/REPORT.md
```

- **Source.** `collect` reads `../shared-addon-resources/saved` by default. When that folder is missing, it looks in the usual game install folders for your system and prints the one it uses. `--wow <game dir>` (or `CT_WOW`) collects `_classic_era_` and `_forever_` with their `WTF` and `Screenshots` folders. `--src <WTF dir>` (or `CT_WTF`) names one folder and wins.
- **Doctor.** `ct.py doctor [--src <WTF dir>] [--wow <game dir>] [--plan <plan.yaml>]` prints each place `collect` would look, in the same order, and what is there: each client folder, the saved-variables files with their times, the Screenshots folder, and any other `_flavor_` folder with a `WTF` that `collect` does not read (only `_classic_era_` and `_forever_` are measured layouts). It says the likely reason for a miss, such as a path that is not a folder or a file the addon has not written yet (it writes after `/reload` or logout). It reads folder listings only, and exits 1 when `collect` would find nothing.
- **Which files.** With no plan, `collect` copies the saved variables of CheckThat, KeepThat, DontDoThat and ClosestVendor. `--plan <plan.yaml>` copies CheckThat's file, the file named for the plan's `addon`, and every file that assigns a `logs.*.global` of the plan, so a plan for any addon is collected. Each file prints its path, modified time and age (`source: ..., modified 2026-11-24 21:03:10, 12m ago`), so a stale copy shows. A plan global that no file defines prints a warning on stderr and `collect` still exits 0.
- **Report.** `REPORT.md` gives each run a `result:` line (`ok`, `UNVERIFIED` or `FAIL` with counts) and a table of every step: verdict, evidence (`met`, `bad`, `missing` or `none`), attempt count and note. Detail lines follow for steps that did not pass. A step that passed after a rerun lists its earlier failed or unverified attempts too. A failed or unverified attempt shows the Lua error that was raised while it was open, with its call stack. The match is by time (whole seconds), so a stack that also fits another attempt says so.
- **Status.** `status` prints one row per run at its newest readable revision: steps done over steps that apply, fail, unverified and open counts, age, and the export size as a percent of the 2 MB limit (`size~`, an estimate from the saved run). It names every revision file it cannot read and every conflict or decode failure `collect` met (kept in `evidence/problems.log`; delete the file once you have looked). It judges the evidence, not the test result. `--json` prints the same as JSON.
- **Compare runs.** `ct.py diff <run A> <run B>` and `ct.py trend` read the collected runs. See [Compare runs](#compare-runs).
- **Newer format.** A run saved in a newer major format is refused with its file name and the reason. `collect` stores nothing of it and writes `refused.json`. `status` lists it, `report` warns (it shows an older revision when there is one, and says when the run is missing), and `report --strict` fails until a later `collect` stores a revision at least as new. `import-results` refuses it before it reads anything else. Update the tools folder. See [Results format](results-format.md).
- **Exit codes.** `status` exits 0 when every revision is readable and nothing conflicts, 1 when there is no run, a revision is unreadable, a conflict was logged or a run is over 80% of the size limit. `report --strict` exits 1 when any step failed or is unverified (a pass or partial whose required evidence failed or has no result counts too), or when there are no runs. Without `--strict` `report` exits 0.
- **Browse.** `browse` (or `tools/ct_tui.py`) opens a read-only viewer in the terminal: runs (failures first), the steps of a run, and one step with its attempts. It needs a terminal and Textual, which is not installed with the plan tools: `.venv/bin/python -m pip install -r requirements-tui.txt`. Without a terminal it prints the `status`, `report --failed-only` and `show` commands that give the same facts. See [Browse the evidence](#browse-the-evidence).
- **Show.** `show <run>` prints one run, as the report does. `show <run> <step>` prints one step with every attempt, its log lines and its error stacks. `<run>` can be part of the run id when only one run matches. A wrong run or step name exits 2 and lists the choices.
- **Failed only.** `report --failed-only` keeps the runs and steps that failed or are unverified, the same steps `--strict` counts.
- **Watch.** `status --watch` prints the status again every `--interval` seconds (default 5) until Ctrl-C. It exits with the last status code. Use it while you collect and fix. It does not go with `--json`.
- **Check detail.** Under a failed attempt the report names each check that did not pass: the rule, the counts, and the lines that decided it (`line 7: ...`). The same lines are marked `>` in the log lines kept for the attempt. `--format json` has them as `checks` on each step, with positions and counts; `--lines` adds the text, the values and the full rule (without it a rule shows as its `shape`, with the plan's literals left out). JUnit gives the same checks of the attempt the result comes from. A passing attempt that kept a failed diagnostic is listed too. How the data is laid out: [Which lines decided a check](features.md#which-lines-decided-a-check).
- **Formats.** `report --format json` prints the steps, counts and categories as JSON. `report --format junit` prints JUnit XML for a CI job: a suite for each run and category, a case for each step. Fail and unverified are failures (the `type` says which). Pending, skip, deselected and not-for-this-client steps are skipped with the reason. Partial passes and keeps its note in `system-out`. With `--stacks`, a step that failed and later passed lists the stacks of its failed attempt in `system-out`, and json holds them under `attemptStacks` for each attempt. A stack whose time fits two attempts says so. A step reopened by Undo or a rerun reads "awaiting retry" with evidence `none` in the table, not its older note and evidence. Json and junit give it the same reason, and json adds `awaitingRetry`. For json and junit, `--out <file>` writes the file instead of printing. Call stacks can hold private paths, so json and junit leave them out unless you add `--stacks`.
- **Log lines.** A run keeps about 60 000 bytes of log lines in failed attempts. When it holds more, the oldest attempts lose theirs first. They keep their attempt records.
- **Results string.** Paste one from `/ct export` with `.venv/bin/python tools/ct.py import-results "<string>"`. A file path works too.
- Keep `evidence/` out of Git.

## Client census

`/ct census` in the game saves the names of that client (see [Client census](features.md#client-census)). Wait for "Client census complete", type `/reload`, then export it:

```
.venv/bin/python tools/ct.py census [--wow <game dir> | --src <WTF dir>] [-o <folder>]
.venv/bin/python tools/ct.py census --diff tests/manifests/era-1.15.8.json tests/manifests/era-1.15.9.json
```

- `census` reads CheckThat's saved variables, the same way `collect` finds them, and writes `tests/manifests/<client>-<build>.json` for the census each file holds (`era` below interface 16000, `forever` from 16000). Each file keeps only the newest census of its client. It prints each path. `-o` picks another folder. The census holds only names the game defines. Only when the census says `unfiltered` does the command drop the globals that start with a loaded addon's folder name (a guess).
- A manifest has `format`, `client`, `build`, `interface`, `date`, `addons`, `globals` (name to type), `tables` (member name to type), `widgets` (method names, sorted by this command), `unavailable` and `truncated` (tables cut at 2000 members), and `unfiltered: true` when the client could not tell every game name from an addon's.
- `--diff OLD NEW` prints `+` for names only in the new manifest, `-` for names only in the old one and `~ name: old -> new` for a changed type, for globals, table members (`member C_X.Y`) and widget methods (`method Frame:SetPoint`), then a count line.
- The manifests stay local: Git ignores them, because they also hold the loaded addons and the globals those addons set. The strict fake client uses a reviewed slice instead: `python3 tools/client_slice.py tests/manifests/<client>-<build>.json <wow-ui-source checkout> --review <file> > tools/clients/<client>.json` keeps only global functions, the functions of `C_` namespaces and widget methods. `--review` writes the names Blizzard's source does not confirm. An `unfiltered` census also needs `--unfiltered-ok`, given after reading those lists. Review the slice before committing it. `python3 tools/template_slice.py tools/clients/<client>.json <wow-ui-source checkout> <template> ... -o tools/clients/<client>.json` then adds the `templates` key (add `--tooltip-hooks script|processor` to write the measured tooltip hook path of the client; a new census slice drops both keys, so run the tool again): the mixin methods and child keys of each named template, read from Blizzard's XML and Lua, so the fake client knows what a templated frame has.
- With no census in the files it exits 1 and says: Run /ct census, wait for completion, type /reload, then copy SavedVariables again. A damaged file or an unreadable manifest also exits 1.

## Coverage of the evidence

`ct.py coverage <plan...> --addon-src <folder> --evidence` joins the newest finished run of each plan to the addon's subcommands, settings and spec requirements: `passed`, `failed` (failed or unverified) or `never-run`; the result describes plan steps, not unit tests. See [Check what the plans cover](authoring-plans.md#check-what-the-plans-cover).

## Record calls for plan mocks

Plan authors use the recordings already in `tools/recordings/`. Making a new one is the maintainer's job for now: CTProbe is not published, and the calls it records are fixed in its source (#214 tracks opening this up).

`ct.py recordings --src <CTProbe.lua>` turns the CTProbe saved variables into `tools/recordings/<client>.json`. In game, run `/ctp record` on a client, then `/reload` and log out so the game saves the file, and point `--src` at `CTProbe.lua` in that client's `WTF/Account/<account>/SavedVariables`. The client comes from the recorded `GetBuildInfo()`. The recording keeps each call's api, arguments (read from its label), return values and count; a `nil` return is listed in `nils`. It leaves out a call that raised an error, a call on the player, a value CTProbe recorded by type only (money, item counts, names, the realm) and a return that is a table or a function. It empties the level and specialization fields of an item link. The file names no character or realm, and a test checks that. A plan then mocks from it with `{ recording: "GetItemInfo(6948)" }` ([Write a plan](authoring-plans.md)).

Vendor, trainer and auction calls return nothing unless their window is open, so CTProbe records them on the window's events. In game: `/ctp record`, then `/ctp record arm`, open a vendor that sells armor or weapons and close it, open a vendor that sells goods, open a class trainer and a profession trainer, open the auction house and search, then `/reload` and log out. `/ctp record status` names the scenes still waiting before you leave. Arming lasts until the next reload, and it first clears the window rows of an earlier run, so two vendors never mix.

Each window kind has scenes. A vendor that sells armor or weapons fills `gear`, any other vendor the plain vendor scene. A class trainer (`IsTradeskillTrainer()` answers nil or false) fills `class`, a profession trainer the plain trainer scene. The auction list has one scene. The plain scene keeps labels such as `GetMerchantItemInfo(1)`; the other scene's labels start with its name, such as `gear:GetMerchantItemInfo(1)` or `class:GetTrainerServiceInfo(4)`. One opening of a window fills one scene, and each later update of that opening records it again, so the last update wins: names and links that arrive late, or an item the client delivers while the vendor is open, are kept. A trainer's header rows are skipped and the real index stays in the label; a class trainer keeps ten rows, the others three. A trainer with no rows, or only headers, records nothing and says to tick Unavailable and Used in the trainer's filter. Each trainer scene also stores `IsTradeskillTrainer()` and the three `GetTrainerServiceTypeFilter` answers. The auction scene waits until every row has all its information (return 18). A client without the auction event (Forever) gets an error entry at arm.

`ct.py recordings` keeps the `window` tag (`merchant`, `trainer` or `auction`) on those calls and writes `"rev": 4` (`format` stays 1; rev 2 added the tag, rev 3 the scene names, rev 4 `source`). Such a recording is a sample from one vendor, trainer or auction house, not fixed data. An auction row loses its bidder and seller names, and an item link loses the level, specialization and uniqueID fields. Each vendor row's item also gets `GetItemInfo` and `C_Item.GetItemInfo`, tagged `merchant`. A call a client lacks, and one that returns a table (the Forever auction house and `C_MerchantFrame.GetItemInfo`, #234), is listed as left out. `BuyMerchantItem` is never recorded: a plan checks a purchase with a spy in the fake client. `/ctp record` keeps `GetMoney()` by type only. Beside each vendor and trainer scene the balance is kept with its value (`gear:GetMoney()`, `trainer:GetMoney()`), so a cost check has a real amount; a balance names no character.

### Signatures and entries not recorded in game

`tools/recordings/signatures.json` says what each recorded call returns on each client: the return names in order, their types, the positions that may be nil (`nilable`) and those that answer 1 or nil (`oneornil`), with the Blizzard source line in `ref`. Which functions a client has comes from the census in `tools/clients/`, not from Blizzard's UI source: Forever has `GetTrainerServiceLevelReq` although its own trainer window never calls it. A test fails when a committed recording does not fit its signature, and `ct.py recordings` lists each call that does not fit (`differs from signature`), so a client change shows without another run.

A recording may also hold calls that were not recorded in game. Such a call has `source`: `{ "kind": "source" | "wiki" | "database" | "authored", "ref": "where it came from" }`. A call without `source` was recorded in game. A plan mocks from either kind the same way. When a run records a call that has `source`, `ct.py recordings` prints `confirmed` when the game agrees in count, nils and types, or `changed` when it does not, and the game's entry replaces it. A run that lacks a call the file has prints `dropped`; `--merge` keeps those calls. The class trainer rows on both clients are `authored` for now: their shape follows the signatures, and their costs and textures are made up.

The vendor, trainer and auction calls above can be mocked in an offline block (`Runner.MOCKABLE`), for example `GetTrainerServiceInfo: { recording: "class:GetTrainerServiceInfo(2)" }`. What each client provides is in [contracts](contracts.md#vendor-trainer-and-auction-calls-source-reviewed-2026-11-26).

## Compare runs

```
.venv/bin/python tools/ct.py diff <run A> <run B> [--format md|json] [--strict] [--include-open]
.venv/bin/python tools/ct.py trend [--addon X] [--title T] [--by client|character|build|version|target] [--last N] [--format md|json] [--include-open]
```

Both read the newest readable revision of each collected run. Each step is judged as `report` judges it, so a pass with a contradicted check counts as a fail. A run id can be a part of the id that names one run.

- **Diff labels.** `regressed` (pass or partial, then fail), `fixed` (fail or unverified, then pass or partial), `newly-unverified` (pass, then unverified), `still-failing`, `not-comparable` (one side is pending, skipped, deselected, not for that client or reopened), `added` and `removed` (a step id only one run has). Unchanged steps are counted, not listed. The header names each run's client, build, character, plan digest, CheckThat version and tested addon version, and says "plan changed" when the digests differ.
- **Exit codes.** `diff` exits 0 and, with `--strict`, 1 when a step regressed. It exits 2 for an unknown run, a run that was left out, or a run that has not ended.
- **Unfinished and newer runs.** A run that has not ended is left out unless you add `--include-open`. A run in a newer format is never read: `diff` refuses it by name, and `trend` leaves it out and lists it as a warning.
- **Same plan, same step?** Equal plan digests mean equal steps. Otherwise the tool compares a fingerprint (a hash of the whole step) from the plan the run stored. The plans come from the collected CheckThat saved variables (`planStore`). A changed step is `not-comparable` (`~` in a trend). When a plan is not stored, the step is `not-comparable` (`?` in a trend) and a warning names the digest. The tool never guesses.
- **Trend.** One table for each addon and plan title, so plan edits stay in one table. Columns are runs, oldest first, named 1, 2, 3 and listed above the table; `--by` adds that value of each run to its line (`version` is the CheckThat version that wrote the run, `target` is the version of the addon under test). `--last` keeps the newest runs. Cells are `P` pass, `p` partial, `F` fail, `U` unverified, `-` not run, blank for no such step. A step that passed in one run and failed or went unverified in another is marked `flaky`. It exits 2 when no run matches.
- **Limits.** Runs that CheckThat pruned before `collect` are not there. A run saved before 0.19.0 does not record the version of the addon under test: it shows as `?` in a diff and has no label in a `--by target` trend.

## Drift ledger

`ct.py drift <plan> --dest evidence` shows where the fake client was wrong. Name the plan steps an offline block predicts in `offline.predicts` (see [authoring plans](authoring-plans.md)), and give the block a TOC for each client in `tocs`. The command runs the block for each client, takes a pass for a plan step when all its offline steps pass, and compares that with the same step in each collected run of that client.

- It prints, for each client, how many predictions the runs confirmed, and one `drift` line for each wrong one: the run, the step, what was predicted, what happened, and the offline steps. A step the run left unverified or skipped is not compared.
- A drift line is a lead, not a verdict: the addon may have a bug the fake client cannot show, or the fake client may be wrong. A step that drifts again on the same client is a fake-client bug: reproduce it with a test in `tests/harness.lua` and add the measured behaviour to `docs/contracts.md`.
- `--expect-version <addon version>` leaves out runs of another addon version, which say nothing about this checkout. A partial result counts as a pass. A block that cannot run (a failed load, a mock the client does not allow) stops the command with that error instead of predicting a fail.
- `--strict` exits 1 when a prediction was wrong or no step was compared. `--format json` gives the same data to a script.
- `replay-flow` is not used: it writes the log lines a plan expects itself, so it proves the plan and cannot be wrong about the game.

## Browse the evidence

```
.venv/bin/python -m pip install -r requirements-tui.txt   # once
.venv/bin/python tools/ct.py browse
```

The viewer only reads. Collect in a shell, as before. The screen reloads when the evidence folder changes, and `r` reloads at once.

| Screen | Shows | Keys |
| --- | --- | --- |
| Runs | A strip counts the runs: failing, unverified and no flags (each run counts once, fail first), and shows the first problem `status` finds. Each row has a result word and mark (`✗ FAIL`, `? UNVER`, or `—` for no flags), the run id and steps done over steps that apply. From 76 columns it adds plan, revision, fail and unverified counts and age. Failures first, then unverified, newest first. | Enter opens a run |
| Steps | A header with the run result and counts, and the filter. From 76 columns it adds a chip for each category (`✗` red, `?` yellow, `✓` green, `…` still open, `·` empty, `–` not picked) with steps done over total. A chip follows the evidence, so an overturned pass makes it red. Each row has a result word and mark and the step id. From 76 columns it adds category and reason. A filter with no match says "No matching steps". | `f` cycles all, fail, unverified. `/` cycles the categories. Enter opens a step. Esc goes back. |
| Step | A colored banner with the result (red fail, yellow unverified, green pass) and the player's verdict. It warns when the evidence overrules a pass. Below it an attempt strip (the shown attempt is filled, an open one is hollow) and one attempt: its facts, the note, a table of required and diagnostic checks, the log lines kept with line numbers, and each error raised while it was open with its stack, frame by frame. | `[` and `]` move between attempts. Esc goes back. |

Everywhere: `e` shows what an export will write (scope, format, file, stacks) and writes it on Enter. `c` shows the collect command. `?` shows the keys. `q` quits. Marks and words carry every state, so nothing depends on color. `NO_COLOR` turns color off. Evidence shows as plain text. Stacks stay out of a JSON or JUnit export until you press `s`, because they can hold private paths.

## Local paths

`tools/ct.py` reads `KEY=VALUE` lines from `$CT_ENV`, `.ct.env` in the working folder (git-ignored) and `~/.checkthat.env`, in that order. A variable already set wins, and a flag wins over both. `CT_WOW` is the game folder. `CT_WTF` and `CT_SHOTS` name one folder each.

## Screenshots

Set `screenshot: true` on a step. The card asks for Print Screen. The addon never captures. `collect` copies screenshots taken inside an attempt's time window (`--shots <folder>`, default `Screenshots` beside `--src`). `--shot-slack SECONDS` (default 2) widens or narrows each window on both sides. A file taken outside every window but within an hour of an attempt is not copied. `collect` counts these files on every run ("2 screenshots matched no attempt"). `--verbose` names each one with the nearest step and the gap in seconds. `--all-shots` copies them to `runs/<id>/unassigned-shots/` of the nearest run. No step lists them. With `--wow`, a folder prefers the runs of its own client. Measured on an SMB-mounted game folder: 191 screenshots, file time minus the game clock in the file name was 0 s (19 files) or 1 s (172 files), so the default slack of 2 s holds on a mount. `collect` prints the gap of the nearest loose file and suggests a `--shot-slack` value when it is within two minutes of an attempt. Raise `--shot-slack` to that value.

## Classic Era per-character data

Some addons keep a log per character. On Classic Era, ClosestVendor's `ClosestVendorCharDB` is one. A copy that takes only account-level saved variables misses it. Run `collect --src "<WoW>/_classic_era_/WTF"` against the real folder instead.

## Windows and other computers

Windows works like any other system: [Set up the tools](setup.md) lists the Python install and the `.venv\Scripts\python` form of each command here. `collect` finds the game in its usual folder, or takes `--wow`. It copies the saved variables (including Era per-character files) and screenshots. No step needs LuaJIT. If the game is on another computer, copy the `WTF` and `Screenshots` folders of each client and point `--wow` at the copy.

## Categories in the report

`report` prints a `categories:` line for each run that holds categories: blue, yellow, red, green or grey with the count of steps with a result over picked steps, or "not picked". Steps of a category that was not picked read `deselected` and are not counted as unverified. A run saved before categories prints no such line.
