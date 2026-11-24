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

    def test_auto_step_with_a_check_that_something_did_not_happen_needs_a_timeout(self):
        for mut in (lambda a: a.update(absent=True), lambda a: a.update(count={"exactly": 2}), lambda a: a.update(count={"max": 2})):
            p, st = self.auto(); mut(st["assertions"][0])
            self.assertTrue(any("needs a timeout for a check that is judged at the end" in e for e in ct.validate(p)))
            st["timeout"] = 30
            self.assertEqual(ct.validate(p), [])
        p, st = self.auto(); st["assertions"][0]["count"] = {"min": 2}
        self.assertEqual(ct.validate(p), [], "a lower bound needs no timeout")

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
        self.assertEqual(errs(lambda st: st["assertions"][0].update(absent=True)), [], "the schema leaves the timeout rule to the tool")
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
        for n in ("keepthat", "dontdothat", "closestvendor"):
            plan = ct.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            steps = sum(len(s["steps"]) for s in plan["sections"])
            self.assertLessEqual(steps, 8, n)
        # The self-test is the runner's own plan, not an addon sample: it exercises every kind of check.
        plan = ct.load_yaml(os.path.join(ROOT, "plans", "selftest.yaml"))
        self.assertLessEqual(sum(len(s["steps"]) for s in plan["sections"]), 16)
        for path in glob.glob(os.path.join(ROOT, "plans", "full", "*.yaml")):
            plan = ct.load_yaml(path)
            self.assertEqual(ct.validate(plan), [], path)
            self.assertEqual(ct.warnings(plan), [], path)


class LogCaps(unittest.TestCase):
    """Every plan for an addon declares the cap of the addon's own debug log (docs/contracts.md names the source line)."""
    def test_plans_declare_the_cap_the_tool_knows(self):
        import glob
        for addon, logs in ct.LOGS.items():
            self.assertIsInstance(logs["debug"].get("cap"), int, addon)
        paths = glob.glob(os.path.join(ROOT, "plans", "*.yaml")) + glob.glob(os.path.join(ROOT, "plans", "full", "*.yaml"))
        checked = 0
        for path in paths:
            plan = ct.load_yaml(path)
            known = ct.LOGS.get(plan.get("addon"), {}).get("debug")
            declared = (plan.get("logs") or {}).get("debug")
            if known and declared and declared.get("global") == known["global"]:
                self.assertEqual(declared.get("cap"), known["cap"], path)
                checked += 1
        self.assertGreaterEqual(checked, 7)


class NamedTools(unittest.TestCase):
    """Player docs name only addons CheckThat works with (docs/contracts.md may record what a test machine had)."""
    def test_docs_name_no_unrelated_tool(self):
        import glob
        files = [os.path.join(ROOT, "README.md")] + [p for p in glob.glob(os.path.join(ROOT, "docs", "*.md")) if not p.endswith("contracts.md")]
        for path in files:
            with open(path, encoding="utf-8") as f:
                hit = re.search(r"wowunit|wowless|wowbench|alluneve", f.read(), re.I)
            self.assertIsNone(hit, f"{path} names {hit and hit.group(0)}")


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

    def test_skill_and_guide_offer_facts_and_the_source_validates(self):
        def read(*parts):
            with open(os.path.join(*parts), encoding="utf-8") as f:
                return f.read()
        skill, guide = read(self.SKILL, "SKILL.md"), read(ROOT, "docs", "debug-logging.md")
        self.assertIn("CheckThat.Report", skill)
        self.assertIn("## Publish a fact", guide)
        self.assertIn("CheckThat.Report", guide)
        plan = ct.load_yaml(os.path.join(self.SKILL, "example.yaml"))
        plan["logs"]["facts"] = {"global": "CheckThatDB", "path": "global.facts", "format": "strings"}
        step = plan["sections"][0]["steps"][0]
        step["assertions"] = [{"kind": "log", "source": "facts", "equals": "[KeepThat] freeSlots=3"}]
        self.assertEqual(ct.validate(plan), [])

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
              "requirements.txt", "tools/ct_tui.py", "requirements-tui.txt")
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
            v = subprocess.run([sys.executable, os.path.join(dest, "ct", "tools", "ct_tui.py")], capture_output=True, text=True, cwd=d)   # no terminal, no Textual needed
            self.assertEqual(v.returncode, 2, v.stdout + v.stderr)
            self.assertIn("needs a terminal", v.stderr)

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

    def test_report_lists_the_log_lines_kept_with_a_failed_attempt(self):
        text = ct.report_text(self.run_fixture(verdict="fail", excerpt={"debug": ["one", "two"]}))
        self.assertIn("log debug, 2 new lines:", text)
        self.assertIn("      one\n      two", text)
        self.assertNotIn("new line", ct.report_text(self.run_fixture(verdict="fail")))

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

    def test_a_reopened_step_shows_no_old_note_or_evidence(self):
        steps = {"r": {"verdict": "pending", "attempts": [self.att("fail", ["fail"], "broke")]}}
        row = self.rows(steps)["r"]
        self.assertEqual(row[:4], ["r", "pending", "none", "1"]); self.assertEqual(row[4:], ["awaiting", "retry"])

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



def cats():
    p = good()
    p["categories"] = [{"id": "one", "title": "One"}, {"id": "two", "title": "Two"}]
    p["sections"][0]["category"] = "one"
    p["sections"][0]["steps"][1]["category"] = "two"
    return p


def fact(**kw):
    a = {"kind": "fact", "source": "debug", "addon": "KeepThat", "key": "level", "op": "eq", "value": 3}
    a.update(kw)
    return a


class Categories(unittest.TestCase):
    def test_declared_categories_validate_and_merge(self):
        p = cats()
        self.assertEqual(ct.validate(p), [])
        m = ct.merge_sections(p)
        steps = m["sections"][0]["steps"]
        self.assertEqual([s["category"] for s in steps], ["one", "two"])
        self.assertNotIn("category", m["sections"][0])
        self.assertEqual(len(m["categories"]), 2)

    def test_failed_is_reserved_for_rerun(self):
        p = cats(); p["categories"][0]["id"] = "failed"
        self.assertTrue(any("category id failed is reserved" in e for e in ct.validate(p)))
        p = good(); p["sections"][0]["id"] = "failed"
        self.assertTrue(any("section id failed is reserved" in e for e in ct.validate(p)))

    def test_unknown_and_missing_category(self):
        p = cats(); p["sections"][0]["steps"][0]["category"] = "nope"
        self.assertTrue(any("a.1: unknown category nope" in e for e in ct.validate(p)))
        p = cats(); del p["sections"][0]["category"]; p["sections"][0]["steps"][1].pop("category")
        self.assertTrue(any("no category" in e for e in ct.validate(p)))
        p = good(); p["sections"][0]["category"] = "one"
        self.assertTrue(any("unknown category one" in e for e in ct.validate(p)))

    def test_duplicate_category_id(self):
        p = cats(); p["categories"][1]["id"] = "one"
        self.assertTrue(any("duplicate category id one" in e for e in ct.validate(p)))

    def test_plan_without_categories_still_validates(self):
        self.assertEqual(ct.validate(good()), [])


