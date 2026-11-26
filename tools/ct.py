#!/usr/bin/env python3
"""CT plan tooling: validate, compile, decode, from-md, collect, census, report.

Needs PyYAML and jsonschema (see requirements.txt). Run via .venv/bin/python tools/ct.py.
"""
import argparse, base64, copy, glob, hashlib, json, math, os, re, shutil, subprocess, sys, time, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMA = os.path.join(ROOT, "schema", "test-plan.schema.json")
PREFIX = "!CT1!"
SLASH = {
    "CheckThat": ["/ct", "/checkthat"],
    "KeepThat": ["/kt", "/keepthat"],
    "DontDoThat": ["/ddt", "/dontdothat"],
    "ClosestVendor": ["/cvn", "/closestvendor"],
}
BUILTIN = ["/reload", "/reloadui"]
LOGS = {
    "CheckThat": {"debug": {"global": "CheckThatDB", "path": "global.log.entries", "format": "entries", "cap": 300}},
    "KeepThat": {"debug": {"global": "KeepThatDB", "path": "global.log", "format": "strings", "cap": 300}},
    "DontDoThat": {"debug": {"global": "DontDoThatDB", "path": "global.log.entries", "format": "entries", "cap": 500}},
    "ClosestVendor": {"debug": {"global": "ClosestVendorCharDB", "path": "log.entries", "format": "entries", "cap": 300}},
}
ADDON_GLOBAL = {"KeepThat": "KeepThat", "DontDoThat": "DontDoThat", "ClosestVendor": "ClosestVendor"}


def load_yaml(path):
    import yaml
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def macro_allowed(text, addon):
    if not isinstance(text, str) or not text or len(text.encode("utf-8")) > 255:
        return False
    allow = set(SLASH.get(addon, [])) | set(BUILTIN) | {"/console"}
    for line in text.split("\n"):
        if not line:
            continue
        m = re.match(r"^(/\S+)", line)
        if not m or m.group(1).lower() not in allow:
            return False
        if m.group(1).lower() == "/console" and not re.match(r"^/console\s+scripterrors\s+[01]\s*$", line, re.I):
            return False
    return True


ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
TYPES = ("number", "boolean", "string")


def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def check_op(a, sid, errs):
    """Value shapes for an operator (mirror of checkOp in CheckThat/Model/Plan.lua)."""
    op, v = a.get("op"), a.get("value")
    if op == "between":
        if not (isinstance(v, list) and len(v) == 2 and all(is_num(x) for x in v) and v[0] <= v[1]):
            errs.append("%s: between needs a value of two numbers, low then high" % sid)
    elif op == "in":
        if not (isinstance(v, list) and v):
            errs.append("%s: in needs a value that is a list" % sid)
    elif op == "approx":
        if not is_num(v):
            errs.append("%s: approx needs a number value" % sid)
        if not (is_num(a.get("tolerance")) and a["tolerance"] >= 0):
            errs.append("%s: approx needs a tolerance of zero or more" % sid)
    elif op == "type":
        if v not in TYPES:
            errs.append("%s: type needs number, boolean or string" % sid)
    elif op == "matches":
        if not (isinstance(v, str) and 0 < len(v) <= 200):
            errs.append("%s: matches needs a pattern of up to 200 characters" % sid)
    elif op in ("ge", "le"):
        if not is_num(v):
            errs.append("%s: %s needs a number value" % (sid, op))
    if "tolerance" in a and op != "approx":
        errs.append("%s: tolerance belongs to approx" % sid)


def check_covers(box, where, requirements, errs):
    for name in box.get("covers", []):
        if requirements is None:
            errs.append("%s: covers needs the addon's openspec/specs folder to check %r (pass --specs)" % (where, name)); break
        if name not in requirements:
            errs.append("%s: covers %r matches no requirement heading" % (where, name))

REQ_HEAD = re.compile(r"^### Requirement:[ \t]*(.+?)[ \t]*$", re.M)

def requirement_names(specs):
    """{requirement name: spec file} for each `### Requirement:` heading under specs/*/spec.md."""
    out = {}
    for p in sorted(glob.glob(os.path.join(specs, "*", "spec.md"))):
        with open(p, encoding="utf-8") as f:
            for m in REQ_HEAD.finditer(f.read()):
                out.setdefault(m.group(1), p)
    return out

def find_specs(path):
    """The nearest openspec/specs folder above the plan file, or None."""
    d = os.path.dirname(os.path.abspath(path))
    while True:
        c = os.path.join(d, "openspec", "specs")
        if os.path.isdir(c):
            return c
        up = os.path.dirname(d)
        if up == d:
            return None
        d = up

def plan_requirements(plan, path, specs=None):
    """The requirement names to check covers against, or None when the plan has no covers (nothing to check) or no specs folder is known."""
    specs = specs or find_specs(path)
    return set(requirement_names(specs)) if specs and os.path.isdir(specs) else None

def check_count(a, sid, errs):
    c = a.get("count")
    if c is None:
        return
    if "exactly" in c and ("min" in c or "max" in c):
        errs.append("%s: count exactly cannot combine with min or max" % sid)
    if "min" in c and "max" in c and c["min"] > c["max"]:
        errs.append("%s: count min is above max" % sid)
    if a.get("absent"):
        errs.append("%s: count cannot combine with absent" % sid)
    return


def expand_cases(plan):
    """Return a copy with each step that has cases replaced by one step per case ({{name}} filled in)."""
    out = copy.deepcopy(plan)
    for sec in out.get("sections", []):
        steps = []
        for st in sec.get("steps", []):
            cases = st.pop("cases", None)
            if cases is None:
                steps.append(st)
                continue
            seen = set()
            for case in cases:
                if case["id"] in seen:
                    raise ValueError("step %s: duplicate case id %s" % (st["id"], case["id"]))
                seen.add(case["id"])

                def fill(v):
                    if isinstance(v, str):
                        whole = re.fullmatch(r"\{\{([A-Za-z0-9_-]+)\}\}", v)
                        if whole and whole.group(1) in case["vars"]:
                            return case["vars"][whole.group(1)]  # a value that is only a placeholder keeps its type
                        def sub(m):
                            if m.group(1) not in case["vars"]:
                                raise ValueError("step %s case %s: no var for {{%s}}" % (st["id"], case["id"], m.group(1)))
                            return str(case["vars"][m.group(1)])
                        return re.sub(r"\{\{([A-Za-z0-9_-]+)\}\}", sub, v)
                    if isinstance(v, list):
                        return [fill(x) for x in v]
                    if isinstance(v, dict):
                        return {k: fill(x) for k, x in v.items()}
                    return v
                new = fill(copy.deepcopy(st))
                new["id"] = "%s.%s" % (st["id"], case["id"])
                steps.append(new)
        sec["steps"] = steps
    return out


def validate(plan, requirements=None):
    """Return a list of error strings; empty means valid. requirements is the set of requirement names a covers field may use; None when no specs folder is known."""
    import jsonschema
    with open(SCHEMA, encoding="utf-8") as f:
        schema = json.load(f)
    errs = []
    v = jsonschema.Draft202012Validator(schema)
    for e in sorted(v.iter_errors(plan), key=lambda e: list(map(str, e.path))):
        errs.append("%s: %s" % ("/".join(map(str, e.path)) or "<root>", e.message[:200]))
    if errs:
        return errs
    try:
        plan = expand_cases(plan)
    except ValueError as e:
        return [str(e)]
    addon = plan["addon"]
    cats = {}
    for c in plan.get("categories", []):
        if str(c["id"]).lower() == "failed":
            errs.append("category id failed is reserved for /ct rerun failed")
        if c["id"] in cats:
            errs.append("duplicate category id %s" % c["id"])
        cats[c["id"]] = c
    for box, key, _ in display_fields(plan):
        if isinstance(box[key], str) and MARKDOWN.search(box[key]):
            errs.append("markdown in %s: use native color codes (|cffffd100text|r), not backticks or **" % key)
            break
    seen, macros = set(), {m["id"] for m in plan.get("macros", [])}
    for m in plan.get("macros", []):
        if not macro_allowed(m["text"], addon):
            errs.append("macro %s: text not allowed" % m["id"])
    reqs = plan.get("requirements", {})
    logs = plan.get("logs", {})
    sec_ids = set()
    for sec in plan["sections"]:
        if str(sec["id"]).lower() == "failed" and not cats:
            errs.append("section id failed is reserved for /ct rerun failed (each section is a category)")
        if not ID.fullmatch(str(sec["id"])):
            errs.append("section id %r is not valid (lowercase letters, digits, . _ -)" % sec["id"])
        if sec["id"] in sec_ids:
            errs.append("duplicate section id %s" % sec["id"])
        sec_ids.add(sec["id"])
        check_covers(sec, 'section %s' % sec["id"], requirements, errs)
        for r in sec.get("requires", []):
            if r not in reqs:
                errs.append("section %s: unresolved requirement %s" % (sec["id"], r))
        if "category" in sec and sec["category"] not in cats:
            errs.append("section %s: unknown category %s" % (sec["id"], sec["category"]))
        for st in sec["steps"]:
            sid = st["id"]
            if not ID.fullmatch(str(sid)):
                errs.append("step id %r is not valid (lowercase letters, digits, . _ -)" % sid)
            if sid in seen:
                errs.append("duplicate step id %s" % sid)
            seen.add(sid)
            check_covers(st, sid, requirements, errs)
            if "category" in st and st["category"] not in cats:
                errs.append("%s: unknown category %s" % (sid, st["category"]))
            elif cats and "category" not in st and "category" not in sec:
                errs.append("%s: no category (the plan declares categories)" % sid)
            for r in st.get("requires", []):
                if r not in reqs:
                    errs.append("%s: unresolved requirement %s" % (sid, r))
            act = st["action"]
            if act["kind"] == "secure-macro" and act.get("macro") not in macros:
                errs.append("%s: macro %s not in plan macros" % (sid, act.get("macro")))
            if act["kind"] == "copy-slash" and not macro_allowed(act.get("text"), addon):
                errs.append("%s: slash text not allowed" % sid)
            for c in act.get("commands", []):
                if not macro_allowed(c, addon):
                    errs.append("%s: command not allowed: %s" % (sid, c))
            if st.get("auto") and "timeout" not in st:
                for a in st.get("assertions", []):
                    c = a.get("count") or {}
                    if not a.get("diagnostic") and (a.get("absent") or (a["kind"] == "fact" and a.get("op") == "missing")
                                                    or "exactly" in c or "max" in c):
                        errs.append("%s: auto step needs a timeout for a check that is judged at the end (absence, missing, exactly or max)" % sid)
                        break
            has_a = "assertions" in st["verify"]
            if has_a and not st.get("assertions"):
                errs.append("%s: verify assertions but none given" % sid)
            if st.get("assertions") and not has_a:
                errs.append("%s: assertions given but verify lacks assertions" % sid)
            if "reviewer" in st["verify"] and not st.get("reviewer"):
                errs.append("%s: verify reviewer but no reviewer text" % sid)
            for a in st.get("assertions", []):
                if a["kind"] in ("log", "log-sequence", "fact") and a["source"] not in logs:
                    errs.append("%s: unknown log source %s" % (sid, a["source"]))
                if a["kind"] in ("fact", "state"):
                    check_op(a, sid, errs)
                if a["kind"] in ("fact", "log"):
                    check_count(a, sid, errs)
                    c = a.get("count") or {}
                if a["kind"] == "log" and sum(k in a for k in ("equals", "contains", "pattern")) != 1:
                    errs.append("%s: log assertion needs exactly one of equals, contains, pattern" % sid)
                own = "[ct] step %s " % sid   # the game judges a result before it writes this line
                if a["kind"] == "log" and (own in a.get("contains", "") or a.get("equals", "").startswith(own)):
                    errs.append("%s: asserts its own result line (%s...); the game judges the result before it writes the line, so check it on a later step with scope session" % (sid, own))
    block = plan.get("offline") or {}
    if block.get("predicts"):
        have = offline_step_ids(block)
        for sid, offs in block["predicts"].items():
            if sid not in seen:
                errs.append("offline.predicts: %s is not a step of the plan" % sid)
            errs += ["offline.predicts.%s: %s is not a step of the offline block" % (sid, o) for o in offs if o not in have]
    return errs

def offline_step_ids(block):
    """The ids ct offline gives each case of a block: offline.N for a step, offline.G.N for step N of group G."""
    if block.get("groups"):
        return {"offline.%d.%d" % (g, i) for g, grp in enumerate(block["groups"], 1) for i in range(1, len(grp["steps"]) + 1)}
    return {"offline.%d" % i for i in range(1, len(block.get("steps") or []) + 1)}


def warnings(plan):
    """(step id, command) for each allowed slash command that step text names but the step's commands lack."""
    known = set(SLASH.get(plan.get("addon"), [c for cmds in SLASH.values() for c in cmds])) | set(BUILTIN) | {"/console"}
    out = []
    for sec in plan["sections"]:
        for st in sec["steps"]:
            if st["action"].get("kind") == "copy-slash":
                continue  # its text is the command and already has a copy box
            text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", st["action"].get("text", ""))
            have = [h.lower() for h in st["action"].get("commands", [])]
            for m in re.finditer(r"(?<![\w/])(/[A-Za-z]+(?: [A-Za-z0-9]+)*)", text):
                cmd = m.group(1).lower()
                if cmd.split(" ")[0] in known and not any(cmd.startswith(h) or h.startswith(cmd) for h in have):
                    out.append((st["id"], m.group(1)))
    return out

def version_warning(plan):
    """A message when the first step of the plan does not check the version under test, else None."""
    st = plan["sections"][0]["steps"][0]
    text = " ".join([st.get("title", ""), st.get("expect", ""), st["action"].get("text", "")] + [a.get("key", "") for a in st.get("assertions", [])])
    if "version" not in text.lower():
        return "%s: the first step does not check the version under test (a run on another build wastes the tester's time)" % st["id"]

PLAN_STEPS_MAX, SECTION_STEPS_MAX = 25, 10  # what one tester runs in one sitting (#162)

def size_warnings(plan):
    """Messages for a plan or section longer than a tester runs before a release. Steps are counted after cases expand,
    because the card shows each case as a step."""
    secs = expand_cases(plan)["sections"]
    out = ["section %s has %d steps (more than %d): split it, or move steps a unit test already proves out of the plan"
           % (sec.get("id"), len(sec["steps"]), SECTION_STEPS_MAX) for sec in secs if len(sec["steps"]) > SECTION_STEPS_MAX]
    n = sum(len(sec["steps"]) for sec in secs)
    if n > PLAN_STEPS_MAX:
        out.append("the plan has %d steps (more than %d): keep only what a fake game cannot prove, and split a larger scope "
                   "into a plan set (see \"Plan sets\" in docs/authoring-plans.md)" % (n, PLAN_STEPS_MAX))
    return out

CARD_MOVES = re.compile(r"^/(ct|checkthat)\s+(pass|partial|fail|skip|undo|back|next|run|rerun|end|start|import)\b", re.I)

def card_move_warnings(plan):
    """[(step id, command)] for a manual step whose own commands (the Run button) or macro lines move the card or record a result,
    so the press records a result on the step or leaves it. A step whose notes say "on purpose" is left out."""
    out = []
    macros = {m.get("id"): m.get("text") or "" for m in plan.get("macros") or []}
    for sec in expand_cases(plan)["sections"]:
        for st in sec["steps"]:
            if st.get("auto") or "on purpose" in (st.get("notes") or "").lower():
                continue
            act = st.get("action") or {}
            lines = [l for c in act.get("commands") or [] for l in c.splitlines()]
            if act.get("kind") == "secure-macro":
                lines += macros.get(act.get("macro"), "").splitlines()
            for l in lines:
                if CARD_MOVES.match(l.strip()):
                    out.append((st["id"], l.strip()))
    return out

def print_warnings(plan):
    for sid, cmd in card_move_warnings(plan):
        print("warning: %s: the Run button sends %s, which moves the card or records a result. Say so in notes (on purpose) or take it out of commands" % (sid, cmd))
    for sid, cmd in warnings(plan):
        print("warning: %s: command named in text but not in commands: %s" % (sid, cmd))
    w = version_warning(plan)
    if w:
        print("warning: " + w)
    for w in size_warnings(plan):
        print("warning: " + w)

def merge_sections(plan):
    """Compile section requirements, setup and clients into each step."""
    out = expand_cases(plan)
    out["kind"], out["ct"] = "plan", 1
    out.pop("offline", None)  # tools only: the game never receives it
    for sec in out["sections"]:
        sec.pop("covers", None)  # tools only, like offline
        for st in sec["steps"]:
            st.pop("covers", None)
        sreq, ssetup, scl = sec.pop("requires", []), sec.pop("setup", None), sec.get("clients")
        scat = sec.pop("category", None)
        sshare = sec.pop("share", None)
        if sshare and sshare != "none" and "share" not in sec["steps"][-1]:
            sec["steps"][-1]["share"] = sshare
        for st in sec["steps"]:
            st["requires"] = list(dict.fromkeys(sreq + st.get("requires", [])))
            if not st["requires"]:
                del st["requires"]
            if scat and "category" not in st:
                st["category"] = scat
            if ssetup:
                st["setup"] = (ssetup + " " + st["setup"]).strip() if st.get("setup") else ssetup
            if scl and "clients" not in st:
                st["clients"] = scl
        sec.pop("clients", None)
    return out


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def encode(obj):
    js = canonical(obj).encode("ascii")
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    packed = c.compress(js) + c.flush()
    return "%s%08x!%s" % (PREFIX, zlib.adler32(js) & 0xFFFFFFFF, base64.b64encode(packed).decode("ascii"))


MAX_INFLATED = 2000000  # CheckThat/Model/Codec.lua LIMITS.inflated


def safe_name(s):
    """One safe filename component: no separators, no dots at the start, never empty."""
    s = re.sub(r"[^A-Za-z0-9._-]", "_", str(s)).lstrip(".")
    return s or "_"


def export_form(run):
    """The run as /ct export sends it: open attempts carry snapshots in the saved variables, not in an export."""
    run = copy.deepcopy(run)
    for rec in (run.get("steps") or {}).values():
        for a in rec.get("attempts") or []:
            a.pop("snapshots", None)
            a.pop("reloaded", None)   # set when the game reloads with the attempt open; it does not change the revision
    run.pop("current", None)   # the step the card shows: browsing moves it without a new revision
    return run

