.PHONY: test test-lua test-py build check install-skill build-plugin mutate

PY := .venv/bin/python
SKILL_DIR ?= $(HOME)/.claude/skills
BIN_DIR ?=

test: build test-lua test-py

build:
	@mkdir -p build
	@for p in dontdothat selftest checkthat-0.8 checkthat-0.16 checkthat-0.17 checkthat-0.20 checkthat-0.20.1 checkthat-0.21 checkthat-0.16-picker checkthat-picker-fixture checkthat-openrun.owner checkthat-openrun.viewer; do $(PY) tools/ct.py compile plans/$$p.yaml -o build/$$p.ct || exit 1; done
	@# the Lua tests open build/keepthat.ct, built from a fixture because KeepThat owns its plan
	@$(PY) tools/ct.py compile tests/fixtures/keepthat.yaml -o build/keepthat.ct

# luajit tests/run.lua [file-pattern [test-name]] runs a subset (an unmatched test name fails); each file also runs alone: luajit tests/test_json.lua
test-lua:
	@luajit tests/run.lua

# On demand, never part of make test: change CheckThat/ one small way at a time and list the changes the tests miss.
# make mutate LIMIT=300 (a seeded sample; LIMIT=0 runs every mutant, about 5500) FILES='CheckThat/Core/*.lua'
mutate: build
	@$(PY) tools/mutate.py --limit $(or $(LIMIT),100) $(if $(FILES),--files '$(FILES)')

test-py:
	@PYTHONDONTWRITEBYTECODE=1 $(PY) -m unittest discover -s tools -p 'test_*.py'

# Install the ct-test-plan and ct-verify skills with everything they run, outside this checkout: the skill text,
# a bundle of the plan tools (same layout as the checkout), and a private Python with PyYAML and
# jsonschema. SKILL_DIR changes the target; SKILL_NO_VENV=1 skips the pip step (tests).
BUNDLE := tools/ct.py tools/ct schema/test-plan.schema.json docs/test-plan.md docs/authoring-plans.md docs/debug-logging.md openspec/specs/test-plan-format/spec.md tools/sv2json.lua tools/replay_sv.lua tools/entry_runner.lua tools/dump_options.lua tools/lua51_check.lua tests/harness.lua tests/replay.lua tests/replay_plan.lua requirements.txt tools/ct_tui.py requirements-tui.txt tests/manifests/README.md
# The whole addon folder: the fake client loads it for flow replay and the offline block. tools/events holds the
# clients' event lists (offline level 4) and tools/clients their surfaces (level 5). Census manifests stay local and
# are never bundled.
BUNDLE_DIR := CheckThat tools/events tools/clients tools/recordings

