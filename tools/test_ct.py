import contextlib, glob, io, json, os, re, shutil, subprocess, sys, tempfile, unittest, zlib
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
        for n in ("dontdothat", "selftest"):
            plan = ct.load_yaml(os.path.join(ROOT, "plans", n + ".yaml"))
            self.assertEqual(ct.validate(plan), [], n)
            self.assertEqual(ct.warnings(plan), [], n)


class TemplateSlice(unittest.TestCase):
    """tools/template_slice.py reads templates from Blizzard-style XML and Lua; here a tiny fake source tree."""
    def tree(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        def put(name, text):
            p = os.path.join(d, "src", name); os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f: f.write(text)
        put("a.xml", '<Ui><!-- <Frame name="Commented" virtual="true"/> -->'
                     '<Frame name="Base" virtual="true" mixin="BaseMixin"><Frames><Frame parentKey="Inner"/></Frames></Frame>'
                     '<Button name="Child" virtual="true" inherits="Base, Missing" mixin="ChildMixin"><Layers><Layer><FontString parentKey="Text"/></Layer></Layers></Button></Ui>')
        put("b.lua", 'LateMixin = LateMixin or {}\nLateMixin.Direct = function() end\nBaseMixin = Mixin(BaseMixin, LateMixin)\n')
        put("a.lua", 'BaseMixin = {}\nfunction BaseMixin:Ping() end\nChildMixin = CreateFromMixins(BaseMixin, OtherMixin)\nfunction ChildMixin:Pong() end\nOtherMixin = {}\nfunction OtherMixin.Far() end\nfunction Unrelated:Nope() end\n')
        surface = os.path.join(d, "surface.json")
        with open(surface, "w") as f: f.write('{\n "format": 1,\n "client": "x",\n "widgets": {"Frame": ["SetPoint"]}\n}\n')
        return d, surface

    def test_methods_follow_mixins_parents_and_inherits_and_keys_are_collected(self):
        import template_slice
        d, surface = self.tree()
        templates, mixins = template_slice.scan(os.path.join(d, "src"))
        self.assertNotIn("Commented", templates)
        methods, keys = template_slice.resolve("Child", templates, mixins)
        self.assertEqual(sorted(methods), ["Direct", "Far", "Ping", "Pong"], "also Name.Method = function and Mixin(Name, ...)"); self.assertEqual(sorted(keys), ["Inner", "Text"])
        self.assertNotIn("Nope", methods)

    def test_the_surface_file_keeps_every_other_byte_and_an_unknown_template_is_an_error(self):
        d, surface = self.tree()
        with open(surface) as fh: before = fh.read()
        tool = [sys.executable, os.path.join(ROOT, "tools", "template_slice.py"), surface, os.path.join(d, "src")]
        out = subprocess.run(tool + ["Child"], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertTrue(out.stdout.startswith(before.rstrip()[:-1].rstrip()), "the old text is the prefix")
        j = json.loads(out.stdout)
        self.assertEqual(j["widgets"], {"Frame": ["SetPoint"]}); self.assertEqual(j["templates"]["Child"]["methods"], ["Direct", "Far", "Ping", "Pong"])
        again = os.path.join(d, "again.json")
        with open(again, "w") as fh: fh.write(out.stdout)
        twice = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "template_slice.py"), again, os.path.join(d, "src"), "Base", "-o", again], capture_output=True, text=True)
        self.assertEqual(twice.returncode, 0, twice.stderr)
        with open(again) as fh: t2 = fh.read()
        self.assertTrue(t2.startswith(before.rstrip()[:-1].rstrip()), "a second run keeps the rest of the file"); self.assertEqual(sorted(json.loads(t2)["templates"]), ["Base", "Child"])
        bad = subprocess.run(tool + ["Nope"], capture_output=True, text=True)
        self.assertNotEqual(bad.returncode, 0); self.assertIn("no template named Nope", bad.stderr)

    def test_the_committed_surfaces_list_the_templates_checkthat_uses(self):
        for client in ("era", "forever"):
            with open(os.path.join(ROOT, "tools", "clients", client + ".json")) as f:
                t = json.load(f)["templates"]
            for n in ("BackdropTemplate", "UIPanelButtonTemplate", "UIPanelScrollFrameTemplate", "UICheckButtonTemplate", "UIDropDownMenuTemplate"):
                self.assertIn(n, t, client)
            self.assertIn("SetBackdrop", t["BackdropTemplate"]["methods"], client)

class KeepThatPlans(unittest.TestCase):
    def test_the_fixture_plan_validates_and_stays_short(self):
        plan = ct.load_yaml(os.path.join(ROOT, "tests", "fixtures", "keepthat.yaml"))
        self.assertEqual(ct.validate(plan), []); self.assertEqual(ct.warnings(plan), [])
        self.assertLessEqual(sum(len(s["steps"]) for s in plan["sections"]), 8)

    def test_the_plan_of_record_in_the_sibling_repository_validates_when_present(self):
        path = os.path.join(ROOT, "..", "wow-keepthat", "plans", "keepthat.yaml")
        if not os.path.isfile(path):
            self.skipTest("../wow-keepthat is not checked out")
        specs = os.path.join(ROOT, "..", "wow-keepthat", "openspec", "specs")
        names = set(ct.requirement_names(specs)) if os.path.isdir(specs) else None
        self.assertEqual(ct.validate(ct.load_yaml(path), names), [])

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
        for path in glob.glob(os.path.join(ROOT, "plans", "**", "*.yaml"), recursive=True) + [os.path.join(ROOT, "tests", "fixtures", "keepthat.yaml")]:
            d = ct.load_yaml(path)
            for box, key, _ in ct.display_fields(d):
                self.assertNotRegex(box[key], r"`|\*\*", path + " " + key)


class SamplePlans(unittest.TestCase):
    def test_sample_plans_stay_short_and_full_plans_stay_valid(self):
        import glob
        for n in ("dontdothat",):
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


@unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
class OfflineBlock(unittest.TestCase):
    PLAN = os.path.join(ROOT, "tests", "fixtures", "offline-plan", "plan.yaml")

    def plan(self, mutate=None):
        p = ct.load_yaml(self.PLAN)
        if mutate:
            mutate(p["offline"])
        return p

    def run_plan(self, mutate=None):
        return ct.offline_plan(self.plan(mutate), os.path.dirname(os.path.dirname(self.PLAN)))

    def test_a_matching_block_passes_and_a_wrong_return_fails(self):
        self.assertEqual([i["result"] for i in self.run_plan()], ["pass"] * 5)
        items = self.run_plan(lambda o: o["steps"][0].update(returns=["Wrong"]))
        self.assertEqual([i["result"] for i in items], ["fail", "pass", "pass", "pass", "pass"])
        self.assertEqual(items[0]["label"], "Captured name is mocked")
        self.assertIn("expected [Wrong]", items[0]["why"])

    def test_an_unlisted_mock_stops_the_run_before_load(self):
        items = self.run_plan(lambda o: o["mocks"].update(loadstring={"returns": [1]}))
        self.assertEqual([i["result"] for i in items], ["fail"])
        self.assertIn("loadstring is not on the allow list", items[0]["why"])

    def test_the_block_is_checked_by_the_schema(self):
        self.assertEqual(ct.validate(self.plan()), [])
        self.assertTrue(ct.validate(self.plan(lambda o: o["steps"][0].update(bogus=1))))
        self.assertTrue(ct.validate(self.plan(lambda o: o["steps"].append({"label": "no action"}))))

    def test_the_toc_cannot_leave_the_addons_folder(self):
        with self.assertRaises(ValueError):
            self.run_plan(lambda o: o.update(toc="../../../../../../etc/hosts"))
        with self.assertRaises(ValueError):
            self.run_plan(lambda o: o.update(toc="/etc/hosts"))

    def test_each_action_takes_only_its_own_fields(self):
        ev = lambda o: o["steps"].append({"event": {"name": "MERCHANT_SHOW"}, "throws": "x"})
        self.assertTrue(ct.validate(self.plan(ev)))
        both = lambda o: o["steps"][0].update(throws="x")      # returns and throws together
        self.assertTrue(ct.validate(self.plan(both)))
        typo = lambda o: o["mocks"]["GetItemInfo"][0].update(retuns=["x"])
        self.assertTrue(ct.validate(self.plan(typo)))

    def test_compile_drops_the_block(self):
        with_block = self.plan()
        without = self.plan(); del without["offline"]
        self.assertEqual(ct.encode(ct.merge_sections(with_block)), ct.encode(ct.merge_sections(without)))
        self.assertNotIn("offline", ct.merge_sections(with_block))

    def test_a_plan_without_a_block_is_an_error(self):
        p = self.plan(); del p["offline"]
        with self.assertRaises(ValueError):
            ct.offline_plan(p, os.path.dirname(os.path.dirname(self.PLAN)))

    def covered(self):
        p = self.plan(); p["sections"][0]["steps"][0]["covers"] = ["First thing works"]
        return p

    def test_a_plan_with_covers_runs_with_the_specs_folder(self):
        specs = os.path.join(ROOT, "tests", "fixtures", "coverage", "openspec", "specs")
        items = ct.offline_plan(self.covered(), os.path.dirname(os.path.dirname(self.PLAN)), ct.plan_requirements(self.covered(), self.PLAN, specs))
        self.assertEqual([i["result"] for i in items], ["pass"] * 5)

    def test_a_plan_with_covers_and_no_specs_folder_exits_2(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "plan.yaml")
            with open(path, "w", encoding="utf-8") as f:
                f.write(json.dumps(self.covered()))
            args = [sys.executable, os.path.join(ROOT, "tools", "ct.py"), "offline", path, "--addons", os.path.dirname(os.path.dirname(self.PLAN))]
            out = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(out.returncode, 2, out.stderr)
            self.assertIn("covers needs the addon's openspec/specs folder", out.stderr)
            specs = os.path.join(ROOT, "tests", "fixtures", "coverage", "openspec", "specs")
            out = subprocess.run(args + ["--specs", specs], capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)

    def nil_plan(self, o):
        o["toc"] = "MockAddon/Hidden.toc"; o["mocks"] = {}; o["level"] = 2
        o["steps"] = [{"call": {"addon": "MockAddon", "entry": "missing_api"}, "returns": [False]}]

    def run_cli(self, manifests, *extra):
        # CT_TEST_MANIFESTS points census_manifests at the folder this test fills (default: tests/manifests).
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "plan.yaml")
            with open(path, "w", encoding="utf-8") as f:
                f.write(json.dumps(self.plan(self.nil_plan)))
            for name, m in manifests.items():
                os.makedirs(os.path.join(d, "m"), exist_ok=True)
                with open(os.path.join(d, "m", name), "w", encoding="utf-8") as f:
                    f.write(json.dumps(m))
            env = dict(os.environ, CT_TEST_MANIFESTS=os.path.join(d, "m"))
            args = [sys.executable, os.path.join(ROOT, "tools", "ct.py"), "offline", path, "--addons", os.path.dirname(os.path.dirname(self.PLAN))] + list(extra)
            return subprocess.run(args, capture_output=True, text=True, env=env)

    def test_a_block_without_level_runs_level_1_and_warns(self):
        def legacy(o):
            self.nil_plan(o); del o["level"]
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "plan.json")
            with open(path, "w", encoding="utf-8") as f:
                f.write(json.dumps(self.plan(legacy)))
            out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "ct.py"), "offline", path, "--addons",
                                  os.path.dirname(os.path.dirname(self.PLAN))], capture_output=True, text=True,
                                 env=dict(os.environ, CT_TEST_MANIFESTS=d))
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn(ct.OFFLINE_LEVEL_WARNING, out.stderr)
        self.assertIn("(interface 11507)", out.stderr)

    def test_the_report_lists_nil_reads_and_junit_carries_it_with_the_interface(self):
        out = self.run_cli({})
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertNotIn(ct.OFFLINE_LEVEL_WARNING, out.stderr)
        self.assertIn("Globals read as nil in this run (interface 16001):", out.stderr)
        self.assertIn("C_NotInThisClient", out.stderr)
        from xml.etree import ElementTree as ET
        suite = ET.fromstring(out.stdout)
        self.assertEqual({p.get("name"): p.get("value") for p in suite.find("properties")}, {"interface": "16001"})
        self.assertIn("C_NotInThisClient", suite.find("system-out").text)
        self.assertEqual(suite.get("failures"), "0")

    def test_a_matching_manifest_splits_present_from_absent(self):
        m = {"format": 1, "client": "forever", "build": "1.60.1.71091", "interface": 16001, "globals": {"io": "table", "Other": "function"}}
        out = self.run_cli({"forever-1.60.1.71091.json": m})
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("Present in census for build 1.60.1.71091: io", out.stderr)
        self.assertIn("Absent from census for build 1.60.1.71091: C_NotInThisClient", out.stderr)
        out = self.run_cli({"forever-1.60.1.71091.json": dict(m, insecure={"C_NotInThisClient": "table"})})
        self.assertIn("Set by addon code in census for build 1.60.1.71091: C_NotInThisClient", out.stderr)
        self.assertNotIn("Absent from census", out.stderr)
        from xml.etree import ElementTree as ET
        props = {p.get("name"): p.get("value") for p in ET.fromstring(out.stdout).find("properties")}
        self.assertEqual(props, {"interface": "16001", "build": "1.60.1.71091"})

    def test_two_builds_for_one_interface_stay_unclassified_until_build_picks_one(self):
        a = {"format": 1, "client": "forever", "build": "1.60.1.1", "interface": 16001, "globals": {"io": "table"}}
        b = dict(a, build="1.61.0.2", globals={"C_NotInThisClient": "table"})
        both = {"a.json": a, "b.json": b}
        out = self.run_cli(both)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("Interface 16001 matches multiple builds. Showing unclassified names.", out.stderr)
        self.assertNotIn("Present in census", out.stderr)
        out = self.run_cli(both, "--build", "1.61.0.2")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("Present in census for build 1.61.0.2: C_NotInThisClient", out.stderr)
        self.assertNotIn("matches multiple builds", out.stderr)
        self.assertEqual(self.run_cli(both, "--build", "9.9").returncode, 2)

    def test_schema_accepts_levels_1_to_5_only(self):
        for lv, ok in ((1, True), (2, True), (3, True), (4, True), (5, True), (6, False), ("2", False)):
            p = self.plan(lambda o: o.__setitem__("level", lv))
            self.assertEqual(not ct.validate(p), ok, lv)

    def life(self, o, level=3, **extra):
        o.clear(); o.update(toc="MockAddon/Life.toc", level=level, **extra)

    def test_reload_groups_and_saved_variables_need_level_3(self):
        reload = {"steps": [{"reload": True}]}
        groups = {"groups": [{"steps": [{"reload": True}]}]}
        saved = {"savedVariables": {"MockLifeDB": {"from": "saved"}}, "steps": []}
        for extra in (reload, groups, saved):
            self.assertEqual(ct.validate(self.plan(lambda o: self.life(o, 3, **extra))), [], extra)
            self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 2, **extra))), extra)
            no_level = lambda o: (self.life(o, 3, **extra), o.pop("level"))
            self.assertTrue(ct.validate(self.plan(no_level)), extra)
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 3, steps=[], groups=[{"steps": []}]))), "steps and groups")
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 3))), "neither steps nor groups")
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 3, steps=[{"reload": False}]))))

    def test_the_command_runs_groups_and_reports_each_step(self):
        groups = [{"label": "A", "steps": [{"call": {"addon": "MockAddon", "entry": "db"}, "returns": ["file"]}]},
                  {"label": "B", "steps": [{"reload": True}, {"call": {"addon": "MockAddon", "entry": "db"}, "returns": ["wrong"]}]}]
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "plan.json")
            with open(path, "w", encoding="utf-8") as f:
                f.write(json.dumps(self.plan(lambda o: self.life(o, 3, groups=groups))))
            out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "ct.py"), "offline", path, "--addons",
                                  os.path.dirname(os.path.dirname(self.PLAN))], capture_output=True, text=True,
                                 env=dict(os.environ, CT_TEST_MANIFESTS=d))
        self.assertEqual(out.returncode, 1, out.stderr)
        self.assertNotIn(ct.OFFLINE_LEVEL_WARNING, out.stderr)
        self.assertIn("offline: 2 passed, 1 failed", out.stderr)
        from xml.etree import ElementTree as ET
        suite = ET.fromstring(out.stdout)
        self.assertEqual(suite.get("failures"), "1")
        self.assertEqual([(c.get("classname"), c.get("name")) for c in suite.iter("testcase")],
                         [("offline.1.1", "A: call 1"), ("offline.2.1", "B: reload 1"), ("offline.2.2", "B: call 2")])

    def test_a_wait_step_needs_level_4(self):
        wait = [{"wait": 2}]
        self.assertEqual(ct.validate(self.plan(lambda o: self.life(o, 4, steps=wait))), [])
        self.assertEqual(ct.validate(self.plan(lambda o: self.life(o, 4, groups=[{"steps": wait}]))), [])
        for lv in (1, 2, 3):
            self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, lv, steps=wait))), lv)
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 3, groups=[{"steps": wait}]))))
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 4, steps=[{"wait": -1}]))))
        self.assertTrue(ct.validate(self.plan(lambda o: self.life(o, 4, steps=[{"wait": "2"}]))))

    def test_the_command_runs_a_level_4_block_with_a_wait(self):
        steps = [{"call": {"addon": "MockAddon", "entry": "after", "args": [2]}, "returns": [True]}, {"wait": 2},
                 {"call": {"addon": "MockAddon", "entry": "fired"}, "returns": [3]}, {"event": {"name": "BAG_UPDATE", "args": [0]}}]
        items = self.run_plan(lambda o: (o.clear(), o.update(toc="MockAddon/Clock.toc", level=4, steps=steps)))
        self.assertEqual([(i["step"], i["label"], i["result"]) for i in items],
                         [("offline.1", "call 1", "pass"), ("offline.2", "wait 2", "pass"), ("offline.3", "call 3", "pass"), ("offline.4", "event 4", "pass")])
        bad = self.run_plan(lambda o: (o.clear(), o.update(toc="MockAddon/Clock.toc", level=4, steps=[{"event": {"name": "NOT_AN_EVENT"}}])))
        self.assertEqual([(i["step"], i["result"]) for i in bad], [("offline.0", "fail")])
        self.assertIn("the client has no event NOT_AN_EVENT", bad[0]["why"])

    def test_a_block_without_groups_keeps_its_step_ids(self):
        self.assertEqual([i["step"] for i in self.run_plan()], ["offline.%d" % n for n in range(1, 6)])

    def test_groups_get_their_own_load_and_ids(self):
        call = lambda entry, ret, label=None, args=None: dict({"call": {"addon": "MockAddon", "entry": entry, "args": args or []}, "returns": ret},
                                                             **({"label": label} if label else {}))
        groups = [{"label": "Mocked A", "mocks": {"GetItemInfo": {"returns": ["A"]}},
                   "steps": [call("item", ["A"], "Item is A"), call("flag", ["set"], args=["set"])]},
                  {"savedVariables": {"MockLifeDB": {"from": "saved"}},
                   "steps": [call("flag", ["none"]), call("db", ["saved"]), {"reload": True}, call("db", ["saved"])]}]
        items = self.run_plan(lambda o: self.life(o, 3, mocks={"GetItemInfo": {"returns": ["Block"]}}, groups=groups))
        self.assertEqual([(i["step"], i["result"]) for i in items],
                         [("offline.1.1", "pass"), ("offline.1.2", "pass"), ("offline.2.1", "pass"), ("offline.2.2", "pass"),
                          ("offline.2.3", "pass"), ("offline.2.4", "pass")], items)
        self.assertEqual(items[0]["label"], "Mocked A: Item is A")
        self.assertEqual(items[2]["label"], "group 2: call 1")
        self.assertEqual(items[4]["label"], "group 2: reload 3")

    def test_build_never_picks_a_manifest_of_another_interface(self):
        era = {"format": 1, "client": "era", "build": "1.15.9.1", "interface": 11509, "globals": {"io": "table"}}
        fv = {"format": 1, "client": "forever", "build": "1.61.0.2", "interface": 16001, "globals": {"io": "table"}}
        out = self.run_cli({"a.json": era, "b.json": fv}, "--build", "1.15.9.1")
        self.assertEqual(out.returncode, 2, out.stderr)
        self.assertIn("no census manifest for build 1.15.9.1 with interface 16001", out.stderr)
        out = self.run_cli({"a.json": era, "b.json": fv}, "--build", "1.61.0.2")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("Present in census for build 1.61.0.2", out.stderr)

    def test_the_build_is_returned_when_no_global_was_read_as_nil(self):
        m = {"build": "1.60.1.1", "interface": 16001, "globals": {}}
        text, build = ct.nil_read_report(16001, [], [m])
        self.assertEqual(build, "1.60.1.1")
        self.assertIn("none", text)

    def test_cli_prints_junit_and_sets_the_exit_code(self):
        out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "ct.py"), "offline", self.PLAN, "--addons", os.path.dirname(os.path.dirname(self.PLAN))], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('failures="0"', out.stdout)
        self.assertIn("offline: 5 passed, 0 failed", out.stderr)


class EntryCall(unittest.TestCase):
    @staticmethod
    def plan(call, auto=True):
        step = {"id": "e.1", "title": "T", "action": {"kind": "manual", "text": "t"}, "expect": "e", "verify": ["assertions"],
                "assertions": [{"kind": "log", "source": "facts", "equals": "[KeepThat] entry.add=5"}], "call": call}
        if auto:
            step["auto"] = True
        return {"ct": 1, "addon": "KeepThat", "title": "T",
                "logs": {"facts": {"global": "CheckThatDB", "path": "global.facts", "format": "strings"}},
                "sections": [{"id": "s", "title": "S", "steps": [step]}]}

    def test_a_call_on_an_auto_step_is_valid_and_travels_in_the_compiled_plan(self):
        p = self.plan({"addon": "KeepThat", "entry": "add", "args": [2, 3, "x", True]})
        self.assertEqual(ct.validate(p), [])
        self.assertEqual(ct.merge_sections(p)["sections"][0]["steps"][0]["call"]["entry"], "add")

    def test_a_call_needs_an_auto_step_literal_args_and_known_fields(self):
        self.assertTrue(ct.validate(self.plan({"addon": "KeepThat", "entry": "add"}, auto=False)))
        self.assertTrue(ct.validate(self.plan({"addon": "KeepThat", "entry": "add", "args": [1, 2, 3, 4, 5, 6, 7, 8, 9]})))
        self.assertTrue(ct.validate(self.plan({"addon": "KeepThat", "entry": "add", "args": [{}]})))
        self.assertTrue(ct.validate(self.plan({"addon": "KeepThat", "entry": "add", "extra": 1})))
        self.assertTrue(ct.validate(self.plan({"addon": "KeepThat"})))
        self.assertTrue(ct.validate(self.plan({"addon": "bad name", "entry": "add"})))


@unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
class ReplayFixture(unittest.TestCase):
    FIXTURE = os.path.join(ROOT, "tests", "fixtures", "replay-sv")

    @staticmethod
    def plan(*assertions):
        steps = [{"id": "r.%d" % i, "title": "T", "action": {"kind": "manual", "text": "Check the version."}, "expect": "e",
                  "verify": ["player", "assertions"], "assertions": [a]} for i, a in enumerate(assertions, 1)]
        return {"ct": 1, "addon": "KeepThat", "title": "Replay",
                "logs": {"debug": {"global": "KeepThatDB", "path": "global.log", "format": "strings"}},
                "sections": [{"id": "s", "title": "S", "steps": steps}]}

    @staticmethod
    def log(**kw):
        return dict({"kind": "log", "source": "debug"}, **kw)

    def results(self, *assertions, **kw):
        items, notes = ct.replay_plan(self.plan(*assertions), self.FIXTURE, **kw)
        return [i["result"] for i in items], notes

    def test_a_typo_in_a_check_fails_and_the_corrected_plan_passes(self):
        self.assertEqual(self.results(self.log(contains="second thng done"))[0], ["fail"])
        self.assertEqual(self.results(self.log(contains="second thing done"))[0], ["pass"])
        self.assertEqual(self.results(self.log(pattern="^second .* done$"), self.log(equals="[kt] loaded"))[0], ["pass", "pass"])

    def test_a_forbidden_line_in_the_log_fails(self):
        self.assertEqual(self.results(self.log(contains="second thing done", absent=True))[0], ["fail"])

    def test_a_check_that_needs_the_step_window_never_passes(self):
        res = self.results(self.log(contains="game call failed", absent=True), self.log(contains="loaded", count={"max": 5}),
                           self.log(contains="loaded", count={"exactly": 1}))[0]
        self.assertEqual(res, ["skipped"] * 3)

    def test_a_fact_is_judged_and_a_diagnostic_or_state_check_is_not_a_pass(self):
        fact = lambda **kw: dict({"kind": "fact", "source": "debug", "addon": "kt", "key": "bag", "op": "eq", "value": 4}, **kw)
        self.assertEqual(self.results(fact())[0], ["pass"])
        self.assertEqual(self.results(fact(value=5))[0], ["fail"])
        state = {"kind": "state", "probe": "addon-loaded", "name": "KeepThat", "op": "eq", "value": True}
        self.assertEqual(self.results(state, self.log(contains="never written", diagnostic=True))[0], ["skipped"])
        item = ct.replay_plan(self.plan(state), self.FIXTURE)[0][0]
        self.assertEqual(item["why"], "a state probe needs the game")

    def test_the_report_names_the_fixture_age_and_a_stale_digest(self):
        import datetime
        _, notes = self.results(self.log(contains="loaded"), today=datetime.date(2026, 11, 24))
        self.assertIn("fixture recorded 2026-11-20 (4 days ago)", notes)
        self.assertTrue(any(n.startswith("stale fixture: it was recorded with plan digest 00000000") for n in notes), notes)
        with tempfile.TemporaryDirectory() as d:
            shutil.copy(os.path.join(self.FIXTURE, "KeepThatDB.lua"), d)
            self.assertTrue(any("fixture.json is missing" in n for n in ct.replay_plan(self.plan(self.log(contains="loaded")), d)[1]))

    def test_the_command_prints_junit_and_exits_non_zero_on_a_failed_check(self):
        import yaml
        with tempfile.TemporaryDirectory() as d:
            for text, rc in (("second thng done", 1), ("second thing done", 0)):
                p = os.path.join(d, "p.yaml")
                with open(p, "w") as f:
                    yaml.safe_dump(self.plan(self.log(contains=text)), f)
                out = io.StringIO()
                with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(ct.main(["replay", p, "--sv", self.FIXTURE]), rc, text)
                self.assertIn('failures="%d"' % rc, out.getvalue())