def note_problem(dest, text):
    """Keep what collect could not store, so a later status still shows it."""
    p = os.path.join(dest, "problems.log")
    old = open(p, encoding="utf-8").read().splitlines() if os.path.exists(p) else []
    if text not in old:
        with open(p, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")

def write_revision(dest, run):
    """Store one run revision. Refuse a path outside dest and a different run that reuses an id and revision.
    Returns "new", "same" or "conflict"."""
    check_major(run)
    base = os.path.realpath(os.path.join(dest, "runs"))
    rp = os.path.realpath(os.path.join(base, safe_name(run["runId"])))
    if os.path.dirname(rp) != base:
        raise ValueError("run id leaves the runs folder")
    os.makedirs(rp, exist_ok=True)
    rev = int(run.get("revision", 0))
    if rev < 0:
        raise ValueError("revision is negative")
    rj = os.path.join(rp, "r%d.json" % rev)
    text = json.dumps(run, indent=1, sort_keys=True)
    if os.path.exists(rj):
        try:
            with open(rj, encoding="utf-8") as fh:
                stored = json.load(fh)
        except (ValueError, OSError):
            # An interrupted write left a partial file. Keep it aside and store this revision again.
            os.replace(rj, rj + ".damaged")
            return write_revision(dest, run)
        try:
            check_major(stored)
        except MajorError as e:
            raise MajorError("the stored %s is kept as it is: %s" % (os.path.basename(rj), e))
        try:
            same = canonical(export_form(stored)) == canonical(export_form(run))
        except (AttributeError, TypeError, ValueError):
            same = False
        return "same" if same else "conflict"
    # Write the whole file under another name, then publish it without overwriting: a stop in between leaves no partial
    # revision, and two collectors cannot both write the same one.
    tmp = "%s.%d.tmp" % (rj, os.getpid())
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    try:
        os.link(tmp, rj)
    except FileExistsError:
        os.remove(tmp)
        return write_revision(dest, run)
    except OSError:
        os.replace(tmp, rj)   # a file system with no hard links
        return "new"
    os.remove(tmp)
    return "new"


def decode(s):
    s = s.strip()
    m = re.match(r"^!CT(\d+)!([0-9a-fA-F]{8})!(.+)$", s, re.S)
    if not m:
        raise ValueError("not a CT string")
    if m.group(1) != "1":
        raise ValueError("unsupported version " + m.group(1))
    # Stop inflating at the same cap the addon uses: a tiny string must not expand without limit.
    d = zlib.decompressobj(-15)
    raw = d.decompress(base64.b64decode("".join(m.group(3).split()), validate=True), MAX_INFLATED + 1)
    if len(raw) > MAX_INFLATED or d.unconsumed_tail:
        raise ValueError("decoded data too large")
    if "%08x" % (zlib.adler32(raw) & 0xFFFFFFFF) != m.group(2).lower():
        raise ValueError("checksum mismatch")
    return json.loads(raw.decode("utf-8"))


# ---------------------------------------------------------------- markdown conversion

ITEM = re.compile(r"^(?:- \[[ xX]\]\s+|\d+\.\s+)(.*)$")


# Display text is shown by the game, which does not render Markdown. Use native color codes instead:
# **bold** becomes gold, `code` becomes light blue; titles, section names and reviewer text lose the marks.
DISPLAY_RICH = ("setup", "expect", "intro", "preamble", "handoff", "notes")
MARKDOWN = re.compile(r"`|\*\*")


def plain(s):
    return re.sub(r"\*\*|`", "", s)


def native(s):
    s = s.replace("|", "||")
    s = re.sub(r"\*\*(.+?)\*\*", lambda m: "|cffffd100" + m.group(1) + "|r", s)
    s = re.sub(r"`([^`]+)`", lambda m: "|cff99ccff" + m.group(1) + "|r", s)
    return s


def display_fields(plan):
    """Yield (container, key, kind) for every player-visible text field."""
    if "title" in plan:
        yield plan, "title", "plain"
    for req in (plan.get("requirements") or {}).values():
        if isinstance(req, dict) and "text" in req:
            yield req, "text", "rich"
    for k in ("preamble", "handoff"):
        if k in plan:
            yield plan, k, "rich"
    for sec in plan.get("sections", []):
        yield sec, "title", "plain"
        if "intro" in sec:
            yield sec, "intro", "rich"
        if "setup" in sec:
            yield sec, "setup", "rich"
        for st in sec.get("steps", []):
            yield st, "title", "plain"
            for k in ("setup", "expect", "notes"):
                if k in st:
                    yield st, k, "rich"
            if "reviewer" in st:
                yield st, "reviewer", "plain"
            if "text" in st.get("action", {}):
                yield st["action"], "text", "rich"
            for a in st.get("assertions", []):
                if "label" in a:
                    yield a, "label", "rich"


def nativize(plan):
    """Convert Markdown marks in every display field to native formatting, in place."""
    for box, key, kind in display_fields(plan):
        v = box[key]
        if isinstance(v, str) and MARKDOWN.search(v):
            box[key] = plain(v) if kind == "plain" else native(v)
    return plan


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:40] or "x"


def split_item(lines):
    """lines of one item -> (action, check, log). Continuations are indented."""
    head, rest = lines[0], lines[1:]
    action, check, log, cur = [head], [], [], None
    for l in rest:
        t = l.strip()
        if t.startswith("Check:"):
            cur = check; cur.append(t[6:].strip())
        elif t.startswith("Log:"):
            cur = log; cur.append(t[4:].strip())
        elif t:
            (cur if cur is not None else action).append(t)
    return " ".join(action), " ".join(check), " ".join(log)


def literals(log):
    """Backticked or quoted literals without placeholders: safe contains-matchers."""
    out = []
    for m in re.finditer(r"`([^`]+)`", log):
        t = m.group(1)
        if not re.search(r"[<>]|\.\.\.|\bN\b", t) and len(t) > 3:
            out.append(t)
    return out


def from_md(path, addon):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    parts = re.split(r"^## ", text, flags=re.M)
    pre = parts[0]
    prefix = {"KeepThat": "kt", "DontDoThat": "ddt", "ClosestVendor": "cv"}[addon]
    plan = {"ct": 1, "kind": "plan", "addon": addon,
            "title": "%s in-game test plan" % addon,
            "preamble": re.sub(r"^# .*\n", "", pre).strip(),
            "logs": copy.deepcopy(LOGS[addon]),
            "requirements": {"addon-loaded": {"text": "%s is loaded" % addon, "probe": "addon-loaded", "name": addon}},
            "sections": []}
    allow = SLASH[addon]
    for part in parts[1:]:
        head, _, body = part.partition("\n")
        m = re.match(r"^(\d+)\.?\s*(.*)$", head.strip())
        num, title = (m.group(1), m.group(2)) if m else (str(len(plan["sections"])), head.strip())
        blocks, cur, intro = [], None, []
        for line in body.split("\n"):
            if ITEM.match(line):
                cur = [ITEM.match(line).group(1)]; blocks.append(cur)
            elif cur is not None and (line.startswith(" ") or line.startswith("\t")):
                cur.append(line)
            elif cur is None and line.strip():
                intro.append(line.strip())
            elif cur is not None and line.strip() == "":
                cur = None if blocks else cur
        steps = []
        for k, blk in enumerate(blocks, 1):
            action, check, log = split_item(blk)
            bold = re.match(r"^\*\*(.+?)\*\*\s*(.*)$", action)
            stitle = bold.group(1).rstrip(".") if bold else " ".join(action.split()[:8]).rstrip(".,:;")
            atext = bold.group(2) if bold and bold.group(2) else action
            cmds = [c for c in dict.fromkeys(re.findall(r"`(/[^`]+)`", atext)) if macro_allowed(c, addon)]
            act = {"kind": "manual", "text": atext}
            if cmds:
                act["commands"] = cmds
            step = {"id": "%s.s%s.%d" % (prefix, num, k), "title": stitle, "action": act,
                    "expect": check or "See the action text.", "verify": ["player"]}
            lead = atext.lstrip("*").lower()
            if lead.startswith(("optional: install tomtom, and waypointui (wow forever only)", "wow forever only")):
                step["clients"] = ["forever-camelot"]
            elif lead.startswith("classic era only"):
                step["clients"] = ["classic-era"]
            if "reload" in atext.lower() and re.search(r"\/reload", atext):
                step["reload"] = "after_action"
            if log and not log.lower().startswith("none"):
                step["verify"] = ["player", "reviewer"]
                step["reviewer"] = log
                lits = literals(log)
                if lits:
                    step["verify"].append("assertions")
                    step["assertions"] = [{"kind": "log", "source": "debug", "contains": s, "diagnostic": True} for s in lits[:4]]
            steps.append(step)
        if steps:
            sec = {"id": "s" + num, "title": title, "steps": steps}
            hint = (title + " " + " ".join(intro)).lower()
            if re.search(r"forever only", hint):
                sec["clients"] = ["forever-camelot"]
            elif re.search(r"classic era only", hint):
                sec["clients"] = ["classic-era"]
            if intro:
                sec["intro"] = " ".join(intro)
            plan["sections"].append(sec)
    return nativize(plan)


# ---------------------------------------------------------------- offline replay

def replay_plan(plan, fixture, today=None):
    """Judge each required log and fact check of a plan against the SavedVariables files in a fixture folder.
    Returns (items, notes): items are {step, label, result: pass|fail|skipped, why}; notes are warnings about the fixture.
    Needs luajit. The fixture folder holds the *.lua files and may hold fixture.json: {"recorded": "YYYY-MM-DD", "digest": "<plan digest>"}."""
    import datetime, tempfile
    errs = validate(plan)
    if errs:
        raise ValueError("the plan is not valid: " + "; ".join(errs))
    merged = merge_sections(plan)
    digest = encode(merged)[len(PREFIX):len(PREFIX) + 8]
    files = sorted(glob.glob(os.path.join(fixture, "*.lua")))
    if not files:
        raise ValueError("no SavedVariables *.lua file in " + fixture)
    notes, meta = [], {}
    try:
        with open(os.path.join(fixture, "fixture.json"), encoding="utf-8") as f:
            meta = json.load(f)
    except (OSError, ValueError):
        notes.append("fixture.json is missing or unreadable: the fixture's age and plan digest are unknown")
    if meta.get("recorded"):
        days = ((today or datetime.date.today()) - datetime.date.fromisoformat(meta["recorded"])).days
        notes.append("fixture recorded %s (%d days ago)" % (meta["recorded"], days))
    if meta.get("digest") and meta["digest"] != digest:
        notes.append("stale fixture: it was recorded with plan digest %s, this plan is %s" % (meta["digest"], digest))
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "plan.json")
        with open(path, "w", encoding="utf-8") as f:
            f.write(canonical(merged))
        r = run_luajit([os.path.join(ROOT, "tools", "replay_sv.lua"), path] + files)
    if r.returncode:
        raise RuntimeError(r.stderr.strip())
    return json.loads(r.stdout), notes


def replay_junit(plan, items, properties=None, system_out=None):
    """properties is a dict for suite-level <properties>; system_out is suite-level text (offline: the nil-read report)."""
    from xml.etree import ElementTree as ET
    count = lambda k: str(sum(i["result"] == k for i in items))
    suite = ET.Element("testsuite", name=plan["title"], tests=str(len(items)), failures=count("fail"), skipped=count("skipped"))
    if properties:
        props = ET.SubElement(suite, "properties")
        for k, v in properties.items():
            ET.SubElement(props, "property", name=k, value=str(v))
    for i in items:
        case = ET.SubElement(suite, "testcase", classname=i["step"], name=i["label"])
        if i["result"] == "fail":
            ET.SubElement(case, "failure", message=i["why"] or "")
        elif i["result"] == "skipped":
            ET.SubElement(case, "skipped", message=i["why"] or "")
    if system_out:
        ET.SubElement(suite, "system-out").text = system_out
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(suite, encoding="unicode") + "\n"


# ---------------------------------------------------------------- flow replay and line source check

def default_addons():
    """The folder above the repository: this checkout's, or (installed skill, no .git beside ct.py) the current folder's."""
    return os.path.dirname(ROOT) if os.path.exists(os.path.join(ROOT, ".git")) else os.path.dirname(os.getcwd())


def run_luajit(cmd, cwd=None, timeout=None):
    try:
        return subprocess.run(["luajit"] + cmd, capture_output=True, text=True, cwd=cwd, timeout=timeout)
    except FileNotFoundError:
        raise ValueError("this command needs luajit, which is not installed")


CLIENTS = (("forever-camelot", "16000"), ("classic-era", "11507"))


def replay_flow(plan, hooks=None, requirements=None):
    """Play a plan's steps in the fake client (tests/replay_plan.lua) the way a tester would, once for each client, and check that
    every step ran on at least one. Returns (exit code, text). Needs luajit and the bundle's tests/ files. Log lines the plan expects
    are written by the replay itself, so a pass proves the plan flow, not that the addon writes them (see lines_check)."""
    import tempfile
    if not os.path.exists(os.path.join(ROOT, "tests", "replay_plan.lua")):
        raise ValueError("replay-flow needs tests/replay_plan.lua (missing): reinstall the skill with make install-skill")
    errs = validate(plan, requirements)
    if errs:
        raise ValueError("the plan is not valid: " + "; ".join(errs))
    merged = merge_sections(plan)
    ids = [st["id"] for sec in merged["sections"] for st in sec["steps"]]
    text, code, ran = [], 0, set()
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "plan.ct")
        with open(path, "w", encoding="utf-8") as f:
            f.write(encode(merged) + "\n")
        for name, iface in CLIENTS:
            if not any(not st.get("clients") or name in st["clients"] for sec in merged["sections"] for st in sec["steps"]):
                text.append("== %s\nno step is for this client" % name)
                continue
            cmd = [os.path.join("tests", "replay_plan.lua"), path, os.path.abspath(hooks) if hooks else "-", iface]
            r = run_luajit(cmd, ROOT)
            out = r.stdout + r.stderr
            text.append("== %s\n%s" % (name, out))
            code = code or r.returncode
            ran.update(m.group(1) for m in re.finditer(r"^(\S+)\s+(?:pass|partial|fail|skip|unverified|pending)\b", out, re.M))
    missing = [i for i in ids if i not in ran]
    if missing:
        code = 1
        text.append("PROBLEM: no client ran %s" % ", ".join(missing))
    return code, "\n".join(text)


def literal_run(pat):
    """The longest run of plain characters a Lua pattern must contain, or "". A character before *, ? or - may be absent. ^ is an
    anchor only first and $ only last; elsewhere they are plain characters."""
    runs, cur, i, n = [], "", 0, len(pat)
    def end():
        nonlocal cur
        runs.append(cur); cur = ""
    while i < n:
        c = pat[i]
        if c == "^" and i == 0:
            i += 1; continue
        if c == "$" and i == n - 1:
            i += 1; continue
        if c == "%" and i + 1 < n:
            e = pat[i + 1]
            lit = None if e.isalnum() else e
            i += 2
        elif c == "[":
            j = i + 1
            if j < n and pat[j] == "^":
                j += 1
            if j < n and pat[j] == "]":
                j += 1
            while j < n and pat[j] != "]":
                j += 2 if pat[j] == "%" else 1
            i = min(j, n - 1) + 1
            lit = None
        elif c in "().":
            i += 1; lit = None
        else:
            lit = c; i += 1
        q = pat[i] if i < n else ""
        if lit is None or q in ("*", "?", "-"):
            end()
            if q in ("*", "?", "-", "+"):
                i += 1
            continue
        cur += lit
        if q == "+":
            i += 1; end()
    end()
    return max(runs, key=len)


def asserted_lines(plan):
    """[(step id, label, text to find in the addon source)] for each required log line and fact key a plan asserts. CheckThat's own
    lines ([ct] ...) are skipped; a fact is the addon's own when it names another addon than CheckThat."""
    out = []
    logs = plan.get("logs") or {}
    for sec in merge_sections(plan).get("sections", []):
        for st in sec.get("steps", []):
            for a in st.get("assertions") or []:
                if a.get("diagnostic") or a.get("absent"):
                    continue
                own = (logs.get(a.get("source")) or {}).get("global") == "CheckThatDB"
                items = (a.get("sequence") or [a]) if a.get("kind") in ("log", "log-sequence") else []
                for it in items:
                    text = it.get("equals") or it.get("contains") or (literal_run(it["pattern"]) if it.get("pattern") else "")
                    if text.startswith("[ct] ") and own:
                        continue
                    out.append((st["id"], a.get("label") or text, text))
                if a.get("kind") == "fact" and a.get("key") and a.get("addon") != "CheckThat":
                    out.append((st["id"], a.get("label") or a["key"], a["key"]))
    return out


def addon_source(src):
    """The addon's Lua text without comments, libraries and tests (a line in a test or a comment is not a line the addon writes)."""
    blob = []  # one string for each file
    for dp, dn, fn in os.walk(src):
        dn[:] = [d for d in dn if d.lower() not in ("libs", "tests", "test")]
        for f in sorted(fn):
            if f.endswith(".lua"):
                with open(os.path.join(dp, f), encoding="utf-8", errors="replace") as h:
                    text = h.read()
                text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
                blob.append("\n".join(l for l in text.splitlines() if not l.lstrip().startswith("--")))
    return [b.replace('\\"', '"') for b in blob]


def lines_check(plan, src):
    """Which asserted log lines and fact keys no Lua file of the addon contains. The whole line is tried first. A line built from a
    format string, a concatenation or two strings (a log tag and its message) matches when the tag sits in quotes in a file that holds most of the
    message's words, so a miss is a warning to check by hand, not proof. Returns (found, missing)."""
    files = addon_source(src)
    found, missing = [], []
    def present(text):
        text = text.strip()
        if text.startswith("entry."):  # an entry registered by name is reported as entry.<name>
            text = text[len("entry."):]
        if len(text) >= 3 and any(text in f for f in files):
            return True
        m = re.match(r"^\[([^\]]+)\] ?(.*)$", text, re.S)
        if not m:
            # built at run time, such as "test command: " .. kind or "%d items found": try runs of words of 8 characters or more,
            # longest first, so a prefix (the old rule) is tried before a run that starts later
            words = text.split(" ")
            for n in range(len(words) - 1, 0, -1):
                for i in range(len(words) - n + 1):
                    run = " ".join(words[i:i + n]).strip(" :=,")
                    if len(run) >= 8 and any(run in f for f in files):
                        return True
            return False
        tag, rest = m.group(1), m.group(2).strip()
        words = re.findall(r"[A-Za-z]{4,}", rest)
        for f in files:
            if '"%s"' % tag in f or "'%s'" % tag in f:
                if not words or sum(w in f for w in words) * 2 >= len(words):
                    return True
        return False
    for sid, label, text in asserted_lines(plan):
        (found if present(text) else missing).append((sid, label, text))
    return found, missing


# ---------------------------------------------------------------- offline entry runner

def census_manifests(folder=None):
    """The census manifests (tests/manifests/*.json, see docs/contracts.md): a list of dicts. A file that does not parse is skipped."""
    import glob
    out = []
    folder = folder or os.environ.get("CT_TEST_MANIFESTS") or os.path.join(ROOT, "tests", "manifests")
    for p in sorted(glob.glob(os.path.join(folder, "*.json"))):
        try:
            with open(p, encoding="utf-8") as f:
                m = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(m, dict) and isinstance(m.get("globals"), dict):
            out.append(m)
    return out


def nil_read_report(interface, names, manifests, build=None):
    """The text of the nil-read report. Returns (text, build or None). With no manifest for the interface it is one sorted list;
    with one (or --build) it splits the names by that build's census; with several and no build it says so and stays unclassified."""
    names = sorted(set(names))
    head = "Globals read as nil in this run (interface %s):" % interface
    pool = [m for m in manifests if m.get("interface") == interface]
    if build is not None:
        pool = [m for m in pool if str(m.get("build")) == str(build)]
        if not pool:
            raise ValueError("no census manifest for build %s with interface %s" % (build, interface))
    notes = []
    if len(pool) > 1:
        notes.append("Interface %s matches multiple builds. Showing unclassified names." % interface)
        pool = []
    m = pool[0] if pool else None
    if not names:
        return "\n".join([head + " none"] + notes) + "\n", m["build"] if m else None
    if not m:
        return "\n".join([head, "  " + " ".join(names)] + notes) + "\n", None
    insecure = m.get("insecure") or {}
    present = [n for n in names if n in m["globals"]]
    byaddon = [n for n in names if n not in m["globals"] and n in insecure]
    absent = [n for n in names if n not in m["globals"] and n not in insecure]
    lines = [head]
    if present:
        lines.append("  Present in census for build %s: %s" % (m["build"], " ".join(present)))
    if byaddon:
        lines.append("  Set by addon code in census for build %s: %s" % (m["build"], " ".join(byaddon)))
    if absent:
        lines.append("  Absent from census for build %s: %s" % (m["build"], " ".join(absent)))
    return "\n".join(lines) + "\n", m["build"]


OFFLINE_LEVEL_WARNING = ("warning: the offline block has no level, so it runs at level 1 (interface 11507, issecurevariable false). "
                         "Add level: 6 for the newer answers: the client's real build and secure names, its own functions and "
                         "frame methods, the game's load order (saved variables, login events, reload), its event list, "
                         "timers on a virtual clock (wait steps), and the taint of game globals.")


