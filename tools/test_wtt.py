import json, os, re, subprocess, sys, tempfile, unittest, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wtt

ROOT = wtt.ROOT


def good():
    return {"wtt": 1, "addon": "KeepThat", "title": "t",
            "logs": {"debug": {"global": "G", "path": "log", "format": "strings"}},
            "requirements": {"r": {"text": "r"}},
            "macros": [{"id": "m", "text": "/kt debug on\n/reload"}],
            "sections": [{"id": "s", "title": "S", "requires": ["r"], "setup": "Do this.", "clients": ["classic-era"], "steps": [
                {"id": "a.1", "title": "A", "action": {"kind": "secure-macro", "macro": "m"}, "expect": "e",
                 "verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "x"}]},
                {"id": "a.2", "title": "B", "setup": "Own.", "action": {"kind": "manual", "text": "t"}, "expect": "e", "verify": ["player"]}]}]}


class Validate(unittest.TestCase):
    def test_good(self):
        self.assertEqual(wtt.validate(good()), [])

    def test_unknown_field(self):
        p = good(); p["sections"][0]["steps"][0]["bogus"] = 1
        self.assertTrue(wtt.validate(p))

    def test_duplicate_id(self):
        p = good(); p["sections"][0]["steps"][1]["id"] = "a.1"
        self.assertTrue(any("duplicate" in e for e in wtt.validate(p)))

    def test_unknown_action(self):
        p = good(); p["sections"][0]["steps"][1]["action"]["kind"] = "cast"
        self.assertTrue(wtt.validate(p))

    def test_unresolved_requirement(self):
        p = good(); p["sections"][0]["requires"] = ["zzz"]
        self.assertTrue(any("unresolved" in e for e in wtt.validate(p)))

    def test_macro_must_be_allowed(self):
        for bad in ("/run print(1)", "/cast x", "/ddt debug on", "/console scriptErrors 1\n/script x"):
            p = good(); p["macros"][0]["text"] = bad
            self.assertTrue(any("not allowed" in e for e in wtt.validate(p)), bad)

    def test_screenshot_flag_must_be_boolean(self):
        p = good(); p["sections"][0]["steps"][1]["screenshot"] = True
        self.assertEqual(wtt.validate(p), [])
        p["sections"][0]["steps"][1]["screenshot"] = "yes"
        self.assertTrue(wtt.validate(p))

    def test_section_share_lands_on_last_step(self):
        p = good(); p["sections"][0]["share"] = "export"
        self.assertEqual(wtt.validate(p), [])
        m = wtt.merge_sections(p)
        self.assertEqual(m["sections"][0]["steps"][-1]["share"], "export")
        self.assertNotIn("share", m["sections"][0]["steps"][0])
        p["sections"][0]["share"] = "email"
        self.assertTrue(wtt.validate(p))

    def test_unknown_probe(self):
        p = good(); p["sections"][0]["steps"][0]["assertions"] = [{"kind": "state", "probe": "cast", "op": "eq"}]
        self.assertTrue(wtt.validate(p))


class Compile(unittest.TestCase):
    def test_section_fields_merge_into_steps(self):
        m = wtt.merge_sections(good())
        s0, s1 = m["sections"][0]["steps"]
        self.assertEqual(s0["requires"], ["r"]); self.assertEqual(s0["clients"], ["classic-era"])
        self.assertEqual(s1["setup"], "Do this. Own.")
        self.assertNotIn("requires", m["sections"][0])

    def test_round_trip_and_checksum(self):
        s = wtt.encode(wtt.merge_sections(good()))
        self.assertTrue(s.startswith("!WTT1!"))
        self.assertEqual(wtt.decode(s), wtt.merge_sections(good()))
        bad = s[:6] + "00000000" + s[14:]
        with self.assertRaises(ValueError):
            wtt.decode(bad)

    def test_log_none_maps_to_player_only(self):
        with tempfile.TemporaryDirectory() as d:
            md = os.path.join(d, "p.md")
            with open(md, "w") as fh:
                fh.write("# T\n\n## 1. Sec\n\n- [ ] Do it.\n  Check: it works.\n  Log: none; on screen only.\n- [ ] Type `/kt log`.\n  Check: ok.\n  Log: `[kt] started` and `[x] n=<n>`\n")
            plan = wtt.from_md(md, "KeepThat")
            s = plan["sections"][0]["steps"]
            self.assertEqual(s[0]["verify"], ["player"])
            self.assertEqual(s[1]["action"]["commands"], ["/kt log"])
            self.assertEqual([a["contains"] for a in s[1]["assertions"]], ["[kt] started"])
            self.assertTrue(all(a["diagnostic"] for a in s[1]["assertions"]))
            self.assertEqual(wtt.validate(plan), [])


class Plans(unittest.TestCase):
    def test_shipped_plans_validate(self):
        for n in ("keepthat", "dontdothat", "closestvendor", "selftest"):
            self.assertEqual(wtt.validate(wtt.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))), [], n)