class UnitAssertions(unittest.TestCase):
    def check(self, a):
        p = good(); p["sections"][0]["steps"][0]["assertions"] = [a]
        return ct.validate(p)

    def test_valid_shapes(self):
        for a in (fact(), fact(op="between", value=[1, 5]), fact(op="approx", value=0.5, tolerance=0.01),
                  fact(op="in", value=["a", "b"]), fact(op="type", value="number"), fact(op="matches", value="^a"),
                  fact(op="missing", value=None), fact(which="any", count={"min": 1}),
                  {"kind": "log", "source": "debug", "contains": "x", "count": {"exactly": 2}},
                  {"kind": "state", "probe": "global-value", "name": "G", "op": "between", "value": [1, 5]}):
            a = {k: v for k, v in a.items() if v is not None}
            self.assertEqual(self.check(a), [], a)

    def test_wrong_shapes(self):
        for a, needle in ((fact(op="between", value=[1]), "between needs"), (fact(op="between", value=[5, 1]), "between needs"),
                          (fact(op="in", value=3), "in needs"), (fact(op="approx", value=1), "tolerance"),
                          (fact(op="type", value="table"), "type needs"), (fact(op="ge", value="3"), "ge needs"),
                          (fact(tolerance=1), "tolerance belongs"), (fact(count={"exactly": 1, "min": 0}), "exactly cannot"),
                          (fact(count={"min": 3, "max": 1}), "min is above max"),
                          ({"kind": "log", "source": "debug", "contains": "x", "absent": True, "count": {"exactly": 0}}, "count cannot combine"),
                          (fact(source="nope"), "unknown log source")):
            self.assertTrue(any(needle in e for e in self.check(a)), (a, self.check(a)))

    def test_auto_step_cannot_use_an_upper_bound_count(self):
        p = good(); st = p["sections"][0]["steps"][0]
        st["verify"], st["auto"] = ["assertions"], True
        st["assertions"] = [{"kind": "log", "source": "debug", "contains": "x", "count": {"exactly": 2}}]
        self.assertTrue(any("needs a timeout for a check that is judged at the end" in e for e in ct.validate(p)))
        st["timeout"] = 30
        self.assertEqual(ct.validate(p), [])

    def test_unknown_operator_and_which_fail_the_schema(self):
        self.assertTrue(self.check(fact(op="near")))
        self.assertTrue(self.check(fact(which="most")))

    def test_log_source_cap(self):
        p = good(); p["logs"]["debug"]["cap"] = 100
        self.assertEqual(ct.validate(p), [])
        for bad in (0, 1.5, 100001, "100"):
            p["logs"]["debug"]["cap"] = bad
            self.assertTrue(ct.validate(p), bad)

    def test_quiet_log_source(self):
        p = good(); p["logs"]["debug"]["quiet"] = True
        self.assertEqual(ct.validate(p), [])
        p["logs"]["debug"]["quiet"] = "yes"
        self.assertTrue(ct.validate(p))

    def test_operator_lists_agree_across_lua_schema_and_tool(self):
        with open(os.path.join(ROOT, "CheckThat", "Model", "Plan.lua"), encoding="utf-8") as f:
            lua = f.read()
        body = re.search(r"Plan\.OPS = \{(.*?)\n?\}\nPlan\.TYPES", lua, re.S).group(1)
        ops = set(re.findall(r'\b([a-z]+) = true', body)) | set(re.findall(r'\["([a-z]+)"\] = true', body))
        with open(ct.SCHEMA, encoding="utf-8") as f:
            schema = json.load(f)
        state = [o for o in schema["$defs"]["assertion"]["oneOf"] if o["properties"]["kind"]["const"] == "state"][0]
        fact_ = [o for o in schema["$defs"]["assertion"]["oneOf"] if o["properties"]["kind"]["const"] == "fact"][0]
        self.assertEqual(ops, set(state["properties"]["op"]["enum"]))
        self.assertEqual(ops, set(fact_["properties"]["op"]["enum"]))


class CategoryReport(unittest.TestCase):
    def test_state_rule_matches_the_lua_fixture(self):
        with open(os.path.join(ROOT, "tests", "fixtures", "category-rule.json"), encoding="utf-8") as f:
            cases = json.load(f)
        self.assertGreater(len(cases), 10)
        for case in cases:
            self.assertEqual(ct.category_rule(case["counts"]), case["state"], case)

    def run_record(self):
        return {"runId": "r", "addon": "KeepThat", "planTitle": "t", "revision": 1, "client": "classic-era", "build": "1", "character": "X",
                "order": ["a", "b", "c"], "categories": [{"id": "bank", "title": "Bank"}, {"id": "mail", "title": "Mail"}, {"id": "ah", "title": "AH"}],
                "cat": {"a": "bank", "b": "bank", "c": "mail", "d": "ah", "e": "mail"}, "selected": {"bank": True, "mail": True},
                "steps": {"a": {"verdict": "pass", "attempts": []}, "b": {"verdict": "fail", "attempts": []}, "c": {"verdict": "pending", "attempts": []},
                          "d": {"verdict": "deselected", "attempts": []}, "e": {"verdict": "inapplicable", "attempts": []}}}

    def test_report_rolls_steps_up_by_category(self):
        states = ct.category_states(self.run_record())
        self.assertEqual([(s[0], s[2], s[3], s[4]) for s in states], [("bank", "red", 2, 2), ("mail", "blue", 0, 1), ("ah", "off", 0, 0)])
        txt = ct.report_text({"r": self.run_record()})
        self.assertIn("categories: bank red 2/2, mail blue 0/1, ah not picked", txt)
        self.assertIn("deselected=1", txt)

    def test_a_run_without_categories_reports_as_before(self):
        r = self.run_record()
        for k in ("categories", "cat", "selected"):
            del r[k]
        self.assertEqual(ct.category_states(r), [])
        self.assertNotIn("categories:", ct.report_text({"r": r}))