def offline_plan(plan, addons, requirements=None, info=None, client=None):
    """Run a plan's offline block in tools/entry_runner.lua. addons is the folder that holds the addon checkouts; the plan's
    toc resolves inside it and may not leave it, so a shared plan cannot pick Lua from elsewhere. It still runs that addon's
    Lua with your permissions: run only addons you trust. requirements is what plan_requirements gives, for covers.
    Returns items {step, label, result: pass|fail, why}. Needs luajit. A dict passed as info gets the run's interface and nilReads.
    client ("era" or "forever") runs the block with the TOC of offline.tocs for that client instead of offline.toc."""
    import tempfile
    if not os.path.exists(os.path.join(ROOT, "tests", "harness.lua")):
        raise ValueError("offline needs tests/harness.lua (missing): reinstall the skill with make install-skill")
    errs = validate(plan, requirements)
    if errs:
        raise ValueError("the plan is not valid: " + "; ".join(errs))
    block = plan.get("offline")
    if not block:
        raise ValueError("the plan has no offline block")
    root = os.path.realpath(addons)
    toc_name = block["toc"]
    if client:
        toc_name = (block.get("tocs") or {}).get(client)
        if not toc_name:
            raise ValueError("the offline block has no tocs.%s: add it, or run without --client" % client)
    toc = os.path.realpath(os.path.join(root, toc_name))
    if os.path.commonpath([root, toc]) != root:
        raise ValueError("toc %s leaves the addons folder %s" % (toc_name, addons))
    spec = dict(block, toc=toc)
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "spec.json")
        with open(path, "w", encoding="utf-8") as f:
            f.write(json.dumps(spec))
        r = run_luajit([os.path.join(ROOT, "tools", "entry_runner.lua"), path], ROOT)
    try:
        res = json.loads(r.stdout)
    except ValueError:
        raise RuntimeError((r.stderr or r.stdout).strip() or "the runner printed nothing")
    if info is not None:
        info["interface"] = res.get("interface")
        info["nilReads"] = list((res.get("nilReads") or {}).values()) if isinstance(res.get("nilReads"), dict) else list(res.get("nilReads") or [])
    items = []
    for s in res["steps"]:
        g = s.get("group")
        if g:  # a step of a group: offline.G.N, labelled "group label: step label"
            group = block["groups"][g - 1]
            given = group["steps"][s["step"] - 1].get("label") if s["step"] else None
            label = "%s: %s" % (group.get("label") or "group %d" % g, given or "%s %d" % (s["kind"], s["step"]))
            step_id = "offline.%d.%d" % (g, s["step"])
        else:
            given = block["steps"][s["step"] - 1].get("label") if s["step"] else None
            label = given or "%s %d" % (s["kind"], s["step"])
            step_id = "offline.%d" % s["step"]
        items.append({"step": step_id, "label": label, "result": "pass" if s["ok"] else "fail", "why": s.get("detail") or ""})
    if not res["ok"] and not any(i["result"] == "fail" for i in items):
        items.append({"step": "offline.0", "label": "run", "result": "fail", "why": "a step produced no result"})
    return items


FLAVOR = {"classic-era": "era", "forever-camelot": "forever"}

def predictions(plan, addons, requirements=None):
    """What the offline block predicts for each plan step it names in offline.predicts, for each client the block has a TOC for.
    Returns {flavor: {step id: {"predicted": pass|fail, "offline": [ids], "why": text of the first failing case}}}. Needs luajit."""
    block = plan.get("offline") or {}
    if not block.get("predicts"):
        raise ValueError("the offline block has no predicts: add offline.predicts to link plan steps to offline steps")
    if not block.get("tocs"):
        raise ValueError("the offline block has no tocs: drift is counted for each client, so name a TOC for each")
    out = {}
    for fl in block["tocs"]:
        got = {i["step"]: i for i in offline_plan(plan, addons, requirements, None, fl)}
        out[fl] = {}
        for sid, offs in block["predicts"].items():
            bad = [got.get(o) for o in offs if not got.get(o) or got[o]["result"] != "pass"]
            out[fl][sid] = {"predicted": "fail" if bad else "pass", "offline": list(offs), "why": (bad[0] or {}).get("why", "the offline step did not run") if bad else ""}
    return out

def drift_report(preds, runs, addon=None, title=None):
    """Compare predictions with real runs. A run counts for a flavor by its client. Only a step the run judged (pass, partial, fail)
    is compared: an unverified or skipped step is not a miss. Returns {"flavors": {flavor: {matched, total, score}}, "drift": [entries]}."""
    ms = [m for m in models(runs) if (addon is None or m["addon"] == addon) and (title is None or m["plan"] == title)]
    flavors, drift = {}, []
    for fl, steps in preds.items():
        tot = hit = 0
        for m in ms:
            if FLAVOR.get(m["client"]) != fl:
                continue
            for s in m["steps"]:
                p = steps.get(s["id"])
                actual = {"pass": "pass", "partial": "pass", "fail": "fail"}.get(s["result"])
                if not p or not actual:
                    continue
                tot += 1
                if p["predicted"] == actual:
                    hit += 1
                else:
                    drift.append({"flavor": fl, "run": m["runId"], "step": s["id"], "predicted": p["predicted"], "actual": actual,
                                  "offline": p["offline"], "why": p["why"] or s["reason"]})
        flavors[fl] = {"matched": hit, "total": tot, "score": round(hit / tot, 3) if tot else None}
    return {"flavors": flavors, "drift": drift}

def drift_text(rep):
    out = []
    for fl, s in sorted(rep["flavors"].items()):
        out.append("%s: %s" % (fl, "%d of %d predictions matched (%.0f%%)" % (s["matched"], s["total"], 100 * s["score"]) if s["total"] else "no run to compare"))
    for d in rep["drift"]:
        out.append("  drift  %s  %s  %s  predicted %s, the run %s (%s): %s" % (d["flavor"], d["run"], d["step"], d["predicted"], d["actual"], ", ".join(d["offline"]), d["why"]))
    return "\n".join(out)

# ---------------------------------------------------------------- evidence harvest

# ---------------------------------------------------------------- saved-variables reader (no luajit)
# Reads the subset of Lua the game writes to SavedVariables and gives the JSON text tools/sv2json.lua gives: the same
# array test, string keys, depth limit and canonical encoder (CheckThat/Model/Json.lua). Strings stay bytes, as in Lua.

class SVError(ValueError):
    pass

_SV_NUM = re.compile(rb"0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
_SV_NAME = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*")
_SV_LONG = re.compile(rb"\[(=*)\[")
_SV_ESC = {ord(k): v for k, v in (("n", 10), ("t", 9), ("r", 13), ("a", 7), ("b", 8), ("f", 12), ("v", 11), ("\\", 92), ('"', 34), ("'", 39), ("\n", 10))}

class _SVParser:
    def __init__(self, data):
        self.s, self.i = data, 0

    def fail(self, msg):
        raise SVError("%s at byte %d" % (msg, self.i))

    def skip(self):
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c in b" \t\r\n":
                self.i += 1
            elif s.startswith(b"--", self.i):
                m = _SV_LONG.match(s, self.i + 2)
                if m:
                    end = s.find(b"]" + m.group(1) + b"]", m.end())
                    if end < 0:
                        self.fail("unfinished long comment")
                    self.i = end + len(m.group(1)) + 2
                else:
                    nl = s.find(b"\n", self.i)
                    self.i = len(s) if nl < 0 else nl
            else:
                break

    def long_string(self, m):
        close = b"]" + m.group(1) + b"]"
        end = self.s.find(close, m.end())
        if end < 0:
            self.fail("unfinished long string")
        body = self.s[m.end():end]
        self.i = end + len(close)
        return body[1:] if body.startswith(b"\r\n") else body[1:] if body.startswith(b"\n") else body

    def string(self):
        s, q = self.s, self.s[self.i]
        self.i += 1
        out = bytearray()
        while True:
            if self.i >= len(s):
                self.fail("unfinished string")
            c = s[self.i]
            if c == q:
                self.i += 1
                return bytes(out)
            if c == 10:
                self.fail("unfinished string")
            if c != 92:
                out.append(c); self.i += 1; continue
            self.i += 1
            e = s[self.i] if self.i < len(s) else None
            if e is None:
                self.fail("unfinished string")
            if e in _SV_ESC:
                out.append(_SV_ESC[e]); self.i += 1
            elif 48 <= e <= 57:
                m = re.compile(rb"\d{1,3}").match(s, self.i)
                if int(m.group()) > 255:
                    self.fail("escape sequence too large")
                out.append(int(m.group())); self.i = m.end()
            elif e == 120:   # \xXX
                m = re.compile(rb"[0-9a-fA-F]{2}").match(s, self.i + 1)
                if not m:
                    self.fail("hexadecimal digit expected")
                out.append(int(m.group(), 16)); self.i = m.end()
            elif e == 122:   # \z skips the white space after it
                self.i += 1
                while self.i < len(s) and s[self.i] in b" \t\r\n\f\v":
                    self.i += 1
            else:
                self.fail("invalid escape sequence")

    def value(self):
        self.skip()
        s = self.s
        if self.i >= len(s):
            self.fail("value expected")
        c = s[self.i]
        if c == 123:
            return self.table()
        if c in b"\"'":
            return self.string()
        m = _SV_LONG.match(s, self.i) if c == 91 else None
        if m:
            return self.long_string(m)
        neg = c == 45
        if neg:
            self.i += 1; self.skip(); c = s[self.i] if self.i < len(s) else 0
        if c in b"0123456789." and (m := _SV_NUM.match(s, self.i)):
            self.i = m.end()
            t = m.group()
            v = float(int(t, 16)) if t[:2] in (b"0x", b"0X") else float(t)
            return -v if neg else v
        if neg:
            self.fail("number expected")
        m = _SV_NAME.match(s, self.i)
        if m and m.group() in (b"true", b"false", b"nil"):
            self.i = m.end()
            return {b"true": True, b"false": False, b"nil": None}[m.group()]
        self.fail("unsupported value")

    def table(self):
        s = self.s
        self.i += 1
        t, n = {}, 0
        while True:
            self.skip()
            if self.i >= len(s):
                self.fail("unfinished table")
            if s[self.i] == 125:
                self.i += 1
                return t
            key = None
            m = _SV_LONG.match(s, self.i) if s[self.i] == 91 else None
            if s[self.i] == 91 and not m:
                self.i += 1
                key = self.value(); self.skip()
                if s[self.i:self.i + 1] != b"]":
                    self.fail("] expected")
                self.i += 1; self.skip()
                if s[self.i:self.i + 1] != b"=":
                    self.fail("= expected")
                self.i += 1
                if key is None:
                    self.fail("nil key")
                if isinstance(key, bool):
                    key = ("bool", key)   # True == 1.0 in a dict: keep the two apart
                val = self.value()
            else:
                nm = _SV_NAME.match(s, self.i)
                after = nm and s[nm.end():].lstrip(b" \t\r\n")[:2]
                if nm and after[:1] == b"=" and after != b"==" and nm.group() not in (b"true", b"false", b"nil"):
                    key = nm.group(); self.i = nm.end(); self.skip(); self.i += 1
                    val = self.value()
                else:
                    n += 1; key = float(n)
                    val = self.value()
            if val is None:
                t.pop(key, None)
            else:
                t[key] = val
            self.skip()
            if s[self.i:self.i + 1] in (b",", b";"):
                self.i += 1
            elif s[self.i:self.i + 1] != b"}":
                self.fail("} expected")

def sv_globals(data):
    """{name: value} for each global the file assigns. Tables are dicts keyed by bytes, bool or float."""
    p, env = _SVParser(data), {}
    while True:
        p.skip()
        if p.i >= len(data):
            return env
        m = _SV_NAME.match(data, p.i)
        if not m:
            p.fail("name expected")
        p.i = m.end(); p.skip()
        if data[p.i:p.i + 1] != b"=" or data[p.i:p.i + 2] == b"==":
            p.fail("= expected")
        p.i += 1
        v = p.value()
        if v is None:
            env.pop(m.group(), None)
        else:
            env[m.group()] = v
        p.skip()
        if data[p.i:p.i + 1] == b";":
            p.i += 1

def _sv_tostring(k):
    if isinstance(k, bytes):
        return k
    if isinstance(k, tuple):
        return b"true" if k[1] else b"false"
    return (b"%.14g" % k)

def _sv_is_array(t):
    return all(float(i) in t for i in range(1, len(t) + 1))

def _sv_norm(v, depth):
    if not isinstance(v, dict):
        return v
    if depth > 30:
        return None
    if _sv_is_array(v):
        pairs = [(float(i), v[float(i)]) for i in range(1, len(v) + 1)]
    else:
        pairs = [(_sv_tostring(k), x) for k, x in v.items()]
    return {k: n for k, x in pairs if (n := _sv_norm(x, depth + 1)) is not None}

_SV_JESC = {34: '\\"', 92: "\\\\", 8: "\\b", 12: "\\f", 10: "\\n", 13: "\\r", 9: "\\t"}

def _sv_utf8cp(s, i):
    c, n = s[i], len(s)
    if c < 0x80:
        return c, 1
    if c >= 0xF0:
        if i + 3 >= n:
            return 0xFFFD, 1
        a, b, d = s[i + 1:i + 4]
        return ((c % 8) * 262144) + ((a % 64) * 4096) + ((b % 64) * 64) + (d % 64), 4
    if c >= 0xE0:
        if i + 2 >= n:
            return 0xFFFD, 1
        a, b = s[i + 1:i + 3]
        return ((c % 16) * 4096) + ((a % 64) * 64) + (b % 64), 3
    if c >= 0xC0:
        if i + 1 >= n:
            return 0xFFFD, 1
        return ((c % 32) * 64) + (s[i + 1] % 64), 2
    return 0xFFFD, 1

def _sv_enc_string(s):
    out, i = ['"'], 0
    while i < len(s):
        c = s[i]
        if c < 0x80:
            out.append(_SV_JESC.get(c) or ("\\u%04x" % c if c < 0x20 or c == 0x7F else chr(c)))
            i += 1
        else:
            cp, ln = _sv_utf8cp(s, i)
            if cp >= 0x10000:
                cp -= 0x10000
                out.append("\\u%04x\\u%04x" % (0xD800 + cp // 1024, 0xDC00 + cp % 1024))
            else:
                out.append("\\u%04x" % cp)
            i += ln
    out.append('"')
    return "".join(out)

def _sv_enc(v, out, depth):
    if depth > 40:
        raise SVError("too deep")
    if isinstance(v, bytes):
        out.append(_sv_enc_string(v))
    elif isinstance(v, bool):
        out.append("true" if v else "false")
    elif isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            raise SVError("bad number")
        out.append("%d" % v if v == int(v) and abs(v) < 1e15 else "%.14g" % v)
    elif isinstance(v, dict):
        if _sv_is_array(v):
            out.append("[")
            for i in range(1, len(v) + 1):
                if i > 1:
                    out.append(",")
                _sv_enc(v[float(i)], out, depth + 1)
            out.append("]")
        else:
            if not all(isinstance(k, bytes) for k in v):
                raise SVError("non-string key")
            out.append("{")
            for j, k in enumerate(sorted(v)):
                if j:
                    out.append(",")
                out.append(_sv_enc_string(k) + ":")
                _sv_enc(v[k], out, depth + 1)
            out.append("}")
    else:
        raise SVError("cannot encode")

def sv_text(path):
    """The canonical JSON text of every global in a saved-variables file: what sv2json.lua prints, without the final newline."""
    with open(path, "rb") as fh:
        env = sv_globals(fh.read())
    top = {k: n for k, v in env.items() if (n := _sv_norm(v, 0)) is not None}
    out = []
    _sv_enc(top, out, 0)
    return "".join(out)

def sv_json(path):
    return json.loads(sv_text(path))


RECORDING_FORMAT = 1
ITEM_LINK = re.compile(r"\|Hitem:([^|]*)\|h")

def anonymize_link(value):
    """An item link carries the looking player's level and specialization (fields 9 and 10 after the item id). A recording keeps the item and
    empties those two fields, so it names no character."""
    if not isinstance(value, str):
        return value
    def blank(m):
        parts = m.group(1).split(":")
        for i in (8, 9):
            if i < len(parts):
                parts[i] = ""
        return "|Hitem:" + ":".join(parts) + "|h"
    return ITEM_LINK.sub(blank, value)
CALL_LABEL = re.compile(r"^([A-Za-z_][\w.]*)\((.*)\)$")

def probe_recordings(sv_path):
    """(client, recording, skipped) from the CTProbeDB.fixtures that CTProbe's /ctp record saved. recording is {format, client, build, calls}
    with calls[label] = {api, args, returns, n, nils}: the arguments are parsed from the label (numbers and plain words), a nil return is a
    false placeholder listed in nils (the plan JSON has no null). skipped names each call left out and why: one that raised an error, a
    personal value (recorded by type only), a call on the player, an argument the label cannot give back exactly (a quoted string, nil),
    and a return that is a table or a function."""
    db = sv_json(sv_path).get("CTProbeDB")
    if not isinstance(db, dict) or not isinstance(db.get("fixtures"), dict):
        raise ValueError("%s holds no CTProbeDB.fixtures: run /ctp record in game, then /reload" % sv_path)
    build_call = db["fixtures"].get("GetBuildInfo()")
    values = [v.get("value") for v in (build_call or {}).get("values", [])]
    if len(values) < 4 or not isinstance(values[3], (int, float)):
        raise ValueError("%s has no GetBuildInfo() recording, so the client is unknown" % sv_path)
    client = "forever" if values[3] >= 16000 else "era"
    calls, skipped = {}, []
    for label in sorted(db["fixtures"]):
        rec = db["fixtures"][label]
        m = CALL_LABEL.match(label)
        if "error" in rec:
            skipped.append((label, "the call raised an error in game: %s" % str(rec["error"])[:60])); continue
        if rec.get("typeOnly"):
            skipped.append((label, "a personal value, recorded by type only")); continue
        if not m:
            skipped.append((label, "the label is not a call")); continue
        parts = [p.strip() for p in m.group(2).split(",") if p.strip()]
        if "player" in parts:
            skipped.append((label, "a call on the player")); continue
        if any(not re.fullmatch(r"-?\d+(\.\d+)?|true|false|[A-Za-z_]\w*", p) for p in parts) or "nil" in parts:
            skipped.append((label, "an argument that cannot be read back exactly from the label")); continue
        args = []
        for part in parts:
            args.append(True if part == "true" else False if part == "false" else int(part) if re.fullmatch(r"-?\d+", part)
                        else float(part) if re.fullmatch(r"-?\d+\.\d+", part) else part)
        returns, nils, bad = [], [], None
        for i, v in enumerate(rec.get("values", []), 1):
            t = v.get("type")
            if t == "nil":
                returns.append(False); nils.append(i)
            elif t in ("table", "function", "userdata", "thread"):
                bad = t
            else:
                returns.append(anonymize_link(v.get("value")))
        if bad:
            skipped.append((label, "returns a %s" % bad)); continue
        calls[label] = {"api": m.group(1), "args": args, "returns": returns, "n": int(rec.get("n", len(returns)))}
        if nils:
            calls[label]["nils"] = nils
    build = ".".join(str(x) for x in values[:2])
    return client, {"format": RECORDING_FORMAT, "client": client, "build": build, "calls": calls}, skipped

def cmd_recordings(a):
    try:
        client, rec, skipped = probe_recordings(a.src)
    except (OSError, ValueError) as e:
        print("error: %s" % e, file=sys.stderr); return 2
    out = a.out or os.path.join(ROOT, "tools", "recordings")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, client + ".json")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rec, f, indent=1, sort_keys=True); f.write("\n")
    print("recordings: %d calls for %s (build %s) -> %s" % (len(rec["calls"]), client, rec["build"], path))
    for label, why in skipped:
        print("  left out  %s: %s" % (label, why))
    return 0


WATCH = ("CheckThat", "KeepThat", "DontDoThat", "ClosestVendor")   # the files collected when no plan is given

def sv_wanted(plan):
    """(file names, globals) a plan asks for: its addon's file, CheckThat's own, and every logs.*.global."""
    plan = plan if isinstance(plan, dict) else {}
    stems = ["CheckThat"] + ([plan["addon"]] if isinstance(plan.get("addon"), str) else [])
    logs = plan.get("logs") if isinstance(plan.get("logs"), dict) else {}
    globs = {l["global"] for l in logs.values() if isinstance(l, dict) and isinstance(l.get("global"), str)}
    return tuple(stems), globs

def find_sv(src, stems=WATCH, globs=(), defined=None):
    """Saved-variables files under src: those named in stems, and (when globs is given) those that assign one of the globals.
    Each global found is added to the set defined."""
    found = set()
    for p in glob.glob(os.path.join(src, "**", "SavedVariables", "*.lua"), recursive=True):
        hit = os.path.basename(p)[:-4] in stems
        if globs:
            try:
                with open(p, "rb") as fh:
                    data = fh.read()
            except OSError:
                continue
            for g in globs:
                if re.search(rb"(?m)^\s*" + re.escape(g.encode()) + rb"\s*=", data):
                    hit = True
                    if defined is not None:
                        defined.add(g)
        if hit:
            found.add(p)
    return sorted(found)


WOW_CLIENTS = ("_classic_era_", "_forever_")


def wow_sources(wow):
    """Standard layout: <game dir>/<client>/WTF and <client>/Screenshots for each client folder that exists."""
    found = [c for c in WOW_CLIENTS if os.path.isdir(os.path.join(wow, c, "WTF"))]
    return [(os.path.join(wow, c, "WTF"), wow) for c in found], [os.path.join(wow, c, "Screenshots") for c in found]


def find_wow():
    """The game folder in a usual install place for this OS, or None. It holds _classic_era_ or _forever_ with a WTF folder."""
    pf = [os.environ.get(k) for k in ("ProgramFiles(x86)", "ProgramFiles")]
    drives = ["C:/Program Files (x86)", "C:/Program Files", "D:/Program Files (x86)", "D:/Program Files"] if os.name == "nt" else []
    wine = ["~/.wine/drive_c/Program Files (x86)", "~/Games/world-of-warcraft/drive_c/Program Files (x86)"] if sys.platform.startswith("linux") else []
    bases = [p for p in pf + drives] + [os.path.expanduser(p) for p in wine] + (["/Applications"] if sys.platform == "darwin" else [])
    for base in bases:
        w = os.path.join(base, "World of Warcraft") if base else None
        if w and wow_sources(w)[0]:
            return w
    return None

def cmd_collect(a):
    dest = a.dest
    wow = getattr(a, "wow", None)
    if not a.src and not wow and not os.path.isdir(default_src()):
        wow = find_wow()
        if not wow:
            sys.exit("no saved variables found: pass --wow <game folder> (holds _classic_era_ or _forever_), or --src <WTF folder>; CT_WOW and CT_WTF work too (docs/harvesting.md)")
        print("using the game folder %s" % wow)
    if a.src or not wow:
        sources, shot_dirs = [(a.src or default_src(), a.src or default_src())], [getattr(a, "shots", None)]
    else:
        sources, shot_dirs = wow_sources(wow)
        if not sources:
            sys.exit("no %s folder with WTF under %s" % (" or ".join(WOW_CLIENTS), wow))
        if getattr(a, "shots", None):
            shot_dirs = [a.shots]
    new_sv = new_runs = failed = 0
    plan = getattr(a, "plan", None)
    want = sv_wanted(load_yaml(plan)) if plan else (WATCH, set())
    defined = set()
    for src, base in sources:
        n_sv, n_runs, n_failed = collect_src(src, base, dest, want, defined)
        new_sv += n_sv; new_runs += n_runs; failed += n_failed
    for g in sorted(want[1] - defined):
        print("warning: no saved-variables file under %s defines %s (a plan log reads it)" % (", ".join(s for s, _ in sources), g), file=sys.stderr)
    new_shots, loose = 0, []
    for d in shot_dirs:
        n, un = collect_shots(dest, d, all_shots=getattr(a, "all_shots", False), slack=getattr(a, "shot_slack", 2))
        new_shots += n; loose += un
    print("collected: %d new saved-variable copies, %d new run revisions, %d new screenshots -> %s" % (new_sv, new_runs, new_shots, dest))
    if loose:
        print("%d screenshot%s matched no attempt (taken outside every step, within an hour of one)%s" % (
            len(loose), "" if len(loose) == 1 else "s", "" if getattr(a, "verbose", False) else ": --verbose names them, --all-shots keeps them"))
        near = min(g for _, _, _, g in loose)
        if near <= SHOT_SKEW_HINT:
            print("the nearest is %d s outside a step: on a game folder over a network mount the file times may differ from the game clock; try --shot-slack %d" % (near, near + 1))
        if getattr(a, "verbose", False):
            for name, rid, sid, gap in loose:
                print("  %s: %d s from step %s of run %s" % (name, gap, sid, rid))
    if failed:
        print("error: %d saved-variables file(s) could not be decoded (is the file damaged?)" % failed, file=sys.stderr)
        return 1
    return 0


def default_src():
    return os.path.join(os.path.dirname(ROOT), "shared-addon-resources", "saved")


def doctor_report(src=None, wow=None, env=None, want=(WATCH, ())):
    """Lines that say where collect looks, what it finds there and the likely reason for a miss. Returns (lines, found): found is the
    number of saved-variables files collect would read. want is (file names, globals), as collect --plan gives. It reads nothing but
    folder listings and file times; a folder it cannot read is reported, not raised."""
    env = os.environ if env is None else env
    src, wow = src or env.get("CT_WTF"), wow or env.get("CT_WOW")
    lines, found = [], 0
    def report_src(label, folder, base):
        nonlocal found
        lines.append("%s: %s" % (label, folder))
        try:
            files = find_sv(folder, want[0], want[1])
        except OSError as e:
            lines.append("  cannot read it: %s" % e)
            return
        if not os.path.isdir(folder):
            lines.append("  not a folder: check the path (a typo, a drive that is not mounted, or a Wine prefix on another path)")
            return
        if not files:
            lines.append("  no saved-variables file named %s under it: the addon writes one only after /reload or logout, and only for a character that logged in" % ", ".join(want[0]))
        for f in files:
            try:
                mt = os.path.getmtime(f)
            except OSError as e:
                lines.append("  cannot read %s: %s" % (f, e))
                continue
            lines.append("  found %s, modified %s, %s ago" % (os.path.relpath(f, base), time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(mt)), age(time.time() - mt)))
            found += 1
    if src:
        lines.append("--src or CT_WTF is set: it wins over the game folder")
        report_src("WTF folder", src, src)
    else:
        if wow:
            lines.append("game folder from --wow or CT_WOW: %s" % wow)
        elif os.path.isdir(default_src()):
            lines.append("default folder %s exists, so collect reads it as a WTF folder" % default_src())
            report_src("WTF folder", default_src(), default_src())
            return lines, found
        else:
            wow = find_wow()
            lines.append("no --src, --wow, CT_WTF or CT_WOW, and no default folder: %s" % (("found a game folder in a usual place: %s" % wow) if wow else "no game folder in a usual install place for this OS"))
        if not wow:
            lines.append("  pass --wow <game folder> (it holds _classic_era_ or _forever_) or --src <WTF folder>, or set CT_WOW or CT_WTF in .ct.env (docs/harvesting.md)")
        elif not os.path.isdir(wow):
            lines.append("  %s is not a folder: check the path, a mounted drive or a Wine prefix" % wow)
        else:
            for c in WOW_CLIENTS:
                wtf = os.path.join(wow, c, "WTF")
                if os.path.isdir(wtf):
                    report_src(c, wtf, wow)
                    shots = os.path.join(wow, c, "Screenshots")
                    try:
                        lines.append("  screenshots: %s" % (("%d file(s) in %s" % (len(os.listdir(shots)), shots)) if os.path.isdir(shots) else "no Screenshots folder (collect skips it)"))
                    except OSError as e:
                        lines.append("  screenshots: cannot read %s: %s" % (shots, e))
                else:
                    lines.append("%s: no WTF folder at %s (this client is not installed or never started here)" % (c, wtf))
            try:
                others = sorted(d for d in os.listdir(wow) if d.startswith("_") and d.endswith("_") and d not in WOW_CLIENTS and os.path.isdir(os.path.join(wow, d, "WTF")))
            except OSError as e:
                others = []
                lines.append("cannot list %s: %s" % (wow, e))
            for d in others:
                lines.append("%s: has a WTF folder, but collect does not read it (only %s are measured layouts); pass --src %s to read it" % (d, " and ".join(WOW_CLIENTS), os.path.join(wow, d, "WTF")))
    if not found:
        lines.append("result: collect would find nothing")
    else:
        lines.append("result: collect would read %d saved-variables file(s)" % found)
    return lines, found


