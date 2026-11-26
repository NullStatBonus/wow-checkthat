#!/usr/bin/env python3
"""Builds the committed slice of a census manifest: tools/clients/<client>.json.

    python3 tools/client_slice.py MANIFEST BLIZZARD_SOURCE > tools/clients/<client>.json

MANIFEST is a local census manifest (tests/manifests/<client>-<build>.json, never committed). BLIZZARD_SOURCE is a
checkout of the matching wow-ui-source track. The slice keeps only what the strict fake client needs, all of it names the
game defines: global functions, the function members of C_ namespaces and the methods of each widget type. A function
the census filed as set by addon code (an addon replaced it) is kept when Blizzard's own source names it. Everything else
in the manifest (the tester's addon list, addon globals, strings, numbers, other tables) is left out. Review the output
before committing it.
"""
import json
import os
import re
import sys

TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def source_names(root):
    words = set()
    for base, _, files in os.walk(root):
        for n in files:
            if n.endswith((".lua", ".xml")):
                with open(os.path.join(base, n), encoding="utf-8", errors="ignore") as f:
                    words.update(TOKEN.findall(f.read()))
    return words


def build(manifest, words):
    g = manifest["globals"]
    functions = {k for k, v in g.items() if v == "function"}
    functions |= {k for k, v in (manifest.get("insecure") or {}).items() if v == "function" and k in words}
    namespaces = {t: sorted(k for k, v in mem.items() if v == "function")
                  for t, mem in manifest["tables"].items() if t.startswith("C_")}
    return {"functions": sorted(functions), "namespaces": {t: v for t, v in sorted(namespaces.items()) if v},
            "widgets": {w: sorted(v) for w, v in sorted(manifest["widgets"].items())}}


def render(manifest, s):
    head = [("format", 1), ("client", manifest["client"]), ("build", manifest["build"]), ("interface", manifest["interface"]),
            ("source", "in-game census of %s (/ct census); game-defined names only" % manifest["date"])]
    out = ["{"] + ["  %s: %s," % (json.dumps(k), json.dumps(v)) for k, v in head]
    out.append('  "functions": [')
    out += ["    %s%s" % (json.dumps(n), "," if i < len(s["functions"]) - 1 else "") for i, n in enumerate(s["functions"])]
    out += ["  ],", '  "namespaces": {']
    ns = list(s["namespaces"].items())
    out += ["    %s: %s%s" % (json.dumps(t), json.dumps(v), "," if i < len(ns) - 1 else "") for i, (t, v) in enumerate(ns)]
    out += ["  },", '  "widgets": {']
    ws = list(s["widgets"].items())
    out += ["    %s: %s%s" % (json.dumps(w), json.dumps(v), "," if i < len(ws) - 1 else "") for i, (w, v) in enumerate(ws)]
    out += ["  }", "}"]
    return "\n".join(out) + "\n"


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        manifest = json.load(f)
    sys.stdout.write(render(manifest, build(manifest, source_names(sys.argv[2]))))


if __name__ == "__main__":
    main()
