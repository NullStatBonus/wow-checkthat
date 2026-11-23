# Tasks

## 1. ClosestVendor assertions (#13)

- [x] 1.1 Ask the player for one in-game run of the sample steps with `/cvn debug on`, then `/reload` at the end. Collect with `python3 -I tools/ct.py collect`. Verify: the saved log holds lines for the sample's commands.
- [x] 1.2 For each sample step with a measured line, add a labelled required log assertion. Verify: `python3 -I tools/ct.py validate plans/closestvendor.yaml` prints ok.
- [x] 1.3 Record each measured line in `docs/contracts.md` under "Measured from saved variables". Verify: the table row names the log path and the date.
- [x] 1.4 Rebuild the sample plan string if the repo ships one. Verify: `make test`.
- [x] 1.5 Comment on #13 with any step left without a measured line.

## 2. Close out

- [x] 2.1 `make test` and `make check` pass.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
- Close #13 only when every sample step that can be asserted is.
