import contextlib, io, json, os, shutil, sys, tempfile, unittest
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mutate


def slurp(path):
    with open(path) as f:
        return f.read()


class Mutate(unittest.TestCase):
    def project(self, tests=None):
        d = tempfile.mkdtemp(); self.addCleanup(shutil.rmtree, d)
        def put(name, text):
            p = os.path.join(d, name); os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f: f.write(text)
        put("CheckThat/Core/A.lua", '-- a == b is a comment, true too\nlocal s = "x == y and true"\nfunction F(x)\n  if x == 1 then return true end\n  return false\nend\nfunction G() return 5 end\n')
        put("CheckThat/Libs/Skipped.lua", "x = true\n")
        put("CheckThat/Core/B.lua", 'function T()\n  return {\n    a = 1,\n  }\nend\nlocal reg = {}\nreg:RegisterEvent("X")\nif reg then H = 1 end\n')
        put("tests/test_a.lua", tests or 'dofile("CheckThat/Core/A.lua")\nassert(F(1) == true)\nassert(F(2) == false)\n')
        return d

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = mutate.main(list(args))
        return code, out.getvalue(), err.getvalue()

    def test_strings_comments_and_libs_are_not_mutated(self):
        d = self.project()
        ms = mutate.mutants(d)
        self.assertTrue(ms)
        self.assertEqual({m["file"] for m in ms}, {"CheckThat/Core/A.lua", "CheckThat/Core/B.lua"}, "Libs is skipped")
        ms = [m for m in ms if m["file"].endswith("A.lua")]
        self.assertEqual({m["line"] for m in ms}, {4, 5, 7}, "lines 1 and 2 hold only a comment and a string")
        self.assertIn(("eq", "==", "~="), {(m["op"], m["before"], m["after"]) for m in ms})

    def test_a_tested_change_is_killed_and_an_untested_one_survives(self):
        d = self.project()
        code, out, err = self.run_main("--root", d, "--runner", "luajit tests/test_a.lua", "--format", "json", "--jobs", "2")
        self.assertEqual(code, 0, err)
        r = json.loads(out)
        self.assertGreater(r["invalid"], 0, "the multi-line return in B.lua does not compile once cut in two")
        self.assertGreater(r["killed"], 0); self.assertGreater(r["survived"], 0)
        left = {(s["line"], s["op"]) for s in r["survivors"]}
        self.assertIn((7, "return-nil"), left, "G is never checked")
        self.assertNotIn((4, "eq"), left, "the test notices x == 1 turned into x ~= 1")
        self.assertEqual(r["run"], r["killed"] + r["survived"])

    def test_each_operator_makes_its_change(self):
        d = self.project()
        by = {(m["file"][-5:], m["op"]): m for m in mutate.mutants(d)}
        self.assertEqual(by[("B.lua", "register")]["after"], "local _ = nil")
        self.assertEqual(by[("B.lua", "if-true")]["after"], "if true then")
        self.assertEqual(by[("B.lua", "if-false")]["after"], "if false then")
        self.assertIn("return nil", by[("A.lua", "return-nil")]["after"])
        self.assertEqual(by[("A.lua", "bool")]["after"] in ("false", "true"), True)

    def test_a_mutant_that_does_not_compile_is_neither_killed_nor_survived(self):
        d = self.project()
        bad = [m for m in mutate.mutants(d, ["CheckThat/Core/B.lua"]) if m["op"] == "return-nil" and m["line"] == 2]
        self.assertEqual(len(bad), 1)
        with tempfile.TemporaryDirectory() as w:
            mutate.prepare(d, w)
            orig = {"CheckThat/Core/B.lua": slurp(os.path.join(d, "CheckThat/Core/B.lua"))}
            self.assertEqual(mutate.run_one(w, orig, bad[0], 30, ["luajit", "tests/test_a.lua"]), "invalid")
            self.assertEqual(slurp(os.path.join(w, "CheckThat/Core/B.lua")), orig["CheckThat/Core/B.lua"], "the file is put back")

    def test_a_missing_runner_is_a_clear_error(self):
        d = self.project()
        code, out, err = self.run_main("--root", d, "--runner", "no-such-binary-xyz tests/test_a.lua")
        self.assertEqual(code, 2); self.assertIn("cannot run no-such-binary-xyz", err)

    def test_a_suite_that_fails_before_any_change_is_an_error(self):
        d = self.project('error("broken from the start")\n')
        code, out, err = self.run_main("--root", d, "--runner", "luajit tests/test_a.lua")
        self.assertEqual(code, 2); self.assertIn("fails on an unmutated copy", err)

    def test_the_sample_is_seeded_and_list_runs_no_tests(self):
        d = self.project()
        a = self.run_main("--root", d, "--list", "--limit", "3", "--seed", "7")[1]
        b = self.run_main("--root", d, "--list", "--limit", "3", "--seed", "7")[1]
        self.assertEqual(a, b); self.assertIn("3 mutants", a)

    def test_the_text_report_gives_the_score_and_the_survivors(self):
        text = mutate.report([{"state": "killed", "file": "f", "line": 1, "op": "eq", "before": "==", "after": "~="},
                              {"state": "survived", "file": "f", "line": 2, "op": "bool", "before": "true", "after": "false"}], "md")
        self.assertIn("50.0% (1 killed of 2 run, 1 survived)", text); self.assertIn("f:2  [bool]  true  ->  false", text)


if __name__ == "__main__":
    unittest.main()
