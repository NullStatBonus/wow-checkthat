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

# Copy the wtt-test-plan skill into the user's skills folder (SKILL_DIR to change it)
# and record this checkout so the skill finds tools/wtt.py from anywhere.
install-skill:
	@root=$$(pwd -P); mkdir -p "$(SKILL_DIR)" || exit 1; dest=$$(cd "$(SKILL_DIR)" && pwd -P); \
	case "$$dest/" in "$$root"/*) echo "SKILL_DIR must be outside this checkout" >&2; exit 1;; esac; \
	tmp=$$(mktemp -d "$$dest/.wtt-test-plan.XXXXXX") || exit 1; trap 'rm -rf "$$tmp"' EXIT; \
	cp -R skills/wtt-test-plan/. "$$tmp" && printf '%s\n' "$$root" > "$$tmp/.wtt-root" || exit 1; \
	rm -rf "$$dest/wtt-test-plan" && mv "$$tmp" "$$dest/wtt-test-plan" && echo "installed wtt-test-plan to $$dest/wtt-test-plan"

# The same checks the release workflow runs.
check:
	@for toc in TestThat/TestThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