def cmd_doctor(a):
    plan = getattr(a, "plan", None)
    lines, found = doctor_report(getattr(a, "src", None), getattr(a, "wow", None), want=sv_wanted(load_yaml(plan)) if plan else (WATCH, ()))
    print("\n".join(lines))
    return 0 if found else 1


CENSUS_MISSING = "no census in the saved variables. Run /ct census, wait for completion, type /reload, then copy SavedVariables again."

def census_manifest(rec):
    """The manifest dict (docs/harvesting.md) for one census record of CheckThatDB.global.census, or None when it is not one.
    The game recorded only the names it defines itself. When the client could not tell (the record says "unfiltered"), globals
    that a loaded addon owns (names that start with its folder name) are dropped as the best guess."""
    if not isinstance(rec, dict) or not isinstance(rec.get("globals"), dict) or not isinstance(rec.get("interface"), (int, float)):
        return None
    addons = [x for x in (rec.get("addons") if isinstance(rec.get("addons"), list) else []) if isinstance(x, str) and len(x) > 2 and not x.startswith("Blizzard_")]
    own = (lambda name: any(name.startswith(x) for x in addons)) if rec.get("unfiltered") else (lambda name: False)
    def dict_of(v):   # an empty Lua table decodes to a list
        return v if isinstance(v, dict) else {}
    interface = int(rec["interface"])
    return {"format": 1, "client": "forever" if interface >= 16000 else "era", "build": str(rec.get("build")), "interface": interface,
            "date": rec.get("date"), "addons": sorted(addons),
            "globals": {k: v for k, v in rec["globals"].items() if not own(k)},
            "insecure": {k: v for k, v in dict_of(rec.get("insecure")).items() if isinstance(v, str)},
            "tables": {k: dict_of(v) for k, v in dict_of(rec.get("tables")).items() if not own(k)},
            "widgets": {k: sorted(v) for k, v in dict_of(rec.get("widgets")).items() if isinstance(v, list)},
            "unavailable": sorted(rec["unavailable"]) if isinstance(rec.get("unavailable"), list) else [],
            "truncated": sorted(x for x in rec["truncated"] if isinstance(x, str)) if isinstance(rec.get("truncated"), list) else [],
            **({"unfiltered": True} if rec.get("unfiltered") else {})}

def census_records(files):
    """{build: record} from the CheckThat saved-variables files, each holding one census (the newest of its client).
    The newer date wins when a build is in several files."""
    found = {}
    for f in files:
        db = sv_json(f).get("CheckThatDB")
        glob_db = db.get("global") if isinstance(db, dict) else None
        rec = glob_db.get("census") if isinstance(glob_db, dict) else None
        if isinstance(rec, dict) and rec.get("build") is not None and isinstance(rec.get("globals"), dict):
            build = str(rec["build"])
            if str(rec.get("date") or "") >= str((found.get(build) or {}).get("date") or ""):
                found[build] = rec
    return found

def cmd_census(a):
    if a.diff:
        return census_diff(a.diff[0], a.diff[1])
    wow = a.wow
    if not a.src and not wow and not os.path.isdir(default_src()):
        wow = find_wow()
        if not wow:
            print("error: no saved variables found: pass --wow <game folder> or --src <WTF folder>; CT_WOW and CT_WTF work too (docs/harvesting.md)", file=sys.stderr)
            return 1
    sources = [(a.src or default_src(), None)] if a.src or not wow else wow_sources(wow)[0]
    files = sorted({f for src, _ in sources for f in find_sv(src, ("CheckThat",))})
    try:
        records = census_records(files)
    except Exception as e:
        print("error: could not decode the saved variables: %s" % e, file=sys.stderr)
        return 1
    manifests = [m for m in map(census_manifest, records.values()) if m]
    if not manifests:
        print("error: " + CENSUS_MISSING, file=sys.stderr)
        return 1
    out = a.o or os.path.join(ROOT, "tests", "manifests")
    os.makedirs(out, exist_ok=True)
    for m in sorted(manifests, key=lambda m: (m["client"], m["build"])):
        path = os.path.join(out, "%s-%s.json" % (m["client"], re.sub(r"[^\w.-]", "_", m["build"])))
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps(m, indent=1, sort_keys=True, ensure_ascii=False) + "\n")
        print(path)
    return 0

def census_diff(old_path, new_path):
    """Print the names added, removed and changed in type between two manifests."""
    try:
        old, new = (json.load(open(p, encoding="utf-8")) for p in (old_path, new_path))
    except (OSError, ValueError) as e:
        print("error: cannot read a manifest: %s" % e, file=sys.stderr)
        return 1
    def names(m):   # "kind name" -> type, for globals, table members and widget methods
        d = {"global " + k: v for k, v in (m.get("globals") or {}).items()}
        for t, members in (m.get("tables") or {}).items():
            d.update({"member %s.%s" % (t, k): v for k, v in members.items()})
        for w, methods in (m.get("widgets") or {}).items():
            d.update({"method %s:%s" % (w, k): "function" for k in methods})
        return d
    a, b = names(old), names(new)
    lines = ["+ %s (%s)" % (k, b[k]) for k in sorted(b.keys() - a.keys())]
    lines += ["- %s (%s)" % (k, a[k]) for k in sorted(a.keys() - b.keys())]
    lines += ["~ %s: %s -> %s" % (k, a[k], b[k]) for k in sorted(a.keys() & b.keys()) if a[k] != b[k]]
    for l in lines:
        print(l)
    added = sum(l[0] == "+" for l in lines); removed = sum(l[0] == "-" for l in lines)
    print("%d added, %d removed, %d changed type" % (added, removed, len(lines) - added - removed))
    return 0


def save_errors(dest, glob_db, h, rids=()):
    """Keep the saved Lua error lines and their call stacks (they are not part of a run) next to the run copies."""
    if not isinstance(glob_db, dict):
        return
    errs, stacks = glob_db.get("errors"), glob_db.get("errorStacks")
    errs, stacks = errs if isinstance(errs, list) else [], stacks if isinstance(stacks, list) else []
    if errs or stacks:
        os.makedirs(os.path.join(dest, "errors"), exist_ok=True)
        with open(os.path.join(dest, "errors", h + ".json"), "w", encoding="utf-8") as fh:
            json.dump({"runs": list(rids), "errors": errs, "errorStacks": stacks}, fh, indent=1)

def load_errors(dest, rid=None):
    """({key: error line}, {key: call stack}) from the collected saved-variables copies. The key is <time>.<counter> and is only
    unique inside one game session, so with rid only the copies that hold that run count."""
    errs, stacks = {}, {}
    for p in sorted(glob.glob(os.path.join(dest or "", "errors", "*.json"))):
        try:
            with open(p, encoding="utf-8") as fh:
                d = json.load(fh)
        except (ValueError, OSError):
            continue
        if rid is not None and d.get("runs") and rid not in d["runs"]:
            continue
        for lines, into in ((d.get("errors"), errs), (d.get("errorStacks"), stacks)):
            for line in lines or []:
                if isinstance(line, str) and " " in line:
                    into.setdefault(line.split(" ", 1)[0], line.split(" ", 1)[1])
    return errs, stacks

def collect_src(src, base, dest, want=(WATCH, ()), defined=None):
    os.makedirs(os.path.join(dest, "sv"), exist_ok=True)
    os.makedirs(os.path.join(dest, "runs"), exist_ok=True)
    new_sv = new_runs = failed = 0
    for f in find_sv(src, want[0], want[1], defined):
        with open(f, "rb") as fh:
            data = fh.read()
        mt = os.path.getmtime(f)
        print("source: %s, modified %s, %s ago" % (os.path.relpath(f, base), time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(mt)), age(time.time() - mt)))
        h = hashlib.sha1(data).hexdigest()[:10]
        rel = os.path.relpath(f, base).replace(os.sep, "__")
        out = os.path.join(dest, "sv", "%s.%s.lua" % (rel[:-4], h))
        if not os.path.exists(out):
            shutil.copyfile(f, out); new_sv += 1
        if os.path.basename(f) == "CheckThat.lua":
            try:
                db = sv_json(f).get("CheckThatDB") or {}   # an empty Lua table decodes to a list
            except Exception as e:
                print("error: could not decode %s: %s" % (f, e), file=sys.stderr); failed += 1
                note_problem(dest, "could not decode %s (%s): %s" % (os.path.relpath(f, base), h, e)); continue
            glob_db = db.get("global") if isinstance(db, dict) else None
            save_errors(dest, glob_db, h, [str(k) for k in ((glob_db or {}).get("runs") or db.get("runs") or {})] if isinstance(glob_db, dict) else [])
            runs = (glob_db.get("runs") if isinstance(glob_db, dict) else None) or (db.get("runs") if isinstance(db, dict) else None) or {}
            if not isinstance(runs, dict):
                runs = {}
            future = glob_db.get("future") if isinstance(glob_db, dict) else None   # runs a newer CheckThat set aside: refused below, and said so
            future = future if isinstance(future, dict) else {}
            for table, rid, run in [("runs", k, v) for k, v in runs.items()] + [("future", k, v) for k, v in future.items()]:   # each table on its own: an id can be in both
                if not isinstance(run, dict):
                    continue
                run = dict(run); run.setdefault("runId", rid)
                try:
                    res = write_revision(dest, run)
                except MajorError as e:
                    print("warning: run %r not stored: %s" % (rid, e), file=sys.stderr)
                    set_refused(dest, rid, run.get("revision"), " ".join(str(e).split())); continue
                except (ValueError, OSError, TypeError) as e:
                    print("skip run %r: %s" % (rid, e), file=sys.stderr)
                    note_problem(dest, "run %s was not stored: %s" % (rid, " ".join(str(e).split()))); continue
                clear_refused(dest, rid, run.get("revision"))   # stored now, and as new as the refused one: that refusal is over
                if res == "new":
                    new_runs += 1
                elif res == "conflict":
                    msg = "run %s revision %s already stored with different content; kept the first (two testers may share an id); new copy in sv/*.%s.lua" % (rid, run.get("revision"), h)
                    print("warning: " + msg, file=sys.stderr)
                    note_problem(dest, msg)
    return new_sv, new_runs, failed


SHOT_EXT = (".jpg", ".jpeg", ".png", ".tga")


SHOT_SKEW_HINT = 120   # a loose screenshot this close to an attempt may be clock skew, not a late photo
SHOT_NEAR = 3600   # a screenshot this many seconds from an attempt, outside its window, is reported; older files are not ours to count
SHOT_CLIENT = {"_classic_era_": "classic-era", "_forever_": "forever-camelot"}


