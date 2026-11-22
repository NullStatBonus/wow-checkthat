.PHONY: test test-lua test-py build check install-skill

PY := .venv/bin/python
SKILL_DIR ?= $(HOME)/.claude/skills

test: build test-lua test-py

build:
	@mkdir -p build
	@for p in keepthat dontdothat closestvendor selftest; do $(PY) tools/wtt.py compile plans/$$p.yaml -o build/$$p.wtt || exit 1; done

# luajit tests/run.lua [pattern] runs a subset; each file also runs alone: luajit tests/test_json.lua
test-lua:
	@luajit tests/run.lua

test-py:
	@PYTHONDONTWRITEBYTECODE=1 $(PY) -m unittest discover -s tools -p 'test_*.py'

# Install the wtt-test-plan skill with everything it runs, outside this checkout: the skill text,
# a bundle of the plan tools (same layout as the checkout), and a private Python with PyYAML and
# jsonschema. SKILL_DIR changes the target; SKILL_NO_VENV=1 skips the pip step (tests).
BUNDLE := tools/wtt.py schema/test-plan.schema.json docs/test-plan.md docs/debug-logging.md openspec/specs/test-plan-format/spec.md TestThat/Model/Plan.lua requirements.txt

install-skill:
	@root=$$(pwd -P); mkdir -p "$(SKILL_DIR)" || exit 1; dest=$$(cd "$(SKILL_DIR)" && pwd -P); \
	case "$$dest/" in "$$root"/*) echo "SKILL_DIR must be outside this checkout" >&2; exit 1;; esac; \
	tmp=$$(mktemp -d "$$dest/.wtt-test-plan.XXXXXX") || exit 1; trap 'rm -rf "$$tmp"' EXIT; \
	cp -R skills/wtt-test-plan/. "$$tmp" || { echo "install-skill: copying the skill failed" >&2; exit 1; }; \
	for f in $(BUNDLE); do mkdir -p "$$tmp/wtt/$$(dirname "$$f")" && cp "$$f" "$$tmp/wtt/$$f" || { echo "install-skill: copying $$f failed" >&2; exit 1; }; done; \
	sed -n 's/^## Version: *//p' TestThat/TestThat_Vanilla.toc > "$$tmp/wtt/VERSION" || exit 1; \
	if [ -z "$$SKILL_NO_VENV" ]; then \
	  python3 -m venv "$$tmp/.venv" || { echo "install-skill: creating the Python environment failed (need python3 with venv)" >&2; exit 1; }; \
	  "$$tmp/.venv/bin/python" -m pip install -q --disable-pip-version-check -r "$$tmp/wtt/requirements.txt" || { echo "install-skill: installing PyYAML and jsonschema failed (need network access)" >&2; exit 1; }; \
	fi; \
	rm -rf "$$dest/wtt-test-plan" && mv "$$tmp" "$$dest/wtt-test-plan" && echo "installed wtt-test-plan to $$dest/wtt-test-plan"

# The same checks the release workflow runs.
check:
	@for toc in TestThat/TestThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
