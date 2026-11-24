#!/usr/bin/env python3
"""CT plan tooling: validate, compile, decode, from-md, collect, report.

Needs PyYAML and jsonschema (see requirements.txt). Run via .venv/bin/python tools/ct.py.
"""
import argparse, base64, copy, glob, hashlib, json, os, re, shutil, subprocess, sys, time, zlib

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
    if not isinstance(text, str) or not text or len(text) > 255:
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
    return isinstance(v, (int, float)) and not isinstance(v, bool)


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


def validate(plan):
    """Return a list of error strings; empty means valid."""
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
        if sec["id"] in sec_ids:
            errs.append("duplicate section id %s" % sec["id"])
        sec_ids.add(sec["id"])
        for r in sec.get("requires", []):
            if r not in reqs:
                errs.append("section %s: unresolved requirement %s" % (sec["id"], r))
        if "category" in sec and sec["category"] not in cats:
            errs.append("section %s: unknown category %s" % (sec["id"], sec["category"]))
        for st in sec["steps"]:
            sid = st["id"]
            if sid in seen:
                errs.append("duplicate step id %s" % sid)
            seen.add(sid)
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
    return errs


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

def print_warnings(plan):
    for sid, cmd in warnings(plan):
        print("warning: %s: command named in text but not in commands: %s" % (sid, cmd))

def merge_sections(plan):
    """Compile section requirements, setup and clients into each step."""
    out = expand_cases(plan)
    out["kind"], out["ct"] = "plan", 1
    for sec in out["sections"]:
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
    return run

def note_problem(dest, text):
    """Keep what collect could not store, so a later status still shows it."""
    p = os.path.join(dest, "problems.log")
    old = open(p).read().splitlines() if os.path.exists(p) else []
    if text not in old:
        with open(p, "a") as fh:
            fh.write(text + "\n")

def write_revision(dest, run):
    """Store one run revision. Refuse a path outside dest and a different run that reuses an id and revision.
    Returns "new", "same" or "conflict"."""
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
            with open(rj) as fh:
                same = canonical(export_form(json.load(fh))) == canonical(export_form(run))
        except ValueError:
            same = False   # a damaged stored file is not the same run
        return "same" if same else "conflict"
    with open(rj, "w") as fh:
        fh.write(text)
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


# ---------------------------------------------------------------- evidence harvest

def sv_json(path):
    r = subprocess.run(["luajit", os.path.join(ROOT, "tools", "sv2json.lua"), path], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr.strip())
    return json.loads(r.stdout)


WATCH = ("CheckThat", "KeepThat", "DontDoThat", "ClosestVendor")


def find_sv(src):
    found = []
    for name in WATCH:
        found += glob.glob(os.path.join(src, "**", "SavedVariables", name + ".lua"), recursive=True)
    return sorted(set(found))


WOW_CLIENTS = ("_classic_era_", "_forever_")


def wow_sources(wow):
    """Standard layout: <game dir>/<client>/WTF and <client>/Screenshots for each client folder that exists."""
    found = [c for c in WOW_CLIENTS if os.path.isdir(os.path.join(wow, c, "WTF"))]
    return [(os.path.join(wow, c, "WTF"), wow) for c in found], [os.path.join(wow, c, "Screenshots") for c in found]


def cmd_collect(a):
    dest = a.dest
    wow = getattr(a, "wow", None)
    if a.src or not wow:
        sources, shot_dirs = [(a.src or default_src(), a.src or default_src())], [getattr(a, "shots", None)]
    else:
        sources, shot_dirs = wow_sources(wow)
        if not sources:
            sys.exit("no %s folder with WTF under %s" % (" or ".join(WOW_CLIENTS), wow))
        if getattr(a, "shots", None):
            shot_dirs = [a.shots]
    new_sv = new_runs = failed = 0
    for src, base in sources:
        n_sv, n_runs, n_failed = collect_src(src, base, dest)
        new_sv += n_sv; new_runs += n_runs; failed += n_failed
    new_shots = sum(collect_shots(dest, d) for d in shot_dirs)
    print("collected: %d new saved-variable copies, %d new run revisions, %d new screenshots -> %s" % (new_sv, new_runs, new_shots, dest))
    if failed:
        print("error: %d saved-variables file(s) could not be decoded (is luajit installed?)" % failed, file=sys.stderr)
        return 1
    return 0


