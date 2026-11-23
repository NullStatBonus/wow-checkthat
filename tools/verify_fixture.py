"""Synthetic, anonymized evidence for the ct-verify skill: python3 tools/verify_fixture.py <dir> [--ambiguous].

Writes plans (the two example tally plans plus fixture.yaml) and a SavedVariables tree under <dir>/src. Known answers:
  Tally-Bank / Tally-Alt   both notes say "total 12"            -> relationship held
  fx.1  hand pass, forbidden line appeared (required fail)      -> contradicted
  fx.2  hand pass, required line missing (unverified)           -> unverified, not contradicted
  fx.3  hand pass, only a diagnostic assertion failed           -> not contradicted
  fx.4  player check only                                       -> no evidence
  --ambiguous adds a second eligible run for the bank role      -> the skill must ask for run IDs
"""
import os, re, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ct

SKILL = os.path.join(ct.ROOT, "skills", "ct-test-plan")
FIXTURE_PLAN = {
    "ct": 1, "kind": "plan", "addon": "KeepThat", "title": "Verify fixture plan",
    "logs": {"debug": {"global": "KeepThatDB", "path": "global.log", "format": "strings"}},
    "sections": [{"id": "fx", "title": "Fixture", "steps": [
        {"id": "fx.1", "title": "Forbidden line", "action": {"kind": "manual", "text": "Do the first thing."}, "expect": "nothing fails.",
         "verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "game call failed", "absent": True, "label": "No game call failed"}]},
        {"id": "fx.2", "title": "Required line", "action": {"kind": "manual", "text": "Do the second thing."}, "expect": "it works.",
         "verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "second thing done", "label": "Second thing logged"}]},
        {"id": "fx.3", "title": "Diagnostic only", "action": {"kind": "manual", "text": "Do the third thing."}, "expect": "it works.",
         "verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "extra detail", "diagnostic": True, "label": "Extra detail"}]},
        {"id": "fx.4", "title": "Player check", "action": {"kind": "manual", "text": "Do the fourth thing."}, "expect": "it looks right.", "verify": ["player"]},
    ]}],
}


def digest(plan):
    return re.match(r"^!CT1!([0-9a-f]{8})!", ct.encode(ct.merge_sections(plan))).group(1)


def lua(v, ind=0):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    return "{" + ", ".join("[%s] = %s" % (lua(k), lua(x)) for k, x in v.items()) + "}"


def attempt(verdict, outcomes=None, evidence=None, note=None, by="player"):
    a = {"n": 1, "claimed": verdict, "by": by, "verdict": verdict, "started": 1000, "finished": 1060}
    if outcomes is not None:
        a["outcomes"] = outcomes
    if evidence:
        a["evidence"] = evidence
    if note:
        a["note"] = note
    return a


def step(verdict, **kw):
    return {"verdict": verdict, "attempts": [attempt(verdict, **kw)]}


def run(rid, character, plan, steps, revision=2):
    return {"runId": rid, "revision": revision, "addon": "KeepThat", "planTitle": plan["title"], "planDigest": digest(plan),
            "character": character, "started": 1000, "client": "classic-era", "build": "0", "order": list(steps), "steps": steps}


def build(dest, ambiguous=False):
    bank = ct.load_yaml(os.path.join(SKILL, "keepthat-tally.bank.yaml"))
    alt = ct.load_yaml(os.path.join(SKILL, "keepthat-tally.alt.yaml"))
    os.makedirs(os.path.join(dest, "plans"), exist_ok=True)
    for name in ("keepthat-tally.bank.yaml", "keepthat-tally.alt.yaml"):
        shutil.copyfile(os.path.join(SKILL, name), os.path.join(dest, "plans", name))
    import yaml
    with open(os.path.join(dest, "plans", "fixture.yaml"), "w") as f:
        yaml.safe_dump(FIXTURE_PLAN, f, sort_keys=False)
    runs = {
        "Bank-1": run("Bank-1", "Tally-Bank-Realm", bank, {"kb.1": step("pass"), "kb.2": step("pass", note="total 12")}),
        "Alt-1": run("Alt-1", "Tally-Alt-Realm", alt, {"ka.1": step("pass"), "ka.2": step("pass", note="total 12")}),
        "Fx-1": run("Fx-1", "Tally-Fx-Realm", FIXTURE_PLAN, {
            "fx.1": step("pass", outcomes=[{"result": "fail", "why": "line present"}], evidence="contradicts"),
            "fx.2": step("pass", outcomes=[{"result": "unverified", "why": "no line"}], evidence="unverified"),
            "fx.3": step("pass", outcomes=[{"result": "fail", "why": "no line", "diagnostic": True}], evidence="diagnostic-only"),
            "fx.4": step("pass")}),
    }
    if ambiguous:
        runs["Bank-2"] = run("Bank-2", "Tally-Bank2-Realm", bank, {"kb.1": step("pass"), "kb.2": step("pass", note="total 9")})
    store = {digest(p): ct.merge_sections(p) for p in (FIXTURE_PLAN,)}
    sv = os.path.join(dest, "src", "Account", "A", "SavedVariables")
    os.makedirs(sv, exist_ok=True)
    with open(os.path.join(sv, "CheckThat.lua"), "w") as f:
        f.write("CheckThatDB = %s\n" % lua({"runs": runs, "planStore": store}))
    return runs


if __name__ == "__main__":
    out = sys.argv[1]
    build(out, "--ambiguous" in sys.argv)
    print("wrote", out)
