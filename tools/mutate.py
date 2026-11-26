#!/usr/bin/env python3
"""Mutation check of the Lua suite: change the addon one small way at a time and see whether the tests notice.

    python3 tools/mutate.py [--files GLOB ...] [--limit N] [--seed N] [--jobs N] [--timeout S] [--format md|json] [--list]

Each mutant is one change to one file of CheckThat/ (Libs is skipped): a comparison flipped, and/or swapped, true/false
swapped, a RegisterEvent call dropped, a function's return value turned into nil, an `if` condition forced true or false.
The mutant runs in a private copy of CheckThat/, tests/, tools/, build/, docs/, plans/, schema/ and README.md against `luajit tests/run.lua`. A failing test (or
a hang past --timeout) kills the mutant. A mutant that leaves every test passing survives: the suite does not check that
code. The report gives the score (killed / run) and lists the survivors by file and line.

The run is on demand and takes about 2 seconds per mutant, so --limit picks a seeded random sample of N mutants (the same
seed gives the same sample). Run `make build` first: some tests read build/*.ct. Mutants that are equal to the original
program (a comment, a string) are avoided by masking strings and comments before matching; a few equivalent mutants still
survive, so read the list before adding a test for each.
"""
import argparse
import concurrent.futures
import fnmatch
import json
import os
import queue
import random
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COPY = ("CheckThat", "tests", "tools", "build", "docs", "plans", "schema", "README.md")

LONG = re.compile(r"\[(=*)\[.*?\]\1\]", re.S)


def mask(text):
    """text with every string, long string and comment replaced by spaces of the same length (newlines kept)."""
    out = list(text)
    i, n = 0, len(text)
    def blank(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                end = text.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            blank(i, end); i = end
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            blank(i + 1, min(j, n)); i = j + 1
        elif c == "[" and re.match(r"\[=*\[", text[i:]):
            m = re.match(r"\[(=*)\[", text[i:])
            end = text.find("]" + m.group(1) + "]", i)
            end = n if end < 0 else end + len(m.group(1)) + 2
            blank(i, end); i = end
        else:
            i += 1
    return "".join(out)


# (name, regex on masked code, replacement function of the match)
def _swap(table):
    return lambda m: table[m.group(0)]

OPERATORS = [
    ("eq", re.compile(r"(?<![=~<>])(==|~=)(?!=)"), _swap({"==": "~=", "~=": "=="})),
    ("cmp", re.compile(r"(?<![=~<>-])(<=|>=|<|>)(?![=<>])"), _swap({"<=": ">", ">=": "<", "<": ">=", ">": "<="})),
    ("andor", re.compile(r"\b(and|or)\b"), _swap({"and": "or", "or": "and"})),
    ("bool", re.compile(r"\b(true|false)\b"), _swap({"true": "false", "false": "true"})),
    ("register", re.compile(r"^[ \t]*[\w.:]*RegisterEvent\([^()\n]*\)[ \t]*$", re.M), lambda m: re.match(r"[ \t]*", m.group(0)).group(0) + "local _ = nil"),
    ("return-nil", re.compile(r"\breturn\s+(?!nil\b|end\b)([^\n]*?)(?=\s*(?:end\b|else\b|elseif\b|$))", re.M), lambda m: "return nil"),
    ("if-true", re.compile(r"\bif\s+(.+?)\s+then\b"), lambda m: "if true then"),
    ("if-false", re.compile(r"\bif\s+(.+?)\s+then\b"), lambda m: "if false then"),
]


def lua_files(root, globs):
    out = []
    base = os.path.join(root, "CheckThat")
    for dirpath, dirs, files in os.walk(base):
        dirs[:] = sorted(d for d in dirs if d != "Libs")
        for fn in sorted(files):
            if fn.endswith(".lua"):
                rel = os.path.relpath(os.path.join(dirpath, fn), root).replace(os.sep, "/")
                if not globs or any(fnmatch.fnmatch(rel, g) for g in globs):
                    out.append(rel)
    return out


def mutants(root, globs=None):
    """[{id, file, line, op, before, after, start, end, text}] for every file; text is the whole mutated source."""
    out = []
    for rel in lua_files(root, globs):
        with open(os.path.join(root, rel), encoding="utf-8", errors="surrogateescape", newline="") as f:
            src = f.read()
        code = mask(src)
        for name, rx, rep in OPERATORS:
            for m in rx.finditer(code):
                new = rep(m)
                if new == m.group(0):
                    continue
                line = src.count("\n", 0, m.start()) + 1
                out.append({"file": rel, "line": line, "op": name, "before": src[m.start():m.end()].strip(), "after": new.strip(),
                            "start": m.start(), "end": m.end(), "text": src[:m.start()] + new + src[m.end():]})
    for i, mu in enumerate(out):
        mu["id"] = i
    return out


def prepare(root, dest):
    for d in COPY:
        src = os.path.join(root, d)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, d), ignore=shutil.ignore_patterns("__pycache__"))
        elif os.path.isfile(src):
            shutil.copy(src, os.path.join(dest, d))


