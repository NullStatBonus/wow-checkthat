## Decisions

- **One number for all outputs.** `JSON_FORMAT` is shared: the outputs change together with `ct.py`, and one number is easier to check than one per command. Census manifests and recordings keep their own `format`, and `decode` prints plans and runs with their own `ct` and `formatRev`.
- **Stable list differs from the issue.** The issue named `from-md`, `sv2json` and `drift` as maintainer tools. The ct-test-plan and ct-verify skills run all three, so they are stable. `from-md` writes a plan and `sv2json` prints saved variables as they are, so their output follows those formats.
- **`refused.json` left as is.** It is a map of run ids. A `format` key there would read as a run id to an older `ct.py`. It is evidence-folder bookkeeping and the docs say it is not a promise.