class LogCaps(unittest.TestCase):
    """Every plan for an addon declares the cap of the addon's own debug log (docs/contracts.md names the source line)."""
    def test_plans_declare_the_cap_the_tool_knows(self):
        import glob
        for addon, logs in ct.LOGS.items():
            self.assertIsInstance(logs["debug"].get("cap"), int, addon)
        paths = glob.glob(os.path.join(ROOT, "plans", "*.yaml")) + glob.glob(os.path.join(ROOT, "plans", "full", "*.yaml")) + [os.path.join(ROOT, "tests", "fixtures", "keepthat.yaml")]
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

    def test_skill_states_the_new_draft_review_and_bundle_rules(self):
        with open(os.path.join(ROOT, "skills", "ct-test-plan", "SKILL.md"), encoding="utf-8") as f:
            text = f.read()
        for needle in ("auto or manual", "end its `expect` text with the press it needs", "`timeout` to 120",
                       "own result press writes", "replay-flow", "stale", "make install-skill",
                       "fake game cannot prove", "at most 25 steps", "Plan sets by area", "test-settings mode", "Debug goes on first"):
            self.assertIn(needle, text)

    def test_step_cannot_assert_its_own_result_line(self):
        for key, text in (("contains", "[ct] step a.1 pass"), ("equals", "[ct] step a.1 pass")):
            p = good(); p["sections"][0]["steps"][0]["assertions"] = [{"kind": "log", "source": "debug", key: text}]
            self.assertTrue(any("asserts its own result line" in e for e in ct.validate(p)), key)
        p = good()   # another step's line, and a longer id that only shares the prefix, are fine
        p["sections"][0]["steps"][1].update({"verify": ["player", "assertions"], "assertions": [{"kind": "log", "source": "debug", "contains": "[ct] step a.1 pass", "scope": "session"}]})
        p["sections"][0]["steps"][0]["assertions"] = [{"kind": "log", "source": "debug", "contains": "[ct] step a.10 pass"}]
        self.assertEqual(ct.validate(p), [])

    def test_first_step_without_a_version_check_warns(self):
        p = good()
        self.assertIn("a.1: the first step does not check the version", ct.version_warning(p))
        p["sections"][0]["steps"][0]["assertions"] = [{"kind": "fact", "source": "debug", "addon": "KeepThat", "key": "version", "op": "ge", "value": "0.17.0"}]
        self.assertIsNone(ct.version_warning(p))
        p = good(); p["sections"][0]["steps"][0]["title"] = "Check the version"
        self.assertIsNone(ct.version_warning(p))

    @staticmethod
    def sized(sections):
        """A valid plan with sections of the given step counts (ids s0, s1, ...)."""
        p = good()
        step = p["sections"][0]["steps"][1]
        p["sections"] = [dict(p["sections"][0], id="s%d" % i, steps=[dict(step, id="s%d.%d" % (i, j)) for j in range(n)])
                         for i, n in enumerate(sections)]
        return p

    def test_a_plan_over_25_steps_or_a_section_over_10_warns(self):
        self.assertEqual(ct.size_warnings(self.sized([10, 10, 5])), [], "25 steps and sections of 10 are the limit")
        got = ct.size_warnings(self.sized([10, 10, 6]))
        self.assertEqual(len(got), 1)
        self.assertIn("the plan has 26 steps (more than 25)", got[0])
        self.assertIn("Plan sets", got[0])
        got = ct.size_warnings(self.sized([11, 10, 5]))
        self.assertEqual(len(got), 2, "a long section and a long plan are both reported")
        self.assertIn("section s0 has 11 steps", got[0])
        self.assertIn("the plan has 26 steps", got[1])
        got = ct.size_warnings(self.sized([11, 2]))
        self.assertEqual(got, ["section s0 has 11 steps (more than 10): split it, or move steps a unit test already proves out of the plan"])

    def test_size_counts_each_case_as_a_step(self):
        def with_cases(n):
            p = self.sized([n])
            p["sections"][0]["steps"][0].update({"title": "{{n}}", "cases": [{"id": c, "vars": {"n": c}} for c in ("x", "y")]})
            self.assertEqual(ct.validate(p), [])
            return p
        self.assertEqual(ct.size_warnings(with_cases(9)), [], "9 steps, one of them 2 cases, are 10 on the card")
        self.assertEqual(ct.size_warnings(with_cases(10)),
                         ["section s0 has 11 steps (more than 10): split it, or move steps a unit test already proves out of the plan"])

    def test_size_warning_prints_and_validate_still_succeeds(self):
        import contextlib, io, yaml
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "p.yaml")
            with open(path, "w") as f:
                yaml.safe_dump(self.sized([10, 10, 10]), f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = ct.main(["validate", path])
        self.assertEqual(rc, 0)
        self.assertIn("warning: the plan has 30 steps (more than 25)", out.getvalue())

    def run_cli(self, args):
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = ct.main(args)
        return rc, out.getvalue()

    def test_size_warning_waits_for_the_errors_to_be_fixed(self):
        import yaml
        p = self.sized([10, 10, 10])
        p["sections"][0]["steps"][0]["bogus"] = 1
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "p.yaml")
            with open(path, "w") as f:
                yaml.safe_dump(p, f)
            rc, out = self.run_cli(["validate", path])
        self.assertEqual(rc, 1)
        self.assertNotIn("more than 25", out)

    def test_from_md_prints_the_size_warning(self):
        with tempfile.TemporaryDirectory() as d:
            md = os.path.join(d, "p.md")
            with open(md, "w") as fh:
                fh.write("# T\n\n## 1. Sec\n\n" + "".join("- [ ] Do %d.\n  Check: it works.\n  Log: none.\n" % i for i in range(11)))
            rc, out = self.run_cli(["from-md", md, "--addon", "KeepThat", "-o", os.path.join(d, "p.yaml")])
        self.assertEqual(rc, 0, out)
        self.assertIn("has 11 steps (more than 10)", out)

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
                plan["sections"][0]["steps"][2]["reviewer"] = "Compare the totals."
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
        step = plan["sections"][0]["steps"][1]
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