def collect_shots(dest, shots_dir, all_shots=False, slack=2):
    """Copy screenshots whose mtime falls inside a step attempt window (plus slack seconds each side) into runs/<id>/shots/.
    Returns (copied, loose): loose lists (file, run, step, gap in seconds) for each file that fits no window but lies within SHOT_NEAR of one.
    A file inside a window is matched whether or not an earlier collect copied it. all_shots copies loose files to runs/<id>/unassigned-shots/."""
    if not shots_dir or not os.path.isdir(shots_dir):
        return 0, []
    files = []
    for name in os.listdir(shots_dir):
        if name.lower().endswith(SHOT_EXT):
            p = os.path.join(shots_dir, name)
            files.append((os.path.getmtime(p), name, p))
    client = next((v for k, v in SHOT_CLIENT.items() if k in shots_dir.replace("\\", "/")), None)
    wins = []   # (run id, plan position, step, start, end)
    for rid, run in sorted(latest_runs(dest).items()):
        pos = {s: i for i, s in enumerate(step_ids(run))}
        for sid, rec in (run.get("steps") or {}).items():
            for at in rec.get("attempts", []):
                start = at.get("started")
                if isinstance(start, (int, float)):
                    wins.append((rid, pos.get(sid, 0), sid, start, at.get("finished") or start + 900, run.get("client")))
    copied, loose = 0, []
    for mt, name, p in sorted(files):
        inside = [w for w in wins if w[3] - slack <= mt <= w[4] + slack]
        for rid, _, sid, _, _, _ in inside:
            out = os.path.join(dest, "runs", safe_name(rid), "shots", "%s__%s" % (safe_name(sid), safe_name(name)))
            if not os.path.exists(out):
                os.makedirs(os.path.dirname(out), exist_ok=True)
                shutil.copyfile(p, out); copied += 1
        if inside:
            continue
        pool = [w for w in wins if client and w[5] == client] or wins   # prefer a run of this folder's client
        if not pool:
            continue
        near = min(pool, key=lambda w: (max(w[3] - mt, mt - w[4], 0), w[0], w[1]))
        gap = int(max(near[3] - mt, mt - near[4], 0))
        if gap > SHOT_NEAR:
            continue
        loose.append((name, near[0], near[2], gap))
        if all_shots:
            out = os.path.join(dest, "runs", safe_name(near[0]), "unassigned-shots", safe_name(name))
            if not os.path.exists(out):
                os.makedirs(os.path.dirname(out), exist_ok=True)
                shutil.copyfile(p, out)
    return copied, loose


def run_shots(dest, rid):
    d = os.path.join(dest, "runs", rid, "shots")
    out = {}
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            out.setdefault(f.split("__", 1)[0], []).append(f)
    return out


def latest_runs(dest, skipped=None):
    """The newest readable revision of each run. skipped, when given, gets (run id, file, reason) for each newer revision that was unreadable."""
    runs = {}
    for rp in glob.glob(os.path.join(dest, "runs", "*")):
        for p in reversed(rev_files(rp)):   # newest readable revision; status names a damaged one
            try:
                runs[os.path.basename(rp)] = read_run(p)
                break
            except (ValueError, OSError) as e:
                if skipped is not None:
                    skipped.append((os.path.basename(rp), os.path.basename(p), " ".join(str(e).split())))
    if skipped is not None:
        for rid, info in sorted(load_refused(dest).items()):
            skipped.append((rid, "the collected copy", info.get("reason", "")))
    return runs

def rev_files(rp):
    """Revision files of one run, oldest first. A file that is not r<number>.json is not a revision."""
    found = [(int(m.group(1)), p) for p in glob.glob(os.path.join(rp, "r*.json")) for m in [re.fullmatch(r"r(\d+)\.json", os.path.basename(p))] if m]
    return [p for _, p in sorted(found)]

def _pos(v):
    return isinstance(v, int) and not isinstance(v, bool) and v >= 1

CHECK_STRINGS = ("why", "kind", "scope", "source", "label", "rule", "shape", "observed")

def outcome_ok(o):
    """An outcome and, when it has them, its check detail, as schema/run-results.schema.json says: counts are whole numbers,
    text is text, and there are at most three hits, each {n >= 1, ...}."""
    if not isinstance(o, dict):
        return False
    hits = o.get("hits", [])
    if not isinstance(hits, list) or len(hits) > 3:
        return False
    for h in hits:
        if not (isinstance(h, dict) and _pos(h.get("n")) and (h.get("item") is None or _pos(h.get("item")))
                and all(h.get(k) is None or isinstance(h[k], str) for k in ("line", "value"))):
            return False
    if o.get("scope") not in (None, "attempt", "session") or o.get("trimmed") not in (None, True):
        return False
    return all(o.get(k) is None or isinstance(o[k], str) for k in CHECK_STRINGS) \
        and all(o.get(k) is None or (isinstance(o[k], int) and not isinstance(o[k], bool) and o[k] >= 0) for k in ("matched", "window")) \
        and (o.get("stoppedAt") is None or _pos(o.get("stoppedAt")))

SUPPORTED_MAJOR = 1   # the `ct` of the run record this tool reads (CheckThat/Model/Run.lua Run.MAJOR); a higher one is refused, never guessed at

class MajorError(ValueError):
    """A run this tool must not interpret: a newer major format, or a `ct` that is not a whole number."""

def check_major(run):
    """An absent ct is a run from before it was kept. A present one must be a whole number from 1 to SUPPORTED_MAJOR (2.0 is 2)."""
    if not isinstance(run, dict) or "ct" not in run:
        return
    c = run["ct"]
    if isinstance(c, bool) or not isinstance(c, (int, float)) or c != c or c in (float("inf"), float("-inf")) or c != int(c) or c < 1:
        raise MajorError("ct %r is not a whole number from 1: not a run this tool can read" % (c,))
    if int(c) > SUPPORTED_MAJOR:
        raise MajorError("format %d is newer than this tool reads (%d): use a newer tools folder" % (int(c), SUPPORTED_MAJOR))

def refused_path(dest):
    return os.path.join(dest, "refused.json")

def load_refused(dest):
    try:
        with open(refused_path(dest), encoding="utf-8") as fh:
            d = json.load(fh)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}

def set_refused(dest, rid, revision, reason):
    """A run collect could not store because of its format. report and status keep saying so until a later collect stores it."""
    d = load_refused(dest)
    d[rid] = {"revision": revision, "reason": reason}
    with open(refused_path(dest), "w", encoding="utf-8") as fh:
        json.dump(d, fh, indent=1, sort_keys=True)

def clear_refused(dest, rid, stored_revision=None):
    """Drop the refusal of a run once a revision at least as new as the refused one is stored."""
    d = load_refused(dest)
    refused = (d.get(rid) or {}).get("revision")
    if rid in d and not (isinstance(refused, int) and isinstance(stored_revision, int) and stored_revision < refused):
        d.pop(rid)
        with open(refused_path(dest), "w", encoding="utf-8") as fh:
            json.dump(d, fh, indent=1, sort_keys=True)

def read_run(path):
    """One stored revision. Raises ValueError (or OSError) when it is not a run record."""
    with open(path, encoding="utf-8") as fh:
        run = json.load(fh)
    check_major(run)   # before the shape: a newer format may have changed it
    if isinstance(run, dict) and run.get("steps") == []:
        run["steps"] = {}   # an empty Lua table decodes to a list
    if not isinstance(run, dict) or not isinstance(run.get("steps"), dict) or not isinstance(run.get("order", []), list):
        raise ValueError("not a run record")
    cats = run.get("categories", [])
    if (not all(isinstance(s, str) for s in run.get("order", []))
            or not isinstance(cats, list) or not all(isinstance(c, dict) and isinstance(c.get("id"), str) for c in cats)
            or not isinstance(run.get("cat", {}), dict) or not isinstance(run.get("selected", {}), dict)):
        raise ValueError("not a run record")
    for rec in run["steps"].values():   # the readers below call .get on each of these
        ats = rec.get("attempts", []) if isinstance(rec, dict) else None
        if not isinstance(ats, list) or not all(isinstance(a, dict) and isinstance(a.get("outcomes", []), list) and all(outcome_ok(o) for o in a.get("outcomes", []))
                                                and isinstance(a.get("excerpt", {}), dict) for a in ats):
            raise ValueError("a step record is malformed")
        if not isinstance(rec.get("verdict", ""), str) or not all(isinstance(a.get(k), (str, type(None))) for a in ats for k in ("verdict", "note", "by")):
            raise ValueError("a step record is malformed")
    return run


def by_checkthat(rec):
    """True when the runner, not the player, recorded the step's last result (an auto step)."""
    done = [a for a in rec.get("attempts") or [] if a.get("verdict")]   # an open retry has no result yet
    return rec.get("verdict") != "pending" and bool(done) and done[-1].get("by") == "auto"   # Undo reopens the step


def evidence_state(rec):
    """met, bad, missing or none: the required checks of the step's last finished attempt. A step reopened by Undo or a rerun has none."""
    if rec.get("verdict") == "pending":
        return "none"
    done = [a for a in rec.get("attempts") or [] if a.get("verdict")]
    outs = [o for o in (done[-1].get("outcomes") or []) if not o.get("diagnostic")] if done else []
    if not outs:
        return "none"
    results = {o.get("result") for o in outs}
    if "fail" in results:
        return "bad"
    return "met" if results == {"pass"} else "missing"   # an outcome without a result is not evidence


def category_rule(c):
    """red, yellow, green, blue or grey from step counts (the rule in CheckThat/Model/Run.lua, checked by one shared fixture)."""
    g = lambda k: c.get(k, 0)
    resolved = g("pass") + g("partial") + g("fail") + g("skip")
    open_ = g("pending") + g("unverified")
    if g("fail") > 0:
        return "red"
    if g("partial") > 0 or g("unverified") > 0:
        return "yellow"
    if open_ == 0 and g("pass") > 0:
        return "green"
    if open_ > 0:
        return "blue"
    return "grey"


def category_states(r):
    """[(id, title, state, resolved, total)] for a run that holds categories; state is off when the tester did not pick it."""
    out = []
    for cat in r.get("categories") or []:
        c = {}
        for sid, cid in (r.get("cat") or {}).items():
            v = (r.get("steps") or {}).get(sid, {}).get("verdict")
            if cid == cat["id"] and v not in ("deselected", "inapplicable", None):
                c[v] = c.get(v, 0) + 1
        total = sum(c.values())
        resolved = sum(c.get(k, 0) for k in ("pass", "partial", "fail", "skip"))
        picked = (r.get("selected") or {}).get(cat["id"])
        out.append((cat["id"], cat.get("title", cat["id"]), category_rule(c) if picked else "off", resolved, total))
    return out


def step_ids(r):
    """Steps in plan order, then any other recorded step (one the client does not use) in name order."""
    order = list(dict.fromkeys(r.get("order") or []))
    return order + sorted(s for s in (r.get("steps") or {}) if s not in order)


def awaiting_retry(rec):
    """A pending step that Undo or a rerun reopened. The flag is trusted only on a pending step (an older CheckThat can finish it without clearing it);
    a run saved before the flag has none, so a pending step with a finished attempt counts too."""
    return rec.get("verdict") == "pending" and (rec.get("reopened") is True or any(a.get("verdict") for a in rec.get("attempts") or []))


def step_table(r, only=None):
    """One row per step in plan order: step, verdict, evidence, attempts, note. only limits it to some step ids."""
    rows = [("step", "verdict", "evidence", "attempts", "note")]
    for sid in step_ids(r):
        if only is not None and sid not in only:
            continue
        rec = (r.get("steps") or {}).get(sid, {})
        done = [a for a in rec.get("attempts") or [] if a.get("verdict")]
        reopened = awaiting_retry(rec)   # Undo or a rerun: the older attempt no longer speaks for the step
        note = "awaiting retry" if reopened else " ".join(((done[-1].get("note") or "") if done else "").splitlines())   # splitlines also splits Unicode line breaks
        if len(note) > 40:
            note = note[:37] + "..."
        stale = rec.get("macroStale")
        if isinstance(stale, int) and stale > 0:
            note = ((note + "; ") if note else "") + "%d stale macro press%s" % (stale, "" if stale == 1 else "es")
        rows.append((sid, str(rec.get("verdict", "?")), evidence_state(rec), str(len(rec.get("attempts") or [])), note))
    widths = [max(len(row[i]) for row in rows) for i in range(4)]
    return ["  ".join(c.ljust(widths[i]) for i, c in enumerate(row[:4])) + ("  " + row[4] if row[4] else "") for row in rows]


CHECK_KEYS = ("kind", "scope", "source", "label", "matched", "window", "stoppedAt", "trimmed")

def outcome_view(index, o, lines=False):
    """One check outcome as plain data for other tools. Line text, values and observed state are left out unless lines is set,
    because log lines can hold private data. Positions (n) and counts are always there."""
    v = {"index": index, "result": o.get("result"), "why": o.get("why"), "diagnostic": bool(o.get("diagnostic"))}
    v.update({k: o[k] for k in CHECK_KEYS if o.get(k) is not None})
    rule = o.get("rule") if lines else o.get("shape")   # the full rule holds the plan's literals, which can be a log line: it needs --lines
    if rule is not None:
        v["rule"] = rule
    hits = []
    for h in o.get("hits") or []:
        hv = {k: h[k] for k in ("n", "item") if h.get(k) is not None}
        if lines:
            hv.update({k: h[k] for k in ("line", "value") if h.get(k) is not None})
        hits.append(hv)
    if hits:
        v["hits"] = hits
    if lines and o.get("observed") is not None:
        v["observed"] = o["observed"]
    return v

def check_lines(at):
    """The checks of an attempt that did not pass, with what they looked at: rule, counts and the lines that decided them."""
    out = []
    for i, o in enumerate(at.get("outcomes") or [], 1):
        if o.get("result") == "pass" or not o.get("rule"):
            continue
        bits = [o.get("source") and "%s%s" % (o["source"], ", whole log" if o.get("scope") == "session" else "")]
        if o.get("matched") is not None and o.get("window") is not None:
            bits.append("%d of %d line%s matched" % (o["matched"], o["window"], "" if o["window"] == 1 else "s"))
        if o.get("stoppedAt") is not None:
            bits.append("stopped at item %d" % o["stoppedAt"])
        if o.get("trimmed"):
            bits.append("lines dropped to keep the export small")
        out.append("    check %d (%s, %s): %s%s" % (i, "diagnostic" if o.get("diagnostic") else "required", o.get("result"), o["rule"],
                                                  "  [" + "; ".join(b for b in bits if b) + "]" if any(bits) else ""))
        if o.get("observed") is not None:
            out.append("      saw: %s" % o["observed"])
        for h in o.get("hits") or []:
            out.append("      %s%s: %s%s" % ("item %d at line " % h["item"] if h.get("item") else "line ", h["n"], h.get("line", ""), "   (value %s)" % h["value"] if h.get("value") is not None else ""))
    return out

def attempt_lines(at, stack_keys, errs, stacks, ambiguous):
    note = at.get("note")
    outs = [o for o in (at.get("outcomes") or []) if o.get("result") != "pass"]
    out = ["  attempt %s: %s%s%s" % (at.get("n"), at.get("verdict"),
           " note=" + note if note else "",
           " evidence=" + ",".join("%s(%s)" % (o.get("result"), o.get("why", "")) for o in outs) if outs else "")]
    out.extend(check_lines(at))
    marked = {}   # source -> positions of the lines that decided a check, within the new lines the excerpt starts from
    for o in at.get("outcomes") or []:
        if o.get("result") != "pass" and o.get("scope") != "session":
            marked.setdefault(o.get("source"), set()).update(h["n"] for h in o.get("hits") or [])
    for src, lines in sorted((at.get("excerpt") or {}).items()):
        out.append("    log %s, %d new line%s:" % (src, len(lines), "" if len(lines) == 1 else "s"))
        out.extend(("    > " if i in marked.get(src, ()) else "      ") + str(line) for i, line in enumerate(lines, 1))
    for key in stack_keys:
        out.append("    error %s%s: %s" % (key, " (time also fits another attempt)" if key in ambiguous else "", errs.get(key, "(error line no longer saved)")))
        out.append("      stack: " + stacks[key])
    return out

def stored_id(rid, r):
    """The run id as the game wrote it. The folder name is a safe version of it (a non-ASCII id differs)."""
    return r.get("runId") if isinstance(r.get("runId"), str) else rid

def stack_hits(r, stacks):
    """{(step, attempt n): [stack keys]} for stacks raised inside the attempt's open time, and the keys that fit more than one attempt.
    The key is <time>.<counter>; time has whole-second precision, so a match is a candidate, not proof."""
    hits, count = {}, {}
    for key in stacks:
        try:
            sec = int(key.split(".")[0])
        except ValueError:
            continue
        for sid, rec in (r.get("steps") or {}).items():
            for at in rec.get("attempts") or []:
                s, f = at.get("started"), at.get("finished")
                if isinstance(s, (int, float)) and isinstance(f, (int, float)) and s <= sec <= f:
                    hits.setdefault((sid, at.get("n")), []).append(key)
                    count[key] = count.get(key, 0) + 1
    return hits, {k for k, n in count.items() if n > 1}

def run_warnings(runs, expect_version=None, digest=None, addon=None, title=None):
    """Warnings about the build a run used: the tested addon's version, CheckThat's own version against this tools bundle, and
    the plan digest. A run with no record of a field says nothing about it."""
    bundle = None
    for name in ("VERSION", os.path.join("CheckThat", "CheckThat_Vanilla.toc")):  # an installed bundle has VERSION, a checkout the TOC
        try:
            with open(os.path.join(ROOT, name), encoding="utf-8") as f:
                text = f.read()
            bundle = (re.search(r"## Version:\s*(\S+)", text) or [None, text.strip()])[1] or None
            break
        except OSError:
            pass
    out, told = [], set()
    for rid, r in sorted(runs.items()):
        if (addon and r.get("addon") != addon) or (title and r.get("planTitle") != title):
            continue  # another addon's run or a partner role's plan is not judged against this plan
        if expect_version and r.get("targetVersion") and r["targetVersion"] != expect_version:
            out.append("run %s tested addon version %s, not the expected %s: its results do not count for that build" % (rid, r["targetVersion"], expect_version))
        if bundle and r.get("writerVersion") and r["writerVersion"] != bundle and r["writerVersion"] not in told:
            told.add(r["writerVersion"])
            out.append("run %s was written by CheckThat %s but these tools are %s: reinstall the skill if the report looks wrong" % (rid, r["writerVersion"], bundle))
        if digest and r.get("planDigest") and r["planDigest"] != digest:
            out.append("run %s used plan %s, the plan file is %s now: edits since that run are untested" % (rid, r["planDigest"], digest))
    return out


def report_text(runs, dest=None, stacks=True, failed_only=False, step=None):
    """The Markdown report. failed_only keeps the runs and steps that failed or are unverified. step (one id) shows every attempt of that step."""
    out = ["# CT report", ""]
    for rid, r in sorted(runs.items()):
        only = {step} if step else {sid for sid in step_ids(r) if classify((r.get("steps") or {}).get(sid, {}))[0] in ("fail", "unverified")} if failed_only else None
        if failed_only and not only:
            continue
        errs, stks = load_errors(dest, stored_id(rid, r)) if stacks and dest else ({}, {})
        counts = {}
        for sid, rec in (r.get("steps") or {}).items():
            counts[rec.get("verdict", "?")] = counts.get(rec.get("verdict", "?"), 0) + 1
        out.append("## %s (%s, rev %s)" % (rid, r.get("planTitle", r.get("addon")), r.get("revision")))
        out.append("client %s build %s character %s" % (r.get("client"), r.get("build"), r.get("character")))
        auto = sum(1 for rec in (r.get("steps") or {}).values() if by_checkthat(rec))
        out.append("counts: " + ", ".join("%s=%d" % kv for kv in sorted(counts.items())) + (", auto=%d" % auto if auto else ""))
        cats = category_states(r)
        if cats:
            out.append("categories: " + ", ".join("%s %s %d/%d" % (cid, state, res, tot) if state != "off" else "%s not picked" % cid
                                                   for cid, _, state, res, tot in cats))
        hits, ambiguous = stack_hits(r, stks)
        bad = [m for m in (classify(rec)[0] for rec in (r.get("steps") or {}).values()) if m in ("fail", "unverified")]
        out.append("result: " + ("FAIL" if "fail" in bad else "UNVERIFIED" if bad else "ok") + (" (%d fail, %d unverified)" % (bad.count("fail"), bad.count("unverified")) if bad else ""))
        out.append("")
        out.extend(step_table(r, only))
        out.append("")
        for sid in step_ids(r):
            if only is not None and sid not in only:
                continue
            rec = (r.get("steps") or {}).get(sid, {})
            shots = (run_shots(dest, rid) if dest else {}).get(sid, [])
            mark = ", recorded by CheckThat" if by_checkthat(rec) else ""
            settled = rec.get("verdict") in ("pass", "skip", "inapplicable") and classify(rec)[0] not in ("fail", "unverified") and not step   # a pass its evidence contradicts keeps its detail
            def bad_check(at):
                return any(o.get("result") != "pass" for o in at.get("outcomes") or [])
            earlier = [at for at in rec.get("attempts", []) if at.get("verdict") in ("fail", "unverified") or bad_check(at)] if settled else []   # a pass with a failed diagnostic shows it
            head = "- %s: %s%s%s" % (sid, rec.get("verdict"), mark, (", screenshots: " + ", ".join(shots)) if shots else "")
            if (shots or mark or earlier) and settled:
                bad = [at for at in earlier if at.get("verdict") in ("fail", "unverified")]
                odd = len(earlier) - len(bad)
                out.append(head + (", after %d earlier failed or unverified attempt%s" % (len(bad), "" if len(bad) == 1 else "s") if bad else "")
                             + (", with %d failed or unverified check%s kept" % (odd, "" if odd == 1 else "s") if odd else ""))
            if settled and not earlier:
                continue
            if not settled:
                out.append(head)
            for at in (earlier if settled else rec.get("attempts", [])):
                out.extend(attempt_lines(at, hits.get((sid, at.get("n")), []) if step or at.get("verdict") in ("fail", "unverified") else [], errs, stks, ambiguous))
        out.append("")
    if failed_only and len(out) == 2:
        out.append("no failed or unverified steps")
    return "\n".join(out)