class Cases(unittest.TestCase):
    def plan(self):
        p = good()
        st = p["sections"][0]["steps"][1]
        st["title"] = "Bind {{slot}}"
        st["expect"] = "Chat says {{slot}} is bound."
        st["cases"] = [{"id": "cloth", "vars": {"slot": "cloth"}}, {"id": "mail", "vars": {"slot": "mail"}}]
        return p

    def test_cases_expand_to_one_step_each(self):
        p = self.plan()
        self.assertEqual(ct.validate(p), [])
        m = ct.merge_sections(p)
        ids = [s["id"] for s in m["sections"][0]["steps"]]
        self.assertEqual(ids, ["a.1", "a.2.cloth", "a.2.mail"])
        self.assertEqual(m["sections"][0]["steps"][2]["title"], "Bind mail")
        self.assertNotIn("cases", json.dumps(m))

    def test_a_value_that_is_only_a_placeholder_keeps_its_type(self):
        p = good()
        st = p["sections"][0]["steps"][0]
        st["logs"] = None
        del st["logs"]
        p["logs"]["facts"] = {"global": "G", "path": "f", "format": "strings"}
        st["assertions"] = [{"kind": "fact", "source": "facts", "addon": "A", "key": "k", "op": "eq", "value": "{{n}}"}]
        st["cases"] = [{"id": "three", "vars": {"n": 3}}]
        m = ct.merge_sections(p)
        self.assertEqual(m["sections"][0]["steps"][0]["assertions"][0]["value"], 3)

    def test_duplicate_section_id_fails(self):
        p = good(); p["sections"].append(dict(p["sections"][0], steps=[dict(p["sections"][0]["steps"][1], id="z.9")]))
        self.assertTrue(any("duplicate section id" in e for e in ct.validate(p)))

    def test_state_and_requirement_approx_take_a_tolerance(self):
        p = good()
        a = {"kind": "state", "probe": "global-value", "name": "G", "op": "approx", "value": 3, "tolerance": 1}
        p["sections"][0]["steps"][0]["assertions"] = [a]
        self.assertEqual(ct.validate(p), [])

    def test_auto_step_cannot_use_a_missing_fact_check(self):
        p = good(); p["logs"]["facts"] = {"global": "G", "path": "f", "format": "strings", "quiet": True}
        st = p["sections"][0]["steps"][0]; st["verify"], st["auto"] = ["assertions"], True
        st["assertions"] = [{"kind": "fact", "source": "facts", "addon": "A", "key": "k", "op": "missing"}]
        self.assertTrue(any("needs a timeout for a check that is judged at the end" in e for e in ct.validate(p)))

    def test_unknown_placeholder_and_duplicate_suffix_fail(self):
        p = self.plan(); p["sections"][0]["steps"][1]["expect"] = "{{other}}"
        self.assertTrue(any("no var for {{other}}" in e for e in ct.validate(p)))
        p = self.plan(); p["sections"][0]["steps"][1]["cases"][1]["id"] = "cloth"
        self.assertTrue(any("duplicate case id cloth" in e for e in ct.validate(p)))

    def test_expanded_ids_must_stay_unique(self):
        p = self.plan(); dup = {k: v for k, v in p["sections"][0]["steps"][1].items() if k != "cases"}
        p["sections"][0]["steps"].append(dict(dup, id="a.2.cloth"))
        self.assertTrue(any("duplicate step id a.2.cloth" in e for e in ct.validate(p)))

    def test_more_than_fifty_cases_fail(self):
        p = self.plan(); p["sections"][0]["steps"][1]["cases"] = [{"id": "c%d" % i, "vars": {"slot": "x"}} for i in range(51)]
        self.assertTrue(ct.validate(p))



