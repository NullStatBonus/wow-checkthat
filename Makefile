.PHONY: test test-lua test-py build check

PY := .venv/bin/python

test: build test-lua test-py

build:
	@mkdir -p build
	@for p in keepthat dontdothat closestvendor selftest; do $(PY) tools/wtt.py compile plans/$$p.yaml -o build/$$p.wtt || exit 1; done

# luajit tests/run.lua [pattern] runs a subset; each file also runs alone: luajit tests/test_json.lua
test-lua:
	@luajit tests/run.lua

test-py:
	@PYTHONDONTWRITEBYTECODE=1 $(PY) -m unittest discover -s tools -p 'test_*.py'

# The same checks the release workflow runs.
check:
	@for toc in TestThat/TestThat_*.toc; do sh tools/check-toc.sh "$$toc" || exit 1; done
	@sh tools/check-tocs-match.sh
	@bash tools/check-embeds.sh
	@sh tools/check-version.sh
