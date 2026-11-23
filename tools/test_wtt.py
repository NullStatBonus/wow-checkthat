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

    def test_runner_plans_allow_ct_and_checkthat_only(self):
        for cmd in ("/ct", "/checkthat"):
            p = good(); p["addon"] = "CheckThat"; p["macros"][0]["text"] = cmd + " debug on\n/reload"
            self.assertEqual(wtt.validate(p), [], cmd)
        for cmd in ("/kt debug on", "/wtt debug on"):
            p = good(); p["addon"] = "CheckThat"; p["macros"][0]["text"] = cmd
            self.assertTrue(wtt.validate(p), cmd)

    def test_unknown_probe(self):
        p = good(); p["sections"][0]["steps"][0]["assertions"] = [{"kind": "state", "probe": "cast", "op": "eq"}]
        self.assertTrue(wtt.validate(p))

    def auto(self):
        p = good(); st = p["sections"][0]["steps"][0]
        st["verify"] = ["assertions"]; st["auto"] = True
        return p, st

    def has(self, p, needle):
        errs = wtt.validate(p)
        self.assertTrue(any(needle in e for e in errs), "%r not in %r" % (needle, errs))

    def test_auto_step_valid(self):
        p, st = self.auto()
        self.assertEqual(wtt.validate(p), [])
        for n in (5, 30, 300):
            st["timeout"] = n
            self.assertEqual(wtt.validate(p), [], n)

    def test_auto_step_needs_assertions_alone(self):
        p, st = self.auto(); st["verify"] = ["player", "assertions"]
        self.assertTrue(wtt.validate(p))
        p, st = self.auto(); st["verify"] = ["reviewer"]; st["reviewer"] = "r"; del st["assertions"]
        self.assertTrue(wtt.validate(p))

    def test_auto_step_needs_a_required_assertion(self):
        p, st = self.auto(); st["assertions"][0]["diagnostic"] = True
        self.assertTrue(wtt.validate(p))

    def test_auto_step_rejects_required_absence(self):
        p, st = self.auto(); st["assertions"][0]["absent"] = True
        self.assertTrue(wtt.validate(p))

    def test_timeout_range_and_auto_only(self):
        for n in (3, 4, 301, 600, 7.5, -1, "30"):
            p, st = self.auto(); st["timeout"] = n
            self.assertTrue(wtt.validate(p), n)
        p = good(); p["sections"][0]["steps"][0]["timeout"] = 30
        self.assertTrue(wtt.validate(p))

    def test_schema_alone_rejects_the_cross_field_auto_rules(self):
        import jsonschema
        with open(wtt.SCHEMA, encoding="utf-8") as f:
            v = jsonschema.Draft202012Validator(json.load(f))
        def errs(mut):
            p, st = self.auto(); mut(st)
            return list(v.iter_errors(p))
        self.assertEqual(errs(lambda st: None), [])
        self.assertTrue(errs(lambda st: st.update(auto=False, timeout=30)), "timeout without auto")
        self.assertTrue(errs(lambda st: st.update(verify=["player", "assertions"])), "auto with player")
        self.assertTrue(errs(lambda st: st.update(verify=["reviewer"], reviewer="r")), "auto without assertions")
        self.assertTrue(errs(lambda st: st.update(auto=False, action={"kind": "wait-event"})), "wait-event without auto")
        self.assertTrue(errs(lambda st: st["assertions"][0].update(diagnostic=True)), "only diagnostic assertions")
        self.assertTrue(errs(lambda st: st["assertions"][0].update(absent=True)), "required absence check")
        def with_diagnostic_absence(st):
            st["assertions"].append({"kind": "log", "source": "debug", "contains": "y", "absent": True, "diagnostic": True})
        self.assertEqual(errs(with_diagnostic_absence), [], "a diagnostic absence check beside a required one is fine")

    def test_wait_event_needs_auto(self):
        p = good(); p["sections"][0]["steps"][0]["action"] = {"kind": "wait-event", "text": "t"}
        self.assertTrue(wtt.validate(p))
        p, st = self.auto(); st["action"] = {"kind": "wait-event", "text": "t"}
        self.assertEqual(wtt.validate(p), [])


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
            plan = wtt.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            self.assertEqual(wtt.validate(plan), [], n)
            self.assertEqual(wtt.warnings(plan), [], n)


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
            plan = wtt.load_yaml(path)
            self.assertEqual(wtt.validate(plan), [], path)
            self.assertEqual(wtt.warnings(plan), [], path)