install-skill:
	@root=$$(pwd -P); mkdir -p "$(SKILL_DIR)" || exit 1; dest=$$(cd "$(SKILL_DIR)" && pwd -P); \
	case "$$dest/" in "$$root"/*) echo "SKILL_DIR must be outside this checkout" >&2; exit 1;; esac; \
	if [ -n "$(BIN_DIR)" ]; then \
	  case "$(BIN_DIR)" in "~"*) echo "BIN_DIR starts with ~: the shell did not expand it; use \$$HOME/bin" >&2; exit 1;; esac; \
	  mkdir -p "$(BIN_DIR)" || exit 1; bin=$$(cd "$(BIN_DIR)" && pwd -P); \
	  case "$$bin/" in "$$root"/*) echo "BIN_DIR must be outside this checkout" >&2; exit 1;; esac; \
	fi; \
	tmp=$$(mktemp -d "$$dest/.ct-test-plan.XXXXXX") || exit 1; tmp2=$$(mktemp -d "$$dest/.ct-verify.XXXXXX") || exit 1; trap 'rm -rf "$$tmp" "$$tmp2"' EXIT; \
	cp -R skills/ct-test-plan/. "$$tmp" && cp -R skills/ct-verify/. "$$tmp2" || { echo "install-skill: copying the skills failed" >&2; exit 1; }; \
	for f in $(BUNDLE); do mkdir -p "$$tmp/ct/$$(dirname "$$f")" && cp "$$f" "$$tmp/ct/$$f" || { echo "install-skill: copying $$f failed" >&2; exit 1; }; done; \
	for d in $(BUNDLE_DIR); do mkdir -p "$$tmp/ct/$$d" && cp -R "$$d/." "$$tmp/ct/$$d" || { echo "install-skill: copying $$d failed" >&2; exit 1; }; done; \
	sed -n 's/^## Version: *//p' CheckThat/CheckThat_Vanilla.toc > "$$tmp/ct/VERSION" || exit 1; \
	if [ -z "$$SKILL_NO_VENV" ]; then \
	  python3 -m venv "$$tmp/.venv" || { echo "install-skill: creating the Python environment failed (need python3 with venv)" >&2; exit 1; }; \
	  "$$tmp/.venv/bin/python" -m pip install -q --disable-pip-version-check -r "$$tmp/ct/requirements.txt" || { echo "install-skill: installing PyYAML and jsonschema failed (need network access)" >&2; exit 1; }; \
	fi; \
	rm -rf "$$dest/ct-test-plan" "$$dest/ct-verify" && mv "$$tmp" "$$dest/ct-test-plan" && mv "$$tmp2" "$$dest/ct-verify" && echo "installed ct-test-plan and ct-verify to $$dest" || { echo "install-skill: replacing the earlier copy failed" >&2; exit 1; }; \
	if [ -n "$(BIN_DIR)" ]; then ln -sf "$$dest/ct-test-plan/ct/tools/ct" "$$bin/ct" && echo "ct launcher linked at $$bin/ct" || exit 1; fi

# Build the Claude Code plugin (skills + tools bundle) into build/plugin. Skills are named plan and verify there, so the
# commands read /checkthat:plan and /checkthat:verify. Load it with: claude --plugin-dir build/plugin
PLUGIN_DIR ?= build/plugin

build-plugin:
	@rm -rf "$(PLUGIN_DIR)" && mkdir -p "$(PLUGIN_DIR)/.claude-plugin" "$(PLUGIN_DIR)/skills" || exit 1; \
	for pair in ct-test-plan:plan ct-verify:verify; do src=$${pair%%:*}; dst=$${pair##*:}; \
	  cp -R "skills/$$src" "$(PLUGIN_DIR)/skills/$$dst" || { echo "build-plugin: copying $$src failed" >&2; exit 1; }; \
	  sed -e 's/ct-test-plan/plan/g' -e 's/ct-verify/verify/g' "skills/$$src/SKILL.md" > "$(PLUGIN_DIR)/skills/$$dst/SKILL.md" || exit 1; \
	done; \
	for f in $(BUNDLE); do mkdir -p "$(PLUGIN_DIR)/skills/plan/ct/$$(dirname "$$f")" && cp "$$f" "$(PLUGIN_DIR)/skills/plan/ct/$$f" || { echo "build-plugin: copying $$f failed" >&2; exit 1; }; done; \
	for d in $(BUNDLE_DIR); do mkdir -p "$(PLUGIN_DIR)/skills/plan/ct/$$d" && cp -R "$$d/." "$(PLUGIN_DIR)/skills/plan/ct/$$d" || { echo "build-plugin: copying $$d failed" >&2; exit 1; }; done; \
	ver=$$(sed -n 's/^## Version: *//p' CheckThat/CheckThat_Vanilla.toc); [ -n "$$ver" ] || exit 1; \
	echo "$$ver" > "$(PLUGIN_DIR)/skills/plan/ct/VERSION"; \
	printf '{\n  "name": "checkthat",\n  "version": "%s",\n  "description": "Draft CheckThat test plans and read finished runs back against them.",\n  "license": "MIT"\n}\n' "$$ver" > "$(PLUGIN_DIR)/.claude-plugin/plugin.json"; \
	echo "built $(PLUGIN_DIR)"

# The same checks the release workflow runs.
check:
	@for toc in CheckThat/CheckThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
	@luajit tools/lua51_check.lua --globals CheckThat/CheckThat_Vanilla.toc CheckThat/CheckThat_Camelot.toc