# ---------------------------------------------------------------- results for machines

SKIP_WHY = {"pending": "not run", "skip": "skipped by the tester", "deselected": "category not picked", "inapplicable": "not for this client"}

def classify(rec):
    """(result, why): pass, partial, fail, unverified or skipped. One rule for every report format and --strict.
    A pass or partial claim is held to its required evidence: a contradicted check is a fail, a check with no result is unverified."""
    v = rec.get("verdict")
    done = [a for a in rec.get("attempts") or [] if a.get("verdict")]
    last = done[-1] if done else {}
    bits = [last.get("note") or ""] + ["%s(%s)" % (o.get("result"), o.get("why", "")) for o in (last.get("outcomes") or []) if o.get("result") != "pass" and not o.get("diagnostic")]
    why = " ".join(" ".join(b for b in bits if b).split())
    if v in ("pass", "partial"):
        ev = evidence_state(rec)
        if ev == "bad":
            return "fail", why or "a required check was contradicted"
        if ev == "missing":
            return "unverified", why or "a required check has no result"
        return v, why
    if v == "fail":
        return "fail", why or "failed"
    if v == "unverified":
        return "unverified", why or "no evidence"
    if awaiting_retry(rec):
        return "skipped", "awaiting retry"
    return "skipped", SKIP_WHY.get(v, "no result")

def run_model(rid, r, stacks=None, lines=False):
    """The run as plain data. stacks is {(step, attempt n): [text]} and is left out unless asked for. Each step lists, for every attempt
    that has a check that did not pass, those checks with what they looked at (positions and counts; line text only with lines)."""
    steps, counts = [], {}
    for sid in step_ids(r):
        rec = (r.get("steps") or {}).get(sid)
        result, why = classify(rec) if rec is not None else ("unverified", "the run has no record of this step")
        rec = rec or {}
        counts[result] = counts.get(result, 0) + 1
        done = [a for a in rec.get("attempts") or [] if a.get("verdict")]
        s = {"id": sid, "category": (r.get("cat") or {}).get(sid), "attempt": done[-1].get("n") if done else None, "result": result, "verdict": rec.get("verdict"), "reason": why,
             "attempts": len(rec.get("attempts") or []), "awaitingRetry": awaiting_retry(rec), "recordedByCheckThat": by_checkthat(rec),
             "macroStale": rec.get("macroStale") if isinstance(rec.get("macroStale"), int) else 0}
        checks = []
        for at in rec.get("attempts") or []:
            outs = [outcome_view(i, o, lines) for i, o in enumerate(at.get("outcomes") or [], 1) if o.get("result") != "pass"]
            if outs:
                checks.append({"attempt": at.get("n"), "verdict": at.get("verdict"), "outcomes": outs})
        if checks:
            s["checks"] = checks
        if stacks:
            # Stacks belong to the attempt that was open; a step that failed and then passed keeps them too.
            last = done[-1] if done else None
            per = [{"attempt": at.get("n"), "stacks": stacks[(sid, at.get("n"))]} for at in rec.get("attempts") or []
                   if (at.get("verdict") in ("fail", "unverified") or (at is last and result in ("fail", "unverified"))) and stacks.get((sid, at.get("n")))]
            if per:
                s["attemptStacks"] = per
            if result in ("fail", "unverified"):
                s["stacks"] = [t for p in per for t in p["stacks"]]
        steps.append(s)
    return {"runId": rid, "addon": r.get("addon"), "plan": r.get("planTitle"), "revision": r.get("revision"), "formatRev": r.get("formatRev"),
            "writerVersion": r.get("writerVersion"), "targetVersion": r.get("targetVersion"), "client": r.get("client"),
            "build": r.get("build"), "character": r.get("character"), "counts": counts,
            "categories": [{"id": c, "title": t, "state": st, "resolved": a, "total": b} for c, t, st, a, b in category_states(r)],
            "steps": steps}

def models(runs, dest=None, with_stacks=False, with_lines=False):
    out = []
    for rid, r in sorted(runs.items()):
        errs, stks = load_errors(dest, stored_id(rid, r)) if with_stacks and dest else ({}, {})
        hits, ambiguous = stack_hits(r, stks)
        label = lambda key: "%s%s: %s" % (key, " (time also fits another attempt)" if key in ambiguous else "", stks[key])
        out.append(run_model(rid, r, {k: [label(key) for key in v] for k, v in hits.items()} if with_stacks else None, with_lines))
    return out

def bad_steps(ms):
    return sum(m["counts"].get("fail", 0) + m["counts"].get("unverified", 0) for m in ms)

def report_json(runs, dest=None, with_stacks=False, with_lines=False):
    ms = models(runs, dest, with_stacks, with_lines)
    totals = {}
    for m in ms:
        for k, n in m["counts"].items():
            totals[k] = totals.get(k, 0) + n
    return json.dumps({"runs": ms, "totals": totals, "ok": bool(ms) and bad_steps(ms) == 0}, indent=1, sort_keys=True)

def report_junit(runs, dest=None, with_stacks=False, with_lines=False):
    """JUnit XML: a suite for each run category, a case for each step. Fail and unverified are failures (type tells them apart);
    partial passes with its note in system-out; pending, skip, deselected and inapplicable are skipped."""
    from xml.etree import ElementTree as ET
    ok = lambda c: c in "\t\n\r" or 0x20 <= ord(c) <= 0xD7FF or 0xE000 <= ord(c) <= 0xFFFD or ord(c) >= 0x10000
    clean = lambda s: "".join(c if ok(c) else "?" for c in str(s))   # XML 1.0 has no place for most control characters
    root = ET.Element("testsuites")
    for m in models(runs, dest, with_stacks, with_lines):
        groups = {}
        for s in m["steps"]:
            groups.setdefault(s["category"] or "uncategorized", []).append(s)
        for cat, steps in groups.items():
            c = lambda *rs: sum(1 for s in steps if s["result"] in rs)
            suite = ET.SubElement(root, "testsuite", name=clean("%s/%s" % (m["runId"], cat)), tests=str(len(steps)),
                                  failures=str(c("fail", "unverified")), errors="0", skipped=str(c("skipped")))
            for s in steps:
                case = ET.SubElement(suite, "testcase", classname=clean(m["runId"]), name=clean(s["id"]))
                if s["result"] in ("fail", "unverified"):
                    f = ET.SubElement(case, "failure", type=s["result"], message=clean(s["reason"]))
                    body = []
                    last = next((c["outcomes"] for c in s.get("checks") or [] if c["attempt"] == s.get("attempt")), [])   # the attempt the result comes from
                    for o in last:
                        if o["result"] != "pass" and not o["diagnostic"] and o.get("rule"):
                            counts = " [%d of %d lines matched]" % (o["matched"], o["window"]) if o.get("matched") is not None and o.get("window") is not None else ""
                            body.append("check %d (%s): %s%s%s" % (o["index"], o["result"], o["rule"], counts, " - " + o["why"] if o.get("why") else ""))
                            if o.get("observed") is not None:
                                body.append("  saw: %s" % o["observed"])
                            body.extend("  line %d%s%s" % (h["n"], ": " + h["line"] if h.get("line") is not None else "", " (value %s)" % h["value"] if h.get("value") is not None else "") for h in o.get("hits", []))
                    f.text = clean("\n".join(body + (s.get("stacks") or [])) or s["reason"])
                elif s["result"] == "skipped":
                    ET.SubElement(case, "skipped", message=clean(s["reason"]))
                else:
                    out = (["partial: " + s["reason"]] if s["result"] == "partial" else [])
                    for p in s.get("attemptStacks") or []:   # a failure that a later attempt recovered
                        out.extend("recovered failure, attempt %s, error %s" % (p["attempt"], t) for t in p["stacks"])
                    if out:
                        ET.SubElement(case, "system-out").text = clean("\n".join(out))
    ET.indent(root)
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode") + "\n"

# ---------------------------------------------------------------- status of the evidence folder