class PlanSkill(unittest.TestCase):
    SKILL = os.path.join(ROOT, "skills", "wtt-test-plan")

    missing_commands = staticmethod(wtt.warnings)

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

    def test_validate_warns_but_still_succeeds(self):
        import contextlib, io
        plan = good()
        plan["sections"][0]["steps"][1]["action"]["text"] = "Type |cff99ccff/kt debug on|r."
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "p.yaml")
            import yaml
            with open(p, "w") as f:
                yaml.safe_dump(plan, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = wtt.main(["validate", p])
        self.assertEqual(rc, 0)
        self.assertIn("warning: a.2: command named in text but not in commands: /kt debug on", out.getvalue())

    def test_skill_points_at_files_that_exist(self):
        def read(name):
            with open(os.path.join(self.SKILL, name), encoding="utf-8") as f:
                return f.read()
        text = read("SKILL.md")
        for rel in ("tools/wtt.py", "schema/test-plan.schema.json", "docs/test-plan.md", "docs/debug-logging.md",
                    "openspec/specs/test-plan-format/spec.md", "CheckThat/Model/Plan.lua"):
            self.assertIn(rel, text + read("reference.md"))
            self.assertTrue(os.path.exists(os.path.join(ROOT, rel)), rel)
        for name in ("reference.md", "example.yaml"):
            self.assertIn(name, text)
            self.assertTrue(os.path.exists(os.path.join(self.SKILL, name)), name)


class InstallSkill(unittest.TestCase):
    SRC = os.path.join(ROOT, "skills", "wtt-test-plan")
    BUNDLE = ("tools/wtt.py", "schema/test-plan.schema.json", "docs/test-plan.md", "docs/debug-logging.md",
              "openspec/specs/test-plan-format/spec.md", "CheckThat/Model/Plan.lua", "requirements.txt")

    def make(self, dest, **env):
        return subprocess.run(["make", "install-skill", "SKILL_DIR=" + dest], cwd=ROOT, capture_output=True, text=True,
                              env=dict(os.environ, **env))

    def test_install_copies_skill_and_bundle_and_replaces_stale_copy(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "wtt-test-plan")
            os.makedirs(dest)
            with open(os.path.join(dest, "stale.txt"), "w") as f:
                f.write("old")
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            self.assertFalse(os.path.exists(os.path.join(dest, "stale.txt")))
            self.assertFalse(os.path.exists(os.path.join(dest, ".wtt-root")))
            for name in os.listdir(self.SRC):
                with open(os.path.join(self.SRC, name), "rb") as a, open(os.path.join(dest, name), "rb") as b:
                    self.assertEqual(a.read(), b.read(), name)
            for rel in self.BUNDLE:
                with open(os.path.join(ROOT, rel), "rb") as a, open(os.path.join(dest, "wtt", rel), "rb") as b:
                    self.assertEqual(a.read(), b.read(), rel)
            with open(os.path.join(ROOT, "CheckThat", "CheckThat_Vanilla.toc"), encoding="utf-8") as f:
                version = re.search(r"^## Version:\s*(\S+)", f.read(), re.M).group(1)
            with open(os.path.join(dest, "wtt", "VERSION"), encoding="utf-8") as f:
                self.assertEqual(f.read().strip(), version)
            self.assertEqual([n for n in os.listdir(d) if n.startswith(".wtt-test-plan.")], [])

    def test_installed_tools_run_without_the_checkout(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            dest = os.path.join(d, "wtt-test-plan")
            r = subprocess.run([sys.executable, os.path.join(dest, "wtt", "tools", "wtt.py"), "validate",
                                os.path.join(dest, "example.yaml")], capture_output=True, text=True, cwd=d)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ok", r.stdout)

    def test_failed_dependency_install_keeps_the_earlier_copy(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "wtt-test-plan")
            os.makedirs(dest)
            with open(os.path.join(dest, "keep.txt"), "w") as f:
                f.write("old")
            r = self.make(d, PIP_INDEX_URL="http://127.0.0.1:9/simple", PIP_RETRIES="0", PIP_TIMEOUT="1",
                          PIP_DISABLE_PIP_VERSION_CHECK="1")
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("installing PyYAML and jsonschema failed", r.stderr + r.stdout)
            self.assertTrue(os.path.exists(os.path.join(dest, "keep.txt")))
            self.assertEqual([n for n in os.listdir(d) if n.startswith(".wtt-test-plan.")], [])

    def test_install_refuses_a_folder_inside_the_checkout(self):
        inside = os.path.join(ROOT, "skills")
        before = sorted(os.listdir(self.SRC))
        r = self.make(inside, SKILL_NO_VENV="1")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(sorted(os.listdir(self.SRC)), before)
        self.assertTrue(os.path.exists(os.path.join(self.SRC, "SKILL.md")))


class Collect(unittest.TestCase):
    def test_sv2json_and_collect_dedupe(self):
        with tempfile.TemporaryDirectory() as d:
            sv = os.path.join(d, "src", "Account", "A", "SavedVariables")
            os.makedirs(sv)
            with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
                fh.write('CheckThatDB = {["runs"] = {["KeepThat-1"] = {["revision"] = 3, ["steps"] = {}, ["order"] = {}}}}\n')
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
            with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
                fh.write('CheckThatDB = {["runs"] = {["R-1"] = {["revision"] = 1, ["order"] = {"a"}, ["steps"] = {["a"] = {["verdict"] = "pass", ["attempts"] = {{["n"] = 1, ["started"] = 1000, ["finished"] = 1060, ["verdict"] = "pass"}}}}}}}\n')
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


class ReportAuto(unittest.TestCase):
    def run_fixture(self, **at):
        attempt = {"n": 1, "verdict": at.pop("verdict", "pass"), **at}
        return {"KeepThat-1": {"planTitle": "t", "addon": "KeepThat", "revision": 1, "client": "classic-era", "build": "1",
                               "character": "X", "order": ["a"], "steps": {"a": {"verdict": attempt["verdict"], "attempts": [attempt]}}}}

    def test_report_says_which_results_checkthat_recorded(self):
        text = wtt.report_text(self.run_fixture(by="auto"))
        self.assertIn("a: pass, recorded by CheckThat", text)
        self.assertIn("auto=1", text)

    def test_report_marks_an_automatic_failure_attempt(self):
        text = wtt.report_text(self.run_fixture(by="auto", verdict="fail"))
        self.assertIn("recorded by CheckThat", text)

    def test_open_retry_does_not_hide_the_mark(self):
        run = self.run_fixture(by="auto", verdict="unverified")
        run["KeepThat-1"]["steps"]["a"]["attempts"].append({"n": 2})   # the retry the card opens straight away
        text = wtt.report_text(run)
        self.assertIn("recorded by CheckThat", text); self.assertIn("auto=1", text)

    def test_reopened_step_is_not_marked(self):
        run = self.run_fixture(by="auto", verdict="unverified")
        run["KeepThat-1"]["steps"]["a"]["verdict"] = "pending"             # the player pressed Undo
        self.assertNotIn("recorded by CheckThat", wtt.report_text(run))

    def test_player_results_carry_no_mark(self):
        text = wtt.report_text(self.run_fixture())
        self.assertNotIn("recorded by CheckThat", text)
        self.assertNotIn("auto=", text)


if __name__ == "__main__":
    unittest.main()