def run_one(work, original, mu, timeout, runner):
    """"killed" when the suite noticed the mutant (a failing file, a crash or a hang), "survived" when every test passed, and
    "invalid" when luajit cannot compile the mutant (a multi-line return cut in two): that says nothing about the tests.
    work is this worker's copy of the project; the mutated file is put back before the call returns."""
    path = os.path.join(work, mu["file"])
    try:
        with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write(mu["text"])
        if subprocess.run(["luajit", "-bl", path], capture_output=True, timeout=timeout).returncode != 0:
            return "invalid"
        try:
            r = subprocess.run(runner, cwd=work, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return "killed"
        return "killed" if r.returncode != 0 else "survived"
    finally:
        with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write(original[mu["file"]])


def report(results, fmt):
    invalid = [r for r in results if r["state"] == "invalid"]
    results = [r for r in results if r["state"] != "invalid"]
    killed = [r for r in results if r["state"] == "killed"]
    survivors = [r for r in results if r["state"] == "survived"]
    score = (100.0 * len(killed) / len(results)) if results else 0.0
    if fmt == "json":
        return json.dumps({"run": len(results), "killed": len(killed), "survived": len(survivors), "invalid": len(invalid), "score": round(score, 1),
                           "survivors": [{k: r[k] for k in ("file", "line", "op", "before", "after")} for r in survivors]}, indent=1)
    lines = ["Mutation score: %.1f%% (%d killed of %d run, %d survived%s)" % (score, len(killed), len(results), len(survivors), ", %d skipped: did not compile" % len(invalid) if invalid else "")]
    if survivors:
        lines += ["", "Survivors (the tests passed with this change):"]
        for r in sorted(survivors, key=lambda r: (r["file"], r["line"])):
            lines.append("  %s:%d  [%s]  %s  ->  %s" % (r["file"], r["line"], r["op"], r["before"][:60], r["after"][:60]))
    return "\n".join(lines)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--files", action="append", help="glob of CheckThat files to mutate, repeatable (default: every file but Libs)")
    p.add_argument("--limit", type=int, default=0, help="run a seeded random sample of N mutants (default: all)")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    p.add_argument("--timeout", type=float, default=60)
    p.add_argument("--format", choices=("md", "json"), default="md")
    p.add_argument("--list", action="store_true", help="list the mutants without running tests")
    p.add_argument("--root", default=ROOT, help="the project folder (default: this repository)")
    p.add_argument("--runner", default="luajit tests/run.lua", help="the test command, run in a copy of the project")
    a = p.parse_args(argv)
    ms = mutants(a.root, a.files)
    if a.limit and a.limit < len(ms):
        ms = sorted(random.Random(a.seed).sample(ms, a.limit), key=lambda m: m["id"])
    if a.list:
        for m in ms:
            print("%s:%d [%s] %s -> %s" % (m["file"], m["line"], m["op"], m["before"][:50], m["after"][:50]))
        print("%d mutants" % len(ms))
        return 0
    if not ms:
        print("no mutants for these files", file=sys.stderr); return 2
    runner = a.runner.split()
    jobs = max(1, min(a.jobs, len(ms)))
    original = {m["file"]: None for m in ms}
    for rel in original:
        with open(os.path.join(a.root, rel), encoding="utf-8", errors="surrogateescape", newline="") as f:
            original[rel] = f.read()
    with tempfile.TemporaryDirectory() as tmp:
        works = []
        try:
            for n in range(jobs):  # one copy of the project for each worker; a mutant replaces one file in it and puts it back
                w = os.path.join(tmp, "w%d" % n); os.makedirs(w); prepare(a.root, w); works.append(w)
            for attempt in (1, 2):  # the suite must pass on an unchanged copy, twice (a flaky test would hide survivors as kills)
                base = subprocess.run(runner, cwd=works[0], capture_output=True, text=True, timeout=a.timeout * 4)
                if base.returncode != 0:
                    print("error: the suite fails on an unmutated copy (run make build first?):\n" + base.stdout[-1500:] + base.stderr[-500:], file=sys.stderr); return 2
        except subprocess.TimeoutExpired:
            print("error: the unmutated suite timed out", file=sys.stderr); return 2
        except OSError as e:
            print("error: cannot run %s: %s" % (runner[0], e), file=sys.stderr); return 2
        free = queue.Queue()
        for w in works:
            free.put(w)
        def job(m):
            w = free.get()
            try:
                return run_one(w, original, m, a.timeout, runner)
            finally:
                free.put(w)
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
            states = list(ex.map(job, ms))
    print(report([dict(m, state=s) for m, s in zip(ms, states)], a.format))
    return 0


if __name__ == "__main__":
    sys.exit(main())