class NativeText(unittest.TestCase):
    def test_markdown_is_converted_to_native_codes_and_rejected_if_left(self):
        p = good()
        st = p["sections"][0]["steps"][1]
        st["action"]["text"] = "Type `/kt log` and press **Pass**."
        st["title"] = "Run `/kt log`"
        self.assertTrue(any("markdown" in e for e in wtt.validate(p)))
        wtt.nativize(p)
        self.assertEqual(st["action"]["text"], "Type |cff99ccff/kt log|r and press |cffffd100Pass|r.")
        self.assertEqual(st["title"], "Run /kt log")
        self.assertEqual(wtt.validate(p), [])

    def test_shipped_plans_have_no_markdown(self):
        import glob
        for path in glob.glob(os.path.join(ROOT, "plans", "**", "*.yaml"), recursive=True):
            d = wtt.load_yaml(path)
            for box, key, _ in wtt.display_fields(d):
                self.assertNotRegex(box[key], r"`|\*\*", path + " " + key)


class SamplePlans(unittest.TestCase):
    def test_sample_plans_stay_short_and_full_plans_stay_valid(self):
        import glob
        for n in ("keepthat", "dontdothat", "closestvendor", "selftest"):
            plan = wtt.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            steps = sum(len(s["steps"]) for s in plan["sections"])
            self.assertLessEqual(steps, 8, n)
        for path in glob.glob(os.path.join(ROOT, "plans", "full", "*.yaml")):
            self.assertEqual(wtt.validate(wtt.load_yaml(path)), [], path)


class PlanSkill(unittest.TestCase):
    SKILL = os.path.join(ROOT, "skills", "wtt-test-plan")

    @staticmethod
    def missing_commands(plan):
        """Slash commands named in step text (colored or not) that the step's commands lack."""
        known = {c for cmds in wtt.SLASH.values() for c in cmds} | set(wtt.BUILTIN) | {"/console"}
        out = []
        for sec in plan["sections"]:
            for st in sec["steps"]:
                text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", st["action"].get("text", ""))
                have = st["action"].get("commands", [])
                for m in re.finditer(r"(?<![\w/])(/[A-Za-z]+(?: [A-Za-z0-9]+)*)", text):
                    word = m.group(1).split(" ")[0].lower()
                    if word in known and not any(m.group(1).lower().startswith(h.lower()) or h.lower().startswith(m.group(1).lower()) for h in have):
                        out.append((st["id"], m.group(1)))
        return out

    def test_example_plan_validates_and_lists_named_commands(self):
        plan = wtt.load_yaml(os.path.join(self.SKILL, "example.yaml"))
        self.assertEqual(wtt.validate(plan), [])
        self.assertEqual(self.missing_commands(plan), [])

    def test_missing_command_check_catches_colored_uncolored_and_other_codes(self):
        for text in ("Enter |cff99ccff/cvn test sell|r.", "Enter /cvn test sell.", "Enter |cffffd100/cvn test sell|r."):
            plan = {"sections": [{"steps": [{"id": "x", "action": {"text": text}}]}]}
            self.assertEqual(self.missing_commands(plan), [("x", "/cvn test sell")], text)
            plan["sections"][0]["steps"][0]["action"]["commands"] = ["/cvn test sell"]
            self.assertEqual(self.missing_commands(plan), [], text)

    def test_skill_points_at_files_that_exist(self):
        def read(name):
            with open(os.path.join(self.SKILL, name), encoding="utf-8") as f:
                return f.read()
        text = read("SKILL.md")
        for rel in ("tools/wtt.py", "schema/test-plan.schema.json", "docs/test-plan.md",
                    "openspec/specs/test-plan-format/spec.md", "TestThat/Model/Plan.lua"):
            self.assertIn(rel, text + read("reference.md"))
            self.assertTrue(os.path.exists(os.path.join(ROOT, rel)), rel)
        for name in ("reference.md", "example.yaml"):
            self.assertIn(name, text)
            self.assertTrue(os.path.exists(os.path.join(self.SKILL, name)), name)


class InstallSkill(unittest.TestCase):
    SRC = os.path.join(ROOT, "skills", "wtt-test-plan")

    def make(self, dest):
        return subprocess.run(["make", "install-skill", "SKILL_DIR=" + dest], cwd=ROOT, capture_output=True, text=True)

    def test_install_copies_files_stamps_checkout_and_replaces_stale_copy(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "wtt-test-plan")
            os.makedirs(dest)
            with open(os.path.join(dest, "stale.txt"), "w") as f:
                f.write("old")
            self.assertEqual(self.make(d).returncode, 0)
            self.assertFalse(os.path.exists(os.path.join(dest, "stale.txt")))
            for name in os.listdir(self.SRC):
                with open(os.path.join(self.SRC, name), "rb") as a, open(os.path.join(dest, name), "rb") as b:
                    self.assertEqual(a.read(), b.read(), name)
            with open(os.path.join(dest, ".wtt-root"), encoding="utf-8") as f:
                self.assertEqual(os.path.realpath(f.read().strip()), os.path.realpath(ROOT))
            self.assertFalse(os.path.exists(os.path.join(self.SRC, ".wtt-root")))
            self.assertEqual([n for n in os.listdir(d) if n.startswith(".wtt-test-plan.")], [])

    def test_install_refuses_a_folder_inside_the_checkout(self):
        inside = os.path.join(ROOT, "skills")
        before = sorted(os.listdir(self.SRC))
        r = self.make(inside)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(sorted(os.listdir(self.SRC)), before)
        self.assertTrue(os.path.exists(os.path.join(self.SRC, "SKILL.md")))


