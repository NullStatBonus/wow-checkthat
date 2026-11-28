# Tasks

## 1. One bundle step

- [x] 1.1 Add `tools/bundle.sh <dest-ct-dir>`, which copies `BUNDLE` and `BUNDLE_DIR` and writes `VERSION`. Switch `install-skill` and `build-plugin` to it, and verify the existing install and plugin tests in `tools/test_ct.py` pass unchanged.
- [x] 1.2 Add `make build-toolkit`, which writes `build/toolkit/{ct-test-plan,ct-verify}` and `build/CheckThat-toolkit-<version>.zip` (Python `zipfile`, mode bits kept). Add a test that unzips it, runs `ct-test-plan/ct/tools/ct validate` on a sample plan, and checks that `ct-verify` resolves `../ct-test-plan/ct`.
- [x] 1.3 Add a test that the `ct/` folders from `install-skill`, `build-plugin` and `build-toolkit` hold the same files with the same contents. Break one target's copy, see the test fail, then restore it.

## 2. Python and LuaJIT

- [x] 2.1 Add `ct setup` (standard library only): build the venv in a temporary sibling of the per-user path, `pip install -r requirements.txt`, rename it into place, and name `venv` or network access on failure. Test it with a fake `pip` and the data path set through `XDG_DATA_HOME`/`LOCALAPPDATA`, including an earlier environment kept after a failed run.
- [x] 2.2 Add the per-user environment to the `tools/ct` launcher lookup after the private Python and before `python3`. Test the order with both present and with only the per-user one.
- [x] 2.3 Update the Python lookup in `skills/ct-test-plan/SKILL.md` and `skills/ct-verify/SKILL.md` to the same order, and name `ct setup` where they now print the venv commands. Update `test_skills_state_the_python_fallback`.
- [x] 2.4 Add the `ct doctor` tools section: tools version, the Python in use and its PyYAML and jsonschema imports, `luajit` on the path, and the platform fix for each miss. Test that the exit code is the same with and without LuaJIT on the path.
- [x] 2.5 Extend the `run_luajit` error with the platform command and `ct doctor`, keeping the current start. Test the text with `luajit` absent from `PATH`.
- [x] 2.6 Add `setup` to the stable commands in `docs/tools-guide.md`.

## 3. Marketplace and release

- [x] 3.1 Add `.claude-plugin/marketplace.json` (`name`, `owner.name`, `description`, one `checkthat` entry with the `github` source and `ref: plugin`), and add `.claude-plugin` to `.pkgmeta` `ignore`. Add a test, skipped without `claude`, that runs `claude plugin validate` on the repository root.
- [x] 3.2 In `release.yml`, for a tag: run `make build-plugin` and `make build-toolkit`, install the Claude Code CLI, and run `claude plugin validate` on the plugin and the root. Then commit the plugin to the `plugin` branch through a worktree (create the branch as an orphan when it does not exist, never force-push), and attach the toolkit zip in `gh release create`. Validation runs before the packager uploads anything.
- [x] 3.4 Publish without a tag: a `publish` input on the manual run (main only) commits the plugin branch and replaces the toolkit zip on the current version's release with `--clobber`. The plugin version is the addon version plus `+<short commit>`. Tests cover the step conditions, the commit message from `plugin.json` and the version format.
- [x] 3.3 Add `workflow_dispatch` to `release.yml`: build and validate both outputs and upload them as workflow artifacts, with every publish step gated (see 3.4). A manual run needs the workflow on `main`, so the first run is a follow-up below.

## 4. Docs

- [x] 4.1 `docs/skills.md`: lead with the marketplace install (`claude plugin marketplace add NullStatBonus/wow-checkthat`, `/plugin install checkthat@<marketplace name>`) and the zip install, then `ct setup` and `ct doctor`. Keep `make install-skill` as the checkout install. State that `tests/` in the bundle is internal, with #273.
- [x] 4.2 Update `docs/adopting.md`, `docs/setup.md` (LuaJIT install for each platform, `ct setup`), `docs/publishing.md` (the plugin branch, the toolkit asset, the dry run), `README.md` (one line for each install) and `docs/listing.md` (developer section: how to install). Run the README and listing tests in `make test`.
- [x] 4.3 Run `make test` and `make check`, and confirm that `git diff --stat` shows no file under `CheckThat/`, so there is no version bump.

## Workflow follow-up

- After merge, run the Release workflow on `main` with `publish` off. Confirm that nothing is published. Record whether `claude plugin validate` needed a sign-in, and file an issue if it did.

- After merge, run the Release workflow on `main` with `publish` set (no tag needed), then install from the marketplace in a clean Claude Code profile and run `/checkthat:plan` on a sample plan. Unzip the toolkit into a second agent's skills folder and validate a plan. If the `github` ref source fails, switch to the fallback layout in design.md.
- Close #53 after that install check passes.
- Archive the change without a version bump.
