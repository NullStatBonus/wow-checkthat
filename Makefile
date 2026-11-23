.PHONY: test test-lua test-py build check install-skill build-plugin

PY := .venv/bin/python
SKILL_DIR ?= $(HOME)/.claude/skills

test: build test-lua test-py

build:
	@mkdir -p build
	@for p in keepthat dontdothat closestvendor selftest checkthat-0.8; do $(PY) tools/ct.py compile plans/$$p.yaml -o build/$$p.ct || exit 1; done

# luajit tests/run.lua [pattern] runs a subset; each file also runs alone: luajit tests/test_json.lua
test-lua:
	@luajit tests/run.lua

test-py:
	@PYTHONDONTWRITEBYTECODE=1 $(PY) -m unittest discover -s tools -p 'test_*.py'

# Install the ct-test-plan and ct-verify skills with everything they run, outside this checkout: the skill text,
# a bundle of the plan tools (same layout as the checkout), and a private Python with PyYAML and
# jsonschema. SKILL_DIR changes the target; SKILL_NO_VENV=1 skips the pip step (tests).
BUNDLE := tools/ct.py schema/test-plan.schema.json docs/test-plan.md docs/debug-logging.md openspec/specs/test-plan-format/spec.md CheckThat/Model/Plan.lua CheckThat/Model/Json.lua tools/sv2json.lua requirements.txt

install-skill:
	@root=$$(pwd -P); mkdir -p "$(SKILL_DIR)" || exit 1; dest=$$(cd "$(SKILL_DIR)" && pwd -P); \
	case "$$dest/" in "$$root"/*) echo "SKILL_DIR must be outside this checkout" >&2; exit 1;; esac; \
	tmp=$$(mktemp -d "$$dest/.ct-test-plan.XXXXXX") || exit 1; tmp2=$$(mktemp -d "$$dest/.ct-verify.XXXXXX") || exit 1; trap 'rm -rf "$$tmp" "$$tmp2"' EXIT; \
	cp -R skills/ct-test-plan/. "$$tmp" && cp -R skills/ct-verify/. "$$tmp2" || { echo "install-skill: copying the skills failed" >&2; exit 1; }; \
	for f in $(BUNDLE); do mkdir -p "$$tmp/ct/$$(dirname "$$f")" && cp "$$f" "$$tmp/ct/$$f" || { echo "install-skill: copying $$f failed" >&2; exit 1; }; done; \
	sed -n 's/^## Version: *//p' CheckThat/CheckThat_Vanilla.toc > "$$tmp/ct/VERSION" || exit 1; \
	if [ -z "$$SKILL_NO_VENV" ]; then \
	  python3 -m venv "$$tmp/.venv" || { echo "install-skill: creating the Python environment failed (need python3 with venv)" >&2; exit 1; }; \
	  "$$tmp/.venv/bin/python" -m pip install -q --disable-pip-version-check -r "$$tmp/ct/requirements.txt" || { echo "install-skill: installing PyYAML and jsonschema failed (need network access)" >&2; exit 1; }; \
	fi; \
	rm -rf "$$dest/ct-test-plan" "$$dest/ct-verify" && mv "$$tmp" "$$dest/ct-test-plan" && mv "$$tmp2" "$$dest/ct-verify" && echo "installed ct-test-plan and ct-verify to $$dest"

# Build the Claude Code plugin (skills + tools bundle) into build/plugin. Load it with: claude --plugin-dir build/plugin
PLUGIN_DIR ?= build/plugin

build-plugin:
	@rm -rf "$(PLUGIN_DIR)" && mkdir -p "$(PLUGIN_DIR)/.claude-plugin" "$(PLUGIN_DIR)/skills" || exit 1; \
	cp -R skills/ct-test-plan skills/ct-verify "$(PLUGIN_DIR)/skills/" || { echo "build-plugin: copying the skills failed" >&2; exit 1; }; \
	for f in $(BUNDLE); do mkdir -p "$(PLUGIN_DIR)/skills/ct-test-plan/ct/$$(dirname "$$f")" && cp "$$f" "$(PLUGIN_DIR)/skills/ct-test-plan/ct/$$f" || { echo "build-plugin: copying $$f failed" >&2; exit 1; }; done; \
	ver=$$(sed -n 's/^## Version: *//p' CheckThat/CheckThat_Vanilla.toc); [ -n "$$ver" ] || exit 1; \
	echo "$$ver" > "$(PLUGIN_DIR)/skills/ct-test-plan/ct/VERSION"; \
	printf '{\n  "name": "checkthat",\n  "version": "%s",\n  "description": "Draft CheckThat test plans and read finished runs back against them.",\n  "license": "MIT"\n}\n' "$$ver" > "$(PLUGIN_DIR)/.claude-plugin/plugin.json"; \
	echo "built $(PLUGIN_DIR)"

# The same checks the release workflow runs.
check:
	@for toc in CheckThat/CheckThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