def default_src():
    return os.path.join(os.path.dirname(ROOT), "shared-addon-resources", "saved")


def save_errors(dest, glob_db, h, rids=()):
    """Keep the saved Lua error lines and their call stacks (they are not part of a run) next to the run copies."""
    if not isinstance(glob_db, dict):
        return
    errs, stacks = glob_db.get("errors"), glob_db.get("errorStacks")
    errs, stacks = errs if isinstance(errs, list) else [], stacks if isinstance(stacks, list) else []
    if errs or stacks:
        os.makedirs(os.path.join(dest, "errors"), exist_ok=True)
        with open(os.path.join(dest, "errors", h + ".json"), "w") as fh:
            json.dump({"runs": list(rids), "errors": errs, "errorStacks": stacks}, fh, indent=1)

def load_errors(dest, rid=None):
    """({key: error line}, {key: call stack}) from the collected saved-variables copies. The key is <time>.<counter> and is only
    unique inside one game session, so with rid only the copies that hold that run count."""
    errs, stacks = {}, {}
    for p in sorted(glob.glob(os.path.join(dest or "", "errors", "*.json"))):
        try:
            with open(p) as fh:
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

def collect_src(src, base, dest):
    os.makedirs(os.path.join(dest, "sv"), exist_ok=True)
    os.makedirs(os.path.join(dest, "runs"), exist_ok=True)
    new_sv = new_runs = failed = 0
    for f in find_sv(src):
        with open(f, "rb") as fh:
            data = fh.read()
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
            for rid, run in runs.items():
                run = dict(run); run.setdefault("runId", rid)
                try:
                    res = write_revision(dest, run)
                except (ValueError, OSError, TypeError) as e:
                    print("skip run %r: %s" % (rid, e), file=sys.stderr)
                    note_problem(dest, "run %s was not stored: %s" % (rid, " ".join(str(e).split()))); continue
                if res == "new":
                    new_runs += 1
                elif res == "conflict":
                    msg = "run %s revision %s already stored with different content; kept the first (two testers may share an id); new copy in sv/*.%s.lua" % (rid, run.get("revision"), h)
                    print("warning: " + msg, file=sys.stderr)
                    note_problem(dest, msg)
    return new_sv, new_runs, failed


SHOT_EXT = (".jpg", ".jpeg", ".png", ".tga")


def collect_shots(dest, shots_dir):
    """Copy screenshots whose mtime falls inside a step attempt window into runs/<id>/shots/."""
    if not shots_dir or not os.path.isdir(shots_dir):
        return 0
    files = []
    for name in os.listdir(shots_dir):
        if name.lower().endswith(SHOT_EXT):
            p = os.path.join(shots_dir, name)
            files.append((os.path.getmtime(p), name, p))
    copied = 0
    for rid, run in latest_runs(dest).items():
        for sid, rec in (run.get("steps") or {}).items():
            for at in rec.get("attempts", []):
                start = at.get("started")
                if not isinstance(start, (int, float)):
                    continue
                end = at.get("finished") or start + 900
                for mt, name, p in files:
                    if start - 2 <= mt <= end + 2:
                        out = os.path.join(dest, "runs", safe_name(rid), "shots", "%s__%s" % (safe_name(sid), safe_name(name)))
                        if not os.path.exists(out):
                            os.makedirs(os.path.dirname(out), exist_ok=True)
                            shutil.copyfile(p, out); copied += 1
    return copied


def run_shots(dest, rid):
    d = os.path.join(dest, "runs", rid, "shots")
    out = {}
    if os.path.isdir(d):
        for f in sorted(os.listdir(d)):
            out.setdefault(f.split("__", 1)[0], []).append(f)
    return out


def latest_runs(dest):
    runs = {}
    for rp in glob.glob(os.path.join(dest, "runs", "*")):
        for p in reversed(rev_files(rp)):   # newest readable revision; status names a damaged one
            try:
                runs[os.path.basename(rp)] = read_run(p)
                break
            except (ValueError, OSError):
                continue
    return runs