class ClientSlice(unittest.TestCase):
    """tools/clients/*.json are committed slices of a census: game-defined names only (see tools/client_slice.py)."""
    KEYS = ["format", "client", "build", "interface", "source", "functions", "namespaces", "widgets"]

    def test_committed_slices_hold_only_the_reviewed_keys(self):
        for client, interface in (("era", 11509), ("forever", 16001)):
            with open(os.path.join(ROOT, "tools", "clients", client + ".json"), encoding="utf-8") as f:
                s = json.load(f)
            self.assertEqual(list(s), self.KEYS + ["templates"], client)   # templates: added by tools/template_slice.py, read from Blizzard's source
            self.assertEqual((s["format"], s["client"], s["interface"]), (1, client, interface))
            self.assertTrue(all(isinstance(n, str) for n in s["functions"]))
            self.assertTrue(all(k.startswith("C_") and all(isinstance(n, str) for n in v) for k, v in s["namespaces"].items()))
            self.assertTrue(all(isinstance(v, list) for v in s["widgets"].values()))
            self.assertTrue(all(sorted(v) == ["keys", "methods"] and all(isinstance(n, str) for n in v["methods"] + v["keys"]) for v in s["templates"].values()))

    def test_the_slice_leaves_out_tester_data(self):
        sys.path.insert(0, os.path.join(ROOT, "tools"))
        import client_slice
        m = {"format": 1, "client": "era", "build": "1.15.9.1", "interface": 11509, "date": "2026-01-01",
             "addons": ["Private"], "globals": {"GetMoney": "function", "SOME_TEXT": "string", "SomeFrame": "table"},
             "insecure": {"PrivateAddonFunc": "function", "HookedBlizzard": "function"},
             "tables": {"C_Item": {"GetItemInfo": "function", "flag": "boolean"}, "PrivateTable": {"x": "function"}},
             "widgets": {"Frame": ["SetPoint", "Show"]}}
        text = client_slice.render(m, client_slice.build(m, {"HookedBlizzard"}))
        s = json.loads(text)
        self.assertEqual(list(s), self.KEYS)
        self.assertEqual(s["functions"], ["GetMoney", "HookedBlizzard"])
        self.assertEqual(s["namespaces"], {"C_Item": ["GetItemInfo"]})
        for private in ("Private", "PrivateAddonFunc", "PrivateTable", "SOME_TEXT"):
            self.assertNotIn(private, text)

    def test_an_unfiltered_census_needs_unfiltered_ok(self):
        with tempfile.TemporaryDirectory() as d:
            m = {"format": 1, "client": "era", "build": "1.15.9.1", "interface": 11509, "date": "2026-01-01", "unfiltered": True,
                 "globals": {"GetMoney": "function"}, "tables": {}, "widgets": {}}
            path = os.path.join(d, "m.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(m, f)
            os.makedirs(os.path.join(d, "src"))
            tool = [sys.executable, os.path.join(ROOT, "tools", "client_slice.py"), path, os.path.join(d, "src")]
            r = subprocess.run(tool, capture_output=True, text=True)
            self.assertNotEqual(r.returncode, 0); self.assertIn("unfiltered", r.stderr)
            r = subprocess.run(tool + ["--unfiltered-ok", "--review", os.path.join(d, "r.json")], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(json.loads(r.stdout)["functions"], ["GetMoney"])
            with open(os.path.join(d, "r.json"), encoding="utf-8") as f:
                self.assertEqual(json.load(f)["functions not named in Blizzard source"], ["GetMoney"])


class InstallSkill(unittest.TestCase):
    SRC = os.path.join(ROOT, "skills", "ct-test-plan")
    BUNDLE = ("tools/ct.py", "schema/test-plan.schema.json", "docs/test-plan.md", "docs/debug-logging.md",
              "openspec/specs/test-plan-format/spec.md", "CheckThat/Model/Plan.lua", "CheckThat/Model/Json.lua", "CheckThat/Model/Evidence.lua", "CheckThat/UI/Card.lua", "CheckThat/CheckThat_Vanilla.toc", "tools/sv2json.lua", "tools/replay_sv.lua",
              "tools/ct", "tools/entry_runner.lua", "tests/harness.lua", "tests/replay.lua", "tests/replay_plan.lua", "docs/authoring-plans.md",
              "requirements.txt", "tools/ct_tui.py", "requirements-tui.txt", "tools/events/era.json", "tools/events/forever.json", "tools/clients/era.json", "tools/clients/forever.json",
              "tests/manifests/README.md")
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

    def test_census_manifests_are_never_bundled(self):
        planted = os.path.join(ROOT, "tests", "manifests", "zz-bundle-test.json")  # ignored by Git, removed below
        with open(planted, "w", encoding="utf-8") as f:
            f.write('{"format": 1, "addons": ["Private"]}')
        try:
            with tempfile.TemporaryDirectory() as d:
                self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
                self.assertEqual(os.listdir(os.path.join(d, "ct-test-plan", "ct", "tests", "manifests")), ["README.md"])
            with tempfile.TemporaryDirectory() as d:
                r = subprocess.run(["make", "build-plugin", "PLUGIN_DIR=" + d], cwd=ROOT, capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(os.listdir(os.path.join(d, "skills", "plan", "ct", "tests", "manifests")), ["README.md"])
        finally:
            os.remove(planted)

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

    @unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
    def test_installed_tools_run_without_the_checkout(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1").returncode, 0)
            dest = os.path.join(d, "ct-test-plan")
            r = subprocess.run([sys.executable, os.path.join(dest, "ct", "tools", "ct.py"), "validate",
                                os.path.join(dest, "example.yaml")], capture_output=True, text=True, cwd=d)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ok", r.stdout)
            fx = os.path.join(d, "fx"); os.makedirs(fx)
            shutil.copy(os.path.join(ROOT, "tests", "fixtures", "replay-sv", "KeepThatDB.lua"), fx)
            rp = subprocess.run([sys.executable, os.path.join(dest, "ct", "tools", "ct.py"), "replay", os.path.join(dest, "example.yaml"), "--sv", fx],
                                capture_output=True, text=True, cwd=d)   # the bundle holds the luajit driver and Evidence.lua
            self.assertIn(rp.returncode, (0, 1), rp.stdout + rp.stderr)
            self.assertIn("<testsuite ", rp.stdout)
            v = subprocess.run([sys.executable, os.path.join(dest, "ct", "tools", "ct_tui.py")], capture_output=True, text=True, cwd=d)   # no terminal, no Textual needed
            self.assertEqual(v.returncode, 2, v.stdout + v.stderr)
            self.assertIn("needs a terminal", v.stderr)

    @unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
    def test_installed_replay_and_offline_run_from_another_folder(self):
        # The bundle must replay a plan and run an offline block with no CheckThat checkout beside it.
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1", BIN_DIR=os.path.join(d, "bin")).returncode, 0)
            ctpy = os.path.join(d, "ct-test-plan", "ct", "tools", "ct.py")
            work = os.path.join(d, "work"); os.makedirs(work)
            run = lambda *args: subprocess.run([sys.executable, ctpy] + list(args), capture_output=True, text=True, cwd=work)
            example = os.path.join(d, "ct-test-plan", "example.yaml")
            r = run("replay-flow", example)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("replay ok", r.stdout)
            fx = os.path.join(d, "fixtures"); shutil.copytree(os.path.join(ROOT, "tests", "fixtures"), fx)
            r = run("offline", os.path.join(fx, "offline-plan", "plan.yaml"), "--addons", fx)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("offline: 5 passed, 0 failed", r.stderr)
            self.assertEqual(os.listdir(work), [], "nothing is written to the working folder")

    @unittest.skipIf(os.name == "nt", "the launcher is a shell script and the link needs a POSIX shell")
    def test_bin_dir_links_a_launcher_that_finds_the_skill_python(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.make(d, SKILL_NO_VENV="1", BIN_DIR=os.path.join(d, "bin")).returncode, 0)
            py = os.path.join(d, "ct-test-plan", ".venv", "bin"); os.makedirs(py)
            with open(os.path.join(py, "python"), "w") as f:   # the skill's private Python
                f.write('#!/bin/sh\nexec "%s" "$@"\n' % sys.executable)
            os.chmod(os.path.join(py, "python"), 0o755)
            r = subprocess.run([os.path.join(d, "bin", "ct"), "validate", os.path.join(d, "ct-test-plan", "example.yaml")],
                               capture_output=True, text=True, cwd=d, env=dict(os.environ, PATH="/usr/bin:/bin"))
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn("ok", r.stdout)

    def test_bin_dir_is_refused_when_it_is_unexpanded_or_inside_the_checkout(self):
        with tempfile.TemporaryDirectory() as d:
            for bad in ("~/x", os.path.join(ROOT, "zz-bin-test")):
                r = self.make(d, SKILL_NO_VENV="1", BIN_DIR=bad)
                self.assertNotEqual(r.returncode, 0, bad)
                self.assertIn("BIN_DIR", r.stderr)
            shutil.rmtree(os.path.join(ROOT, "zz-bin-test"), ignore_errors=True)

    @unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
    def test_replay_flow_runs_each_client_and_every_step_runs_on_one(self):
        p = good(); p["sections"][0]["clients"] = ["classic-era"]
        code, text = ct.replay_flow(p)
        self.assertEqual(code, 0, text)
        self.assertIn("== classic-era", text); self.assertIn("== forever-camelot", text)
        self.assertNotIn("no client ran", text)

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


class SVReader(unittest.TestCase):
    FIXTURES = sorted(glob.glob(os.path.join(ROOT, "tests", "fixtures", "sv-edge", "*.lua")) + glob.glob(os.path.join(ROOT, "tests", "fixtures", "replay-sv", "*.lua")))

    def read(self, text):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "X.lua")
            with open(p, "wb") as fh:
                fh.write(text if isinstance(text, bytes) else text.encode())
            return ct.sv_text(p)

    def test_there_are_fixtures(self):
        self.assertGreaterEqual(len(self.FIXTURES), 3)

    def test_string_escapes_and_numbers(self):
        self.assertEqual(self.read(r'A = "q\"b\\c\n\65\x41\z   d"'), r'{"A":"q\"b\\c\nAAd"}')
        self.assertEqual(self.read("A = { 1e15, 999999999999999, 0.5, -3, 0x10, 1e300 }"), '{"A":[1e+15,999999999999999,0.5,-3,16,1e+300]}')
        self.assertEqual(self.read(r'A = "\195\169\240\159\152\128\1"'), r'{"A":"\u00e9\ud83d\ude00\u0001"}')

    def test_tables_follow_sv2json(self):
        self.assertEqual(self.read("A = {}"), '{"A":[]}')
        self.assertEqual(self.read("A = { 1, 2, x = true }"), '{"A":{"1":1,"2":2,"x":true}}')
        self.assertEqual(self.read('A = { [3] = "c", [1] = "a" }'), '{"A":{"1":"a","3":"c"}}')
        self.assertEqual(self.read("A = { [true] = 1, [1] = 2 }"), '{"A":{"1":2,"true":1}}')

    def test_bad_files_raise(self):
        for bad in ("A = {", 'A = "x', "A = 1 +", "A = f()", r"A = 'a\qb'"):
            with self.assertRaises(ct.SVError, msg=bad):
                self.read(bad)

    @unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
    def test_same_json_as_luajit_on_every_fixture(self):
        for path in self.FIXTURES:
            r = subprocess.run(["luajit", os.path.join(ROOT, "tools", "sv2json.lua"), path], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(ct.sv_text(path) + "\n", r.stdout, path)


class Census(unittest.TestCase):
    BODY = ('CheckThatDB = {["global"] = {["census"] = {["build"] = "1.15.9.70576", ["interface"] = 11509, ["date"] = "2026-11-25", '
            '["addons"] = {"CheckThat", "Blizzard_Foo", "SomeAddon"}, '
            '["globals"] = {["CreateFrame"] = "function", ["MenuUtil"] = "table", ["Blizzard_FooX"] = "table", ["SomeAddonLike"] = "table"}, '
            '["truncated"] = {"MenuUtil"}, '
            '["tables"] = {["MenuUtil"] = {["CreateContextMenu"] = "function"}}, '
            '["widgets"] = {["Frame"] = {"SetPoint", "ClearAllPoints"}}, ["unavailable"] = {}}}}\n')

    def tree(self, body):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write(body)
        return d

    def args(self, d, **kw):
        return type("A", (), dict({"src": os.path.join(d, "src"), "wow": None, "o": os.path.join(d, "out"), "diff": None}, **kw))

    def run_census(self, a):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ct.cmd_census(a)
        return code, out.getvalue(), err.getvalue()

    def test_export_writes_a_manifest_for_the_stored_census(self):
        d = self.tree(self.BODY)
        code, out, _ = self.run_census(self.args(d))
        path = os.path.join(d, "out", "era-1.15.9.70576.json")
        self.assertEqual((code, out), (0, path + "\n"))
        with open(path) as fh: m = json.load(fh)
        self.assertEqual((m["format"], m["client"], m["build"], m["interface"], m["date"]), (1, "era", "1.15.9.70576", 11509, "2026-11-25"))
        self.assertEqual(m["globals"], {"CreateFrame": "function", "MenuUtil": "table", "Blizzard_FooX": "table", "SomeAddonLike": "table"},
                         "the game already left addon names out: nothing is guessed from folder names")
        self.assertEqual(m["truncated"], ["MenuUtil"])
        self.assertEqual(m["tables"], {"MenuUtil": {"CreateContextMenu": "function"}})
        self.assertEqual(m["widgets"], {"Frame": ["ClearAllPoints", "SetPoint"]})
        self.assertEqual((m["unavailable"], m["addons"]), ([], ["CheckThat", "SomeAddon"]))

    def test_unfiltered_census_drops_names_that_start_with_an_addon_folder(self):
        d = self.tree(self.BODY.replace('["unavailable"] = {}', '["unavailable"] = {}, ["unfiltered"] = true')
                      .replace('["SomeAddonLike"] = "table"}', '["SomeAddonLike"] = "table", ["SomeAddonDB"] = "table"}')
                      .replace('["CreateContextMenu"] = "function"}}', '["CreateContextMenu"] = "function"}, ["SomeAddonDB"] = {["x"] = "table"}}'))
        code, out, _ = self.run_census(self.args(d))
        with open(out.strip()) as fh: m = json.load(fh)
        self.assertEqual(m["globals"], {"CreateFrame": "function", "MenuUtil": "table", "Blizzard_FooX": "table"})
        self.assertEqual(m["tables"], {"MenuUtil": {"CreateContextMenu": "function"}})

    def test_forever_client_from_the_interface(self):
        d = self.tree(self.BODY.replace("11509", "16001").replace("1.15.9.70576", "2.5.5.1"))
        code, out, _ = self.run_census(self.args(d))
        self.assertEqual(os.path.basename(out.strip()), "forever-2.5.5.1.json")

    def test_missing_census_says_how_to_make_one(self):
        for body in ("CheckThatDB = {}\n", 'CheckThatDB = {["global"] = {["census"] = {}}}\n'):
            code, out, err = self.run_census(self.args(self.tree(body)))
            self.assertEqual((code, out), (1, ""))
            self.assertIn("Run /ct census, wait for completion, type /reload, then copy SavedVariables again.", err)

    def test_damaged_file_is_an_error(self):
        code, _, err = self.run_census(self.args(self.tree("CheckThatDB = {\n")))
        self.assertEqual(code, 1)
        self.assertIn("could not decode", err)

    def test_diff_lists_added_removed_and_changed(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        def write(name, m):
            p = os.path.join(d, name); 
            with open(p, "w") as fh: json.dump(m, fh)
            return p
        old = write("old.json", {"globals": {"Keep": "function", "Gone": "table", "Shift": "table"}, "tables": {"C_X": {"A": "function"}}, "widgets": {"Frame": ["SetPoint"]}})
        new = write("new.json", {"globals": {"Keep": "function", "New": "function", "Shift": "function"}, "tables": {"C_X": {"A": "function", "B": "function"}}, "widgets": {"Frame": ["SetPoint", "SetThing"]}})
        code, out, _ = self.run_census(self.args(d, diff=[old, new]))
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines(), ["+ global New (function)", "+ member C_X.B (function)", "+ method Frame:SetThing (function)",
                                           "- global Gone (table)", "~ global Shift: table -> function", "3 added, 1 removed, 1 changed type"])
        code, _, err = self.run_census(self.args(d, diff=[old, os.path.join(d, "none.json")]))
        self.assertEqual(code, 1); self.assertIn("cannot read a manifest", err)


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

    def plan_tree(self, d, plan):
        """A fake WTF with CheckThat's file, a made-up addon whose file name differs from its global, and an unrelated addon."""
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        files = {"CheckThat.lua": 'CheckThatDB = {["runs"] = {["R-1"] = {["revision"] = 1, ["steps"] = {}, ["order"] = {}}}}\n',
                 "MadeUpThing.lua": 'MadeUpDB = {["log"] = {"x"}}\nMadeUpCharDB = {}\n',
                 "Unrelated.lua": 'UnrelatedDB = {}\n'}
        for name, body in files.items():
            with open(os.path.join(sv, name), "w") as fh:
                fh.write(body)
        pp = os.path.join(d, "plan.yaml")
        with open(pp, "w") as fh:
            json.dump(plan, fh)
        return type("A", (), {"src": os.path.join(d, "src"), "dest": os.path.join(d, "dest"), "shots": None, "plan": pp})

    def test_plan_names_the_files_to_collect(self):
        plan = {"addon": "MadeUp", "logs": {"debug": {"global": "MadeUpDB", "path": "log", "format": "strings"}}}
        with tempfile.TemporaryDirectory() as d:
            args = self.plan_tree(d, plan)
            with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(ct.cmd_collect(args), 0)
            self.assertEqual(sorted(f.split(".")[0] for f in os.listdir(os.path.join(args.dest, "sv"))), ["Account__A__SavedVariables__CheckThat", "Account__A__SavedVariables__MadeUpThing"])
            self.assertEqual(err.getvalue(), "")
            self.assertRegex(out.getvalue(), r"source: Account.A.SavedVariables.MadeUpThing\.lua, modified \d{4}-\d\d-\d\d \d\d:\d\d:\d\d, \d+s ago")
            args.plan = None   # no plan: the default list, which names neither the made-up addon nor the unrelated one
            shutil.rmtree(args.dest)
            with contextlib.redirect_stdout(io.StringIO()):
                ct.cmd_collect(args)
            self.assertEqual(len(os.listdir(os.path.join(args.dest, "sv"))), 1)

    def test_a_plan_global_no_file_defines_is_reported(self):
        plan = {"addon": "MadeUp", "logs": {"a": {"global": "MadeUpDB"}, "b": {"global": "GhostDB"}}}
        with tempfile.TemporaryDirectory() as d:
            args = self.plan_tree(d, plan)
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(ct.cmd_collect(args), 0)
            self.assertIn("GhostDB", err.getvalue())
            self.assertNotIn("MadeUpDB", err.getvalue())

    def test_shot_slack_widens_or_narrows_the_window(self):
        files = (("edge.jpg", 1062), ("far.jpg", 1065))   # attempt a runs 1000 to 1060
        for slack, copied, loose in ((2, ["a__edge.jpg"], 1), (0, [], 2), (10, ["a__edge.jpg", "a__far.jpg"], 0)):
            with tempfile.TemporaryDirectory() as d:
                shots, dest, args = self.shot_setup(d, files)
                args.shot_slack = slack
                with contextlib.redirect_stdout(io.StringIO()):
                    ct.cmd_collect(args)
                got = os.path.join(dest, "runs", "R-1", "shots")
                self.assertEqual(sorted(f for f in (os.listdir(got) if os.path.isdir(got) else []) if f.startswith("a__")), copied, slack)
                self.assertEqual(len(ct.collect_shots(dest, shots, slack=slack)[1]), loose, slack)

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

    def test_find_wow_in_the_usual_place(self):
        with tempfile.TemporaryDirectory() as d:
            sv = os.path.join(d, "World of Warcraft", "_forever_", "WTF", "Account", "A", "SavedVariables"); os.makedirs(sv)
            with open(os.path.join(sv, "CheckThat.lua"), "w", encoding="utf-8") as fh:
                fh.write('CheckThatDB = {["runs"] = {["R-9"] = {["revision"] = 1, ["steps"] = {}, ["order"] = {}}}}\n')
            dest = os.path.join(d, "dest")
            args = type("A", (), {"src": None, "wow": None, "dest": dest, "shots": None})
            old_env, old_src = os.environ.get("ProgramFiles"), ct.default_src
            ct.default_src = lambda: os.path.join(d, "none")
            try:
                os.environ["ProgramFiles"] = os.path.join(d, "empty")
                with self.assertRaises(SystemExit) as e:   # nothing found: the message names the flags
                    ct.cmd_collect(args)
                self.assertIn("--wow", str(e.exception))
                os.environ["ProgramFiles"] = d
                self.assertEqual(ct.find_wow(), os.path.join(d, "World of Warcraft"))
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(ct.cmd_collect(args), 0)
                self.assertEqual(os.listdir(os.path.join(dest, "runs")), ["R-9"])
            finally:
                ct.default_src = old_src
                if old_env is None: os.environ.pop("ProgramFiles", None)
                else: os.environ["ProgramFiles"] = old_env

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

    def shot_setup(self, d, files, extra=""):
        sv = os.path.join(d, "src", "Account", "A", "SavedVariables"); os.makedirs(sv)
        shots = os.path.join(d, "shots"); os.makedirs(shots)
        with open(os.path.join(sv, "CheckThat.lua"), "w") as fh:
            fh.write('CheckThatDB = {["runs"] = {["R-1"] = {["revision"] = 1, ["order"] = {"a", "b"}, ["steps"] = {["a"] = {["verdict"] = "pass", ["attempts"] = {{["n"] = 1, ["started"] = 1000, ["finished"] = 1060, ["verdict"] = "pass"}}}, ["b"] = {["verdict"] = "pending", ["attempts"] = {{["n"] = 1, ["started"] = 2000}}}}}}}\n')
        for name, t in files:
            p = os.path.join(shots, name); open(p, "wb").close(); os.utime(p, (t, t))
        dest = os.path.join(d, "dest")
        return shots, dest, type("A", (), {"src": os.path.join(d, "src"), "dest": dest, "shots": shots})

    def test_a_screenshot_just_outside_a_step_suggests_a_slack(self):
        with tempfile.TemporaryDirectory() as d:
            shots, dest, args = self.shot_setup(d, (("skew.jpg", 1070),))
            with contextlib.redirect_stdout(io.StringIO()) as out:
                ct.cmd_collect(args)
            self.assertIn("try --shot-slack 11", out.getvalue())
        with tempfile.TemporaryDirectory() as d:
            shots, dest, args = self.shot_setup(d, (("late.jpg", 1500),))
            with contextlib.redirect_stdout(io.StringIO()) as out:
                ct.cmd_collect(args)
            self.assertNotIn("--shot-slack", out.getvalue(), "440 s is not clock skew")

    def test_loose_screenshots_are_counted_named_and_kept_on_request(self):
        files = (("in.jpg", 1030), ("edge.jpg", 1062), ("late.jpg", 1500), ("open.jpg", 2800), ("old.jpg", 90000))
        with tempfile.TemporaryDirectory() as d:
            shots, dest, args = self.shot_setup(d, files)
            with contextlib.redirect_stdout(io.StringIO()) as out:
                ct.cmd_collect(args)
            text = out.getvalue()
            self.assertIn("1 screenshot matched no attempt", text)   # late.jpg only: edge is inside the 2 s slack, open is in the 900 s window, old is days away
            self.assertNotIn("late.jpg", text)
            self.assertEqual(sorted(os.listdir(os.path.join(dest, "runs", "R-1", "shots"))), ["a__edge.jpg", "a__in.jpg", "b__open.jpg"])
            args.verbose = True
            with contextlib.redirect_stdout(io.StringIO()) as out:
                ct.cmd_collect(args)   # a second collect still counts the same file and does not call the copied ones loose
            self.assertIn("late.jpg: 440 s from step a of run R-1", out.getvalue())
            self.assertIn("1 screenshot matched no attempt", out.getvalue())
            self.assertFalse(os.path.exists(os.path.join(dest, "runs", "R-1", "unassigned-shots")))
            args.all_shots = True
            with contextlib.redirect_stdout(io.StringIO()):
                ct.cmd_collect(args)
            self.assertEqual(os.listdir(os.path.join(dest, "runs", "R-1", "unassigned-shots")), ["late.jpg"])
            self.assertEqual(ct.run_shots(dest, "R-1").get("unassigned-shots"), None)
            self.assertNotIn("unassigned", ct.report_text(ct.latest_runs(dest), dest))

    def test_nearest_attempt_prefers_the_folder_client_then_the_earliest_run(self):
        with tempfile.TemporaryDirectory() as d:
            dest = os.path.join(d, "dest")
            for rid, client in (("R-2", "classic-era"), ("R-1", "forever-camelot"), ("R-3", "classic-era")):
                p = os.path.join(dest, "runs", rid); os.makedirs(p)
                run = {"runId": rid, "revision": 1, "client": client, "order": ["a"], "steps": {"a": {"verdict": "pass", "attempts": [{"n": 1, "started": 1000, "finished": 1060, "verdict": "pass"}]}}}
                with open(os.path.join(p, "r1.json"), "w") as fh:
                    json.dump(run, fh)
            era = os.path.join(d, "wow", "_classic_era_", "Screenshots"); os.makedirs(era)
            fx = os.path.join(d, "wow", "_forever_", "Screenshots"); os.makedirs(fx)
            for folder in (era, fx):
                p = os.path.join(folder, "late.jpg"); open(p, "wb").close(); os.utime(p, (1500, 1500))
            self.assertEqual(ct.collect_shots(dest, era)[1], [("late.jpg", "R-2", "a", 440)])   # equal gaps: the earliest run of the client
            self.assertEqual(ct.collect_shots(dest, fx)[1], [("late.jpg", "R-1", "a", 440)])

    def test_loose_screenshot_with_no_run_is_not_counted(self):
        with tempfile.TemporaryDirectory() as d:
            shots = os.path.join(d, "shots"); os.makedirs(shots)
            open(os.path.join(shots, "x.jpg"), "wb").close()
            self.assertEqual(ct.collect_shots(os.path.join(d, "dest"), shots, all_shots=True), (0, []))


class RunWarnings(unittest.TestCase):
    def test_each_mismatch_is_named_and_a_missing_field_is_not(self):
        runs = {"R-1": {"addon": "KeepThat", "planTitle": "t", "targetVersion": "0.16.0", "writerVersion": "0.0.1", "planDigest": "aaaa1111"},
                "R-2": {"planTitle": "no fields recorded"}}
        got = ct.run_warnings(runs, "0.17.0", "bbbb2222")
        self.assertTrue(any("R-1" in w and "0.16.0" in w and "0.17.0" in w for w in got), got)
        self.assertTrue(any("R-1" in w and "edits since that run are untested" in w for w in got), got)
        self.assertFalse(any("R-2" in w for w in got), got)
        scoped = ct.run_warnings(dict(runs, **{"R-3": {"addon": "Other", "planTitle": "p", "planDigest": "cccc3333"}}), None, "bbbb2222", "KeepThat", "t")
        self.assertFalse(any("R-3" in w for w in scoped), "another addon's run is not judged against this plan")
        self.assertTrue(any("R-1" in w and "untested" in w for w in scoped))
        two = {"R-%d" % i: {"writerVersion": "0.0.1"} for i in (1, 2)}
        self.assertLessEqual(sum("written by" in w for w in ct.run_warnings(two)), 1, "one warning for each writer version")


class GoldenPlans(unittest.TestCase):
    """The plans the skill ships as its examples must pass what the skill tells authors to run: no validate error or warning,
    compile, a clean flow replay, and partner references that resolve."""
    DIR = os.path.join(ROOT, "skills", "ct-test-plan")
    PLANS = sorted(glob.glob(os.path.join(DIR, "*.yaml")))

    def test_each_example_validates_without_warning_and_compiles(self):
        self.assertTrue(self.PLANS)
        for path in self.PLANS:
            plan = ct.load_yaml(path)
            self.assertEqual(ct.validate(plan), [], path)
            self.assertIsNone(ct.version_warning(plan), path)
            self.assertEqual(ct.card_move_warnings(plan), [], path)
            self.assertEqual(ct.warnings(plan), [], path)
            self.assertEqual(ct.size_warnings(plan), [], path)
            self.assertIn("!CT1!", ct.encode(ct.merge_sections(plan)), path)

    @unittest.skipUnless(shutil.which("luajit"), "luajit is not installed")
    def test_each_example_replays_cleanly(self):
        for path in self.PLANS:
            code, text = ct.replay_flow(ct.load_yaml(path))
            self.assertEqual(code, 0, path + "\n" + text)

    def test_partner_references_name_a_real_step(self):
        steps = {os.path.basename(p): {s["id"] for sec in ct.load_yaml(p)["sections"] for s in sec["steps"]} for p in self.PLANS}
        for path in self.PLANS:
            with open(path, encoding="utf-8") as f:
                for name, sid in re.findall(r"([\w.-]+\.yaml) step (\w+(?:\.\w+)*)", f.read()):
                    self.assertIn(sid, steps.get(name, set()), "%s names %s step %s" % (os.path.basename(path), name, sid))


class SkillText(unittest.TestCase):
    def test_every_ct_py_command_the_skills_and_docs_name_exists(self):
        with open(os.path.join(ROOT, "tools", "ct.py"), encoding="utf-8") as f:
            real = set(re.findall(r'sub\.add_parser\("([\w-]+)"', f.read()))
        for path in ("skills/ct-test-plan/SKILL.md", "skills/ct-verify/SKILL.md", "docs/skills.md", "docs/adopting.md", "docs/authoring-plans.md"):
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                named = set(re.findall(r"ct\.py`? ([a-z][\w-]+)", f.read())) - {"is", "in", "and", "runs", "to", "for", "from", "with", "or", "the", "a", "on"}
            self.assertEqual(sorted(named - real), [], path)


class SkillSplit(unittest.TestCase):
    def test_the_main_text_leaves_checkthat_internals_to_the_reference(self):
        with open(os.path.join(ROOT, "skills", "ct-test-plan", "SKILL.md"), encoding="utf-8") as f:
            main = f.read()
        with open(os.path.join(ROOT, "skills", "ct-test-plan", "reference.md"), encoding="utf-8") as f:
            ref = f.read()
        for internal in ("`Plan.SLASH`", "`LOGS` in `ct.py`", "major*10000"):
            self.assertNotIn(internal, main)
            self.assertIn(internal, ref)
        for section in ("### Supported addons", "### Log sources", "### Version check"):
            self.assertIn(section, ref)
        self.assertIn('in `reference.md`', main)


class ReviseMode(unittest.TestCase):
    def test_skill_states_the_revise_rules(self):
        with open(os.path.join(ROOT, "skills", "ct-test-plan", "SKILL.md"), encoding="utf-8") as f:
            text = f.read()
        for rule in ("## 4c. Revise after a run", "**Plan fault.**", "**Addon fault.**", "**Cannot tell.**", "/ct rerun failed", "new run", "ct.py diff",
                     "Never edit addon code unasked", "keep every step id"):
            self.assertIn(rule, text)
        with open(os.path.join(ROOT, "skills", "ct-verify", "SKILL.md"), encoding="utf-8") as f:
            self.assertIn("Revise after a run", f.read())


class SkillFlags(unittest.TestCase):
    DOCS = ("skills/ct-test-plan/SKILL.md", "skills/ct-verify/SKILL.md", "docs/skills.md", "docs/adopting.md", "docs/authoring-plans.md", "README.md")

    def flags(self):
        with open(os.path.join(ROOT, "tools", "ct.py"), encoding="utf-8") as f:
            parts = f.read().split("sub.add_parser(")[1:]
        out = {}
        for part in parts:
            name = re.match(r'"([\w-]+)"', part).group(1)
            out[name] = set(re.findall(r'add_argument\("(--[\w-]+)"', part))
        return out

    def test_every_flag_the_docs_name_exists_for_that_command(self):
        real = self.flags()
        self.assertIn("--expect-version", real["report"])
        for path in self.DOCS:
            with open(os.path.join(ROOT, path), encoding="utf-8") as f:
                text = f.read()
            for cmd, rest in re.findall(r"ct\.py `?([a-z][\w-]+)([^`\n]*)", text):
                if cmd not in real:
                    continue
                for flag in re.findall(r"(--[a-z][\w-]*)", rest):
                    self.assertIn(flag, real[cmd], "%s: ct.py %s names %s" % (path, cmd, flag))


class CardMoveWarning(unittest.TestCase):
    def plan(self, cmds, **extra):
        st = {"id": "a.1", "action": {"kind": "manual", "text": "t", "commands": cmds}}
        st.update(extra)
        return {"sections": [{"steps": [st]}]}

    def test_a_command_that_moves_the_card_is_named(self):
        self.assertEqual(ct.card_move_warnings(self.plan(["/ct version", "/ct pass"])), [("a.1", "/ct pass")])
        self.assertEqual(ct.card_move_warnings(self.plan(["/checkthat Fail"])), [("a.1", "/checkthat Fail")])

    def test_a_second_line_a_macro_body_and_a_case_are_checked(self):
        self.assertEqual(ct.card_move_warnings(self.plan(["/ct version\n/ct next"])), [("a.1", "/ct next")])
        p = self.plan([]); p["macros"] = [{"id": "m", "text": "/ct debug on\n/ct skip"}]; p["sections"][0]["steps"][0]["action"] = {"kind": "secure-macro", "macro": "m"}
        self.assertEqual(ct.card_move_warnings(p), [("a.1", "/ct skip")])
        self.assertEqual(ct.card_move_warnings(self.plan(["/ct pass"], notes="Sent ON PURPOSE.")), [])

    def test_other_commands_and_on_purpose_notes_are_left_alone(self):
        self.assertEqual(ct.card_move_warnings(self.plan(["/ct version", "/ct debug on", "/passport"])), [])
        self.assertEqual(ct.card_move_warnings(self.plan(["/ct pass"], notes="The Pass is sent on purpose.")), [])


class Defaults(unittest.TestCase):
    def test_default_addons_follows_the_layout_and_a_missing_luajit_is_a_clear_error(self):
        from unittest import mock
        with tempfile.TemporaryDirectory() as d:
            root = os.path.join(d, "checkout"); os.makedirs(root)
            with mock.patch.object(ct, "ROOT", root):
                self.assertEqual(ct.default_addons(), os.path.dirname(os.getcwd()), "no .git: an installed skill, the folder above the current one")
                open(os.path.join(root, ".git"), "w").close()   # a linked worktree holds a .git file
                self.assertEqual(ct.default_addons(), d)
        with mock.patch.object(ct.subprocess, "run", side_effect=FileNotFoundError):
            with self.assertRaises(ValueError) as e:
                ct.run_luajit(["x.lua"])
            self.assertIn("luajit", str(e.exception))


class LinesCheck(unittest.TestCase):
    def test_literal_run_is_the_longest_plain_part(self):
        self.assertEqual(ct.literal_run("^%[toast%] shown %d+$"), "[toast] shown ")
        self.assertEqual(ct.literal_run("^%[a%] (x)-?%d+ done$"), " done")
        self.assertEqual(ct.literal_run("^abc?def$"), "def")
        self.assertEqual(ct.literal_run("[xyz]+"), "")

    def test_a_line_the_source_lacks_is_reported(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "A.lua"), "w") as f:
                f.write('Log("toast", ("shown %d"):format(id))\nReport("KeepThat", "toast.seq", 1)\n')
            plan = {"sections": [{"steps": [{"id": "s.1", "assertions": [
                {"kind": "log", "source": "debug", "pattern": "^%[toast%] shown %d+$", "label": "toast"},
                {"kind": "log", "source": "debug", "equals": "[toast] vanished", "label": "gone"},
                {"kind": "fact", "source": "facts", "addon": "KeepThat", "key": "toast.seq", "op": "ge", "value": 1},
                {"kind": "fact", "source": "facts", "addon": "KeepThat", "key": "toast.nope", "op": "ge", "value": 1}]}]}]}
            found, missing = ct.lines_check(plan, d)
            self.assertEqual([m[2] for m in missing], ["[toast] vanished", "toast.nope"])
            self.assertEqual(len(found), 2)

    def plan_for(self, *assertions):
        return {"logs": {"debug": {"global": "G"}, "facts": {"global": "CheckThatDB"}}, "sections": [{"steps": [{"id": "s.1", "assertions": list(assertions)}]}]}

    def src(self, **files):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        for name, text in files.items():
            p = os.path.join(d, name.replace("__", "/")); os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f: f.write(text)
        return d

    def test_a_comment_or_a_test_file_does_not_count_and_a_whole_line_does(self):
        d = self.src(**{"A.lua": '-- toast vanished from the screen\nLog("toast", "shown")\nLog("[opt] whole line")\n', "tests__T.lua": 'x = "[toast] vanished from the screen"\n'})
        line = lambda s: {"kind": "log", "source": "debug", "equals": s}
        found, missing = ct.lines_check(self.plan_for(line("[toast] vanished from the screen"), line("[opt] whole line")), d)
        self.assertEqual([m[2] for m in missing], ["[toast] vanished from the screen"])
        self.assertEqual([f[2] for f in found], ["[opt] whole line"])

    def test_an_untagged_line_built_at_run_time_matches_on_its_prefix(self):
        d = self.src(**{"A.lua": 'Log("test command: " .. kind)\nLog("unrelated " .. x)\n'})
        line = lambda s: {"kind": "log", "source": "debug", "contains": s}
        found, missing = ct.lines_check(self.plan_for(line("test command: sell"), line("vanished thing here"), line("un x")), d)
        self.assertEqual([f[2] for f in found], ["test command: sell"])
        self.assertEqual([m[2] for m in missing], ["vanished thing here", "un x"], "a prefix under 8 characters is not enough")

    def test_a_contains_line_built_at_run_time_matches_on_its_longest_literal_part(self):
        d = self.src(**{"A.lua": 'Log(("%d items found"):format(n))\nLog("score: " .. n .. " points earned")\n'})
        line = lambda s: {"kind": "log", "source": "debug", "contains": s}
        found, missing = ct.lines_check(self.plan_for(line("3 items found"), line("score: 5 points earned"), line("5 widgets found")), d)
        self.assertEqual([f[2] for f in found], ["3 items found", "score: 5 points earned"])
        self.assertEqual([m[2] for m in missing], ["5 widgets found"])

    def test_a_fact_under_any_source_name_is_checked_and_strict_sets_the_exit_code(self):
        d = self.src(**{"A.lua": 'Report("K", "have.it", 1)\n'})
        facts = [{"kind": "fact", "source": "mine", "addon": "K", "key": "have.it"}, {"kind": "fact", "source": "mine", "addon": "K", "key": "not.there"}]
        found, missing = ct.lines_check(self.plan_for(*facts), d)
        self.assertEqual([m[2] for m in missing], ["not.there"])
        plan_file = os.path.join(d, "p.yaml")
        import yaml
        with open(plan_file, "w") as f: yaml.safe_dump(dict(self.plan_for(*facts), ct=1), f)
        self.assertEqual(self.cli("lines", plan_file, "--addon-src", d)[0], 0)
        self.assertEqual(self.cli("lines", plan_file, "--addon-src", d, "--strict")[0], 1)

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ct.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_dollar_and_caret_are_anchors_only_at_the_ends(self):
        self.assertEqual(ct.literal_run("^foo$bar$"), "foo$bar")
        self.assertEqual(ct.literal_run("a^b"), "a^b")
        self.assertEqual(ct.literal_run("[%]x]yy"), "yy")


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

    def test_ids_and_numbers_follow_the_game_rules(self):
        p = self.plan(); p["sections"][0]["steps"][0]["id"] = "a.1\n"   # the schema pattern lets a trailing newline through
        self.assertTrue(any("step id" in e and "not valid" in e for e in ct.validate(p)))
        p = self.plan(); p["sections"][0]["id"] = "Basics"
        self.assertTrue(any("section id" in e and "not valid" in e for e in ct.validate(p)))
        self.assertFalse(ct.is_num(float("nan"))); self.assertFalse(ct.is_num(float("inf"))); self.assertTrue(ct.is_num(2.5))
        self.assertFalse(ct.macro_allowed("/reload " + chr(233) * 130, "KeepThat"), "bytes, not characters")

    def test_the_validator_rejects_every_plan_of_the_shared_parity_set(self):
        with open(os.path.join(ROOT, "tests", "fixtures", "parity-plan.json"), encoding="utf-8") as fh: base = json.load(fh)
        with open(os.path.join(ROOT, "tests", "fixtures", "parity-bad.json"), encoding="utf-8") as fh: muts = json.load(fh)   # tests/test_plan.lua reads the same files
        self.assertEqual(ct.validate(json.loads(json.dumps(base))), [])
        for m in muts:
            p = json.loads(json.dumps(base)); o = p
            for k in m["path"][:-1]: o = o[k]
            o[m["path"][-1]] = m["value"]
            self.assertTrue(ct.validate(p), "ct.py accepted: " + m["name"])

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

    def test_stale_macro_presses_show_in_the_table_the_model_and_the_diff_text(self):
        run = {"order": ["a", "b"], "steps": {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}], "macroStale": 2}, "b": {"verdict": "pending", "attempts": []}}}
        rows = ct.step_table(run)
        self.assertIn("2 stale macro presses", rows[1]); self.assertNotIn("stale", rows[2])
        model = {s["id"]: s for s in ct.run_model("R", run)["steps"]}
        self.assertEqual([model["a"]["macroStale"], model["b"]["macroStale"]], [2, 0])
        d = {"a": {"runId": "A", "client": None, "build": None, "character": None, "planDigest": None, "writerVersion": None, "targetVersion": None},
             "b": {"runId": "B", "client": None, "build": None, "character": None, "planDigest": None, "writerVersion": None, "targetVersion": None},
             "planChanged": False, "counts": {"unchanged": 2}, "warnings": [],
             "steps": [{"id": "a", "a": "pass", "b": "pass", "label": "unchanged", "reason": "", "macroStale": [0, 2]}]}
        self.assertIn("## stale macro presses\n- a: 0 -> 2", ct.diff_text(d))

    def test_a_reopened_step_is_awaiting_retry_in_the_table_and_the_reports(self):
        done = {"n": 1, "verdict": "fail", "note": "old note"}
        flagged = {"verdict": "pending", "reopened": True, "attempts": []}                 # Undo removed the only attempt
        kept = {"verdict": "pending", "attempts": [done]}                                    # a run from before the flag: the attempt stays
        fresh = {"verdict": "pending", "attempts": []}
        stale = {"verdict": "pass", "reopened": True, "attempts": [{"n": 2, "verdict": "pass"}]}   # an older CheckThat finished it and kept the flag
        for rec in (flagged, kept):
            self.assertEqual(ct.classify(rec), ("skipped", "awaiting retry"))
        self.assertEqual(ct.classify(fresh), ("skipped", "not run"))
        self.assertEqual(ct.classify(stale)[0], "pass")
        run = {"order": ["f", "k", "n", "s"], "steps": {"f": flagged, "k": kept, "n": fresh, "s": stale}}
        rows = [line.split() for line in ct.step_table(run)[1:]]
        self.assertEqual([r[-2:] for r in rows[:2]], [["awaiting", "retry"]] * 2)
        self.assertNotIn("retry", rows[2]); self.assertNotIn("retry", rows[3])
        model = {s["id"]: s for s in ct.run_model("R", run)["steps"]}
        self.assertEqual([model[i]["awaitingRetry"] for i in "fkns"], [True, True, False, False])
        self.assertEqual(model["f"]["reason"], "awaiting retry")

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

    def test_a_run_record_with_the_wrong_types_is_unreadable(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        bad = ({"order": [["a"]], "steps": {}}, {"steps": {}, "categories": [5]}, {"steps": {}, "categories": {"id": "x"}},
               {"steps": {}, "cat": []}, {"steps": {}, "selected": 3}, {"steps": {"a": {"verdict": 5, "attempts": []}}},
               {"steps": {"a": {"attempts": [{"n": 1, "verdict": ["pass"]}]}}}, {"steps": {"a": {"attempts": [{"n": 1, "note": 7}]}}})
        for i, run in enumerate(bad):
            p = os.path.join(d, "r%d.json" % i)
            with open(p, "w") as fh: json.dump(run, fh)
            with self.assertRaises(ValueError, msg=str(run)):
                ct.read_run(p)

    def test_the_results_schema_accepts_old_and_new_runs_and_names_bad_detail(self):
        import jsonschema
        with open(os.path.join(ROOT, "schema", "run-results.schema.json")) as fh:
            schema = json.load(fh)
        check = lambda run: jsonschema.Draft202012Validator(schema).iter_errors(run)
        new = self.run_with(self.checked_steps())["R-1"]
        new["steps"]["a"]["attempts"][0]["outcomes"][0].update(stoppedAt=2, observed="3", trimmed=True)
        self.assertEqual(list(check(new)), [])
        self.assertEqual(list(check({"steps": {"a": {"verdict": "pass", "attempts": [{"n": 1, "verdict": "pass"}]}}})), [], "an older run has none of the new keys")
        self.assertEqual(list(check({"steps": {"a": {"verdict": "pending", "reopened": True, "attempts": []}}})), [])
        self.assertTrue(list(check({"steps": {"a": {"verdict": "pending", "reopened": "yes"}}})), "reopened is a boolean")
        for bad in ({"hits": [{"n": 0}]}, {"result": "bogus"}, {"matched": -1}, {"scope": "everywhere"}, {"hits": [{"n": 1}] * 4}, {"trimmed": False}):
            run = {"steps": {"a": {"attempts": [{"n": 1, "outcomes": [dict({"result": "fail"}, **bad)]}]}}}
            self.assertTrue(list(check(run)), bad)

    def test_every_export_of_a_played_run_passes_the_schema(self):
        import jsonschema
        path = os.path.join(ROOT, "build", "export-runs.json")   # written by tests/test_export_schema.lua, which make test runs first
        if not os.path.exists(path):
            self.skipTest("run tests/test_export_schema.lua first")
        with open(os.path.join(ROOT, "schema", "run-results.schema.json")) as fh:
            schema = json.load(fh)
        with open(path) as fh:
            runs = json.load(fh)
        self.assertGreaterEqual(len(runs), 8)
        for i, run in enumerate(runs):
            self.assertEqual(list(jsonschema.Draft202012Validator(schema).iter_errors(run)), [], "export %d" % i)
            # The schema lets unknown keys through (readers ignore them), so a key the writer adds must be named in it.
            known = lambda d, obj: set(obj) - set((d.get("properties") or {}))
            self.assertEqual(known(schema, run), set(), "top-level keys not in the schema")
            for rec in run["steps"].values():
                self.assertEqual(known(schema["$defs"]["step"], rec), set(), "step keys not in the schema")
                for a in rec["attempts"]:
                    self.assertEqual(known(schema["$defs"]["attempt"], a), set(), "attempt keys not in the schema")

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
        with open(os.path.join(ROOT, "CheckThat", "Model", "Run.lua"), encoding="utf-8") as fh:
            rev = int(re.search(r"Run\.MAJOR, Run\.FORMAT_REV = \d+, (\d+)", fh.read()).group(1))
        self.assertEqual((run["ct"], run["formatRev"]), (1, rev)); self.assertEqual(run["steps"]["a"]["attempts"][0]["formatRev"], rev)   # stamped by the addon
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
        for bad in ({"ct": 2}, {"formatRev": 0}, {"formatRev": "1"}, {"writerVersion": 3}, {"targetVersion": 3}, {"targetVersion": ""}):
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


class CompareRuns(unittest.TestCase):
    """ct.py diff and trend, on made-up runs."""
    def st(self, verdict, result=None):
        at = {"n": 1, "verdict": verdict}
        if result:
            at["outcomes"] = [{"result": result, "why": "w"}]
        return {"verdict": verdict, "attempts": [at] if verdict not in ("pending", "skip", "deselected", "inapplicable") else []}

    def mk(self, steps, digest="d1", started=100, ended=True, **extra):
        return {"planTitle": "P", "addon": "KeepThat", "revision": 1, "client": "classic-era", "build": "1", "character": "X", "planDigest": digest,
                "started": started, "order": [s for s in steps if steps[s]["verdict"] not in ("deselected", "inapplicable")], "steps": steps,
                **({"endedAt": started + 50} if ended else {}), **extra}

    def dest(self, runs, store=None):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        for rid, r in runs.items():
            ct.write_revision(d, {**r, "runId": rid})
        if store is not None:
            import verify_fixture
            os.makedirs(os.path.join(d, "sv"))
            with open(os.path.join(d, "sv", "CheckThat-abc.lua"), "w") as f:
                f.write("CheckThatDB = %s\n" % verify_fixture.lua({"planStore": store}))
        return d

    def test_plan_store_reads_a_collected_file_name_and_the_global_table(self):
        import verify_fixture
        d = self.dest({}); os.makedirs(os.path.join(d, "sv"))
        with open(os.path.join(d, "sv", "Account__A__SavedVariables__CheckThat.1234567890.lua"), "w") as f:
            f.write("CheckThatDB = %s\n" % verify_fixture.lua({"global": {"planStore": {"dig": {"sections": []}}}}))
        self.assertIn("dig", ct.plan_store(d))

    def test_a_partial_revision_file_is_replaced_and_navigation_is_not_a_conflict(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        run = {"runId": "R-1", "revision": 3, "ct": 1, "steps": {}, "current": 2}
        self.assertEqual(ct.write_revision(d, run), "new")
        self.assertEqual(ct.write_revision(d, dict(run, current=5)), "same", "browsing does not change a revision")
        rj = os.path.join(d, "runs", "R-1", "r3.json")
        with open(rj, "w") as f: f.write('{"runId": "R-1", "rev')
        self.assertEqual(ct.write_revision(d, run), "new", "a damaged file is kept aside and the revision stored again")
        self.assertTrue(os.path.exists(rj + ".damaged"))
        self.assertEqual([n for n in os.listdir(os.path.dirname(rj)) if n.endswith(".tmp")], [])

    def cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ct.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def diff(self, a, b, *extra, store=None):
        d = self.dest({"A-1": a, "B-1": b}, store)
        code, out, err = self.cli("diff", "A-1", "B-1", "--dest", d, "--format", "json", *extra)
        return code, (json.loads(out) if out.strip() else None), err

    def labels(self, data):
        return {r["id"]: r["label"] for r in data["steps"]}

    def test_each_change_gets_its_label(self):
        a = self.mk({"s1": self.st("pass"), "s2": self.st("fail"), "s3": self.st("pass"), "s4": self.st("fail"), "s5": self.st("pass"), "s6": self.st("pass")})
        b = self.mk({"s1": self.st("fail"), "s2": self.st("pass"), "s3": self.st("unverified"), "s4": self.st("fail"), "s5": self.st("pass"), "s6": self.st("skip")})
        code, d, _ = self.diff(a, b)
        self.assertEqual(code, 0)
        self.assertEqual(self.labels(d), {"s1": "regressed", "s2": "fixed", "s3": "newly-unverified", "s4": "still-failing", "s5": "unchanged", "s6": "not-comparable"})
        self.assertFalse(d["planChanged"])

    def test_the_header_names_the_version_of_the_tested_addon(self):
        a = self.mk({"s1": self.st("pass")}, targetVersion="1.2.0")
        b = self.mk({"s1": self.st("fail")})
        d = self.diff(a, b)[1]
        self.assertEqual((d["a"]["targetVersion"], d["b"]["targetVersion"]), ("1.2.0", None))
        text = ct.diff_text(d)
        self.assertIn("tested addon 1.2.0", text)
        self.assertIn("tested addon ?", text, "a run that did not record it says so, it does not guess")

    def test_trend_names_columns_by_the_version_of_the_tested_addon(self):
        runs = {"R-%d" % i: self.mk({"s1": self.st(v)}, started=i, targetVersion=tv) for i, v, tv in ((1, "pass", "1.0.0"), (2, "fail", "1.1.0"), (3, "pass", None))}
        runs["R-3"].pop("targetVersion")
        d = self.dest(runs)
        t = json.loads(self.cli("trend", "--dest", d, "--format", "json", "--by", "target")[1])
        self.assertEqual([r["label"] for r in t["groups"][0]["runs"]], ["1.0.0", "1.1.0", None])
        self.assertIn("R-2  1.1.0", self.cli("trend", "--dest", d, "--by", "target")[1])
        self.assertEqual(json.loads(self.cli("trend", "--dest", d, "--format", "json", "--by", "version")[1])["groups"][0]["runs"][1]["label"], None,
                         "version is still the CheckThat version")

    def test_a_pass_with_contradicting_evidence_counts_as_fail(self):
        a = self.mk({"s1": self.st("pass", "pass")})
        b = self.mk({"s1": self.st("pass", "fail")})
        self.assertEqual(self.labels(self.diff(a, b)[1]), {"s1": "regressed"})

    def test_pending_and_not_for_this_client_are_not_comparable(self):
        a = self.mk({"s1": self.st("pass"), "s2": self.st("pass")})
        b = self.mk({"s1": self.st("pending"), "s2": self.st("inapplicable")})
        d = self.diff(a, b)[1]
        self.assertEqual(self.labels(d), {"s1": "not-comparable", "s2": "not-comparable"})
        self.assertEqual(d["counts"], {"not-comparable": 2})

    def test_other_digests_show_added_removed_and_plan_changed(self):
        a = self.mk({"s1": self.st("pass"), "gone": self.st("pass")})
        b = self.mk({"s1": self.st("fail"), "new": self.st("pass")}, digest="d2")
        plan = lambda *ids: {"sections": [{"steps": [{"id": i, "title": i} for i in ids]}]}
        code, d, err = self.diff(a, b, store={"d1": plan("s1", "gone"), "d2": plan("s1", "new")})
        self.assertTrue(d["planChanged"])
        self.assertEqual(self.labels(d), {"s1": "regressed", "gone": "removed", "new": "added"})
        self.assertIn("plan changed", self.cli("diff", "A-1", "B-1", "--dest", self.dest({"A-1": a, "B-1": b}))[1])

    def test_a_step_that_only_changed_its_id_is_called_renamed(self):
        a = self.mk({"s1.1": self.st("pass"), "s2": self.st("pass")})
        b = self.mk({"s1.2": self.st("pass"), "s2": self.st("pass")}, digest="d2")
        p1 = {"sections": [{"steps": [{"id": "s1.1", "expect": "same"}, {"id": "s2", "expect": "x"}]}]}
        p2 = {"sections": [{"steps": [{"id": "s1.2", "expect": "same"}, {"id": "s2", "expect": "x"}]}]}
        d = self.diff(a, b, store={"d1": p1, "d2": p2})[1]
        rows = {r["id"]: r for r in d["steps"]}
        self.assertEqual(rows["s1.1"]["reason"], "renamed to s1.2")
        self.assertEqual(rows["s1.2"]["reason"], "renamed from s1.1")
        self.assertTrue(any("history is split" in w for w in d["warnings"]))
        p2["sections"][0]["steps"][0]["expect"] = "different"
        d = self.diff(a, b, store={"d1": p1, "d2": p2})[1]
        self.assertEqual(d["warnings"], [], "a step with new text is a new step, not a rename")

    def test_identical_steps_are_not_guessed_to_be_renames(self):
        a = self.mk({"old": self.st("pass")}); b = self.mk({"n1": self.st("pass"), "n2": self.st("pass")}, digest="d2")
        p1 = {"sections": [{"steps": [{"id": "old", "expect": "same"}]}]}
        p2 = {"sections": [{"steps": [{"id": "n1", "expect": "same"}, {"id": "n2", "expect": "same"}]}]}
        d = self.diff(a, b, store={"d1": p1, "d2": p2})[1]
        self.assertEqual(d["warnings"], [])

    def test_a_changed_step_is_not_comparable_and_a_missing_plan_is_never_guessed(self):
        a = self.mk({"s1": self.st("pass"), "s2": self.st("pass")})
        b = self.mk({"s1": self.st("fail"), "s2": self.st("fail")}, digest="d2")
        p1 = {"sections": [{"steps": [{"id": "s1", "expect": "old"}, {"id": "s2", "expect": "x"}]}]}
        p2 = {"sections": [{"steps": [{"id": "s1", "expect": "new"}, {"id": "s2", "expect": "x"}]}]}
        d = self.diff(a, b, store={"d1": p1, "d2": p2})[1]
        self.assertEqual(self.labels(d), {"s1": "not-comparable", "s2": "regressed"})
        code, d, err = self.diff(a, b)
        self.assertEqual(self.labels(d), {"s1": "not-comparable", "s2": "not-comparable"})
        self.assertIn("no stored plan for digest d1, d2", err)

    def test_strict_exits_1_on_a_regression_0_otherwise_and_2_for_an_unknown_run(self):
        good = self.mk({"s1": self.st("pass")}); bad = self.mk({"s1": self.st("fail")})
        self.assertEqual(self.diff(good, bad, "--strict")[0], 1)
        self.assertEqual(self.diff(bad, good, "--strict")[0], 0)
        self.assertEqual(self.diff(good, bad)[0], 0)
        d = self.dest({"A-1": good})
        code, _, err = self.cli("diff", "A-1", "nope", "--dest", d, "--strict")
        self.assertEqual(code, 2)
        self.assertIn("no run 'nope'", err)

    def test_an_unfinished_run_needs_include_open(self):
        a = self.mk({"s1": self.st("pass")}); b = self.mk({"s1": self.st("fail")}, ended=False)
        code, d, err = self.diff(a, b)
        self.assertEqual(code, 2)
        self.assertIn("not finished", err)
        self.assertEqual(self.diff(a, b, "--include-open")[0], 0)

    def test_a_newer_format_run_is_refused_and_named(self):
        good = self.mk({"s1": self.st("pass")})
        d = self.dest({"A-1": good, "B-1": good})
        ct.set_refused(d, "C-1", 3, "format 2 is newer than this tool reads (1)")
        code, _, err = self.cli("diff", "A-1", "C-1", "--dest", d)
        self.assertEqual(code, 2)
        self.assertIn("C-1 was left out: format 2 is newer", err)
        code, out, err = self.cli("trend", "--dest", d)
        self.assertEqual(code, 0)
        self.assertIn("left out: C-1", err)
        self.assertEqual(len(json.loads(self.cli("trend", "--dest", d, "--format", "json")[1])["groups"][0]["runs"]), 2)

    def test_trend_marks_flaky_steps_and_skips_open_runs(self):
        runs = {"R-%d" % i: self.mk({"s1": self.st(v), "s2": self.st("pass")}, started=100 * i, ended=i != 4) for i, v in ((1, "pass"), (2, "fail"), (3, "pass"), (4, "fail"))}
        d = self.dest(runs)
        code, out, err = self.cli("trend", "--dest", d, "--format", "json", "--by", "build")
        t = json.loads(out)
        g = t["groups"][0]
        self.assertEqual([r["runId"] for r in g["runs"]], ["R-1", "R-2", "R-3"])
        self.assertEqual({s["id"]: (s["cells"], s["flaky"]) for s in g["steps"]}, {"s1": (["P", "F", "P"], True), "s2": (["P", "P", "P"], False)})
        self.assertEqual(g["runs"][0]["label"], "1")
        text = self.cli("trend", "--dest", d, "--include-open", "--last", "2")[1]
        self.assertIn("R-4  (open)", text)
        self.assertNotIn("R-2", text)
        self.assertEqual(self.cli("trend", "--dest", d, "--addon", "Other")[0], 2)

    def test_trend_marks_a_changed_step_and_warns_when_the_plan_is_not_stored(self):
        runs = {"R-1": self.mk({"s1": self.st("pass"), "s2": self.st("pass")}, started=1),
                "R-2": self.mk({"s1": self.st("pass"), "s2": self.st("fail")}, digest="d2", started=2)}
        p1 = {"sections": [{"steps": [{"id": "s1", "expect": "old"}, {"id": "s2", "expect": "x"}]}]}
        p2 = {"sections": [{"steps": [{"id": "s1", "expect": "new"}, {"id": "s2", "expect": "x"}]}]}
        t = json.loads(self.cli("trend", "--dest", self.dest(runs, {"d1": p1, "d2": p2}), "--format", "json")[1])
        self.assertEqual({s["id"]: s["cells"] for s in t["groups"][0]["steps"]}, {"s1": ["~", "P"], "s2": ["P", "F"]})
        self.assertFalse(t["groups"][0]["steps"][0]["flaky"])
        code, out, err = self.cli("trend", "--dest", self.dest(runs), "--format", "json")
        self.assertEqual({s["id"]: s["cells"] for s in json.loads(out)["groups"][0]["steps"]}, {"s1": ["?", "P"], "s2": ["?", "F"]})
        self.assertIn("no stored plan for digest d1, d2", err)


class Coverage(unittest.TestCase):
    """ct.py coverage and the covers field, on the fixture addon in tests/fixtures/coverage."""
    FX = os.path.join(ROOT, "tests", "fixtures", "coverage")
    SRC = os.path.join(FX, "addon")

    def plan(self, *steps, covers=None):
        p = good()
        p["sections"] = [{"id": "s", "title": "S", "steps": [
            {"id": sid, "title": sid, "action": act, "expect": "e", "verify": ["player"] if not asr else ["assertions"],
             **({"assertions": asr} if asr else {})} for sid, act, asr in steps]}]
        if covers:
            p["sections"][0]["covers"] = covers
        return p

    def fact(self, key):
        return [{"kind": "fact", "source": "debug", "addon": "KeepThat", "key": key, "op": "exists"}]

    def cov(self, *plans, extra=()):
        dirs = []
        for i, p in enumerate(plans):
            f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False); dirs.append(f.name); self.addCleanup(os.unlink, f.name)
            import yaml
            yaml.safe_dump(p, f); f.close()
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ct.main(["coverage", *dirs, "--addon-src", self.SRC, "--format", "json", *extra])
        return code, (json.loads(out.getvalue()) if out.getvalue().strip() else None), err.getvalue()

    def by(self, d, kind):
        return {i["name"]: i for i in d[kind]}

    def test_two_of_three_subcommands_used_one_unused(self):
        p = self.plan(("c1", {"kind": "manual", "text": "Type |cff99ccff/kt alpha|r.", "commands": ["/kt alpha"]}, None),
                      ("c2", {"kind": "copy-slash", "text": "/kt beta 5"}, None))
        code, d, _ = self.cov(p)
        self.assertEqual(code, 0)
        c = self.by(d, "commands")
        self.assertEqual({k: v["steps"] for k, v in c.items()}, {"alpha": ["c1"], "beta": ["c2"], "gamma": []})

    def test_a_setting_used_only_by_a_fact_check_counts_as_covered(self):
        p = self.plan(("f1", {"kind": "manual", "text": "Look."}, self.fact("settings.size")),
                      ("f2", {"kind": "manual", "text": "Type /kt verbose."}, None))
        s = self.by(self.cov(p)[1], "settings")
        self.assertEqual({k: v["steps"] for k, v in s.items()}, {"verbose": ["f2"], "size": ["f1"], "quiet": []})

    def test_unit_test_markers_count_toward_requirements(self):
        p = self.plan(("r1", {"kind": "manual", "text": "t"}, None), covers=["Second thing works"])
        code, d, _ = self.cov(p)
        self.assertEqual(code, 0)
        r = self.by(d, "requirements")
        self.assertEqual(r["First thing works"]["tests"], ["test_cap.lua:1"])
        self.assertEqual(r["Second thing works"]["tests"], ["test_cap.lua:3"]); self.assertEqual(r["Second thing works"]["steps"], ["r1"])
        self.assertEqual(r["Third thing works"]["tests"], [], "a marker under fixtures is not read")
        self.assertEqual(d["testCounts"], {"tests": 2, "plans": 1, "both": 1, "neither": 1, "total": 3})
        self.assertEqual(d["testAndPlan"], ["Second thing works"])
        self.assertEqual(d["unknownTests"], ["Not a requirement"])

    def test_an_explicit_tests_folder_that_is_missing_is_an_error(self):
        f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False); self.addCleanup(os.unlink, f.name)
        import yaml
        yaml.safe_dump(self.plan(("r1", {"kind": "manual", "text": "t"}, None)), f); f.close()
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(ct.main(["coverage", f.name, "--addon-src", self.SRC, "--tests", os.path.join(self.FX, "nope")]), 2)
        self.assertIn("is not a folder", err.getvalue())
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(ct.main(["coverage", f.name, "--addon-src", self.SRC, "--specs", os.path.join(self.FX, "nope"), "--tests", os.path.join(self.FX, "tests")]), 2)
        self.assertIn("needs the addon's openspec specs", err.getvalue())

    def test_without_a_tests_folder_the_output_has_no_test_keys(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        shutil.copytree(self.SRC, os.path.join(d, "addon")); shutil.copytree(os.path.join(self.FX, "openspec"), os.path.join(d, "openspec"))
        f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False); self.addCleanup(os.unlink, f.name)
        import yaml
        yaml.safe_dump(self.plan(("r1", {"kind": "manual", "text": "t"}, None)), f); f.close()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(ct.main(["coverage", f.name, "--addon-src", os.path.join(d, "addon"), "--format", "json"]), 0)
        j = json.loads(out.getvalue())
        self.assertNotIn("testCounts", j); self.assertTrue(all("tests" not in r for r in j["requirements"]))

    def test_the_text_report_shows_test_coverage_and_overlap(self):
        p = self.plan(("r1", {"kind": "manual", "text": "t"}, None), covers=["Second thing works"])
        f = tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False); self.addCleanup(os.unlink, f.name)
        import yaml
        yaml.safe_dump(p, f); f.close()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            ct.main(["coverage", f.name, "--addon-src", self.SRC])
        t = out.getvalue()
        self.assertIn("by unit tests 2, by plans 1, by both 1, by neither 1 (of 3)", t)
        self.assertIn("in both, a plan step may repeat a unit test: Second thing works", t)
        self.assertIn("unknown requirement named by a test: Not a requirement", t)
        self.assertIn("tests    First thing works  test_cap.lua:1", t)

    def test_a_plain_word_in_prose_is_not_a_command(self):
        p = self.plan(("t1", {"kind": "manual", "text": "The size is large and verbose, and alpha is a letter."}, None))
        d = self.cov(p)[1]
        self.assertTrue(all(not i["steps"] for i in d["commands"] + d["settings"]))

    def test_subcommands_come_from_every_lua_file_the_toc_lists_through_embeds_xml(self):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        def put(name, text):
            p = os.path.join(d, name); os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f: f.write(text)
        put("Mock.toc", "## Title: Mock\n# Comment.lua\nembeds.xml\nCommands.lua\nCore\\Dispatch.lua\n")
        put("embeds.xml", '<Ui><!-- <Script file="Skipped.lua"/> --><Include file="More\\more.xml"/></Ui>')
        put("More/more.xml", '<Ui><Script file="Deep.lua"/></Ui>')
        put("Commands.lua", 'if cmd == "get" then end\n')
        put("Core/Dispatch.lua", 'elseif cmd == "put" then end\n')
        put("More/Deep.lua", 'elseif cmd == "deep" then end\n')
        put("Skipped.lua", 'elseif cmd == "skipped" then end\n')
        put("Unlisted.lua", 'elseif cmd == "unlisted" then end\n')
        put("Libs/Lib.lua", 'elseif cmd == "lib" then end\n')
        put("Slash.lua", 'if cmd == "old" then end\n')
        self.assertEqual(ct.slash_commands(d), ["deep", "get", "old", "put"])

    def test_nothing_extracted_and_mixed_addons_are_errors(self):
        p = self.plan(("c1", {"kind": "manual", "text": "t"}, None))
        out = io.StringIO()
        with contextlib.redirect_stderr(out):
            code = ct.main(["coverage", "--addon-src", os.path.join(self.FX, "openspec"), os.path.join(ROOT, "plans", "selftest.yaml")])
        self.assertEqual(code, 2); self.assertIn("no subcommand found", out.getvalue()); self.assertIn("the Lua files its TOC lists", out.getvalue())
        q = self.plan(("c1", {"kind": "manual", "text": "t"}, None)); q["addon"] = "DontDoThat"; q["macros"] = []
        code, _, err = self.cov(p, q)
        self.assertEqual(code, 2); self.assertIn("2 addons", err)

    def test_covers_names_a_requirement_and_the_report_lists_the_rest(self):
        p = self.plan(("r1", {"kind": "manual", "text": "t"}, None), covers=["First thing works"])
        p["sections"][0]["steps"][0]["covers"] = ["Second thing works"]
        code, d, _ = self.cov(p)
        self.assertEqual(code, 0)
        self.assertEqual({k: v["steps"] for k, v in self.by(d, "requirements").items()},
                         {"First thing works": ["r1"], "Second thing works": ["r1"], "Third thing works": []})

    def test_an_unknown_requirement_name_is_a_validation_error(self):
        p = self.plan(("r1", {"kind": "manual", "text": "t"}, None))
        p["sections"][0]["steps"][0]["covers"] = ["No such thing"]
        names = ct.requirement_names(os.path.join(self.FX, "openspec", "specs"))
        errs = ct.validate(p, set(names))
        self.assertTrue(any("r1" in e and "No such thing" in e for e in errs), errs)
        self.assertEqual(ct.validate(p, None)[0].split(":")[0], "r1")   # no specs folder to check against
        self.assertEqual(self.cov(p)[0], 2)
        p["sections"][0]["steps"][0]["covers"] = ["Third thing works"]
        self.assertEqual(ct.validate(p, set(names)), [])

    def test_the_schema_alone_allows_covers_and_rejects_other_unknown_fields(self):
        import jsonschema
        with open(ct.SCHEMA) as f:
            schema = json.load(f)
        p = self.plan(("r1", {"kind": "manual", "text": "t"}, None), covers=["x"])
        v = jsonschema.Draft202012Validator(schema)
        self.assertEqual(list(v.iter_errors(p)), [])
        p["sections"][0]["bogus"] = 1
        self.assertTrue(list(v.iter_errors(p)))

    def test_compile_drops_covers_and_the_string_is_byte_identical(self):
        a = self.plan(("r1", {"kind": "manual", "text": "t {{x}}"}, None), ("r2", {"kind": "manual", "text": "t"}, None))
        a["sections"][0]["steps"][0]["cases"] = [{"id": "one", "vars": {"x": 1}}, {"id": "two", "vars": {"x": 2}}]
        b = json.loads(json.dumps(a))
        b["sections"][0]["covers"] = ["First thing works"]
        b["sections"][0]["steps"][0]["covers"] = ["Second thing works"]
        b["sections"][0]["steps"][1]["covers"] = ["Third thing works"]
        self.assertEqual(ct.encode(ct.merge_sections(a)), ct.encode(ct.merge_sections(b)))
        self.assertNotIn("covers", json.dumps(ct.merge_sections(b)))

    def test_evidence_joins_the_newest_finished_run(self):
        p = self.plan(("e1", {"kind": "copy-slash", "text": "/kt alpha"}, None), ("e2", {"kind": "copy-slash", "text": "/kt beta"}, None),
                      ("e3", {"kind": "copy-slash", "text": "/kt gamma"}, None))
        p["title"] = "P"
        st = lambda v: {"verdict": v, "attempts": [{"n": 1, "verdict": v}] if v != "skip" else []}
        def run(started, **steps):
            return {"planTitle": "P", "addon": "KeepThat", "revision": 1, "client": "classic-era", "build": "1", "character": "X", "planDigest": "d",
                    "started": started, "endedAt": started + 5, "order": list(steps), "steps": {k: st(v) for k, v in steps.items()}}
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        ct.write_revision(d, {**run(1, e1="fail", e2="fail", e3="fail"), "runId": "R-1"})   # older: ignored
        ct.write_revision(d, {**run(2, e1="pass", e2="fail", e3="skip"), "runId": "R-2"})
        code, data, _ = self.cov(p, extra=("--evidence", "--dest", d))
        self.assertEqual(code, 0)
        self.assertEqual({k: v["result"] for k, v in self.by(data, "commands").items()}, {"alpha": "passed", "beta": "failed", "gamma": "never-run"})
        self.assertEqual(data["notes"], ["P: run R-2"])
        self.assertIsNone(self.cov(p)[1]["commands"][0]["result"])

    def test_a_plan_with_no_finished_run_is_never_run(self):
        p = self.plan(("e1", {"kind": "copy-slash", "text": "/kt alpha"}, None))
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        data = self.cov(p, extra=("--evidence", "--dest", d))[1]
        self.assertEqual(self.by(data, "commands")["alpha"]["result"], "never-run")
        self.assertEqual(self.by(data, "commands")["beta"]["result"], None)


if __name__ == "__main__":
    unittest.main()