class Collect(unittest.TestCase):
    def test_sv2json_and_collect_dedupe(self):
        with tempfile.TemporaryDirectory() as d:
            sv = os.path.join(d, "src", "Account", "A", "SavedVariables")
            os.makedirs(sv)
            with open(os.path.join(sv, "TestThat.lua"), "w") as fh:
                fh.write('TestThatDB = {["runs"] = {["KeepThat-1"] = {["revision"] = 3, ["steps"] = {}, ["order"] = {}}}}\n')
            with open(os.path.join(sv, "KeepThat.lua"), "w") as fh:
                fh.write('KeepThatDB = {["global"] = {["log"] = {"a", "b"}}}\n')
            dest = os.path.join(d, "dest")
            args = type("A", (), {"src": os.path.join(d, "src"), "dest": dest})
            wtt.cmd_collect(args); wtt.cmd_collect(args)
            self.assertEqual(len(os.listdir(os.path.join(dest, "sv"))), 2)
            self.assertEqual(os.listdir(os.path.join(dest, "runs", "KeepThat-1")), ["r3.json"])
            self.assertIn("KeepThat-1", wtt.report_text(wtt.latest_runs(dest)))

    def test_screenshots_by_attempt_window(self):
        with tempfile.TemporaryDirectory() as d:
            sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
            shots = os.path.join(d, "shots"); os.makedirs(shots)
            with open(os.path.join(sv, "TestThat.lua"), "w") as fh:
                fh.write('TestThatDB = {["runs"] = {["R-1"] = {["revision"] = 1, ["order"] = {"a"}, ["steps"] = {["a"] = {["verdict"] = "pass", ["attempts"] = {{["n"] = 1, ["started"] = 1000, ["finished"] = 1060, ["verdict"] = "pass"}}}}}}}\n')
            for name, t in (("in.jpg", 1030), ("out.jpg", 5000)):
                p = os.path.join(shots, name); open(p, "wb").close(); os.utime(p, (t, t))
            dest = os.path.join(d, "dest")
            args = type("A", (), {"src": os.path.join(d, "src"), "dest": dest, "shots": shots})
            wtt.cmd_collect(args); wtt.cmd_collect(args)
            self.assertEqual(os.listdir(os.path.join(dest, "runs", "R-1", "shots")), ["a__in.jpg"])
            self.assertIn("screenshots: a__in.jpg", wtt.report_text(wtt.latest_runs(dest), dest))


class Safety(unittest.TestCase):
    def test_run_ids_cannot_leave_the_runs_folder(self):
        with tempfile.TemporaryDirectory() as d:
            run = {"runId": "../../evil", "revision": 1, "steps": {}}
            wtt.write_revision(d, run)
            self.assertFalse(os.path.exists(os.path.join(d, "evil")))
            self.assertFalse(os.path.exists(os.path.join(os.path.dirname(d), "evil")))
            self.assertTrue(any(f.startswith("r1") for _, _, fs in os.walk(os.path.join(d, "runs")) for f in fs))

    def test_a_different_run_with_the_same_id_and_revision_is_a_conflict(self):
        with tempfile.TemporaryDirectory() as d:
            a = {"runId": "R-1", "revision": 2, "steps": {"x": {"verdict": "pass"}}}
            self.assertEqual(wtt.write_revision(d, a), "new")
            self.assertEqual(wtt.write_revision(d, dict(a)), "same")
            b = {"runId": "R-1", "revision": 2, "steps": {"x": {"verdict": "fail"}}}
            self.assertEqual(wtt.write_revision(d, b), "conflict")
            with open(os.path.join(d, "runs", "R-1", "r2.json")) as fh:
                self.assertEqual(json.load(fh)["steps"]["x"]["verdict"], "pass", "the first copy is kept")

    def test_decode_stops_a_zip_bomb(self):
        raw = b"\0" * (wtt.MAX_INFLATED + 10)
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        packed = c.compress(raw) + c.flush()
        import base64
        s = "!WTT1!%08x!%s" % (zlib.adler32(raw) & 0xFFFFFFFF, base64.b64encode(packed).decode())
        with self.assertRaises(ValueError):
            wtt.decode(s)

    def test_title_and_requirement_text_are_checked_for_markdown(self):
        p = good(); p["title"] = "Run `x`"; p["requirements"]["r"]["text"] = "needs **it**"
        self.assertTrue(any("markdown" in e for e in wtt.validate(p)))
        wtt.nativize(p)
        self.assertNotIn("`", p["title"]); self.assertNotIn("**", p["requirements"]["r"]["text"])


if __name__ == "__main__":
    unittest.main()