def rev_files(rp):
    """Revision files of one run, oldest first. A file that is not r<number>.json is not a revision."""
    found = [(int(m.group(1)), p) for p in glob.glob(os.path.join(rp, "r*.json")) for m in [re.fullmatch(r"r(\d+)\.json", os.path.basename(p))] if m]
    return [p for _, p in sorted(found)]

def read_run(path):
    """One stored revision. Raises ValueError (or OSError) when it is not a run record."""
    with open(path) as fh:
        run = json.load(fh)
    if isinstance(run, dict) and run.get("steps") == []:
        run["steps"] = {}   # an empty Lua table decodes to a list
    if not isinstance(run, dict) or not isinstance(run.get("steps"), dict) or not isinstance(run.get("order", []), list):
        raise ValueError("not a run record")
    for rec in run["steps"].values():   # the readers below call .get on each of these
        ats = rec.get("attempts", []) if isinstance(rec, dict) else None
        if not isinstance(ats, list) or not all(isinstance(a, dict) and isinstance(a.get("outcomes", []), list) and all(isinstance(o, dict) for o in a.get("outcomes", []))
                                                and isinstance(a.get("excerpt", {}), dict) for a in ats):
            raise ValueError("a step record is malformed")
    return run


def by_checkthat(rec):
    """True when the runner, not the player, recorded the step's last result (an auto step)."""
    done = [a for a in rec.get("attempts") or [] if a.get("verdict")]   # an open retry has no result yet
    return rec.get("verdict") != "pending" and bool(done) and done[-1].get("by") == "auto"   # Undo reopens the step


def evidence_state(rec):
    """met, bad, missing or none: the required checks of the step's last finished attempt."""
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


def step_table(r, only=None):
    """One row per step in plan order: step, verdict, evidence, attempts, note. only limits it to some step ids."""
    rows = [("step", "verdict", "evidence", "attempts", "note")]
    for sid in step_ids(r):
        if only is not None and sid not in only:
            continue
        rec = (r.get("steps") or {}).get(sid, {})
        done = [a for a in rec.get("attempts") or [] if a.get("verdict")]
        note = " ".join(((done[-1].get("note") or "") if done else "").splitlines())   # splitlines also splits Unicode line breaks
        if len(note) > 40:
            note = note[:37] + "..."
        rows.append((sid, str(rec.get("verdict", "?")), evidence_state(rec), str(len(rec.get("attempts") or [])), note))
    widths = [max(len(row[i]) for row in rows) for i in range(4)]
    return ["  ".join(c.ljust(widths[i]) for i, c in enumerate(row[:4])) + ("  " + row[4] if row[4] else "") for row in rows]


def attempt_lines(at, stack_keys, errs, stacks, ambiguous):
    note = at.get("note")
    outs = [o for o in (at.get("outcomes") or []) if o.get("result") != "pass"]
    out = ["  attempt %s: %s%s%s" % (at.get("n"), at.get("verdict"),
           " note=" + note if note else "",
           " evidence=" + ",".join("%s(%s)" % (o.get("result"), o.get("why", "")) for o in outs) if outs else "")]
    for src, lines in sorted((at.get("excerpt") or {}).items()):
        out.append("    log %s, %d new line%s:" % (src, len(lines), "" if len(lines) == 1 else "s"))
        out.extend("      " + str(line) for line in lines)
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
            earlier = [at for at in rec.get("attempts", []) if at.get("verdict") in ("fail", "unverified")] if settled else []
            head = "- %s: %s%s%s" % (sid, rec.get("verdict"), mark, (", screenshots: " + ", ".join(shots)) if shots else "")
            if (shots or mark or earlier) and settled:
                out.append(head + (", after %d earlier failed or unverified attempt%s" % (len(earlier), "" if len(earlier) == 1 else "s") if earlier else ""))
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
    return "skipped", SKIP_WHY.get(v, "no result")

