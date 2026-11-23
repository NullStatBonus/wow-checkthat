#!/usr/bin/env python3
"""CT plan tooling: validate, compile, decode, from-md, collect, report.

Needs PyYAML and jsonschema (see requirements.txt). Run via .venv/bin/python tools/ct.py.
"""
import argparse, base64, copy, glob, hashlib, json, os, re, shutil, subprocess, sys, zlib

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
    "CheckThat": {"debug": {"global": "CheckThatDB", "path": "global.log.entries", "format": "entries"}},
    "KeepThat": {"debug": {"global": "KeepThatDB", "path": "global.log", "format": "strings"}},
    "DontDoThat": {"debug": {"global": "DontDoThatDB", "path": "global.log.entries", "format": "entries"}},
    "ClosestVendor": {"debug": {"global": "ClosestVendorCharDB", "path": "log.entries", "format": "entries"}},
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
    addon = plan["addon"]
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
    for sec in plan["sections"]:
        for r in sec.get("requires", []):
            if r not in reqs:
                errs.append("section %s: unresolved requirement %s" % (sec["id"], r))
        for st in sec["steps"]:
            sid = st["id"]
            if sid in seen:
                errs.append("duplicate step id %s" % sid)
            seen.add(sid)
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
            has_a = "assertions" in st["verify"]
            if has_a and not st.get("assertions"):
                errs.append("%s: verify assertions but none given" % sid)
            if st.get("assertions") and not has_a:
                errs.append("%s: assertions given but verify lacks assertions" % sid)
            if "reviewer" in st["verify"] and not st.get("reviewer"):
                errs.append("%s: verify reviewer but no reviewer text" % sid)
            for a in st.get("assertions", []):
                if a["kind"] in ("log", "log-sequence") and a["source"] not in logs:
                    errs.append("%s: unknown log source %s" % (sid, a["source"]))
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
    out = copy.deepcopy(plan)
    out["kind"], out["ct"] = "plan", 1
    for sec in out["sections"]:
        sreq, ssetup, scl = sec.pop("requires", []), sec.pop("setup", None), sec.get("clients")
        sshare = sec.pop("share", None)
        if sshare and sshare != "none" and "share" not in sec["steps"][-1]:
            sec["steps"][-1]["share"] = sshare
        for st in sec["steps"]:
            st["requires"] = list(dict.fromkeys(sreq + st.get("requires", [])))
            if not st["requires"]:
                del st["requires"]
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


def write_revision(dest, run):
    """Store one run revision. Refuse a path outside dest and a different run that reuses an id and revision.
    Returns "new", "same" or "conflict"."""
    base = os.path.realpath(os.path.join(dest, "runs"))
    rp = os.path.realpath(os.path.join(base, safe_name(run["runId"])))
    if os.path.dirname(rp) != base:
        raise ValueError("run id leaves the runs folder")
    os.makedirs(rp, exist_ok=True)
    rj = os.path.join(rp, "r%d.json" % int(run.get("revision", 0)))
    text = json.dumps(run, indent=1, sort_keys=True)
    if os.path.exists(rj):
        with open(rj) as fh:
            return "same" if fh.read() == text else "conflict"
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
    new_sv = new_runs = 0
    for src, base in sources:
        n_sv, n_runs = collect_src(src, base, dest)
        new_sv += n_sv; new_runs += n_runs
    new_shots = sum(collect_shots(dest, d) for d in shot_dirs)
    print("collected: %d new saved-variable copies, %d new run revisions, %d new screenshots -> %s" % (new_sv, new_runs, new_shots, dest))


def default_src():
    return os.path.join(os.path.dirname(ROOT), "shared-addon-resources", "saved")


def collect_src(src, base, dest):
    os.makedirs(os.path.join(dest, "sv"), exist_ok=True)
    os.makedirs(os.path.join(dest, "runs"), exist_ok=True)
    new_sv = new_runs = 0
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
                db = sv_json(f).get("CheckThatDB", {})
            except Exception as e:
                print("skip %s: %s" % (f, e), file=sys.stderr); continue
            runs = (db.get("global") or {}).get("runs") or db.get("runs") or {}
            for rid, run in runs.items():
                run = dict(run); run.setdefault("runId", rid)
                try:
                    res = write_revision(dest, run)
                except (ValueError, OSError, TypeError) as e:
                    print("skip run %r: %s" % (rid, e), file=sys.stderr); continue
                if res == "new":
                    new_runs += 1
                elif res == "conflict":
                    print("warning: run %s revision %s already stored with different content; kept the first (two testers may share an id)" % (rid, run.get("revision")), file=sys.stderr)
    return new_sv, new_runs


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
        revs = sorted(glob.glob(os.path.join(rp, "r*.json")), key=lambda p: int(re.search(r"r(\d+)\.json", p).group(1)))
        if revs:
            with open(revs[-1]) as fh:
                runs[os.path.basename(rp)] = json.load(fh)
    return runs


def by_checkthat(rec):
    """True when the runner, not the player, recorded the step's last result (an auto step)."""
    done = [a for a in rec.get("attempts") or [] if a.get("verdict")]   # an open retry has no result yet
    return rec.get("verdict") != "pending" and bool(done) and done[-1].get("by") == "auto"   # Undo reopens the step


def report_text(runs, dest=None):
    out = ["# CT report", ""]
    for rid, r in sorted(runs.items()):
        counts = {}
        for sid, rec in (r.get("steps") or {}).items():
            counts[rec.get("verdict", "?")] = counts.get(rec.get("verdict", "?"), 0) + 1
        out.append("## %s (%s, rev %s)" % (rid, r.get("planTitle", r.get("addon")), r.get("revision")))
        out.append("client %s build %s character %s" % (r.get("client"), r.get("build"), r.get("character")))
        auto = sum(1 for rec in (r.get("steps") or {}).values() if by_checkthat(rec))
        out.append("counts: " + ", ".join("%s=%d" % kv for kv in sorted(counts.items())) + (", auto=%d" % auto if auto else ""))
        for sid in r.get("order", []):
            rec = r["steps"].get(sid, {})
            shots = (run_shots(dest, rid) if dest else {}).get(sid, [])
            mark = ", recorded by CheckThat" if by_checkthat(rec) else ""
            if (shots or mark) and rec.get("verdict") in ("pass", "skip", "inapplicable"):
                out.append("- %s: %s%s%s" % (sid, rec.get("verdict"), mark, (", screenshots: " + ", ".join(shots)) if shots else ""))
            if rec.get("verdict") in ("pass", "skip", "inapplicable"):
                continue
            out.append("- %s: %s%s%s" % (sid, rec.get("verdict"), mark, (", screenshots: " + ", ".join(shots)) if shots else ""))
            for at in rec.get("attempts", []):
                note = at.get("note")
                outs = [o for o in (at.get("outcomes") or []) if o.get("result") != "pass"]
                out.append("  attempt %s: %s%s%s" % (at.get("n"), at.get("verdict"),
                           " note=" + note if note else "",
                           " evidence=" + ",".join("%s(%s)" % (o.get("result"), o.get("why", "")) for o in outs) if outs else ""))
        out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------- CLI

def main(argv=None):
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
        cmd_collect(a); return 0
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
        txt = report_text(runs, a.dest)
        open(os.path.join(a.dest, "REPORT.md"), "w").write(txt)
        print(txt); return 0


if __name__ == "__main__":
    sys.exit(main())