class Results(unittest.TestCase):
    def run_with(self, steps, **extra):
        return {"R-1": {"planTitle": "t", "addon": "KeepThat", "revision": 2, "client": "classic-era", "build": "1", "character": "X",
                        "order": [s for s in steps if steps[s].get("verdict") not in ("deselected", "inapplicable")], "steps": steps,
                        "cat": {s: "c1" for s in steps}, "categories": [{"id": "c1", "title": "One"}], "selected": {"c1": True}, **extra}}

    def steps(self):
        return {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "fail", "note": "broke", "started": 100, "finished": 110},
                                                       {"n": 2, "verdict": "pass", "started": 111, "finished": 120}]},
                "b": {"verdict": "fail", "attempts": [{"n": 1, "verdict": "fail", "note": "nope", "started": 200, "finished": 210}]},
                "c": {"verdict": "unverified", "attempts": [{"n": 1, "verdict": "unverified"}]},
                "d": {"verdict": "partial", "attempts": [{"n": 1, "verdict": "partial", "note": "slow"}]},
                "e": {"verdict": "pending", "attempts": []}, "f": {"verdict": "skip", "attempts": []},
                "g": {"verdict": "deselected", "attempts": []}}

    def cli(self, *argv):
        import io, contextlib
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ct.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def dest_with(self, runs):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        for rid, run in runs.items():
            ct.write_revision(d, {**run, "runId": rid})
        return d

    def test_report_shows_the_earlier_failure_under_a_later_pass(self):
        text = ct.report_text(self.run_with(self.steps()))
        self.assertIn("- a: pass, after 1 earlier failed or unverified attempt", text)
        self.assertIn("attempt 1: fail note=broke", text)
        self.assertNotIn("attempt 2: pass", text)
        self.assertIn("result: FAIL (1 fail, 1 unverified)", text)

    def test_classify_holds_a_pass_to_its_required_evidence(self):
        rec = lambda v, res: {"verdict": v, "attempts": [{"n": 1, "verdict": v, "outcomes": [{"result": res, "why": "w"}]}]}
        self.assertEqual(ct.classify(rec("pass", "fail"))[0], "fail")
        self.assertEqual(ct.classify(rec("pass", None))[0], "unverified")
        self.assertEqual(ct.classify(rec("pass", "pass"))[0], "pass")
        self.assertEqual(ct.classify(rec("partial", "pass"))[0], "partial")
        self.assertEqual(ct.classify({"verdict": "deselected"}), ("skipped", "category not picked"))
        self.assertEqual(ct.classify({"verdict": "pending"}), ("skipped", "not run"))

    def test_junit_has_a_suite_per_category_and_failures_skips_and_partials(self):
        from xml.etree import ElementTree as ET
        root = ET.fromstring(ct.report_junit(self.run_with(self.steps())))
        suite = root.find("testsuite")
        self.assertEqual((suite.get("name"), suite.get("tests"), suite.get("failures"), suite.get("skipped")), ("R-1/c1", "7", "2", "3"))
        cases = {c.get("name"): c for c in suite}
        self.assertEqual(cases["b"].find("failure").get("type"), "fail")
        self.assertEqual(cases["c"].find("failure").get("type"), "unverified")
        self.assertEqual(cases["g"].find("skipped").get("message"), "category not picked")
        self.assertIsNone(cases["d"].find("failure")); self.assertIn("slow", cases["d"].find("system-out").text)

    def test_json_totals_and_ok(self):
        d = json.loads(ct.report_json(self.run_with(self.steps())))
        self.assertFalse(d["ok"]); self.assertEqual(d["totals"]["fail"], 1); self.assertEqual(d["runs"][0]["steps"][0]["id"], "a")
        clean = self.run_with({"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}})
        self.assertTrue(json.loads(ct.report_json(clean))["ok"])

    def errors_dest(self, errs, stacks):
        d = self.dest_with(self.run_with(self.steps()))
        os.makedirs(os.path.join(d, "errors"))
        with open(os.path.join(d, "errors", "x.json"), "w") as fh:
            json.dump({"runs": ["R-1"], "errors": errs, "errorStacks": stacks}, fh)
        return d

    def test_report_prints_the_stack_under_the_attempt_that_was_open(self):
        d = self.errors_dest(["205.001 [KeepThat] boom"], ["205.001 a.lua:1 / b.lua:2"])
        text = ct.report_text(ct.latest_runs(d), d)
        self.assertIn("error 205.001: [KeepThat] boom", text)
        self.assertIn("stack: a.lua:1 / b.lua:2", text)
        self.assertLess(text.index("attempt 1: fail note=nope"), text.index("error 205.001"))
        self.assertNotIn("stack:", ct.report_text(ct.latest_runs(d), d, stacks=False))

    def test_a_stack_whose_time_fits_two_attempts_is_labelled(self):
        steps = self.steps(); steps["b"]["attempts"][0].update(started=105, finished=210)
        d = self.dest_with(self.run_with(steps))
        os.makedirs(os.path.join(d, "errors"))
        with open(os.path.join(d, "errors", "x.json"), "w") as fh:
            json.dump({"errors": ["108.002 [K] x"], "errorStacks": ["108.002 s"]}, fh)
        self.assertIn("(time also fits another attempt)", ct.report_text(ct.latest_runs(d), d))

    def test_a_failure_that_a_later_attempt_recovered_keeps_its_stack_in_json_and_junit(self):
        steps = {"a": {"verdict": "pass", "attempts": [
            {"n": 1, "verdict": "fail", "started": 100, "finished": 110, "outcomes": [{"result": "fail"}]},
            {"n": 2, "verdict": "pass", "started": 108, "finished": 120}]}}
        d = self.dest_with(self.run_with(steps))
        os.makedirs(os.path.join(d, "errors"))
        with open(os.path.join(d, "errors", "x.json"), "w") as fh:
            json.dump({"errors": ["109.001 [K] x"], "errorStacks": ["109.001 STACKTEXT"]}, fh)
        runs = ct.latest_runs(d)
        step = json.loads(ct.report_json(runs, d, True))["runs"][0]["steps"][0]
        self.assertEqual([p["attempt"] for p in step["attemptStacks"]], [1])
        self.assertIn("time also fits another attempt", step["attemptStacks"][0]["stacks"][0])
        self.assertNotIn("stacks", step, "the step passed in the end")
        from xml.etree import ElementTree as ET
        self.assertIn("STACKTEXT", ET.fromstring(ct.report_junit(runs, d, True)).find(".//system-out").text)
        self.assertNotIn("STACKTEXT", ct.report_json(runs, d))

    def test_a_pass_contradicted_by_evidence_keeps_its_stack(self):
        steps = {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass", "started": 100, "finished": 110, "outcomes": [{"result": "fail"}]}]}}
        d = self.dest_with(self.run_with(steps))
        os.makedirs(os.path.join(d, "errors"))
        with open(os.path.join(d, "errors", "x.json"), "w") as fh:
            json.dump({"errors": ["105.001 [K] x"], "errorStacks": ["105.001 KEEPME"]}, fh)
        step = json.loads(ct.report_json(ct.latest_runs(d), d, True))["runs"][0]["steps"][0]
        self.assertEqual(step["result"], "fail"); self.assertIn("KEEPME", step["stacks"][0])

    def test_json_and_junit_keep_stacks_out_unless_asked(self):
        d = self.errors_dest(["205.001 [K] boom"], ["205.001 SECRET /Users/x"])
        runs = ct.latest_runs(d)
        self.assertNotIn("SECRET", ct.report_json(runs, d)); self.assertNotIn("SECRET", ct.report_junit(runs, d))
        self.assertIn("SECRET", ct.report_json(runs, d, True)); self.assertIn("SECRET", ct.report_junit(runs, d, True))

    def test_strict_report_exit_code(self):
        d = self.dest_with(self.run_with(self.steps()))
        self.assertEqual(self.cli("report", "--dest", d, "--format", "junit")[0], 0)
        code, out, err = self.cli("report", "--dest", d, "--format", "json", "--strict")
        self.assertEqual(code, 1); self.assertIn("failed or are unverified", err); json.loads(out)   # stdout stays valid JSON
        clean = self.dest_with(self.run_with({"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}}))
        self.assertEqual(self.cli("report", "--dest", clean, "--format", "json", "--strict")[0], 0)
        self.assertEqual(self.cli("report", "--dest", tempfile.mkdtemp(), "--format", "json", "--strict")[0], 1)

    def test_status_says_what_is_wrong_with_the_folder(self):
        code, out, _ = self.cli("status", "--dest", tempfile.mkdtemp())
        self.assertEqual(code, 1); self.assertIn("no run revisions", out)
        d = self.dest_with(self.run_with(self.steps()))
        code, out, _ = self.cli("status", "--dest", d)
        self.assertEqual(code, 0, out); self.assertIn("R-1", out); self.assertIn("no problems", out); self.assertIn("report --strict", out)
        rp = os.path.join(d, "runs", "R-1")
        with open(os.path.join(rp, "r3.json"), "w") as fh:
            fh.write("{broken")
        code, out, _ = self.cli("status", "--dest", d, "--json")
        data = json.loads(out)
        self.assertEqual(code, 1); self.assertFalse(data["ok"]); self.assertEqual(data["runs"][0]["revision"], 2)   # the healthy revision still shows
        self.assertTrue(any("r3.json is unreadable" in p for p in data["problems"]))
        self.assertIn("R-1", ct.latest_runs(d))

    def test_status_reports_a_collect_conflict_and_a_size_near_the_limit(self):
        d = self.dest_with(self.run_with(self.steps()))
        ct.note_problem(d, "run R-1 revision 2 already stored with different content")
        self.assertTrue(any("already stored" in p for p in ct.status_data(d)[1]))
        big = self.run_with({"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass", "note": "x" * int(ct.MAX_INFLATED * 0.9)}]}})
        self.assertTrue(any("export limit" in p for p in ct.status_data(self.dest_with(big))[1]))

    def test_an_open_attempt_snapshot_is_not_a_conflict(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        run = {"runId": "R-1", "revision": 1, "steps": {"a": {"attempts": [{"n": 1, "snapshots": {"debug": {"n": 3}}}]}}}
        exported = json.loads(json.dumps(run)); exported["steps"]["a"]["attempts"][0].pop("snapshots")
        self.assertEqual(ct.write_revision(d, run), "new")
        self.assertEqual(ct.write_revision(d, exported), "same")   # /ct export strips snapshots
        exported["steps"]["a"]["attempts"][0]["n"] = 2
        self.assertEqual(ct.write_revision(d, exported), "conflict")

    def test_junit_stays_valid_xml_with_control_characters_in_a_note(self):
        from xml.etree import ElementTree as ET
        steps = {"a": {"verdict": "fail", "attempts": [{"n": 1, "verdict": "fail", "note": "bad \x01 byte"}]}}
        root = ET.fromstring(ct.report_junit(self.run_with(steps)))
        self.assertIn("bad ? byte", root.find("testsuite/testcase/failure").get("message"))

    def test_status_skips_files_that_are_not_run_records(self):
        d = self.dest_with(self.run_with(self.steps()))
        rp = os.path.join(d, "runs", "R-1")
        for name, body in (("r3.json", "{}"), ("r4.json", "[]"), ("r-1.json", "{}"), ("r-old.json", "x")):
            with open(os.path.join(rp, name), "w") as fh:
                fh.write(body)
        self.assertEqual(ct.latest_runs(d)["R-1"]["revision"], 2)
        problems = ct.status_data(d)[1]
        self.assertTrue(any("r3.json is unreadable" in p for p in problems)); self.assertTrue(any("r4.json is unreadable" in p for p in problems))
        with self.assertRaises(ValueError):
            ct.write_revision(d, {"runId": "R-2", "revision": -1, "steps": {}})

    def test_a_stack_from_another_sessions_saved_variables_is_not_matched(self):
        d = self.dest_with(self.run_with(self.steps()))
        os.makedirs(os.path.join(d, "errors"))
        with open(os.path.join(d, "errors", "x.json"), "w") as fh:
            json.dump({"runs": ["Other-9"], "errors": ["205.001 [K] boom"], "errorStacks": ["205.001 theirs"]}, fh)
        self.assertNotIn("theirs", ct.report_text(ct.latest_runs(d), d))

    def test_a_pass_its_evidence_contradicts_keeps_its_attempt_detail(self):
        steps = {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass", "outcomes": [{"result": "fail", "why": "line seen"}]}]}}
        text = ct.report_text(self.run_with(steps))
        self.assertIn("result: FAIL", text); self.assertIn("evidence=fail(line seen)", text)

    def test_a_step_named_in_order_but_missing_is_not_a_pass(self):
        run = self.run_with({"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}})
        run["R-1"]["order"] = ["a", "a", "ghost"]
        m = ct.models(run)[0]
        self.assertEqual([s["id"] for s in m["steps"]], ["a", "ghost"]); self.assertEqual(m["counts"], {"pass": 1, "unverified": 1})
        self.assertFalse(json.loads(ct.report_json({}))["ok"])

    def test_failed_only_keeps_the_failing_steps_and_says_when_there_are_none(self):
        text = ct.report_text(self.run_with(self.steps()), failed_only=True)
        self.assertIn("\nb ", text); self.assertIn("\nc ", text); self.assertNotIn("\nd ", text); self.assertNotIn("\na ", text)
        clean = self.run_with({"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}})
        self.assertIn("no failed or unverified steps", ct.report_text(clean, failed_only=True))

    def test_show_prints_every_attempt_of_one_step_and_names_choices_on_a_mistake(self):
        d = self.errors_dest(["205.001 [K] boom"], ["205.001 a.lua:1"])
        code, out, _ = self.cli("show", "R-1", "a", "--dest", d)
        self.assertEqual(code, 0); self.assertIn("attempt 1: fail note=broke", out); self.assertIn("attempt 2: pass", out); self.assertNotIn("\nb ", out); self.assertNotIn("- b:", out)
        self.assertIn("stack:", self.cli("show", "-1", "b", "--dest", d)[1])   # a part of the id names the run
        code, _, err = self.cli("show", "R-1", "zzz", "--dest", d)
        self.assertEqual(code, 2); self.assertIn("steps: a, b", err)
        code, _, err = self.cli("show", "nope", "--dest", d)
        self.assertEqual(code, 2); self.assertIn("runs: R-1", err)
        self.assertIn("no runs collected yet", self.cli("show", "x", "--dest", tempfile.mkdtemp())[2])

    def test_status_watch_prints_each_round_and_returns_the_last_exit_code(self):
        d = self.dest_with(self.run_with(self.steps()))
        seen, naps = [], []
        self.assertEqual(ct.status_watch(d, 3, sleep=naps.append, rounds=2, out=seen.append), 0)
        self.assertEqual((len(seen), naps), (2, [3]))
        self.assertEqual(ct.status_watch(tempfile.mkdtemp(), 1, sleep=naps.append, rounds=1, out=seen.append), 1)
        self.assertEqual(self.cli("status", "--watch", "--json", "--dest", d)[0], 2)

    def checked_steps(self):
        out = {"result": "fail", "why": "a forbidden line appeared", "rule": 'absent: contains "FAILED"', "shape": 'absent: contains "…"', "kind": "log", "scope": "attempt", "source": "debug",
               "matched": 2, "window": 4, "hits": [{"n": 2, "line": "[kt] FAILED: SECRET-LINE"}, {"n": 4, "line": "[kt] FAILED: y"}]}
        return {"a": {"verdict": "fail", "attempts": [{"n": 1, "verdict": "fail", "outcomes": [out, {"result": "pass"}],
                                                       "excerpt": {"debug": ["one", "[kt] FAILED: SECRET-LINE", "three", "[kt] FAILED: y"]}},
                                                      ]},
                "b": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "fail", "outcomes": [dict(out, hits=[{"n": 1, "line": "RETRY-LINE"}])]},
                                                      {"n": 2, "verdict": "pass", "outcomes": [{"result": "pass"}]}]}}

    def test_report_names_the_check_and_marks_the_lines_that_decided_it(self):
        text = ct.report_text(self.run_with(self.checked_steps()))
        self.assertIn('check 1 (required, fail): absent: contains "FAILED"  [debug; 2 of 4 lines matched]', text)
        self.assertIn("line 2: [kt] FAILED: SECRET-LINE", text)
        self.assertIn("    > [kt] FAILED: SECRET-LINE", text); self.assertIn("      one", text)   # only the lines that decided a check are marked
        self.assertIn("RETRY-LINE", text)   # a pass after a retry still shows what the earlier attempt tripped on

    def test_json_has_the_check_detail_but_line_text_only_when_asked(self):
        runs = self.run_with(self.checked_steps())
        plain = json.loads(ct.report_json(runs))
        step = {s["id"]: s for s in plain["runs"][0]["steps"]}
        o = step["a"]["checks"][0]["outcomes"][0]
        self.assertEqual((o["index"], o["rule"], o["source"], o["matched"], o["window"], [h["n"] for h in o["hits"]]), (1, 'absent: contains "…"', "debug", 2, 4, [2, 4]))   # the shape: the plan's literal is not given away
        self.assertNotIn('"FAILED"', ct.report_json(runs))
        self.assertEqual(json.loads(ct.report_json(runs, with_lines=True))["runs"][0]["steps"][0]["checks"][0]["outcomes"][0]["rule"], 'absent: contains "FAILED"')
        self.assertNotIn("SECRET-LINE", ct.report_json(runs)); self.assertNotIn("line", o["hits"][0])
        self.assertEqual(step["b"]["checks"][0]["attempt"], 1)   # the retry that passed keeps the attempt it tripped in
        full = json.loads(ct.report_json(runs, with_lines=True))
        self.assertEqual({s["id"]: s for s in full["runs"][0]["steps"]}["a"]["checks"][0]["outcomes"][0]["hits"][0]["line"], "[kt] FAILED: SECRET-LINE")

    def test_junit_failure_names_the_check_and_leaves_line_text_out_unless_asked(self):
        from xml.etree import ElementTree as ET
        runs = self.run_with(self.checked_steps())
        body = ET.fromstring(ct.report_junit(runs)).find("testsuite/testcase[@name='a']/failure").text
        self.assertIn('check 1 (fail): absent: contains "…" [2 of 4 lines matched] - a forbidden line appeared', body); self.assertIn("line 2", body)
        self.assertNotIn("SECRET-LINE", body); self.assertNotIn('"FAILED"', body)
        full = ET.fromstring(ct.report_junit(runs, with_lines=True)).find("testsuite/testcase[@name='a']/failure").text
        self.assertIn("SECRET-LINE", full); self.assertIn('absent: contains "FAILED"', full)

    def test_junit_takes_the_checks_from_the_attempt_the_result_comes_from(self):
        from xml.etree import ElementTree as ET
        steps = {"a": {"verdict": "fail", "attempts": [
            {"n": 1, "verdict": "unverified", "outcomes": [{"result": "unverified", "rule": "R1", "shape": "OLD-ATTEMPT", "why": "w"}]},
            {"n": 2, "verdict": "fail", "note": "by hand", "outcomes": [{"result": "pass"}]}]}}
        body = ET.fromstring(ct.report_junit(self.run_with(steps))).find("testsuite/testcase/failure").text
        self.assertNotIn("OLD-ATTEMPT", body)   # a manual failure on attempt 2 is not explained by attempt 1's check

    def test_the_report_keeps_a_failed_diagnostic_of_a_passing_attempt(self):
        steps = {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass", "outcomes": [
            {"result": "pass"}, {"result": "unverified", "diagnostic": True, "rule": 'present: contains "x"', "why": "no matching log line", "matched": 0, "window": 3}]}]}}
        text = ct.report_text(self.run_with(steps))
        self.assertIn("with 1 failed or unverified check kept", text); self.assertIn('check 2 (diagnostic, unverified): present: contains "x"', text)

    def test_a_malformed_check_detail_is_an_unreadable_revision(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        for i, bad in enumerate(({"hits": [{"n": 0}]}, {"hits": ["x"]}, {"matched": "2"}, {"window": -1}, {"hits": {"n": 1}}, {"stoppedAt": 0},
                                  {"hits": [{"n": 1}] * 4}, {"hits": [{"n": 1, "line": 5}]}, {"rule": 3}, {"scope": "x"}, {"trimmed": False})):
            p = os.path.join(d, "r%d.json" % i)
            with open(p, "w") as fh:
                json.dump({"steps": {"a": {"attempts": [{"n": 1, "outcomes": [dict({"result": "fail"}, **bad)]}]}}}, fh)
            with self.assertRaises(ValueError, msg=str(bad)):
                ct.read_run(p)
        with open(os.path.join(d, "ok.json"), "w") as fh:
            json.dump({"steps": {"a": {"attempts": [{"n": 1, "outcomes": [{"result": "fail", "hits": [{"n": 1, "line": "x"}], "matched": 1, "window": 1}, {"result": "pass"}]}]}}}, fh)
        ct.read_run(os.path.join(d, "ok.json"))   # older runs, with none of it, read as before

    def test_the_results_schema_accepts_old_and_new_runs_and_names_bad_detail(self):
        import jsonschema
        with open(os.path.join(ROOT, "schema", "run-results.schema.json")) as fh:
            schema = json.load(fh)
        check = lambda run: jsonschema.Draft202012Validator(schema).iter_errors(run)
        new = self.run_with(self.checked_steps())["R-1"]
        new["steps"]["a"]["attempts"][0]["outcomes"][0].update(stoppedAt=2, observed="3", trimmed=True)
        self.assertEqual(list(check(new)), [])
        self.assertEqual(list(check({"steps": {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}}})), [], "an older run has none of the new keys")
        for bad in ({"hits": [{"n": 0}]}, {"result": "bogus"}, {"matched": -1}, {"scope": "everywhere"}, {"hits": [{"n": 1}] * 4}, {"trimmed": False}):
            run = {"steps": {"a": {"attempts": [{"n": 1, "outcomes": [dict({"result": "fail"}, **bad)]}]}}}
            self.assertTrue(list(check(run)), bad)

    def test_a_run_the_addon_wrote_passes_the_schema_and_both_tools_read_it(self):
        import jsonschema
        path = os.path.join(ROOT, "build", "hits-run.json")   # written by tests/test_hits.lua, which make test runs first
        if not os.path.exists(path):
            self.skipTest("run tests/test_hits.lua first")
        with open(os.path.join(ROOT, "schema", "run-results.schema.json")) as fh:
            schema = json.load(fh)
        with open(path) as fh:
            run = json.load(fh)
        self.assertEqual(list(jsonschema.Draft202012Validator(schema).iter_errors(run)), [])
        ct.read_run(path)
        self.assertEqual((run["ct"], run["formatRev"]), (1, 1)); self.assertEqual(run["steps"]["a"]["attempts"][0]["formatRev"], 1)   # stamped by the addon
        outs = run["steps"]["a"]["attempts"][0]["outcomes"]
        self.assertEqual((outs[0]["rule"], outs[0]["hits"][0]["line"]), ('absent: contains "boom"', "boom here"))
        self.assertEqual((outs[1]["stoppedAt"], outs[1]["matched"]), (2, 1)); self.assertEqual(outs[2]["observed"], "2")
        text = ct.report_text({"R": run})
        self.assertIn('check 1 (required, fail): absent: contains "boom"', text); self.assertIn("stopped at item 2", text)

    def test_a_newer_major_is_refused_before_anything_reads_its_shape_and_the_reason_is_said(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        p = os.path.join(d, "r1.json")
        with open(p, "w") as fh:
            json.dump({"ct": 2, "steps": "a newer shape", "formatRev": 9}, fh)
        with self.assertRaises(ValueError) as cm:
            ct.read_run(p)
        self.assertIn("format 2 is newer than this tool reads (1)", str(cm.exception))
        with self.assertRaises(ValueError):
            ct.write_revision(d, {"ct": 2, "runId": "F-1", "revision": 1, "steps": {}})
        with open(p, "w") as fh:
            json.dump({"ct": 1, "formatRev": 99, "writerVersion": "9.9.9", "steps": {}, "somethingNew": [1]}, fh)
        self.assertEqual(ct.read_run(p)["formatRev"], 99)   # a higher revision is only more optional keys: read it

    def test_status_and_report_say_a_newer_revision_was_skipped_and_strict_fails(self):
        d = self.dest_with(self.run_with(self.steps()))
        with open(os.path.join(d, "runs", "R-1", "r3.json"), "w") as fh:
            json.dump({"ct": 2, "steps": {}}, fh)
        problems = ct.status_data(d)[1]
        self.assertTrue(any("r3.json is unreadable (format 2 is newer than this tool reads (1)" in p for p in problems), problems)
        code, out, err = self.cli("report", "--dest", d, "--format", "json")
        self.assertEqual(code, 0); self.assertIn("r3.json is unreadable (format 2 is newer", err); self.assertIn("shows an older revision", err)
        code, out, err = self.cli("report", "--dest", d, "--format", "json", "--strict")
        self.assertEqual(code, 1); self.assertIn("1 run(s) have a revision that could not be read", err)

    def test_collect_names_a_run_a_newer_checkthat_saved_and_stores_nothing_of_it(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write('CheckThatDB = {["global"] = {["runs"] = {}, ["future"] = {["F-1"] = {["ct"] = 2, ["runId"] = "F-1", ["revision"] = 4, ["steps"] = {}}}}}\n')
        dest = os.path.join(d, "dest")
        ct.cmd_collect(type("A", (), {"src": os.path.join(d, "src"), "dest": dest, "shots": None}))
        self.assertEqual(ct.latest_runs(dest), {})
        rows, problems, _ = ct.status_data(dest)
        self.assertTrue(any("F-1" in p and "format 2 is newer" in p for p in problems), problems)

    def test_the_stamps_are_in_json_status_and_schema(self):
        import jsonschema
        runs = self.run_with(self.steps(), formatRev=1, writerVersion="0.15.0")
        m = json.loads(ct.report_json(runs))["runs"][0]
        self.assertEqual((m["formatRev"], m["writerVersion"]), (1, "0.15.0"))
        d = self.dest_with(runs)
        row = ct.status_data(d)[0][0]
        self.assertEqual((row["formatRev"], row["writerVersion"]), (1, "0.15.0"))
        with open(os.path.join(ROOT, "schema", "run-results.schema.json")) as fh:
            schema = json.load(fh)
        ok = lambda run: not list(jsonschema.Draft202012Validator(schema).iter_errors(run))
        steps = {"a": {"attempts": [{"n": 1, "formatRev": 1}]}}
        self.assertTrue(ok({"ct": 1, "formatRev": 3, "writerVersion": "1.2.3", "steps": steps}))
        self.assertTrue(ok({"steps": steps}), "an older run has no stamp")
        for bad in ({"ct": 2}, {"formatRev": 0}, {"formatRev": "1"}, {"writerVersion": 3}):
            self.assertFalse(ok(dict({"steps": steps}, **bad)), bad)
        self.assertFalse(ok({"steps": {"a": {"attempts": [{"n": 1, "formatRev": 0}]}}}))

    def test_the_results_format_page_matches_the_code(self):
        with open(os.path.join(ROOT, "CheckThat", "Model", "Run.lua"), encoding="utf-8") as fh:
            major, rev = re.search(r"Run\.MAJOR, Run\.FORMAT_REV = (\d+), (\d+)", fh.read()).groups()
        with open(os.path.join(ROOT, "docs", "results-format.md"), encoding="utf-8") as fh:
            page = fh.read()
        self.assertIn("Current: **ct %s, formatRev %s.**" % (major, rev), page)
        self.assertTrue(re.search(r"^\| %s \| \d+\.\d+\.\d+ \|" % rev, page, re.M), "the revision table has a row for the current formatRev")
        self.assertEqual(int(major), ct.SUPPORTED_MAJOR, "ct.py reads the major the addon writes")
        with open(os.path.join(ROOT, "CheckThat", "CheckThat_Vanilla.toc"), encoding="utf-8") as fh:
            version = re.search(r"^## Version:\s*(\S+)", fh.read(), re.M).group(1)
        row = re.search(r"^\| %s \| (\d+\.\d+\.\d+) \|" % rev, page, re.M).group(1)
        self.assertLessEqual(tuple(map(int, row.split("."))), tuple(map(int, version.split("."))), "a revision cannot be newer than the addon")

    def test_ct_must_be_a_whole_number_from_one_and_a_stored_newer_revision_is_kept_not_crashed_on(self):
        for good in ({}, {"ct": 1}, {"ct": 1.0}):
            ct.check_major(good)
        for bad in (2, 2.0, "2", "1", True, 1.5, 0, -1, None, [], float("nan"), float("inf")):
            with self.assertRaises(ct.MajorError, msg=repr(bad)):
                ct.check_major({"ct": bad})
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        os.makedirs(os.path.join(d, "runs", "R-1"))
        stored = os.path.join(d, "runs", "R-1", "r1.json")
        with open(stored, "w") as fh:
            json.dump({"ct": 2, "steps": "future"}, fh)
        with self.assertRaises(ct.MajorError) as cm:
            ct.write_revision(d, {"runId": "R-1", "revision": 1, "steps": {}})
        self.assertIn("the stored r1.json is kept as it is", str(cm.exception))
        with open(stored) as fh:
            self.assertEqual(json.load(fh), {"ct": 2, "steps": "future"})

    def collect_sv(self, body):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write(body)
        return d, type("A", (), {"src": os.path.join(d, "src"), "dest": os.path.join(d, "dest"), "shots": None})

    def test_a_run_set_aside_does_not_mask_a_readable_run_with_the_same_id_and_strict_stays_failed_until_it_is_stored(self):
        d, args = self.collect_sv('CheckThatDB = {["global"] = {["runs"] = {["R-1"] = {["ct"] = 1, ["runId"] = "R-1", ["revision"] = 3, ["steps"] = {["a"] = {["verdict"] = "pass", ["attempts"] = {}}}, ["order"] = {"a"}}}, '
                                  '["future"] = {["R-1"] = {["ct"] = 2, ["runId"] = "R-1", ["revision"] = 9, ["steps"] = {}}}}}\n')
        ct.cmd_collect(args)
        runs = ct.latest_runs(args.dest)
        self.assertEqual(runs["R-1"]["revision"], 3)   # the readable one is stored, not masked
        self.assertIn("R-1", ct.load_refused(args.dest))
        code, out, err = self.cli("report", "--dest", args.dest, "--format", "json", "--strict")
        self.assertEqual(code, 1); self.assertIn("1 run(s) have a revision that could not be read", err)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables", "CheckThat.lua")
        with open(sv, "w") as fh:   # the next collect: the run is readable now (the addon moved it back)
            fh.write('CheckThatDB = {["global"] = {["runs"] = {["R-1"] = {["ct"] = 1, ["runId"] = "R-1", ["revision"] = 9, ["steps"] = {["a"] = {["verdict"] = "pass", ["attempts"] = {}}}, ["order"] = {"a"}}}}}\n')
        ct.cmd_collect(args)
        self.assertEqual(ct.load_refused(args.dest), {})
        self.assertEqual(self.cli("report", "--dest", args.dest, "--format", "json", "--strict")[0], 0)

    def test_a_readable_copy_in_another_account_does_not_clear_a_refusal_of_the_same_run(self):
        d, args = self.collect_sv('CheckThatDB = {["global"] = {["runs"] = {}, ["future"] = {["R-1"] = {["ct"] = 2, ["runId"] = "R-1", ["revision"] = 9, ["steps"] = {}}}}}\n')
        b = os.path.join(d, "src", "Account", "B", "SavedVariables"); os.makedirs(b)
        with open(os.path.join(b, "CheckThat.lua"), "w") as fh:
            fh.write('CheckThatDB = {["global"] = {["runs"] = {["R-1"] = {["ct"] = 1, ["runId"] = "R-1", ["revision"] = 4, ["steps"] = {}, ["order"] = {}}}}}\n')
        ct.cmd_collect(args)
        self.assertEqual(ct.latest_runs(args.dest)["R-1"]["revision"], 4)
        self.assertIn("R-1", ct.load_refused(args.dest), "the other account's run is not the one that was refused")

    def test_a_ct_with_a_fraction_is_refused(self):
        with self.assertRaises(ct.MajorError):
            ct.check_major({"ct": 1.5})

    def test_report_says_when_a_refused_run_is_not_in_the_report_at_all(self):
        d = self.dest_with(self.run_with(self.steps()))
        ct.set_refused(d, "Other-9", 2, "format 2 is newer than this tool reads (1)")
        code, out, err = self.cli("report", "--dest", d, "--format", "json")
        self.assertIn("run Other-9: the collected copy is unreadable (format 2 is newer", err); self.assertIn("the run is not in this report", err)
        self.assertTrue(any("Other-9" in p and "not stored" in p for p in ct.status_data(d)[1]))

    def test_import_checks_the_major_before_the_kind(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        s = ct.encode({"ct": 2, "kind": "renamed", "runId": "F-1", "revision": 1})
        code, out, err = self.cli("import-results", s, "--dest", d)
        self.assertEqual(code, 1); self.assertIn("format 2 is newer than this tool reads", err); self.assertNotIn("not a results string", err)

    def test_collect_keeps_the_error_lines_and_stacks(self):
        d = tempfile.mkdtemp(); self.addCleanup(__import__("shutil").rmtree, d)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write('CheckThatDB = {["global"] = {["errors"] = {"7.001 [K] e"}, ["errorStacks"] = {"7.001 s1 / s2"}, ["runs"] = {}}}\n')
        dest = os.path.join(d, "dest")
        ct.cmd_collect(type("A", (), {"src": os.path.join(d, "src"), "dest": dest, "shots": None}))
        self.assertEqual(ct.load_errors(dest), ({"7.001": "[K] e"}, {"7.001": "s1 / s2"}))


if __name__ == "__main__":
    unittest.main()