def run_model(rid, r, stacks=None):
    """The run as plain data. stacks is {(step, attempt n): [text]} and is left out unless asked for."""
    steps, counts = [], {}
    for sid in step_ids(r):
        rec = (r.get("steps") or {}).get(sid)
        result, why = classify(rec) if rec is not None else ("unverified", "the run has no record of this step")
        rec = rec or {}
        counts[result] = counts.get(result, 0) + 1
        s = {"id": sid, "category": (r.get("cat") or {}).get(sid), "result": result, "verdict": rec.get("verdict"), "reason": why,
             "attempts": len(rec.get("attempts") or []), "recordedByCheckThat": by_checkthat(rec)}
        if stacks and result in ("fail", "unverified"):
            s["stacks"] = [t for at in rec.get("attempts") or [] for t in stacks.get((sid, at.get("n")), [])]
        steps.append(s)
    return {"runId": rid, "addon": r.get("addon"), "plan": r.get("planTitle"), "revision": r.get("revision"), "client": r.get("client"),
            "build": r.get("build"), "character": r.get("character"), "counts": counts,
            "categories": [{"id": c, "title": t, "state": st, "resolved": a, "total": b} for c, t, st, a, b in category_states(r)],
            "steps": steps}

def models(runs, dest=None, with_stacks=False):
    out = []
    for rid, r in sorted(runs.items()):
        errs, stks = load_errors(dest, stored_id(rid, r)) if with_stacks and dest else ({}, {})
        hits, _ = stack_hits(r, stks)
        out.append(run_model(rid, r, {k: ["%s: %s" % (key, stks[key]) for key in v] for k, v in hits.items()} if with_stacks else None))
    return out

def bad_steps(ms):
    return sum(m["counts"].get("fail", 0) + m["counts"].get("unverified", 0) for m in ms)

def report_json(runs, dest=None, with_stacks=False):
    ms = models(runs, dest, with_stacks)
    totals = {}
    for m in ms:
        for k, n in m["counts"].items():
            totals[k] = totals.get(k, 0) + n
    return json.dumps({"runs": ms, "totals": totals, "ok": bool(ms) and bad_steps(ms) == 0}, indent=1, sort_keys=True)

