#!/usr/bin/env python3
"""Adds the "templates" key to a client surface: tools/clients/<client>.json.

    python3 tools/template_slice.py SURFACE BLIZZARD_SOURCE TEMPLATE [TEMPLATE ...] [-o OUT]

SURFACE is a client surface made by tools/client_slice.py. BLIZZARD_SOURCE is a checkout of the matching wow-ui-source
track. For each TEMPLATE the tool reads the XML that defines it, follows inherits, and lists what a frame made from it
gains beyond its widget type: the methods of the Lua mixins the template (and the templates it inherits) names, and its
parentKey and parentArray child keys. Output is the surface with templates = { name: { "methods": [...], "keys": [...] } }
added at the end; every other byte of the file stays. The source holds one definition per name for each client, but a name defined in two
files (a Classic and a Mainline copy) takes the union, so a frame errs toward accepting a call. Only names the game
defines are written. Nothing from the source is executed.

Limits: a mixin is found by `Name = {}`, `Name = Name or {}`, `CreateFromMixins(...)` and `Mixin(Name, ...)` at the start of a line, and a
method by `function Name:Method(`, `function Name.Method(` and `Name.Method = function`. A mixin built another way is missed, so a
frame would take fewer names than the game gives it: review the output. A parentKey anywhere inside a template counts as a key of
the template (a nested child's keys are included too), which errs toward accepting an access.
"""
import json
import os
import re
import sys

ATTR = re.compile(r'([A-Za-z]+)="([^"]*)"')
# Name = {} | Name = Name or {} | Name = CreateFromMixins(A, B) | Name = Mixin(Name, A, B)
MIXIN_DEF = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:\1\s+or\s+)?(?:CreateFromMixins\(([^)]*)\)|Mixin\(\s*\1\s*,([^)]*)\)|\{\s*\})", re.M)
# function Name:Method( | function Name.Method( | Name.Method = function
METHOD_DEF = re.compile(r"^(?:function\s+([A-Za-z_][A-Za-z0-9_]*)[:.]([A-Za-z_][A-Za-z0-9_]*)\s*\(|([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\b)", re.M)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def split_names(v):
    return [n.strip() for n in re.split(r"[,\s]+", v or "") if n.strip()]


def scan(root):
    """(templates, mixins): templates[name] = {"inherits": set, "mixins": set, "keys": set}; mixins[name] = {"parents": set, "methods": set}."""
    templates, mixins = {}, {}
    for dirpath, _, files in os.walk(root):
        for fn in files:
            path = os.path.join(dirpath, fn)
            if fn.endswith(".xml"):
                scan_xml(read(path), templates)
            elif fn.endswith(".lua"):
                text = read(path)
                for name, parents, mixed in MIXIN_DEF.findall(text):
                    m = mixins.setdefault(name, {"parents": set(), "methods": set()})
                    m["parents"].update(split_names(parents) + split_names(mixed))
                if "AddTooltipDataAccessorDelegate(" in text:  # tooltip methods the game generates: SetHyperlink = "GetHyperlink", ...
                    gen = mixins.setdefault("TooltipDataHandlerMixin", {"parents": set(), "methods": set()})["methods"]
                    gen.update(re.findall(r'^\s*(Set\w+)\s*=\s*"Get\w+",', text, re.M))
                for o1, m1, o2, m2 in METHOD_DEF.findall(text):
                    mixins.setdefault(o1 or o2, {"parents": set(), "methods": set()})["methods"].add(m1 or m2)
    return templates, mixins


def scan_xml(text, templates):
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    stack = []  # open elements: (name of the virtual template it belongs to, or None)
    for m in re.finditer(r"</([A-Za-z]+)\s*>|<([A-Za-z]+)\b([^>]*?)(/?)>", text):
        if m.group(1):
            if stack:
                stack.pop()
            continue
        attrs = dict(ATTR.findall(m.group(3)))
        owner = stack[-1] if stack else None
        if attrs.get("virtual") == "true" and attrs.get("name"):
            owner = attrs["name"]
            t = templates.setdefault(owner, {"inherits": set(), "mixins": set(), "keys": set()})
            t["inherits"].update(split_names(attrs.get("inherits")))
            t["mixins"].update(split_names(attrs.get("mixin")) + split_names(attrs.get("secureMixin")))
        elif owner:
            for k in ("parentKey", "parentArray"):
                if attrs.get(k):
                    templates[owner]["keys"].add(attrs[k])
        if not m.group(4):
            stack.append(owner)


def mixin_methods(name, mixins, seen):
    if name in seen or name not in mixins:
        return set()
    seen.add(name)
    out = set(mixins[name]["methods"])
    for p in mixins[name]["parents"]:
        out |= mixin_methods(p, mixins, seen)
    return out


def resolve(name, templates, mixins, seen=None):
    """(methods, keys) of one template with everything it inherits."""
    seen = seen if seen is not None else set()
    if name in seen or name not in templates:
        return set(), set()
    seen.add(name)
    t = templates[name]
    methods, keys = set(), set(t["keys"])
    for mx in t["mixins"]:
        methods |= mixin_methods(mx, mixins, set())
    for parent in t["inherits"]:
        pm, pk = resolve(parent, templates, mixins, seen)
        methods |= pm
        keys |= pk
    return methods, keys


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("surface"); p.add_argument("source"); p.add_argument("templates", nargs="+"); p.add_argument("-o")
    a = p.parse_args()
    surface = json.loads(read(a.surface))
    templates, mixins = scan(a.source)
    out = dict(surface.get("templates", {}))
    for name in a.templates:
        if name not in templates:
            sys.exit("no template named %s in %s" % (name, a.source))
        methods, keys = resolve(name, templates, mixins)
        out[name] = {"methods": sorted(methods), "keys": sorted(keys)}
    block = ',\n "templates": {\n' + ",\n".join('  %s: %s' % (json.dumps(k), json.dumps(v)) for k, v in sorted(out.items())) + "\n }\n}\n"
    raw = read(a.surface)
    if "templates" in surface:  # replace the block this tool wrote earlier (it is the last key) and keep the rest
        i = raw.find(',\n "templates": {')
        if i < 0:
            sys.exit("%s has a templates key in another layout: remove it and run again" % a.surface)
        text = raw[:i] + block
    else:  # add the key at the end and leave the rest of the file as it was
        text = raw.rstrip()[:-1].rstrip() + block
    if a.o:
        with open(a.o, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        sys.stdout.write(text)

if __name__ == "__main__":
    main()
