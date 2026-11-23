import json, os, re, subprocess, sys, tempfile, unittest, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ct

ROOT = ct.ROOT


def good():
    return {"ct": 1, "addon": "KeepThat", "title": "t",
            "logs": {"debug": {"global": "G", "path": "log", "format": "strings"}},
            "requirements": {"r": {"text": "r"}},
            "macros": [{"id": "m", "text": "/kt debug on\n/reload"}],
            "sections": [{"id": "s", "title": "S", "requires": ["r"], "setup": "Do this.", "clients": ["classic-era"], "steps": [
                {"id": "a.1", "title": "A", "action": {"kind": "secure-macro", "macro": "m"}, "expect": "e",
                 "verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "x"}]},
                {"id": "a.2", "title": "B", "setup": "Own.", "action": {"kind": "manual", "text": "t"}, "expect": "e", "verify": ["player"]}]}]}


class Validate(unittest.TestCase):
    def test_good(self):
        self.assertEqual(ct.validate(good()), [])

    def test_unknown_field(self):
        p = good(); p["sections"][0]["steps"][0]["bogus"] = 1
        self.assertTrue(ct.validate(p))

    def test_duplicate_id(self):
        p = good(); p["sections"][0]["steps"][1]["id"] = "a.1"
        self.assertTrue(any("duplicate" in e for e in ct.validate(p)))

    def test_unknown_action(self):
        p = good(); p["sections"][0]["steps"][1]["action"]["kind"] = "cast"
        self.assertTrue(ct.validate(p))

    def test_unresolved_requirement(self):
        p = good(); p["sections"][0]["requires"] = ["zzz"]
        self.assertTrue(any("unresolved" in e for e in ct.validate(p)))

    def test_macro_must_be_allowed(self):
        for bad in ("/run print(1)", "/cast x", "/ddt debug on", "/console scriptErrors 1\n/script x"):
            p = good(); p["macros"][0]["text"] = bad
            self.assertTrue(any("not allowed" in e for e in ct.validate(p)), bad)

    def test_screenshot_flag_must_be_boolean(self):
        p = good(); p["sections"][0]["steps"][1]["screenshot"] = True
        self.assertEqual(ct.validate(p), [])
        p["sections"][0]["steps"][1]["screenshot"] = "yes"
        self.assertTrue(ct.validate(p))

    def test_section_share_lands_on_last_step(self):
        p = good(); p["sections"][0]["share"] = "export"
        self.assertEqual(ct.validate(p), [])
        m = ct.merge_sections(p)
        self.assertEqual(m["sections"][0]["steps"][-1]["share"], "export")
        self.assertNotIn("share", m["sections"][0]["steps"][0])
        p["sections"][0]["share"] = "email"
        self.assertTrue(ct.validate(p))

    def test_runner_plans_allow_ct_and_checkthat_only(self):
        for cmd in ("/ct", "/checkthat"):
            p = good(); p["addon"] = "CheckThat"; p["macros"][0]["text"] = cmd + " debug on\n/reload"
            self.assertEqual(ct.validate(p), [], cmd)
        for cmd in ("/kt debug on", "/ct2 debug on"):
            p = good(); p["addon"] = "CheckThat"; p["macros"][0]["text"] = cmd
            self.assertTrue(ct.validate(p), cmd)

    def test_unknown_probe(self):
        p = good(); p["sections"][0]["steps"][0]["assertions"] = [{"kind": "state", "probe": "cast", "op": "eq"}]
        self.assertTrue(ct.validate(p))

    def auto(self):
        p = good(); st = p["sections"][0]["steps"][0]
        st["verify"] = ["assertions"]; st["auto"] = True
        return p, st

    def has(self, p, needle):
        errs = ct.validate(p)
        self.assertTrue(any(needle in e for e in errs), "%r not in %r" % (needle, errs))

    def test_auto_step_valid(self):
        p, st = self.auto()
        self.assertEqual(ct.validate(p), [])
        for n in (5, 30, 300):
            st["timeout"] = n
            self.assertEqual(ct.validate(p), [], n)

    def test_auto_step_needs_assertions_alone(self):
        p, st = self.auto(); st["verify"] = ["player", "assertions"]
        self.assertTrue(ct.validate(p))
        p, st = self.auto(); st["verify"] = ["reviewer"]; st["reviewer"] = "r"; del st["assertions"]
        self.assertTrue(ct.validate(p))

    def test_auto_step_needs_a_required_assertion(self):
        p, st = self.auto(); st["assertions"][0]["diagnostic"] = True
        self.assertTrue(ct.validate(p))

    def test_auto_step_rejects_required_absence(self):
        p, st = self.auto(); st["assertions"][0]["absent"] = True
        self.assertTrue(ct.validate(p))

    def test_timeout_range_and_auto_only(self):
        for n in (3, 4, 301, 600, 7.5, -1, "30"):
            p, st = self.auto(); st["timeout"] = n
            self.assertTrue(ct.validate(p), n)
        p = good(); p["sections"][0]["steps"][0]["timeout"] = 30
        self.assertTrue(ct.validate(p))

    def test_schema_alone_rejects_the_cross_field_auto_rules(self):
        import jsonschema
        with open(ct.SCHEMA, encoding="utf-8") as f:
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
        self.assertTrue(ct.validate(p))
        p, st = self.auto(); st["action"] = {"kind": "wait-event", "text": "t"}
        self.assertEqual(ct.validate(p), [])


class Compile(unittest.TestCase):
    def test_section_fields_merge_into_steps(self):
        m = ct.merge_sections(good())
        s0, s1 = m["sections"][0]["steps"]
        self.assertEqual(s0["requires"], ["r"]); self.assertEqual(s0["clients"], ["classic-era"])
        self.assertEqual(s1["setup"], "Do this. Own.")
        self.assertNotIn("requires", m["sections"][0])

    def test_round_trip_and_checksum(self):
        s = ct.encode(ct.merge_sections(good()))
        self.assertTrue(s.startswith("!CT1!"))
        self.assertEqual(ct.decode(s), ct.merge_sections(good()))
        bad = s[:6] + "00000000" + s[14:]
        with self.assertRaises(ValueError):
            ct.decode(bad)

    def test_log_none_maps_to_player_only(self):
        with tempfile.TemporaryDirectory() as d:
            md = os.path.join(d, "p.md")
            with open(md, "w") as fh:
                fh.write("# T\n\n## 1. Sec\n\n- [ ] Do it.\n  Check: it works.\n  Log: none; on screen only.\n- [ ] Type `/kt log`.\n  Check: ok.\n  Log: `[kt] started` and `[x] n=<n>`\n")
            plan = ct.from_md(md, "KeepThat")
            s = plan["sections"][0]["steps"]
            self.assertEqual(s[0]["verify"], ["player"])
            self.assertEqual(s[1]["action"]["commands"], ["/kt log"])
            self.assertEqual([a["contains"] for a in s[1]["assertions"]], ["[kt] started"])
            self.assertTrue(all(a["diagnostic"] for a in s[1]["assertions"]))
            self.assertEqual(ct.validate(plan), [])


class Plans(unittest.TestCase):
    def test_shipped_plans_validate(self):
        for n in ("keepthat", "dontdothat", "closestvendor", "selftest"):
            plan = ct.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            self.assertEqual(ct.validate(plan), [], n)
            self.assertEqual(ct.warnings(plan), [], n)


class OpenRunPlans(unittest.TestCase):
    PATHS = [os.path.join(ROOT, "plans", "checkthat-openrun.%s.yaml" % r) for r in ("owner", "viewer")]

    def test_plans_validate_and_name_their_partners(self):
        for p in self.PATHS:
            plan = ct.load_yaml(p)
            self.assertEqual(ct.validate(plan), [], p)
            self.assertEqual(ct.warnings(plan), [], p)
        self.assertEqual(PlanSkill.partner_problems(self.PATHS), [])

    def test_every_step_has_one_action_and_no_step_asks_for_another_character(self):
        for p in self.PATHS:
            for sec in ct.load_yaml(p)["sections"]:
                for s in sec["steps"]:
                    self.assertEqual(len(s["action"].get("commands") or []) <= 1, True, s["id"])
                    self.assertNotIn("log in", s["action"].get("text", "").lower(), s["id"])


class NativeText(unittest.TestCase):
    def test_markdown_is_converted_to_native_codes_and_rejected_if_left(self):
        p = good()
        st = p["sections"][0]["steps"][1]
        st["action"]["text"] = "Type `/kt log` and press **Pass**."
        st["title"] = "Run `/kt log`"
        self.assertTrue(any("markdown" in e for e in ct.validate(p)))
        ct.nativize(p)
        self.assertEqual(st["action"]["text"], "Type |cff99ccff/kt log|r and press |cffffd100Pass|r.")
        self.assertEqual(st["title"], "Run /kt log")
        self.assertEqual(ct.validate(p), [])

    def test_shipped_plans_have_no_markdown(self):
        import glob
        for path in glob.glob(os.path.join(ROOT, "plans", "**", "*.yaml"), recursive=True):
            d = ct.load_yaml(path)
            for box, key, _ in ct.display_fields(d):
                self.assertNotRegex(box[key], r"`|\*\*", path + " " + key)


class SamplePlans(unittest.TestCase):
    def test_sample_plans_stay_short_and_full_plans_stay_valid(self):
        import glob
        for n in ("keepthat", "dontdothat", "closestvendor", "selftest"):
            plan = ct.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            steps = sum(len(s["steps"]) for s in plan["sections"])
            self.assertLessEqual(steps, 8, n)
        for path in glob.glob(os.path.join(ROOT, "plans", "full", "*.yaml")):
            plan = ct.load_yaml(path)
            self.assertEqual(ct.validate(plan), [], path)
            self.assertEqual(ct.warnings(plan), [], path)


class PlanSkill(unittest.TestCase):
    SKILL = os.path.join(ROOT, "skills", "ct-test-plan")

    missing_commands = staticmethod(ct.warnings)

    def test_example_plan_validates_and_lists_named_commands(self):
        plan = ct.load_yaml(os.path.join(self.SKILL, "example.yaml"))
        self.assertEqual(ct.validate(plan), [])
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
                rc = ct.main(["validate", p])
        self.assertEqual(rc, 0)
        self.assertIn("warning: a.2: command named in text but not in commands: /kt debug on", out.getvalue())

    @staticmethod
    def partner_problems(paths):
        """Each preamble names every partner file. Some reviewer line of the set names each plan with one of its step ids."""
        plans = {os.path.basename(p): ct.load_yaml(p) for p in paths}
        steps = lambda plan: [s for sec in plan["sections"] for s in sec["steps"]]
        out = []
        for name, plan in plans.items():
            for other in plans:
                if other != name and other not in (plan.get("preamble") or ""):
                    out.append("%s: preamble does not name %s" % (name, other))
        def completes(name):
            rev = [s.get("reviewer") or "" for s in steps(plans[name])]
            return all(any(o in r and any(s["id"] in r for s in steps(plans[o])) for r in rev) for o in plans if o != name)
        if len(plans) > 1 and not any(completes(n) for n in plans):
            out.append("no plan has reviewer lines that name every partner file with a step id")
        return out

    def example_set(self):
        return [os.path.join(self.SKILL, n) for n in ("keepthat-tally.bank.yaml", "keepthat-tally.alt.yaml")]

    def test_example_plan_set_validates_and_names_its_partners(self):
        for p in self.example_set():
            self.assertEqual(ct.validate(ct.load_yaml(p)), [], p)
        self.assertEqual(self.partner_problems(self.example_set()), [])

    def test_partner_check_fails_when_a_reference_is_missing(self):
        import yaml
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for p in self.example_set():
                plan = ct.load_yaml(p)
                paths.append(os.path.join(d, os.path.basename(p)))
                with open(paths[-1], "w") as f:
                    yaml.safe_dump(plan, f)
            plan = ct.load_yaml(paths[0]); plan["preamble"] = "No partner named."
            with open(paths[0], "w") as f:
                yaml.safe_dump(plan, f)
            self.assertIn("%s: preamble does not name keepthat-tally.alt.yaml" % os.path.basename(paths[0]), self.partner_problems(paths))
            for p in paths:
                plan = ct.load_yaml(p)
                plan["sections"][0]["steps"][1]["reviewer"] = "Compare the totals."
                with open(p, "w") as f:
                    yaml.safe_dump(plan, f)
            self.assertTrue(any("no plan has reviewer lines" in x for x in self.partner_problems(paths)))

    def test_skill_states_the_interview_and_draft_rules(self):
        with open(os.path.join(self.SKILL, "SKILL.md"), encoding="utf-8") as f:
            text = f.read()
        for rule in ("**one question per turn**", "Skip a question when the OpenSpec change", "Simple steps by default", "Compound step, drafted on request",
                     "one plan for each character role", "<name>.<role>.yaml", "A rejected new step stays out", "ct-verify"):
            self.assertIn(rule, text)

    def test_skill_points_at_files_that_exist(self):
        def read(name):
            with open(os.path.join(self.SKILL, name), encoding="utf-8") as f:
                return f.read()
        text = read("SKILL.md")
        for rel in ("tools/ct.py", "schema/test-plan.schema.json", "docs/test-plan.md", "docs/debug-logging.md",
                    "openspec/specs/test-plan-format/spec.md", "CheckThat/Model/Plan.lua"):
            self.assertIn(rel, text + read("reference.md"))
            self.assertTrue(os.path.exists(os.path.join(ROOT, rel)), rel)
        for name in ("reference.md", "example.yaml"):
            self.assertIn(name, text)
            self.assertTrue(os.path.exists(os.path.join(self.SKILL, name)), name)


class InstallSkill(unittest.TestCase):
    SRC = os.path.join(ROOT, "skills", "ct-test-plan")
    BUNDLE = ("tools/ct.py", "schema/test-plan.schema.json", "docs/test-plan.md", "docs/debug-logging.md",
              "openspec/specs/test-plan-format/spec.md", "CheckThat/Model/Plan.lua", "CheckThat/Model/Json.lua", "tools/sv2json.lua",
              "requirements.txt")
    VERIFY = os.path.join(ROOT, "skills", "ct-verify")

    def make(self, dest, **env):
        return subprocess.run(["make", "install-skill", "SKILL_DIR=" + dest], cwd=ROOT, capture_output=True, text=True,
                              env=dict(os.environ, **env))

    def test_install_copies_skill_and_bundle_and_replaces_stale_copy(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "ct-test-plan")
            os.makedirs(dest)
            with open(os.path.join(dest, "stale.txt"), "w") as f:
                f.write("old")
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            self.assertFalse(os.path.exists(os.path.join(dest, "stale.txt")))
            self.assertFalse(os.path.exists(os.path.join(dest, ".ct-root")))
            for name in os.listdir(self.SRC):
                with open(os.path.join(self.SRC, name), "rb") as a, open(os.path.join(dest, name), "rb") as b:
                    self.assertEqual(a.read(), b.read(), name)
            for rel in self.BUNDLE:
                with open(os.path.join(ROOT, rel), "rb") as a, open(os.path.join(dest, "ct", rel), "rb") as b:
                    self.assertEqual(a.read(), b.read(), rel)
            with open(os.path.join(ROOT, "CheckThat", "CheckThat_Vanilla.toc"), encoding="utf-8") as f:
                version = re.search(r"^## Version:\s*(\S+)", f.read(), re.M).group(1)
            with open(os.path.join(dest, "ct", "VERSION"), encoding="utf-8") as f:
                self.assertEqual(f.read().strip(), version)
            self.assertEqual([n for n in os.listdir(d) if n.startswith(".ct-test-plan.") or n.startswith(".ct-verify.")], [])
            for name in os.listdir(self.VERIFY):
                with open(os.path.join(self.VERIFY, name), "rb") as a, open(os.path.join(d, "ct-verify", name), "rb") as b:
                    self.assertEqual(a.read(), b.read(), name)

    def write_sv(self, root, body):
        sv = os.path.join(root, "src", "Account", "A", "SavedVariables"); os.makedirs(sv, exist_ok=True)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write(body)
        return os.path.join(root, "src")

    def installed_collect(self, d, sib, body):
        tool = os.path.join(d, "ct-test-plan", "ct", "tools", "ct.py")
        dest = os.path.join(sib, "evidence")
        r = subprocess.run([sys.executable, tool, "collect", "--src", self.write_sv(sib, body), "--dest", dest],
                           capture_output=True, text=True, cwd=sib)
        return r, dest

    RUN = 'CheckThatDB = {["runs"] = {["KeepThat-1"] = {["revision"] = 3, ["steps"] = {["a.1"] = {["verdict"] = "pass"}}, ["order"] = {"a.1"}}}}\n'

    def test_installed_collect_decodes_from_a_sibling_directory(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            sib = os.path.join(d, "sibling"); os.makedirs(sib)
            r, dest = self.installed_collect(d, sib, self.RUN)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            with open(os.path.join(dest, "runs", "KeepThat-1", "r3.json")) as fh:
                run = json.load(fh)
            self.assertEqual(run["revision"], 3)
            self.assertEqual(run["steps"]["a.1"]["verdict"], "pass")
            self.assertFalse(os.path.exists(os.path.join(d, "ct-test-plan", "ct", "evidence")), "evidence stays outside the bundle")
            r2, _ = self.installed_collect(d, sib, self.RUN)
            self.assertEqual(r2.returncode, 0, "the same revision again is not a failure")
            self.assertIn("0 new run revisions", r2.stdout)

    def test_installed_collect_reports_a_decode_failure(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            sib = os.path.join(d, "sibling"); os.makedirs(sib)
            r, dest = self.installed_collect(d, sib, "CheckThatDB = {\n")
            self.assertEqual(r.returncode, 1)
            self.assertIn("could not decode", r.stderr)

    def test_installed_tools_run_without_the_checkout(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            dest = os.path.join(d, "ct-test-plan")
            r = subprocess.run([sys.executable, os.path.join(dest, "ct", "tools", "ct.py"), "validate",
                                os.path.join(dest, "example.yaml")], capture_output=True, text=True, cwd=d)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ok", r.stdout)

    def test_failed_dependency_install_keeps_the_earlier_copy(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "ct-test-plan")
            os.makedirs(dest)
            with open(os.path.join(dest, "keep.txt"), "w") as f:
                f.write("old")
            r = self.make(d, PIP_INDEX_URL="http://127.0.0.1:9/simple", PIP_RETRIES="0", PIP_TIMEOUT="1",
                          PIP_DISABLE_PIP_VERSION_CHECK="1")
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("installing PyYAML and jsonschema failed", r.stderr + r.stdout)
            self.assertTrue(os.path.exists(os.path.join(dest, "keep.txt")))
            self.assertEqual([n for n in os.listdir(d) if n.startswith(".ct-test-plan.")], [])

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
            ct.cmd_collect(args); ct.cmd_collect(args)
            self.assertEqual(len(os.listdir(os.path.join(dest, "sv"))), 2)
            self.assertEqual(os.listdir(os.path.join(dest, "runs", "KeepThat-1")), ["r3.json"])
            self.assertIn("KeepThat-1", ct.report_text(ct.latest_runs(dest)))

    def collect_body(self, body):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write(body)
        return type("A", (), {"src": os.path.join(d, "src"), "dest": os.path.join(d, "dest"), "shots": None})

    def test_malformed_saved_variables_report_a_decode_failure(self):
        self.assertEqual(ct.cmd_collect(self.collect_body("CheckThatDB = {\n")), 1)

    def test_empty_database_and_a_repeat_collect_are_not_failures(self):
        self.assertEqual(ct.cmd_collect(self.collect_body("CheckThatDB = {}\n")), 0)
        a = self.collect_body('CheckThatDB = {["runs"] = {["R-1"] = {["revision"] = 1, ["steps"] = {}, ["order"] = {}}}}\n')
        self.assertEqual(ct.cmd_collect(a), 0)
        self.assertEqual(ct.cmd_collect(a), 0)

    def test_wow_folder_collects_each_client(self):
        with tempfile.TemporaryDirectory() as d:
            for c, rev in (("_classic_era_", 1), ("_forever_", 2)):
                sv = os.path.join(d, "wow", c, "WTF", "Account", "A", "SavedVariables"); os.makedirs(sv)
                with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
                    fh.write('CheckThatDB = {["runs"] = {["R-%d"] = {["revision"] = %d, ["steps"] = {}, ["order"] = {}}}}\n' % (rev, rev))
            os.makedirs(os.path.join(d, "wow", "_retail_", "WTF", "Account", "A", "SavedVariables"))
            dest = os.path.join(d, "dest")
            args = type("A", (), {"src": None, "wow": os.path.join(d, "wow"), "dest": dest, "shots": None})
            ct.cmd_collect(args)
            self.assertEqual(sorted(os.listdir(os.path.join(dest, "runs"))), ["R-1", "R-2"])
            self.assertEqual(len(os.listdir(os.path.join(dest, "sv"))), 2)
            args.wow = os.path.join(d, "nothing")
            with self.assertRaises(SystemExit):
                ct.cmd_collect(args)

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
            ct.cmd_collect(args); ct.cmd_collect(args)
            self.assertEqual(os.listdir(os.path.join(dest, "runs", "R-1", "shots")), ["a__in.jpg"])
            self.assertIn("screenshots: a__in.jpg", ct.report_text(ct.latest_runs(dest), dest))


class VerifySkill(unittest.TestCase):
    SKILL = os.path.join(ROOT, "skills", "ct-verify")

    def test_skill_names_the_commands_and_fields_the_tools_and_runs_have(self):
        with open(os.path.join(self.SKILL, "SKILL.md"), encoding="utf-8") as f:
            text = f.read()
        self.assertTrue(text.startswith("---\nname: ct-verify\n"))
        for rel in ("tools/ct.py", "tools/sv2json.lua", "CheckThat/Model/Json.lua", "CheckThat/Model/Plan.lua"):
            self.assertIn(rel, text)
            self.assertTrue(os.path.exists(os.path.join(ROOT, rel)), rel)
        for word in ("collect", "import-results", "sv2json", "compile", "--dest", "planDigest", "planStore", "claimed", "outcomes",
                     "contradicted", "unverified", "reviewer", "ct-test-plan/ct"):
            self.assertIn(word, text)
        with open(os.path.join(ROOT, "tools", "ct.py"), encoding="utf-8") as f:
            src = f.read()
        for cmd in ("collect", "import-results", "sv2json", "compile"):
            self.assertIn('add_parser("%s")' % cmd, src)


class BuildPlugin(unittest.TestCase):
    def build(self, d):
        return subprocess.run(["make", "build-plugin", "PLUGIN_DIR=" + os.path.join(d, "plugin")], cwd=ROOT, capture_output=True, text=True)

    def test_plugin_holds_the_manifest_skills_and_tools(self):
        with tempfile.TemporaryDirectory() as d:
            r = self.build(d)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            p = os.path.join(d, "plugin")
            with open(os.path.join(p, ".claude-plugin", "plugin.json")) as f:
                manifest = json.load(f)
            with open(os.path.join(ROOT, "CheckThat", "CheckThat_Vanilla.toc"), encoding="utf-8") as f:
                version = re.search(r"^## Version:\s*(\S+)", f.read(), re.M).group(1)
            self.assertEqual((manifest["name"], manifest["version"]), ("checkthat", version))
            for src, dst in (("ct-test-plan", "plan"), ("ct-verify", "verify")):
                with open(os.path.join(p, "skills", dst, "SKILL.md"), encoding="utf-8") as a, open(os.path.join(ROOT, "skills", src, "SKILL.md"), encoding="utf-8") as b:
                    want = b.read().replace("ct-test-plan", "plan").replace("ct-verify", "verify")
                    got = a.read()
                self.assertEqual(got, want, dst)
                self.assertTrue(got.startswith("---\nname: %s\n" % dst), dst)
                self.assertNotIn("ct-test-plan", got); self.assertNotIn("ct-verify", got)
                self.assertTrue(os.path.exists(os.path.join(p, "skills", dst, "ct")) == (dst == "plan"))
            with open(os.path.join(p, "skills", "verify", "SKILL.md"), encoding="utf-8") as f:
                self.assertIn("../plan/ct", f.read())
            ctdir = os.path.join(p, "skills", "plan", "ct")
            for rel in InstallSkill.BUNDLE:
                self.assertTrue(os.path.exists(os.path.join(ctdir, rel)), rel)
            with open(os.path.join(ctdir, "VERSION")) as f:
                self.assertEqual(f.read().strip(), version)
            self.assertFalse(os.path.exists(os.path.join(p, "skills", "plan", ".venv")))

    def test_claude_validates_the_plugin(self):
        import shutil
        if not shutil.which("claude"):
            self.skipTest("claude is not installed")
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.build(d).returncode, 0)
            r = subprocess.run(["claude", "plugin", "validate", os.path.join(d, "plugin")], capture_output=True, text=True, timeout=120)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_collect_runs_from_a_copy_of_the_built_plugin(self):
        import shutil, verify_fixture
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.build(d).returncode, 0)
            copy = os.path.join(d, "elsewhere", "plugin")
            shutil.copytree(os.path.join(d, "plugin"), copy)
            sib = os.path.join(d, "sibling"); os.makedirs(sib)
            verify_fixture.build(sib)
            tool = os.path.join(copy, "skills", "plan", "ct", "tools", "ct.py")
            r = subprocess.run([sys.executable, tool, "collect", "--src", os.path.join(sib, "src"), "--dest", os.path.join(sib, "evidence")],
                               capture_output=True, text=True, cwd=sib)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertTrue(os.path.exists(os.path.join(sib, "evidence", "runs", "Fx-1", "r2.json")))

    def test_skills_state_the_python_fallback(self):
        for skill in ("ct-test-plan", "ct-verify"):
            with open(os.path.join(ROOT, "skills", skill, "SKILL.md"), encoding="utf-8") as f:
                text = f.read()
            for needle in ('python3 -c "import yaml, jsonschema"', "python3 -m venv", "pip install -r"):
                self.assertIn(needle, text, skill)


class ReadmeSkills(unittest.TestCase):
    def test_readme_tells_how_to_install_both_skills_for_each_agent(self):
        text = ""
        for name in ("README.md", os.path.join("docs", "skills.md")):
            with open(os.path.join(ROOT, name), encoding="utf-8") as f:
                text += f.read()
        for needle in ("make install-skill", "SKILL_DIR=~/.codex/skills", "~/.claude/skills", "ct-test-plan", "ct-verify", "luajit",
                       "<name>.<role>.yaml", "outside the checkout"):
            self.assertIn(needle, text)


class VerifyFixture(unittest.TestCase):
    def test_fixture_collects_with_the_known_answers(self):
        import verify_fixture
        with tempfile.TemporaryDirectory() as d:
            verify_fixture.build(d, ambiguous=True)
            dest = os.path.join(d, "evidence")
            self.assertEqual(ct.cmd_collect(type("A", (), {"src": os.path.join(d, "src"), "dest": dest, "shots": None})), 0)
            runs = ct.latest_runs(dest)
            self.assertEqual(sorted(runs), ["Alt-1", "Bank-1", "Bank-2", "Fx-1"])
            fx = runs["Fx-1"]["steps"]
            last = lambda sid: fx[sid]["attempts"][-1]
            self.assertEqual((last("fx.1")["claimed"], last("fx.1")["outcomes"][0]["result"]), ("pass", "fail"))
            self.assertEqual(last("fx.2")["outcomes"][0]["result"], "unverified")
            self.assertTrue(last("fx.3")["outcomes"][0]["diagnostic"])
            self.assertEqual(runs["Bank-1"]["planDigest"], runs["Bank-2"]["planDigest"])
            self.assertNotEqual(runs["Bank-1"]["planDigest"], runs["Alt-1"]["planDigest"])
            for p in ("keepthat-tally.bank.yaml", "keepthat-tally.alt.yaml", "fixture.yaml"):
                self.assertEqual(ct.validate(ct.load_yaml(os.path.join(d, "plans", p))), [], p)


class LoadEnv(unittest.TestCase):
    def test_file_fills_unset_variables_only(self):
        with tempfile.TemporaryDirectory() as d:
            first, second = os.path.join(d, "a.env"), os.path.join(d, "b.env")
            with open(first, "w") as fh:
                fh.write('# paths\nCT_T_ONE=/one\nexport CT_T_TWO="~/two"\nCT_T_SET=file\n')
            with open(second, "w") as fh:
                fh.write("CT_T_ONE=/other\nCT_T_THREE=3\n")
            for k in ("CT_T_ONE", "CT_T_TWO", "CT_T_THREE"):
                os.environ.pop(k, None)
            os.environ["CT_T_SET"] = "real"
            try:
                ct.load_env([first, os.path.join(d, "missing.env"), second])
                self.assertEqual(os.environ["CT_T_ONE"], "/one")
                self.assertEqual(os.environ["CT_T_TWO"], os.path.expanduser("~/two"))
                self.assertEqual(os.environ["CT_T_THREE"], "3")
                self.assertEqual(os.environ["CT_T_SET"], "real")
            finally:
                for k in ("CT_T_ONE", "CT_T_TWO", "CT_T_THREE", "CT_T_SET"):
                    os.environ.pop(k, None)


class PackageRoot(unittest.TestCase):
    def test_no_script_at_the_top_of_the_repository(self):
        # The packager ships every top-level file that .pkgmeta does not ignore, so a script here lands in the addon folder.
        found = [n for n in os.listdir(ct.ROOT) if n.lower().endswith((".bat", ".cmd", ".ps1", ".sh", ".exe"))]
        self.assertEqual(found, [])


class Safety(unittest.TestCase):
    def test_run_ids_cannot_leave_the_runs_folder(self):
        with tempfile.TemporaryDirectory() as d:
            run = {"runId": "../../evil", "revision": 1, "steps": {}}
            ct.write_revision(d, run)
            self.assertFalse(os.path.exists(os.path.join(d, "evil")))
            self.assertFalse(os.path.exists(os.path.join(os.path.dirname(d), "evil")))
            self.assertTrue(any(f.startswith("r1") for _, _, fs in os.walk(os.path.join(d, "runs")) for f in fs))

    def test_a_different_run_with_the_same_id_and_revision_is_a_conflict(self):
        with tempfile.TemporaryDirectory() as d:
            a = {"runId": "R-1", "revision": 2, "steps": {"x": {"verdict": "pass"}}}
            self.assertEqual(ct.write_revision(d, a), "new")
            self.assertEqual(ct.write_revision(d, dict(a)), "same")
            b = {"runId": "R-1", "revision": 2, "steps": {"x": {"verdict": "fail"}}}
            self.assertEqual(ct.write_revision(d, b), "conflict")
            with open(os.path.join(d, "runs", "R-1", "r2.json")) as fh:
                self.assertEqual(json.load(fh)["steps"]["x"]["verdict"], "pass", "the first copy is kept")

    def test_decode_stops_a_zip_bomb(self):
        raw = b"\0" * (ct.MAX_INFLATED + 10)
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        packed = c.compress(raw) + c.flush()
        import base64
        s = "!CT1!%08x!%s" % (zlib.adler32(raw) & 0xFFFFFFFF, base64.b64encode(packed).decode())
        with self.assertRaises(ValueError):
            ct.decode(s)

    def test_title_and_requirement_text_are_checked_for_markdown(self):
        p = good(); p["title"] = "Run `x`"; p["requirements"]["r"]["text"] = "needs **it**"
        self.assertTrue(any("markdown" in e for e in ct.validate(p)))
        ct.nativize(p)
        self.assertNotIn("`", p["title"]); self.assertNotIn("**", p["requirements"]["r"]["text"])


class ReportAuto(unittest.TestCase):
    def run_fixture(self, **at):
        attempt = {"n": 1, "verdict": at.pop("verdict", "pass"), **at}
        return {"KeepThat-1": {"planTitle": "t", "addon": "KeepThat", "revision": 1, "client": "classic-era", "build": "1",
                               "character": "X", "order": ["a"], "steps": {"a": {"verdict": attempt["verdict"], "attempts": [attempt]}}}}

    def test_report_says_which_results_checkthat_recorded(self):
        text = ct.report_text(self.run_fixture(by="auto"))
        self.assertIn("a: pass, recorded by CheckThat", text)
        self.assertIn("auto=1", text)

    def test_report_marks_an_automatic_failure_attempt(self):
        text = ct.report_text(self.run_fixture(by="auto", verdict="fail"))
        self.assertIn("recorded by CheckThat", text)

    def test_open_retry_does_not_hide_the_mark(self):
        run = self.run_fixture(by="auto", verdict="unverified")
        run["KeepThat-1"]["steps"]["a"]["attempts"].append({"n": 2})   # the retry the card opens straight away
        text = ct.report_text(run)
        self.assertIn("recorded by CheckThat", text); self.assertIn("auto=1", text)

    def test_reopened_step_is_not_marked(self):
        run = self.run_fixture(by="auto", verdict="unverified")
        run["KeepThat-1"]["steps"]["a"]["verdict"] = "pending"             # the player pressed Undo
        self.assertNotIn("recorded by CheckThat", ct.report_text(run))

    def test_player_results_carry_no_mark(self):
        text = ct.report_text(self.run_fixture())
        self.assertNotIn("recorded by CheckThat", text)
        self.assertNotIn("auto=", text)


class ReportTable(unittest.TestCase):
    def table(self, steps, order=None):
        run = {"R-1": {"planTitle": "t", "addon": "KeepThat", "revision": 1, "client": "c", "build": "1", "character": "X",
                       "order": order or list(steps), "steps": steps}}
        text = ct.report_text(run)
        return [ln for ln in text.splitlines() if ln.split()[:1] and ln.split()[0] in steps or ln.startswith("step ")]

    def rows(self, steps):
        return {ln.split()[0]: ln.split() for ln in self.table(steps)[1:] if "attempt " not in ln}

    def att(self, verdict, outcomes=None, note=None):
        a = {"n": 1, "verdict": verdict}
        if outcomes is not None:
            a["outcomes"] = [{"result": r} for r in outcomes]
        if note:
            a["note"] = note
        return a

    def test_every_step_has_a_row_with_its_evidence_state(self):
        steps = {
            "p": {"verdict": "pass", "attempts": [self.att("pass", ["pass", "pass"])]},
            "q": {"verdict": "pass", "attempts": [self.att("pass")]},
            "f": {"verdict": "fail", "attempts": [self.att("fail", ["fail"], "broke"), self.att("fail", ["pass", "fail"])]},
            "u": {"verdict": "unverified", "attempts": [self.att("unverified", ["pass", "unverified"])]},
            "s": {"verdict": "skip", "attempts": [self.att("skip")]},
            "i": {"verdict": "inapplicable", "attempts": []},
            "w": {"verdict": "pending", "attempts": []},
        }
        rows = self.rows(steps)
        self.assertEqual(rows["p"][:4], ["p", "pass", "met", "1"])
        self.assertEqual(rows["q"][:4], ["q", "pass", "none", "1"], "a click-only pass shows no evidence")
        self.assertEqual(rows["f"][:4], ["f", "fail", "bad", "2"])
        self.assertEqual(rows["u"][:4], ["u", "unverified", "missing", "1"])
        self.assertEqual(rows["s"][:4], ["s", "skip", "none", "1"])
        self.assertEqual(rows["i"][:4], ["i", "inapplicable", "none", "0"])
        self.assertEqual(rows["w"][:4], ["w", "pending", "none", "0"])

    def test_a_step_the_client_does_not_use_still_has_a_row(self):
        steps = {"a": {"verdict": "pass", "attempts": [self.att("pass", ["pass"])]}, "z": {"verdict": "inapplicable", "attempts": []}}
        run = {"R-1": {"planTitle": "t", "addon": "K", "revision": 1, "order": ["a"], "steps": steps}}
        rows = [ln.split() for ln in ct.report_text(run).splitlines() if ln.startswith("z ")]
        self.assertEqual(rows[0][:3], ["z", "inapplicable", "none"])

    def test_a_run_without_order_lists_its_steps(self):
        run = {"R-1": {"planTitle": "t", "addon": "K", "revision": 1, "steps": {"s": {"verdict": "pass", "attempts": []}}}}
        self.assertTrue(any(ln.startswith("s ") for ln in ct.report_text(run).splitlines()))

    def test_an_order_naming_a_missing_step_does_not_stop_the_report(self):
        run = {"R-1": {"planTitle": "t", "addon": "K", "revision": 1, "order": ["s"], "steps": {}}}
        self.assertTrue(any(ln.startswith("s ") for ln in ct.report_text(run).splitlines()))

    def test_an_outcome_without_a_result_is_not_evidence(self):
        a = {"n": 1, "verdict": "pass", "outcomes": [{}]}
        self.assertEqual(self.rows({"m": {"verdict": "pass", "attempts": [a]}})["m"][2], "missing")

    def test_a_unicode_line_break_in_a_note_does_not_split_the_row(self):
        note = "one" + chr(0x2028) + "two" + chr(0x85) + "three\r\nfour"
        steps = {"u": {"verdict": "pass", "attempts": [self.att("pass", ["pass"], note)]}}
        text = ct.report_text({"R-1": {"planTitle": "t", "addon": "K", "revision": 1, "order": ["u"], "steps": steps}})
        rows = [ln for ln in text.splitlines() if ln.startswith("u ")]
        self.assertEqual(len(rows), 1); self.assertIn("one two three four", rows[0])

    def test_diagnostic_checks_do_not_count_as_evidence(self):
        a = {"n": 1, "verdict": "pass", "outcomes": [{"result": "unverified", "diagnostic": True}]}
        self.assertEqual(self.rows({"d": {"verdict": "pass", "attempts": [a]}})["d"][2], "none")

    def test_the_note_shows_and_a_long_one_is_cut(self):
        steps = {"n": {"verdict": "pass", "attempts": [self.att("pass", ["pass"], "x" * 80)]}}
        row = [ln for ln in self.table(steps) if ln.startswith("n ")][0]
        self.assertIn("x" * 37 + "...", row); self.assertNotIn("x" * 38, row)

    def test_passing_steps_get_no_detail_lines_and_failing_ones_keep_theirs(self):
        steps = {"p": {"verdict": "pass", "attempts": [self.att("pass", ["pass"])]},
                 "f": {"verdict": "fail", "attempts": [self.att("fail", ["fail"], "broke")]}}
        text = ct.report_text({"R-1": {"planTitle": "t", "addon": "K", "revision": 1, "order": ["p", "f"], "steps": steps}})
        self.assertIn("- f: fail", text); self.assertIn("attempt 1: fail note=broke", text)
        self.assertNotIn("- p:", text)


class Names(unittest.TestCase):
    """The old names are gone. Archived changes, vendored libraries and past changelog entries keep them as history."""
    OLD = re.compile("|".join(["w" + "tt", "Test" + "That"]), re.I)   # built from pieces so this file does not match itself
    SKIP = ("openspec/changes/archive/", "CheckThat/Libs/", "CHANGELOG.md")

    def test_no_tracked_file_uses_an_old_name(self):
        out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True).stdout
        found = []
        for rel in out.decode().split("\0"):
            if not rel or rel.startswith(self.SKIP) or rel == "CHANGELOG.md":
                continue
            if self.OLD.search(rel):
                found.append(rel)
                continue
            try:
                with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
                    for n, line in enumerate(fh, 1):
                        if self.OLD.search(line):
                            found.append("%s:%d" % (rel, n)); break
            except (UnicodeDecodeError, FileNotFoundError):
                continue
        self.assertEqual(found, [])


if __name__ == "__main__":
    unittest.main()