def age(sec):
    if sec is None:
        return "?"
    sec = max(0, int(sec))
    for n, u in ((86400, "d"), (3600, "h"), (60, "m")):
        if sec >= n:
            return "%d%s" % (sec // n, u)
    return "%ds" % sec

def status_data(dest, now=None):
    """What the evidence folder holds, one row per run at its newest readable revision, and what is wrong with it.
    Sizes are estimates: the saved run, written compact, against the 2 MB limit of an export."""
    now = time.time() if now is None else now
    rows, problems = [], []
    runs_dir = os.path.join(dest, "runs")
    if not os.path.isdir(runs_dir) or not glob.glob(os.path.join(runs_dir, "*", "r*.json")):
        problems.append("no run revisions under %s: run 'ct.py collect' or 'import-results' first" % runs_dir)
    for rp in sorted(glob.glob(os.path.join(runs_dir, "*"))):
        rid, good, bad = os.path.basename(rp), None, []
        files = rev_files(rp)
        for p in files:
            try:
                good = (p, read_run(p))
            except (ValueError, OSError) as e:
                bad.append((os.path.basename(p), " ".join(str(e).split())))
        for b, why in bad:
            problems.append("run %s: %s is unreadable (%s)%s" % (rid, b, why, "; showing the newest readable revision" if good else ""))
        if not good:
            continue
        r = good[1]
        ms = run_model(rid, r)
        c = ms["counts"]
        eligible = [s for s in ms["steps"] if s["verdict"] not in ("deselected", "inapplicable")]
        resolved = sum(1 for s in eligible if s["verdict"] in ("pass", "partial", "fail", "skip"))
        size = len(json.dumps(export_form(r), separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
        rows.append({"runId": rid, "revision": r.get("revision"), "revisions": len(files), "plan": r.get("planTitle"), "character": r.get("character"),
                     "resolved": resolved, "eligible": len(eligible), "pass": c.get("pass", 0) + c.get("partial", 0), "fail": c.get("fail", 0),
                     "unverified": c.get("unverified", 0), "open": sum(1 for s in eligible if s["verdict"] in ("pending", "unverified")),
                     "ageSeconds": (now - (r.get("updated") or r.get("started"))) if isinstance(r.get("updated") or r.get("started"), (int, float)) else None,
                     "sizeEstimate": size, "sizeLimit": MAX_INFLATED, "finished": bool(r.get("endedAt")), "unreadableRevisions": [b for b, _ in bad],
                     "formatRev": r.get("formatRev"), "writerVersion": r.get("writerVersion")})
        if size > MAX_INFLATED * 0.8:
            problems.append("run %s: about %d of %d bytes: close to the export limit" % (rid, size, MAX_INFLATED))
    for rid, info in sorted(load_refused(dest).items()):
        problems.append("run %s: not stored, %s" % (rid, info.get("reason", "format not readable")))
    log = os.path.join(dest, "problems.log")
    if os.path.exists(log):
        with open(log, encoding="utf-8") as fh:
            problems += ["collect: " + ln for ln in fh.read().splitlines() if ln]
    extra = {"savedVariables": len(glob.glob(os.path.join(dest, "sv", "*.lua"))), "errorFiles": len(glob.glob(os.path.join(dest, "errors", "*.json")))}
    return rows, problems, extra

def find_run(runs, name):
    """The run id that name is, or the only run id that contains it. Raises ValueError with the choices otherwise."""
    if name in runs:
        return name
    near = sorted(r for r in runs if name in r)
    if len(near) == 1:
        return near[0]
    if not runs:
        raise ValueError("no runs collected yet")
    if near:
        raise ValueError("%r matches %d runs: %s" % (name, len(near), ", ".join(near)))
    raise ValueError("no run %r; runs: %s" % (name, ", ".join(sorted(runs))))

def show_text(runs, dest, name, step=None):
    rid = find_run(runs, name)
    if step and step not in step_ids(runs[rid]):
        raise ValueError("run %s has no step %r; steps: %s" % (rid, step, ", ".join(step_ids(runs[rid]))))
    return report_text({rid: runs[rid]}, dest, True, step=step)

# ---------------------------------------------------------------- compare runs

OK_RESULTS = ("pass", "partial")

def plan_store(dest):
    """{digest: plan} from the CheckThat saved variables that collect copied to dest/sv. A file that cannot be read adds nothing."""
    store = {}
    for p in sorted(glob.glob(os.path.join(dest, "sv", "*CheckThat*.lua"))):   # collect prefixes the name with the folder it came from
        try:
            db = sv_json(p).get("CheckThatDB")
        except (OSError, ValueError, RecursionError):
            continue
        g = db.get("global") if isinstance(db, dict) else None
        ps = (g.get("planStore") if isinstance(g, dict) else None) or (db.get("planStore") if isinstance(db, dict) else None)   # AceDB keeps it under global
        for digest, plan in (ps.items() if isinstance(ps, dict) else []):
            store.setdefault(digest, plan)
    return store

def step_prints(store, digest, ignore_id=False):
    """{step id: fingerprint} of the stored plan with this digest, or None when the plan is not stored. The fingerprint is a hash of the whole step."""
    plan = store.get(digest) if digest is not None else None
    if not isinstance(plan, dict):
        return None
    out = {}
    for sec in plan.get("sections") or []:
        for st in (sec.get("steps") or []) if isinstance(sec, dict) else []:
            if isinstance(st, dict) and isinstance(st.get("id"), str):
                body = {k: v for k, v in st.items() if k != "id"} if ignore_id else st
                out[st["id"]] = hashlib.sha1(canonical(body).encode("utf-8")).hexdigest()[:12]
    return out

def same_step(ra, rb, sid, store):
    """True when the step is the same plan step in both runs, False when its fingerprint changed, None when that cannot be told.
    The same plan digest means the same steps. Otherwise both stored plans must name the step: a missing one is never guessed."""
    da, db = ra.get("planDigest"), rb.get("planDigest")
    if da is not None and da == db:
        return True
    pa, pb = step_prints(store, da), step_prints(store, db)
    fa, fb = (pa or {}).get(sid), (pb or {}).get(sid)
    return None if fa is None or fb is None else fa == fb

def missing_plans(runs, store):
    return sorted({r.get("planDigest") or "(none)" for r in runs if step_prints(store, r.get("planDigest")) is None})

def diff_label(x, y):
    if x in OK_RESULTS:
        return "unchanged" if y in OK_RESULTS else ("regressed" if y == "fail" else "newly-unverified")
    return "fixed" if y in OK_RESULTS else "still-failing"

DIFF_ORDER = ("regressed", "newly-unverified", "still-failing", "fixed", "not-comparable", "added", "removed")

def run_head(rid, r):
    return {"runId": rid, "addon": r.get("addon"), "plan": r.get("planTitle"), "planDigest": r.get("planDigest"), "client": r.get("client"),
            "build": r.get("build"), "character": r.get("character"), "writerVersion": r.get("writerVersion"),
            "targetVersion": r.get("targetVersion")}

def diff_data(ida, ra, idb, rb, store):
    """Both runs through run_model (a pass with contradicting evidence is a fail), then one label for each step id."""
    sa = {s["id"]: s for s in run_model(ida, ra)["steps"]}
    sb = {s["id"]: s for s in run_model(idb, rb)["steps"]}
    rows, unknown = [], False
    for sid in list(sa) + [i for i in sb if i not in sa]:
        x, y = sa.get(sid), sb.get(sid)
        row = {"id": sid, "a": x and x["result"], "b": y and y["result"], "label": None, "reason": "", "macroStale": [x["macroStale"] if x else 0, y["macroStale"] if y else 0]}
        if y is None:
            row["label"] = "removed"
        elif x is None:
            row["label"] = "added"
        elif "skipped" in (x["result"], y["result"]):
            row["label"], row["reason"] = "not-comparable", "A: %s; B: %s" % (x["reason"] if x["result"] == "skipped" else x["result"], y["reason"] if y["result"] == "skipped" else y["result"])
        else:
            same = same_step(ra, rb, sid, store)
            if same is None:
                row["label"], row["reason"], unknown = "not-comparable", "the plan changed and its steps are not stored", True
            elif not same:
                row["label"], row["reason"] = "not-comparable", "the step changed in the plan"
            else:
                row["label"] = diff_label(x["result"], y["result"])
        rows.append(row)
    warnings = []
    if unknown:
        warnings.append("plan changed and no stored plan for digest %s: collect the saved variables of the machine that ran it" % ", ".join(missing_plans([ra, rb], store)))
    pa, pb = step_prints(store, ra.get("planDigest"), True), step_prints(store, rb.get("planDigest"), True)
    if pa and pb:  # a step that kept its text but changed its id splits its history: say so
        gone = {r["id"]: r for r in rows if r["label"] == "removed"}
        news = [r for r in rows if r["label"] == "added"]
        count = lambda prints, ids, fp: sum(1 for i in ids if prints.get(i) == fp)
        for new in news:
            fp = pb.get(new["id"])
            old = next((i for i in gone if pa.get(i) is not None and pa[i] == fp), None)
            # only a one-to-one match is a rename: steps with identical bodies cannot be told apart
            if old and count(pa, gone, fp) == 1 and count(pb, [n["id"] for n in news], fp) == 1:
                gone[old]["reason"], new["reason"] = "renamed to " + new["id"], "renamed from " + old
                warnings.append("step id %s is now %s with the same text: its history is split. Keep a step's id when you edit the plan" % (old, new["id"]))
    counts = {}
    for row in rows:
        counts[row["label"]] = counts.get(row["label"], 0) + 1
    return {"a": run_head(ida, ra), "b": run_head(idb, rb), "planChanged": ra.get("planDigest") != rb.get("planDigest"),
            "counts": counts, "steps": rows, "warnings": warnings}

def head_text(tag, h):
    return "%s: %s  client %s, build %s, character %s, plan %s, writer %s, tested addon %s" % (tag, h["runId"], h["client"] or "?", h["build"] or "?", h["character"] or "?",
                                                                       h["planDigest"] or "?", h["writerVersion"] or "?", h["targetVersion"] or "?")

def diff_text(d):
    lines = ["# Diff", head_text("A", d["a"]), head_text("B", d["b"])]
    if d["planChanged"]:
        lines.append("plan changed")
    lines.append("summary: " + (", ".join("%d %s" % (d["counts"][k], k) for k in DIFF_ORDER + ("unchanged",) if k in d["counts"]) or "no steps"))
    for k in DIFF_ORDER:
        rows = [r for r in d["steps"] if r["label"] == k]
        if rows:
            lines += ["", "## " + k]
            lines += ["- %s: %s -> %s%s" % (r["id"], r["a"] or "-", r["b"] or "-", " (%s)" % r["reason"] if r["reason"] else "") for r in rows]
    stale = [r for r in d["steps"] if any(r["macroStale"])]
    if stale:
        lines += ["", "## stale macro presses"] + ["- %s: %d -> %d" % (r["id"], *r["macroStale"]) for r in stale]
    return "\n".join(lines)

def finished(r):
    return bool(r.get("endedAt"))

CELL = {"pass": "P", "partial": "p", "fail": "F", "unverified": "U", "skipped": "-"}

def trend_data(runs, store, addon=None, title=None, by=None, last=None, include_open=False):
    """One table for each addon and plan title: a row for each step, a column for each run (oldest first), judged against the newest run's plan.
    Cells: P pass, p partial, F fail, U unverified, - not run here, ~ the step changed in the plan, ? it cannot be told, blank the run has no such step."""
    groups, warnings = {}, []
    for rid, r in runs.items():
        if (addon and r.get("addon") != addon) or (title and r.get("planTitle") != title):
            continue
        if finished(r) or include_open:
            groups.setdefault((r.get("addon"), r.get("planTitle")), []).append((rid, r))
    out = []
    for (ad, ti), members in sorted(groups.items(), key=lambda kv: tuple(str(x) for x in kv[0])):
        members.sort(key=lambda m: (m[1].get("started") or 0, m[0]))
        members = members[-last:] if last else members
        ref = members[-1][1]
        models = [{s["id"]: s for s in run_model(rid, r)["steps"]} for rid, r in members]
        ids = list(step_ids(ref)) + sorted({i for m in models for i in m} - set(step_ids(ref)))
        rows, unknown = [], False
        for sid in ids:
            cells = []
            for (rid, r), m in zip(members, models):
                s = m.get(sid)
                if s is None:
                    cells.append(" ")
                    continue
                same = same_step(r, ref, sid, store) if s["result"] != "skipped" else True
                unknown = unknown or same is None
                cells.append(CELL[s["result"]] if same else ("~" if same is False else "?"))
            seen = {c for c in cells if c in "PpFU"}
            rows.append({"id": sid, "cells": cells, "flaky": bool(seen & set("Pp")) and bool(seen & set("FU"))})
        if unknown:
            warnings.append("%s / %s: plan changed and no stored plan for digest %s: marked ?" % (ad, ti, ", ".join(missing_plans([r for _, r in members], store))))
        out.append({"addon": ad, "plan": ti, "runs": [dict(run_head(rid, r), label=r.get(by_key(by)) if by else None, open=not finished(r)) for rid, r in members], "steps": rows})
    return {"groups": out, "warnings": warnings}

def by_key(by):
    return {"client": "client", "character": "character", "build": "build", "version": "writerVersion", "target": "targetVersion"}[by]

def trend_text(t):
    lines = []
    for g in t["groups"]:
        n = len(g["runs"])
        wc = len(str(n))
        lines += ["# %s / %s" % (g["addon"], g["plan"]), ""]
        for i, h in enumerate(g["runs"], 1):
            lines.append("%d  %s%s%s" % (i, h["runId"], "" if h["label"] is None else "  " + str(h["label"]), "  (open)" if h["open"] else ""))
        w = max([len(s["id"]) for s in g["steps"]] + [4])
        lines += ["", "%s  %s  flaky" % ("step".ljust(w), " ".join(str(i).rjust(wc) for i in range(1, n + 1)))]
        lines += ["%s  %s  %s" % (s["id"].ljust(w), " ".join(c.rjust(wc) for c in s["cells"]), "flaky" if s["flaky"] else "") for s in g["steps"]]
        lines.append("")
    lines.append("P pass, p partial, F fail, U unverified, - not run, ~ step changed in the plan, ? cannot be told")
    return "\n".join(lines)

def left_out(skipped):
    return ["%s: %s (%s)" % (rid, f, why) for rid, f, why in sorted(skipped)]


def status_watch(dest, interval, sleep=time.sleep, rounds=None, out=print, tty=False):
    """Print status again every interval seconds until Ctrl-C (or rounds). Returns the last exit code."""
    code, n = 0, 0
    try:
        while rounds is None or n < rounds:
            rows, problems, extra = status_data(dest)
            code = 1 if problems else 0
            out(("\033[2J\033[H" if tty else "--- %s\n" % time.strftime("%H:%M:%S")) + status_text(rows, problems, extra, dest))
            n += 1
            if rounds is None or n < rounds:
                sleep(interval)
    except KeyboardInterrupt:
        pass
    return code

def status_text(rows, problems, extra, dest):
    out = ["evidence: %s (%d saved-variable copies, %d error files)" % (dest, extra["savedVariables"], extra["errorFiles"]), ""]
    if rows:
        head = ("run", "rev", "done", "fail", "unver", "open", "age", "size~")
        body = [(r["runId"], str(r["revision"]), "%d/%d" % (r["resolved"], r["eligible"]), str(r["fail"]), str(r["unverified"]), str(r["open"]),
                 age(r["ageSeconds"]), "%d%%" % (100 * r["sizeEstimate"] // r["sizeLimit"])) for r in rows]
        w = [max(len(x[i]) for x in [head] + body) for i in range(len(head))]
        out += ["  ".join(c.ljust(w[i]) for i, c in enumerate(row)).rstrip() for row in [head] + body]
    out.append("")
    out += ["problem: " + p for p in problems] or ["no problems: every revision is readable and none conflicts"]
    out.append("test results are not judged here: 'ct.py report --strict' fails on a failed or unverified step")
    return "\n".join(out)

# ---------------------------------------------------------------- CLI

# --- coverage: which commands, settings and requirements the plans touch (docs/authoring-plans.md) ---
SLASH_CMD = re.compile(r'\bcmd\s*==\s*"(\w+)"')
WIDGETS = "toggle|range|select|multiselect|input|color|keybinding"
SETTING_LITERAL = re.compile(r'(?:\["([^"\n]+)"\]|\b([A-Za-z_]\w*))\s*=\s*\{[^{}]*?\btype\s*=\s*"(?:%s)"' % WIDGETS)
SETTING_CALL = re.compile(r'\w+\(\s*[\w.]+\s*,\s*"([^"\n]+)"\s*,\s*\{\s*type\s*=\s*"(?:%s)"' % WIDGETS)
SETTING_KEYS = re.compile(r'\["([A-Za-z][\w-]*(?:\.[\w-]+)+)"\]\s*=\s*\{')

def lua_files(src):
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in ("Libs", "Locales"))
        for f in sorted(files):
            if f.endswith(".lua"):
                yield os.path.join(root, f)

def toc_lua_files(src):
    """The Lua files the addon's TOC files list, in order, following Script and Include entries of the XML files they list (embeds.xml).
    A file that does not exist is skipped, and so is anything under Libs. Paths use / or \\ ."""
    seen, out = set(), []
    def add(path):
        path = os.path.normpath(path.strip().replace("\\", "/"))
        if path in seen or not os.path.isfile(path):
            return
        seen.add(path)
        if "libs" in [x.lower() for x in os.path.relpath(path, src).split(os.sep)]:
            return
        if path.lower().endswith(".lua"):
            out.append(path)
        elif path.lower().endswith(".xml"):
            with open(path, encoding="utf-8", errors="replace") as f:
                text = re.sub(r"<!--.*?-->", "", f.read(), flags=re.S)
            for m in re.finditer(r'<(?:Script|Include)\b[^>]*?\bfile\s*=\s*"([^"]+)"', text, re.I):
                add(os.path.join(os.path.dirname(path), m.group(1)))
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d.lower() != "libs")
        for f in sorted(files):
            if f.lower().endswith(".toc"):
                with open(os.path.join(root, f), encoding="utf-8", errors="replace") as h:
                    for line in h:
                        line = line.strip()
                        if line and not line.startswith("#") and line.lower().endswith((".lua", ".xml")):
                            add(os.path.join(root, line))
    return out

def slash_commands(src):
    """Subcommand names an addon handles: cmd == "name" in its Slash*.lua files and in every Lua file its TOC lists."""
    out = set()
    paths = [p for p in lua_files(src) if os.path.basename(p).startswith("Slash")] + toc_lua_files(src)
    for p in dict.fromkeys(paths):
        with open(p, encoding="utf-8", errors="replace") as f:
            out.update(SLASH_CMD.findall(f.read()))
    return sorted(out)

def setting_keys(src):
    """Setting keys an addon declares: AceConfig widgets (key = { type = "toggle" ... } or add(group, "key", { type = "toggle" ...)
    and dotted keys of a Settings*.lua table (["card.scale"] = {)."""
    out = set()
    for p in lua_files(src):
        with open(p, encoding="utf-8", errors="replace") as f:
            text = f.read()
        out.update(a or b for a, b in SETTING_LITERAL.findall(text))
        out.update(SETTING_CALL.findall(text))
        if os.path.basename(p).startswith("Settings"):
            out.update(SETTING_KEYS.findall(text))
    return sorted(out)

CMD_AT = re.compile(r"(?<![\w/])(/[A-Za-z]+)(?=[\s.,;:)]|$)(.*)")

def step_touches(plan):
    """[(step id, covers, commands [(subcommand, rest of the line)], fact and state names)] for each step of the expanded plan."""
    plan = expand_cases(plan)
    macros = {m["id"]: m["text"] for m in plan.get("macros", [])}
    aliases = set(SLASH.get(plan["addon"], []))
    out = []
    for sec in plan["sections"]:
        for st in sec["steps"]:
            act = st["action"]
            texts = [act.get("text", ""), sec.get("setup", ""), st.get("setup", ""), st.get("cleanup", "")] + list(act.get("commands", []))
            if act.get("kind") == "secure-macro":
                texts.append(macros.get(act.get("macro"), ""))
            cmds = []
            for t in texts:
                for line in re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "\n", t or "").split("\n"):
                    for m in CMD_AT.finditer(line):
                        if m.group(1).lower() in aliases:
                            w = m.group(2).split()
                            cmds.append((w[0].lower().strip(".,;:)") if w else "", m.group(2)))
            names = [a.get(k) for a in st.get("assertions", []) for k in ("key", "name", "path") if a.get("kind") in ("fact", "state") and a.get(k)]
            out.append((st["id"], list(sec.get("covers", [])) + list(st.get("covers", [])), cmds, names))
    return out

TEST_COVERS = re.compile(r"^\s*--\s*covers:\s*(.+?)\s*(?:\s--.*)?$")

def test_covers(tests_dir):
    """{requirement name: ["file.lua:line", ...] (paths relative to tests_dir)} from `-- covers: <Requirement name>` comments in the unit test files (*.lua) under
    tests_dir. One name per comment. Folders named fixtures are skipped."""
    out = {}
    for root, dirs, files in os.walk(tests_dir):
        dirs[:] = sorted(d for d in dirs if d != "fixtures")
        for fn in sorted(files):
            if not fn.endswith(".lua"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8", errors="replace") as f:
                for n, line in enumerate(f, 1):
                    m = TEST_COVERS.match(line)
                    if m:
                        out.setdefault(m.group(1), []).append("%s:%d" % (os.path.relpath(path, tests_dir).replace(os.sep, "/"), n))
    return out

def registry_setting_keys(src):
    """(keys, tables, toc, error): the setting keys of the options tables the addon registers with AceConfigRegistry-3.0 once its TOC
    is loaded under the fake client (tools/dump_options.lua), how many tables that was, and the TOC it read. error is a short text
    (and keys is empty) when the addon has no TOC here, the run fails or times out, or luajit is missing. It runs the addon's Lua:
    use addons you trust."""
    tocs = sorted(glob.glob(os.path.join(src, "*.toc")))
    if not tocs or not os.path.exists(os.path.join(ROOT, "tools", "dump_options.lua")):
        return [], 0, None, "the addon folder has no TOC"
    toc = next((t for t in tocs if t.endswith("_Vanilla.toc")), tocs[0])
    name = os.path.basename(toc)
    try:
        r = run_luajit([os.path.join(ROOT, "tools", "dump_options.lua"), os.path.abspath(toc)], ROOT, timeout=60)
    except subprocess.TimeoutExpired:
        return [], 0, name, "loading %s took over 60 seconds" % name
    except ValueError as e:
        return [], 0, name, str(e)
    try:
        got = json.loads(r.stdout)
    except ValueError:
        got = None
    if r.returncode != 0 or not isinstance(got, dict) or not isinstance(got.get("keys"), list):
        why = (r.stderr or r.stdout).strip().splitlines()
        return [], 0, name, "loading %s failed%s" % (name, ": " + why[0][:120] if why else "")
    return sorted(str(k) for k in got["keys"]), int(got.get("tables") or 0), name, None

def coverage_data(plans, src, specs=None, runs=None, tests=None, harness=False):
    """Every subcommand, setting key and requirement name with the ids of the steps that cover it. runs ({id: run}, or None) adds a result:
    passed (a covering step passed), failed (one failed or is unverified), never-run. tests ({name: locations} from test_covers, or None)
    adds "tests" to each requirement, the names no spec has ("unknownTests") and the counts by tests, plans, both and neither ("testCounts")."""
    addons = {p["addon"] for p in plans}
    if len(addons) != 1:
        raise ValueError("the plans belong to %d addons (%s); give the plans of one addon" % (len(addons), ", ".join(sorted(addons))))
    if not SLASH.get(plans[0]["addon"]):
        raise ValueError("unknown addon %s: no slash aliases known" % plans[0]["addon"])
    cmds = slash_commands(src)
    if not cmds:
        raise ValueError("no subcommand found in %s: looked for cmd == \"name\" in Slash*.lua files and in the Lua files its TOC lists" % src)
    keys, settings_source = setting_keys(src), None
    if harness:
        reg_keys, tables, toc_name, err = registry_setting_keys(src)
        if reg_keys:  # the registry may hold only the tables made at load: the source scan still adds what it finds
            keys = sorted(set(reg_keys) | set(keys))
            settings_source = "registry (%d table%s, %s) and the source" % (tables, "" if tables == 1 else "s", toc_name)
        else:
            settings_source = "source (%s)" % (err or "the options registry was empty after %s loaded" % toc_name)
    reqs = sorted(requirement_names(specs)) if specs else None
    cover = {"commands": {c: [] for c in cmds}, "settings": {k: [] for k in keys}, "requirements": {r: [] for r in reqs or []}}
    ok = {}
    notes = []
    for i, plan in enumerate(plans):
        res = {}
        if runs is not None:
            fin = [(r.get("started") or 0, rid) for rid, r in runs.items() if r.get("addon") == plan["addon"] and r.get("planTitle") == plan["title"] and finished(r)]
            if fin:
                rid = max(fin)[1]
                res = {s["id"]: s["result"] for s in run_model(rid, runs[rid])["steps"]}
                notes.append("%s: run %s" % (plan["title"], rid))
            else:
                notes.append("%s: no finished run" % plan["title"])
        for sid, covers, cm, names in step_touches(plan):
            ok[(i, sid)] = res.get(sid)
            def add(kind, name):
                if (i, sid) not in cover[kind][name]:
                    cover[kind][name].append((i, sid))
            for sub, rest in cm:
                if sub in cover["commands"]:
                    add("commands", sub)
                for k in cover["settings"]:
                    if re.search(r"(?<![\w.-])%s(?![\w-]|\.\w)" % re.escape(k), rest):
                        add("settings", k)
            for k in cover["settings"]:
                if any(n == k or n.endswith("." + k) for n in names):
                    add("settings", k)
            for r in covers:
                if r in cover["requirements"]:
                    add("requirements", r)
    def result(steps):
        if runs is None or not steps:
            return None
        got = [ok.get(s) for s in steps]
        return "passed" if any(g in OK_RESULTS for g in got) else ("failed" if any(g in ("fail", "unverified") for g in got) else "never-run")
    out = {"addon": plans[0]["addon"], "plans": [p["title"] for p in plans], "evidence": runs is not None, "notes": notes}
    if settings_source:
        out["settingsSource"] = settings_source
    for kind, items in cover.items():
        if kind == "requirements" and reqs is None:
            continue
        out[kind] = [{"name": n, "steps": [s for _, s in v], "result": result(v)} for n, v in items.items()]
    if tests is not None and reqs is not None:
        for r in out["requirements"]:
            r["tests"] = list(tests.get(r["name"], []))
        out["unknownTests"] = sorted(n for n in tests if n not in cover["requirements"])
        both = [r["name"] for r in out["requirements"] if r["tests"] and r["steps"]]
        out["testCounts"] = {"tests": sum(1 for r in out["requirements"] if r["tests"]), "plans": sum(1 for r in out["requirements"] if r["steps"]),
                             "both": len(both), "neither": sum(1 for r in out["requirements"] if not r["tests"] and not r["steps"]), "total": len(out["requirements"])}
        out["testAndPlan"] = both
    return out

def coverage_text(d):
    lines = ["Coverage of %s by %s" % (d["addon"], ", ".join(d["plans"]))] + ["evidence: " + n for n in d["notes"]]
    if d.get("settingsSource"):
        lines.append("settings read from: " + d["settingsSource"])
    for kind in ("commands", "settings", "requirements"):
        if kind not in d:
            continue
        items = d[kind]
        used = [i for i in items if i["steps"]]
        lines += ["", "%s: %d of %d covered" % (kind, len(used), len(items))]
        for i in used:
            lines.append("  covered  %s  %s%s%s" % (i["name"], ", ".join(i["steps"]), "  [%s]" % i["result"] if i["result"] else "", "  tests: " + ", ".join(i["tests"]) if i.get("tests") else ""))
        for i in items:
            if not i["steps"]:
                lines.append("  %s %s%s" % ("tests   " if i.get("tests") else "unused  ", i["name"], "  " + ", ".join(i["tests"]) if i.get("tests") else ""))
        if kind == "requirements" and "testCounts" in d:
            c = d["testCounts"]
            lines.append("  by unit tests %d, by plans %d, by both %d, by neither %d (of %d)" % (c["tests"], c["plans"], c["both"], c["neither"], c["total"]))
            for n in d["testAndPlan"]:
                lines.append("  in both, a plan step may repeat a unit test: %s" % n)
            for n in d["unknownTests"]:
                lines.append("  unknown requirement named by a test: %s" % n)
    return "\n".join(lines)


def load_env(paths=None):
    """Fill unset environment variables from KEY=VALUE files. Earlier files win; real variables and flags win over all."""
    for p in paths or [os.environ.get("CT_ENV"), os.path.join(os.getcwd(), ".ct.env"), os.path.expanduser("~/.checkthat.env")]:
        if not p or not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                key = key.strip()
                if key.startswith("export "):
                    key = key[7:].strip()
                val = val.strip().strip("\"'")
                if key:
                    os.environ.setdefault(key, os.path.expanduser(val))


def main(argv=None):
    for st in (sys.stdout, sys.stderr):   # a Windows console may use a legacy code page
        if hasattr(st, "reconfigure"):
            st.reconfigure(encoding="utf-8", errors="replace")
    load_env()
    ap = argparse.ArgumentParser(prog="ct")
    sub = ap.add_subparsers(dest="cmd", required=True)
    specs_help = "folder of the addon's openspec specs that covers names are checked against (default: the nearest openspec/specs above the plan)"
    p = sub.add_parser("validate"); p.add_argument("plan"); p.add_argument("--specs", help=specs_help)
    p = sub.add_parser("compile"); p.add_argument("plan"); p.add_argument("-o"); p.add_argument("--specs", help=specs_help)
    p = sub.add_parser("coverage", help="list the addon's slash subcommands, settings and spec requirements that the plans cover or leave unused (reads the addon's Lua source)"); p.add_argument("plans", nargs="+")
    p.add_argument("--addon-src", dest="addon_src", required=True, help="the addon's folder (the one with its TOC): Slash*.lua gives the subcommands, its option tables the setting keys")
    p.add_argument("--specs", help="requirements: folder of the addon's openspec specs (default: openspec/specs next to the addon folder, when it exists)")
    p.add_argument("--tests", help="folder of the addon's unit tests: `-- covers: <Requirement name>` comments in its *.lua files count toward requirements (default: tests next to the addon folder, when it exists)")
    p.add_argument("--harness", action="store_true", help="read the setting keys from the options tables the addon registers with AceConfigRegistry-3.0 when its TOC loads in the fake client (needs luajit; runs the addon's Lua: use addons you trust); falls back to the source when the registry is empty")
    p.add_argument("--evidence", action="store_true", help="join the newest finished run of each plan: passed, failed or never-run"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p.add_argument("--format", choices=("md", "json"), default="md")
    p = sub.add_parser("replay", help="judge a plan's log and fact checks against a saved-variables fixture folder (needs luajit)"); p.add_argument("plan"); p.add_argument("--sv", required=True, help="folder with the SavedVariables *.lua files and an optional fixture.json"); p.add_argument("-o")
    p = sub.add_parser("offline", help="run a plan's offline block (mocks, entry calls, fake events) in the fake client (needs luajit). It runs the addon's Lua: use addons you trust"); p.add_argument("plan"); p.add_argument("--addons", default=default_addons(), help="folder that holds the addon checkouts; the plan's toc is read from inside it (default: the folder above this repository, or above the current folder when ct.py runs from an installed skill)"); p.add_argument("-o"); p.add_argument("--specs", help=specs_help); p.add_argument("--build", help="split the nil-read report with the census of this build (tests/manifests/*.json); needed when the interface matches several builds"); p.add_argument("--client", choices=("era", "forever", "both"), help="run the block with the TOC of offline.tocs for that client; both runs it twice and prefixes each case with its client. Without it the block runs once with offline.toc, as before")
    p = sub.add_parser("replay-flow", help="play a plan's steps in the fake client and report plan mistakes (needs luajit). Log lines the plan expects are written by the replay: it checks the plan, not the addon"); p.add_argument("plan"); p.add_argument("--hooks", help="Lua hooks file for steps that need more than a Pass (see docs/authoring-plans.md)"); p.add_argument("--specs", help=specs_help)
    p = sub.add_parser("lines", help="check that each log line and fact key a plan asserts appears in the addon's Lua source"); p.add_argument("plan"); p.add_argument("--addon-src", dest="addon_src", required=True, help="the addon's folder (the one with its TOC)"); p.add_argument("--strict", action="store_true", help="exit 1 when a line is missing")
    p = sub.add_parser("decode"); p.add_argument("string_or_file")
    p = sub.add_parser("from-md"); p.add_argument("md"); p.add_argument("--addon", required=True, choices=sorted(SLASH)); p.add_argument("-o", required=True)
    p = sub.add_parser("sv2json"); p.add_argument("file")
    p = sub.add_parser("collect"); p.add_argument("--src", default=os.environ.get("CT_WTF"), help="one WTF folder; wins over --wow"); p.add_argument("--wow", default=os.environ.get("CT_WOW"), help="game folder; collects _classic_era_ and _forever_ (WTF and Screenshots)"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p.add_argument("--shots", default=os.environ.get("CT_SHOTS"), help="folder with game screenshots (default: Screenshots next to --src, if it exists)")
    p.add_argument("--plan", help="plan file: collect the saved variables it reads (logs.*.global, its addon) and CheckThat's own, not the default four addons")
    p.add_argument("--shot-slack", dest="shot_slack", type=float, default=2, help="seconds a screenshot may lie outside an attempt's window and still match it (default 2)")
    p.add_argument("--verbose", action="store_true", help="name each screenshot that matched no attempt, with the nearest step and the gap in seconds")
    p.add_argument("--all-shots", dest="all_shots", action="store_true", help="copy screenshots that matched no attempt to runs/<id>/unassigned-shots/ of the nearest run")
    p = sub.add_parser("doctor", help="say where collect looks for saved variables, what it finds, the file times and the likely reason for a miss (reads folder listings only)"); p.add_argument("--src", default=os.environ.get("CT_WTF"), help="one WTF folder; wins over --wow"); p.add_argument("--wow", default=os.environ.get("CT_WOW"), help="game folder"); p.add_argument("--plan", help="look for the files collect --plan would copy")
    p = sub.add_parser("recordings", help="turn the CTProbe saved variables (CTProbe.lua after /ctp record and /reload) into tools/recordings/<client>.json, the recorded calls a plan mock can name"); p.add_argument("--src", required=True, help="the CTProbe.lua saved-variables file from the game folder"); p.add_argument("-o", dest="out", help="folder for the recording (default: tools/recordings)")
    p = sub.add_parser("census", help="write tests/manifests/<client>-<build>.json from the census that /ct census saved (docs/harvesting.md), or compare two manifests with --diff OLD NEW"); p.add_argument("--src", default=os.environ.get("CT_WTF"), help="one WTF folder; wins over --wow"); p.add_argument("--wow", default=os.environ.get("CT_WOW"), help="game folder; reads _classic_era_ and _forever_"); p.add_argument("-o", help="folder for the manifests (default: tests/manifests)"); p.add_argument("--diff", nargs=2, metavar=("OLD", "NEW"), help="print added, removed and type-changed names between two manifests")
    p = sub.add_parser("drift", help="compare what the offline block predicts (offline.predicts) with the steps of real runs, for each client (needs luajit). It runs the addon's Lua: use addons you trust"); p.add_argument("plan"); p.add_argument("--addons", default=default_addons(), help="folder that holds the addon checkouts (as for offline)"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence")); p.add_argument("--specs", help=specs_help); p.add_argument("--format", choices=("text", "json"), default="text"); p.add_argument("--strict", action="store_true", help="exit 1 when a prediction was wrong")
    p = sub.add_parser("report"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence")); p.add_argument("--expect-version", dest="expect_version", help="warn about a run that tested another version of the addon"); p.add_argument("--plan", dest="plan_file", help="warn about a run made from another version of this plan file")
    p.add_argument("--format", choices=("md", "json", "junit"), default="md", help="md also writes REPORT.md; json and junit go to stdout (or --out)")
    p.add_argument("--strict", action="store_true", help="exit 1 when any step failed or is unverified, there are no runs, or a revision could not be read")
    p.add_argument("--lines", action="store_true", help="put the log lines that decided each check (and values the checks saw) in json and junit; they can hold private data")
    p.add_argument("--stacks", action="store_true", help="put saved error call stacks in json and junit (md always shows them); they can hold private paths")
    p.add_argument("--out", help="write the json or junit report to this file")
    p.add_argument("--failed-only", action="store_true", help="md only: runs and steps that failed or are unverified")
    p = sub.add_parser("show", help="print one run, or one step of it with every attempt, log excerpt and error stack"); p.add_argument("run", help="run id, or part of it that names one run"); p.add_argument("step", nargs="?"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p = sub.add_parser("browse", help="open the read-only evidence viewer (needs a terminal and Textual: requirements-tui.txt)"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p = sub.add_parser("status", help="check what the evidence folder holds: readable revisions, conflicts, sizes"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence")); p.add_argument("--json", action="store_true")
    p.add_argument("--watch", action="store_true", help="print status again every --interval seconds until Ctrl-C"); p.add_argument("--interval", type=float, default=5)
    p = sub.add_parser("import-results"); p.add_argument("string_or_file"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p = sub.add_parser("diff", help="compare two finished runs step by step: regressed, fixed, newly-unverified, still-failing, not-comparable, added, removed"); p.add_argument("a", help="run id (or part of it) to compare from"); p.add_argument("b", help="run id (or part of it) to compare to"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p.add_argument("--format", choices=("md", "json"), default="md"); p.add_argument("--strict", action="store_true", help="exit 1 when a step regressed"); p.add_argument("--include-open", dest="include_open", action="store_true", help="allow a run that has not ended")
    p = sub.add_parser("trend", help="one row for each step, one column for each finished run of a plan, with flaky steps marked"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence")); p.add_argument("--addon"); p.add_argument("--title", help="plan title")
    p.add_argument("--by", choices=("client", "character", "build", "version", "target"), help="name each column by this value of its run (version is the CheckThat version that wrote it, target is the version of the addon under test)"); p.add_argument("--last", type=int, help="only the newest N runs of each plan")
    p.add_argument("--format", choices=("md", "json"), default="md"); p.add_argument("--include-open", dest="include_open", action="store_true", help="add runs that have not ended")
    a = ap.parse_args(argv)

    if a.cmd == "validate":
        plan = load_yaml(a.plan)
        errs = validate(plan, plan_requirements(plan, a.plan, a.specs))
        for e in errs:
            print("error:", e)
        if not errs:
            print_warnings(plan)
        print("ok" if not errs else "%d errors" % len(errs))
        return 1 if errs else 0
    if a.cmd == "coverage":
        plans, specs = [], a.specs or os.path.join(os.path.dirname(os.path.abspath(a.addon_src)), "openspec", "specs")
        specs = specs if os.path.isdir(specs) else None
        tdir = a.tests or os.path.join(os.path.dirname(os.path.abspath(a.addon_src)), "tests")
        if a.tests and not os.path.isdir(tdir):
            print("error: --tests %s is not a folder" % a.tests, file=sys.stderr); return 2
        if a.tests and not specs:
            print("error: --tests needs the addon's openspec specs folder (pass --specs)", file=sys.stderr); return 2
        tests = test_covers(tdir) if specs and os.path.isdir(tdir) else None
        for path in a.plans:
            plan = load_yaml(path)
            errs = validate(plan, set(requirement_names(specs)) if specs else None)
            for e in errs:
                print("error: %s: %s" % (path, e), file=sys.stderr)
            if errs:
                return 2
            plans.append(plan)
        try:
            d = coverage_data(plans, a.addon_src, specs, latest_runs(a.dest) if a.evidence else None, tests, a.harness)
        except ValueError as e:
            print("error:", e, file=sys.stderr); return 2
        print(json.dumps(d, indent=1, sort_keys=True) if a.format == "json" else coverage_text(d))
        return 0
    if a.cmd == "compile":
        plan = load_yaml(a.plan)
        errs = validate(plan, plan_requirements(plan, a.plan, a.specs))
        if errs:
            for e in errs:
                print("error:", e, file=sys.stderr)
            return 1
        s = encode(merge_sections(plan))
        if a.o:
            open(a.o, "w", encoding="utf-8").write(s + "\n")
        else:
            print(s)
        return 0
    if a.cmd == "replay":
        plan = load_yaml(a.plan)
        try:
            items, notes = replay_plan(plan, a.sv)
        except (ValueError, RuntimeError) as e:
            print("error:", e, file=sys.stderr); return 2
        for n in notes:
            print("replay:", n, file=sys.stderr)
        n = lambda k: sum(i["result"] == k for i in items)
        print("replay: %d passed, %d failed, %d not judged offline" % (n("pass"), n("fail"), n("skipped")), file=sys.stderr)
        xml = replay_junit(plan, items)
        if a.o:
            open(a.o, "w", encoding="utf-8").write(xml)
        else:
            print(xml, end="")
        return 1 if n("fail") else 0
    if a.cmd == "replay-flow":
        plan = load_yaml(a.plan)
        try:
            code, text = replay_flow(plan, a.hooks, plan_requirements(plan, a.plan, a.specs))
        except (ValueError, RuntimeError) as e:
            print("error:", e, file=sys.stderr); return 2
        print(text, end="")
        return code
    if a.cmd == "lines":
        plan = load_yaml(a.plan)
        found, missing = lines_check(plan, a.addon_src)
        print("lines: %d found in the source, %d not found" % (len(found), len(missing)))
        for sid, label, text in missing:
            print("  not found  %s  %s: %r" % (sid, label, text))
        return 1 if missing and a.strict else 0
    if a.cmd == "offline":
        plan = load_yaml(a.plan)
        clients = {"era": ["era"], "forever": ["forever"], "both": ["era", "forever"]}.get(getattr(a, "client", None), [None])
        items, props, report = [], {}, ""
        if len(clients) > 1 and a.build:
            print("error: --build names one build, and --client both runs two clients with different builds: run each client with --client era or forever", file=sys.stderr); return 2
        try:
            reqs = plan_requirements(plan, a.plan, a.specs)
            for cl in clients:
                info = {}
                got = offline_plan(plan, a.addons, reqs, info, cl)
                rep, build = nil_read_report(info.get("interface"), info.get("nilReads") or [], census_manifests(), a.build)
                if len(clients) > 1:  # both clients: every case names its client, so the two runs read apart
                    for i in got:
                        i["step"] = "%s.%s" % (cl, i["step"]); i["label"] = "%s: %s" % (cl, i["label"])
                    rep = "%s:\n%s" % (cl, rep) if rep else rep
                    if info.get("interface"): props["interface." + cl] = info["interface"]
                    if build: props["build." + cl] = build
                else:
                    if info.get("interface"): props["interface"] = info["interface"]
                    if build: props["build"] = build
                items += got; report += rep
        except (ValueError, RuntimeError) as e:
            print("error:", e, file=sys.stderr); return 2
        bad = sum(i["result"] == "fail" for i in items)
        print("offline: %d passed, %d failed" % (len(items) - bad, bad), file=sys.stderr)
        if "level" not in plan["offline"]:
            print(OFFLINE_LEVEL_WARNING, file=sys.stderr)
        print(report, end="", file=sys.stderr)
        xml = replay_junit(plan, items, props, report)
        if a.o:
            open(a.o, "w", encoding="utf-8").write(xml)
        else:
            print(xml, end="")
        return 1 if bad else 0
    if a.cmd == "decode":
        s = a.string_or_file
        if os.path.exists(s):
            s = open(s, encoding="utf-8").read()
        print(json.dumps(decode(s), indent=1, sort_keys=True))
        return 0
    if a.cmd == "from-md":
        import yaml
        plan = nativize(from_md(a.md, a.addon))
        with open(a.o, "w", encoding="utf-8") as f:
            f.write("# Draft converted from %s. Review assertions, then promote diagnostic ones.\n" % os.path.basename(a.md))
            yaml.safe_dump(plan, f, sort_keys=False, allow_unicode=True, width=100)
        errs = validate(plan)
        for e in errs:
            print("error:", e)
        if not errs:
            print_warnings(plan)
        print("%d sections, %d steps" % (len(plan["sections"]), sum(len(s["steps"]) for s in plan["sections"])))
        return 1 if errs else 0
    if a.cmd == "sv2json":
        print(json.dumps(sv_json(a.file), indent=1, sort_keys=True))
        return 0
    if a.cmd == "recordings":
        return cmd_recordings(a)
    if a.cmd == "doctor":
        return cmd_doctor(a)
    if a.cmd == "collect":
        if not a.shots and (a.src or not a.wow):
            guess = os.path.join(os.path.dirname(os.path.abspath(a.src or default_src())), "Screenshots")
            a.shots = guess if os.path.isdir(guess) else None
        return cmd_collect(a)
    if a.cmd == "census":
        return cmd_census(a)
    if a.cmd == "import-results":
        s = a.string_or_file
        if os.path.exists(s):
            s = open(s, encoding="utf-8").read()
        run = decode(s)
        try:
            check_major(run)   # before kind or anything else: a newer major may have renamed them
        except MajorError as e:
            print("not imported:", e, file=sys.stderr); return 1
        if not isinstance(run, dict) or run.get("kind") != "results":
            print("not a results string", file=sys.stderr); return 1
        try:
            res = write_revision(a.dest, run)
        except (ValueError, OSError, TypeError, KeyError) as e:
            print("not imported:", e, file=sys.stderr); return 1
        if res == "conflict":
            print("not imported: run %s revision %s is already stored with different content" % (run["runId"], run.get("revision")), file=sys.stderr)
            return 1
        print("imported" if res == "new" else "already imported", run["runId"], "rev", run.get("revision")); return 0
    if a.cmd == "drift":
        plan = load_yaml(a.plan)
        try:
            rep = drift_report(predictions(plan, a.addons, plan_requirements(plan, a.plan, a.specs)), latest_runs(a.dest), plan.get("addon"), plan.get("title"))
        except (ValueError, RuntimeError) as e:
            print("error:", e, file=sys.stderr); return 2
        print(json.dumps(rep, indent=1) if a.format == "json" else drift_text(rep))
        return 1 if a.strict and rep["drift"] else 0
    if a.cmd == "report":
        skipped = []
        runs = latest_runs(a.dest, skipped)
        for rid, f, why in skipped:
            print("warning: run %s: %s is unreadable (%s); %s" % (rid, f, why, "the report shows an older revision" if rid in runs else "the run is not in this report"), file=sys.stderr)
        digest = scope = None
        if a.plan_file:
            try:
                scope = load_yaml(a.plan_file)
                digest = encode(merge_sections(scope)).split("!")[2]
            except (OSError, IndexError, KeyError, ValueError) as e:
                print("error: cannot read the digest of %s: %s" % (a.plan_file, e), file=sys.stderr); return 2
        for w in run_warnings(runs, a.expect_version, digest, scope and scope.get("addon"), scope and scope.get("title")):
            print("warning: " + w, file=sys.stderr)
        if a.format == "md":
            txt = report_text(runs, a.dest, failed_only=a.failed_only)
            os.makedirs(a.dest, exist_ok=True)
            open(os.path.join(a.dest, "REPORT.md"), "w", encoding="utf-8").write(txt)
        else:
            txt = (report_json if a.format == "json" else report_junit)(runs, a.dest, a.stacks, a.lines)
        if a.out and a.format != "md":
            open(a.out, "w", encoding="utf-8").write(txt)
        else:
            print(txt)
        if a.strict and skipped:
            print("strict: %d run(s) have a revision that could not be read" % len({s[0] for s in skipped}), file=sys.stderr)
            return 1
        if a.strict and (not runs or bad_steps(models(runs))):
            print("strict: %s" % ("no runs" if not runs else "%d step(s) failed or are unverified" % bad_steps(models(runs))), file=sys.stderr)
            return 1
        return 0
    if a.cmd == "diff":
        skipped = []
        runs = latest_runs(a.dest, skipped)
        ids = []
        for name in (a.a, a.b):
            try:
                ids.append(find_run(runs, name))
            except ValueError as e:
                out = [s for s in skipped if s[0] == name]
                print("error: run %s was left out: %s" % (name, out[0][2]) if out else "error: %s" % e, file=sys.stderr); return 2
        for rid in ids:
            if not finished(runs[rid]) and not a.include_open:
                print("error: run %s is not finished: end it, or add --include-open" % rid, file=sys.stderr); return 2
        d = diff_data(ids[0], runs[ids[0]], ids[1], runs[ids[1]], plan_store(a.dest))
        d["warnings"] += ["run %s: %s: %s" % s for s in skipped if s[0] in ids]
        for w in d["warnings"]:
            print("warning:", w, file=sys.stderr)
        print(json.dumps(d, indent=1, sort_keys=True) if a.format == "json" else diff_text(d))
        if a.strict and d["counts"].get("regressed"):
            print("strict: %d step(s) regressed" % d["counts"]["regressed"], file=sys.stderr); return 1
        return 0
    if a.cmd == "trend":
        skipped = []
        runs = latest_runs(a.dest, skipped)
        t = trend_data(runs, plan_store(a.dest), a.addon, a.title, a.by, a.last, a.include_open)
        t["warnings"] += ["left out: %s" % s for s in left_out(skipped)]
        for w in t["warnings"]:
            print("warning:", w, file=sys.stderr)
        if not t["groups"]:
            print("error: no %srun matches" % ("" if a.include_open else "finished "), file=sys.stderr); return 2
        print(json.dumps(t, indent=1, sort_keys=True) if a.format == "json" else trend_text(t))
        return 0
    if a.cmd == "browse":
        import ct_tui   # only here: the viewer and Textual stay optional
        return ct_tui.main(["--dest", a.dest])
    if a.cmd == "show":
        try:
            print(show_text(latest_runs(a.dest), a.dest, a.run, a.step))
        except ValueError as e:
            print("error:", e, file=sys.stderr); return 2
        return 0
    if a.cmd == "status":
        if a.watch:
            if a.json:
                print("error: --watch and --json do not go together", file=sys.stderr); return 2
            return status_watch(a.dest, a.interval, tty=sys.stdout.isatty())
        rows, problems, extra = status_data(a.dest)
        if a.json:
            print(json.dumps({"runs": rows, "problems": problems, **extra, "ok": not problems}, indent=1, sort_keys=True))
        else:
            print(status_text(rows, problems, extra, a.dest))
        return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