def report_junit(runs, dest=None, with_stacks=False):
    """JUnit XML: a suite for each run category, a case for each step. Fail and unverified are failures (type tells them apart);
    partial passes with its note in system-out; pending, skip, deselected and inapplicable are skipped."""
    from xml.etree import ElementTree as ET
    ok = lambda c: c in "\t\n\r" or 0x20 <= ord(c) <= 0xD7FF or 0xE000 <= ord(c) <= 0xFFFD or ord(c) >= 0x10000
    clean = lambda s: "".join(c if ok(c) else "?" for c in str(s))   # XML 1.0 has no place for most control characters
    root = ET.Element("testsuites")
    for m in models(runs, dest, with_stacks):
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
                    f.text = clean("\n".join(s.get("stacks") or []) or s["reason"])
                elif s["result"] == "skipped":
                    ET.SubElement(case, "skipped", message=clean(s["reason"]))
                elif s["result"] == "partial":
                    ET.SubElement(case, "system-out").text = clean("partial: " + s["reason"])
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
            except (ValueError, OSError):
                bad.append(os.path.basename(p))
        for b in bad:
            problems.append("run %s: %s is unreadable%s" % (rid, b, "; showing the newest readable revision" if good else ""))
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
                     "sizeEstimate": size, "sizeLimit": MAX_INFLATED, "finished": bool(r.get("endedAt")), "unreadableRevisions": bad})
        if size > MAX_INFLATED * 0.8:
            problems.append("run %s: about %d of %d bytes: close to the export limit" % (rid, size, MAX_INFLATED))
    log = os.path.join(dest, "problems.log")
    if os.path.exists(log):
        with open(log) as fh:
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
    load_env()
    ap = argparse.ArgumentParser(prog="ct")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("validate"); p.add_argument("plan")
    p = sub.add_parser("compile"); p.add_argument("plan"); p.add_argument("-o")
    p = sub.add_parser("decode"); p.add_argument("string_or_file")
    p = sub.add_parser("from-md"); p.add_argument("md"); p.add_argument("--addon", required=True, choices=sorted(SLASH)); p.add_argument("-o", required=True)
    p = sub.add_parser("sv2json"); p.add_argument("file")
    p = sub.add_parser("collect"); p.add_argument("--src", default=os.environ.get("CT_WTF"), help="one WTF folder; wins over --wow"); p.add_argument("--wow", default=os.environ.get("CT_WOW"), help="game folder; collects _classic_era_ and _forever_ (WTF and Screenshots)"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p.add_argument("--shots", default=os.environ.get("CT_SHOTS"), help="folder with game screenshots (default: Screenshots next to --src, if it exists)")
    p = sub.add_parser("report"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p.add_argument("--format", choices=("md", "json", "junit"), default="md", help="md also writes REPORT.md; json and junit go to stdout (or --out)")
    p.add_argument("--strict", action="store_true", help="exit 1 when any step failed or is unverified, or there are no runs")
    p.add_argument("--stacks", action="store_true", help="put saved error call stacks in json and junit (md always shows them); they can hold private paths")
    p.add_argument("--out", help="write the json or junit report to this file")
    p.add_argument("--failed-only", action="store_true", help="md only: runs and steps that failed or are unverified")
    p = sub.add_parser("show", help="print one run, or one step of it with every attempt, log excerpt and error stack"); p.add_argument("run", help="run id, or part of it that names one run"); p.add_argument("step", nargs="?"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p = sub.add_parser("browse", help="open the read-only evidence viewer (needs a terminal and Textual: requirements-tui.txt)"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    p = sub.add_parser("status", help="check what the evidence folder holds: readable revisions, conflicts, sizes"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence")); p.add_argument("--json", action="store_true")
    p.add_argument("--watch", action="store_true", help="print status again every --interval seconds until Ctrl-C"); p.add_argument("--interval", type=float, default=5)
    p = sub.add_parser("import-results"); p.add_argument("string_or_file"); p.add_argument("--dest", default=os.path.join(ROOT, "evidence"))
    a = ap.parse_args(argv)

    if a.cmd == "validate":
        plan = load_yaml(a.plan)
        errs = validate(plan)
        for e in errs:
            print("error:", e)
        if not errs:
            print_warnings(plan)
        print("ok" if not errs else "%d errors" % len(errs))
        return 1 if errs else 0
    if a.cmd == "compile":
        plan = load_yaml(a.plan)
        errs = validate(plan)
        if errs:
            for e in errs:
                print("error:", e, file=sys.stderr)
            return 1
        s = encode(merge_sections(plan))
        if a.o:
            open(a.o, "w").write(s + "\n")
        else:
            print(s)
        return 0
    if a.cmd == "decode":
        s = a.string_or_file
        if os.path.exists(s):
            s = open(s).read()
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
    if a.cmd == "collect":
        if not a.shots and (a.src or not a.wow):
            guess = os.path.join(os.path.dirname(os.path.abspath(a.src or default_src())), "Screenshots")
            a.shots = guess if os.path.isdir(guess) else None
        return cmd_collect(a)
    if a.cmd == "import-results":
        s = a.string_or_file
        if os.path.exists(s):
            s = open(s).read()
        run = decode(s)
        if run.get("kind") != "results":
            print("not a results string", file=sys.stderr); return 1
        try:
            res = write_revision(a.dest, run)
        except (ValueError, OSError, TypeError, KeyError) as e:
            print("not imported:", e, file=sys.stderr); return 1
        if res == "conflict":
            print("not imported: run %s revision %s is already stored with different content" % (run["runId"], run.get("revision")), file=sys.stderr)
            return 1
        print("imported" if res == "new" else "already imported", run["runId"], "rev", run.get("revision")); return 0
    if a.cmd == "report":
        runs = latest_runs(a.dest)
        if a.format == "md":
            txt = report_text(runs, a.dest, failed_only=a.failed_only)
            os.makedirs(a.dest, exist_ok=True)
            open(os.path.join(a.dest, "REPORT.md"), "w").write(txt)
        else:
            txt = (report_json if a.format == "json" else report_junit)(runs, a.dest, a.stacks)
        if a.out and a.format != "md":
            open(a.out, "w").write(txt)
        else:
            print(txt)
        if a.strict and (not runs or bad_steps(models(runs))):
            print("strict: %s" % ("no runs" if not runs else "%d step(s) failed or are unverified" % bad_steps(models(runs))), file=sys.stderr)
            return 1
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
