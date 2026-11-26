#!/usr/bin/env python3
"""Builds the committed slice of a census manifest: tools/clients/<client>.json.

    python3 tools/client_slice.py MANIFEST BLIZZARD_SOURCE [--review FILE] [--unfiltered-ok] > tools/clients/<client>.json

MANIFEST is a local census manifest (tests/manifests/<client>-<build>.json, never committed). BLIZZARD_SOURCE is a
checkout of the matching wow-ui-source track. The slice keeps only what the strict fake client needs, all of it names the
game defines: global functions, the function members of C_ namespaces and the methods of each widget type. A function
the census filed as set by addon code (an addon replaced it) is kept when Blizzard's own source names it. Everything else
in the manifest (the tester's addon list, addon globals, strings, numbers, other tables) is left out. Review the output
before committing it: --review FILE writes the names Blizzard's source does not confirm, list by list.

A manifest the census marked "unfiltered" (the client could not tell every game name from an addon's) is refused unless
--unfiltered-ok says its review lists were read.
"""
import json
import os
import re
import sys

TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


CALLED = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")
ASSIGNED = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=[^=]", re.M)  # a global set at file scope, as Deprecated_*.lua does
DOC_FUNCTION = re.compile(r'Name = "([A-Za-z0-9_]+)",\s*Type = "Function"')


def source_names(root):
    """Every identifier in Blizzard's source, and the names it calls, assigns or defines as functions (with the documented ones)."""
    words, called = set(), set()
    for base, _, files in os.walk(root):
        for n in files:
            if n.endswith((".lua", ".xml")):
                with open(os.path.join(base, n), encoding="utf-8", errors="ignore") as f:
                    text = f.read()
                words.update(TOKEN.findall(text))
                called.update(CALLED.findall(text))
                called.update(ASSIGNED.findall(text))
                if "Blizzard_APIDocumentationGenerated" in base:
                    called.update(DOC_FUNCTION.findall(text))
    return words, called


def review(s, words):
    return {
        "functions not named in Blizzard source": [n for n in s["functions"] if n not in words],
        "C_ namespaces not named in Blizzard source": [t for t in s["namespaces"] if t not in words],
        "C_ functions not named in Blizzard source": [t + "." + k for t, v in s["namespaces"].items() for k in v if k not in words],
        "widget methods not named in Blizzard source": sorted({m for v in s["widgets"].values() for m in v if m not in words}),
    }


def build(manifest, called):
    """called: the names Blizzard's source calls, assigns or documents. An addon-replaced function is kept only then."""
    g = manifest["globals"]
    functions = {k for k, v in g.items() if v == "function"}
    functions |= {k for k, v in (manifest.get("insecure") or {}).items() if v == "function" and k in called}
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
    import argparse
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("manifest"); p.add_argument("source"); p.add_argument("--review"); p.add_argument("--unfiltered-ok", action="store_true")
    a = p.parse_args()
    with open(a.manifest, encoding="utf-8") as f:
        manifest = json.load(f)
    if manifest.get("unfiltered") and not a.unfiltered_ok:
        sys.exit("the census is unfiltered: read the --review lists, then pass --unfiltered-ok")
    words, called = source_names(a.source)
    s = build(manifest, called)
    if a.review:
        with open(a.review, "w", encoding="utf-8") as f:
            json.dump(review(s, words), f, indent=1)
    sys.stdout.write(render(manifest, s))


if __name__ == "__main__":
    main()
