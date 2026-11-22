# Design

## Context

Today `install-skill` stamps `.wtt-root` and the skill calls `python3 $WTT/tools/wtt.py`. `wtt.py` finds the schema through `ROOT` (two folders above itself), so a copy of `tools/` and `schema/` in a mirrored layout works unchanged. See proposal.md.

## Goals / Non-Goals

**Goals:**
- Skill works with no checkout and no preinstalled Python packages.
- One command installs and updates it.

**Non-Goals:**
- No PyPI package, plugin marketplace or shared plugin (issue #18).
- Bundle excludes `collect`/`report` support (`sv2json.lua`, luajit); the skill never calls them.
- No automatic update when the checkout changes; re-run `make install-skill`.

## Decisions

- **Mirrored bundle under `wtt-test-plan/wtt/`**: `tools/wtt.py`, `schema/…`, `docs/test-plan.md`, `openspec/specs/test-plan-format/spec.md`, `TestThat/Model/Plan.lua`, `requirements.txt`, `VERSION`. Needs no code change in `wtt.py`. Alternative: edit `wtt.py` to find the schema elsewhere. Rejected: more code, same result.
- **Private venv at `wtt-test-plan/.venv`**, built in the temp folder and moved with the rest. A moved venv keeps working because `bin/python` finds `pyvenv.cfg` beside it; we call only `.venv/bin/python -m`, never pip scripts. Alternative: `pip install --target`; rejected, because it ties the packages to one interpreter path style and needs sys.path edits in `wtt.py`.
- **Drop `.wtt-root`.** The bundle replaces it. The skill lookup order is bundle, then checkout two folders up (developer run from the repo).
- **Version stamp** is the TOC `## Version:`, so the skill can report which tools it ran and a stale install is visible.
- **Fail early, keep old copy.** The existing temp-folder-then-`mv` flow covers every step, including the venv.
- **Output path default** loses "plans/ in the TestThat checkout". The skill asks, and suggests the target addon repo's docs folder only if it exists.

## Risks / Trade-offs

- [Install needs network once] → clear error naming the step; README documents it.
- [Bundle goes stale after a checkout update] → version stamp in the report; README says re-run install.
- [Moved venv breaks on a future Python layout change] → test runs the installed Python after the move.
- [Unit tests cannot rely on network] → tests skip the pip step with a `SKILL_NO_VENV=1` variable and cover the failure path with an unreachable index. One manual check runs a real install.
