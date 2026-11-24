import asyncio, json, os, shutil, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ct, ct_tui

try:
    import textual  # noqa: F401
    HAVE_TEXTUAL = True
except ImportError:
    HAVE_TEXTUAL = False


def run(rid, steps, updated, **extra):
    return {"runId": rid, "planTitle": "plan " + rid, "addon": "KeepThat", "revision": 2, "client": "classic-era", "build": "1", "character": "X",
            "started": updated - 50, "updated": updated, "order": list(steps), "steps": steps,
            "cat": {s: ("c1" if s != "z" else "c2") for s in steps}, "categories": [{"id": "c1", "title": "One"}, {"id": "c2", "title": "Two"}], "selected": {"c1": True, "c2": True}, **extra}


def at(n, verdict, **kw):
    return {"n": n, "verdict": verdict, "started": 100, "finished": 110, **kw}


def make_dest():
    d = tempfile.mkdtemp()
    runs = {
        "R-ok": run("R-ok", {"a": {"verdict": "pass", "attempts": [at(1, "pass")]}}, 3000),
        "R-un": run("R-un", {"a": {"verdict": "unverified", "attempts": [at(1, "unverified")]}}, 2000),
        "R-bad": run("R-bad", {"a": {"verdict": "fail", "attempts": [at(1, "fail", note="first"), at(2, "fail", note="second", excerpt={"debug": ["line one"]})]},
                               "b": {"verdict": "unverified", "attempts": [at(1, "unverified")]},
                               "c": {"verdict": "pass", "attempts": [at(1, "pass")]},
                               "z": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 1000),
    }
    for rid, r in runs.items():
        ct.write_revision(d, r)
    return d


class Logic(unittest.TestCase):
    def setUp(self):
        self.d = make_dest(); self.addCleanup(shutil.rmtree, self.d)
        self.runs = ct.latest_runs(self.d)

    def test_runs_sort_failures_first_then_unverified_then_the_rest(self):
        self.assertEqual([r["id"] for r in ct_tui.run_rows(self.runs, 4000)], ["R-bad", "R-un", "R-ok"])
        row = ct_tui.run_rows(self.runs, 4000)[0]
        self.assertEqual((row["fail"], row["unverified"], row["age"]), (2, 1, "50m"))

    def test_steps_filter_by_result_and_category_and_count_the_total(self):
        r = self.runs["R-bad"]
        rows, total = ct_tui.step_rows("R-bad", r)
        self.assertEqual(([s["id"] for s in rows], total), (["a", "b", "c", "z"], 4))
        self.assertEqual([s["id"] for s in ct_tui.step_rows("R-bad", r, "fail")[0]], ["a", "z"])
        self.assertEqual([s["id"] for s in ct_tui.step_rows("R-bad", r, "unverified")[0]], ["b"])
        self.assertEqual([s["id"] for s in ct_tui.step_rows("R-bad", r, "all", "c2")[0]], ["z"])

    def test_detail_leads_with_the_result_and_opens_the_latest_finished_attempt(self):
        text = ct_tui.detail_text("R-bad", self.runs["R-bad"], "a", self.d)
        self.assertTrue(text.splitlines()[1].startswith("result: FAIL"))
        self.assertIn("attempt 2 of 2", text); self.assertIn("note: second", text); self.assertIn("  line one", text)
        self.assertIn("note: first", ct_tui.detail_text("R-bad", self.runs["R-bad"], "a", self.d, 1))

    def test_detail_says_when_the_evidence_overrules_a_pass_and_when_an_attempt_is_open(self):
        rec = {"verdict": "pass", "attempts": [at(1, "pass", outcomes=[{"result": "fail", "why": "line seen"}]), {"n": 2, "started": 120}]}
        text = ct_tui.detail_text("R", run("R", {"a": rec}, 1), "a")
        self.assertIn("the evidence says otherwise", text); self.assertIn("a newer attempt (2) is still open", text); self.assertIn("required   fail line seen", text)

    def test_detail_shows_the_stack_candidate_and_marks_a_shared_time(self):
        os.makedirs(os.path.join(self.d, "errors"))
        with open(os.path.join(self.d, "errors", "x.json"), "w") as fh:
            json.dump({"runs": ["R-bad"], "errors": ["105.001 [K] boom"], "errorStacks": ["105.001 a.lua:1"]}, fh)
        text = ct_tui.detail_text("R-bad", self.runs["R-bad"], "a", self.d, 2)
        self.assertIn("error 105.001", text); self.assertIn("stack: a.lua:1", text); self.assertIn("time also fits another attempt", text)

    def test_a_huge_detail_is_cut(self):
        rec = {"verdict": "fail", "attempts": [at(1, "fail", outcomes=[{"result": "fail", "why": "w"}] * 1000)]}
        text = ct_tui.detail_text("R", run("R", {"a": rec}, 1), "a")
        self.assertLessEqual(len(text.splitlines()), ct_tui.MAX_DETAIL_LINES + 1); self.assertIn("more lines", text)

    def test_store_reloads_only_after_a_change_has_held_for_one_poll(self):
        s = ct_tui.Store(self.d)
        self.assertFalse(s.poll())
        ct.write_revision(self.d, run("R-new", {"a": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 5000))
        self.assertFalse(s.poll()); self.assertNotIn("R-new", s.runs)      # first sight: a write may still be going on
        self.assertTrue(s.poll()); self.assertIn("R-new", s.runs)
        self.assertFalse(s.poll())

    def test_a_revision_being_written_keeps_the_older_one_on_screen(self):
        s = ct_tui.Store(self.d)
        with open(os.path.join(self.d, "runs", "R-bad", "r3.json"), "w") as fh:
            fh.write('{"steps": {')   # half a write
        s.poll(); s.poll()
        self.assertEqual(s.runs["R-bad"]["revision"], 2)
        self.assertTrue(any("r3.json is unreadable" in p for p in s.problems))

    def test_export_writes_one_run_or_all_and_keeps_stacks_out_unless_asked(self):
        os.makedirs(os.path.join(self.d, "errors"))
        with open(os.path.join(self.d, "errors", "x.json"), "w") as fh:
            json.dump({"runs": ["R-bad"], "errors": ["105.001 [K] boom"], "errorStacks": ["105.001 SECRET"]}, fh)
        def read(p):
            with open(p) as fh:
                return fh.read()
        p = ct_tui.export_report(self.d, self.runs, "json", False, "R-bad")
        self.assertTrue(p.endswith("REPORT-R-bad.json")); self.assertNotIn("SECRET", read(p))
        self.assertIn("SECRET", read(ct_tui.export_report(self.d, self.runs, "json", True)))
        self.assertTrue(os.path.exists(ct_tui.export_report(self.d, self.runs, "junit")))
        self.assertIn("# CT report", read(ct_tui.export_report(self.d, self.runs, "md")))

    def test_a_syntactically_valid_but_malformed_revision_is_unreadable_not_a_crash(self):
        s = ct_tui.Store(self.d)
        with open(os.path.join(self.d, "runs", "R-bad", "r3.json"), "w") as fh:
            json.dump({"steps": {"a": {"attempts": [None]}}}, fh)
        s.poll(); s.poll()
        self.assertEqual(s.runs["R-bad"]["revision"], 2)
        self.assertTrue(any("r3.json is unreadable" in p for p in s.problems))

    def test_export_refuses_nothing_to_write_and_a_symbolic_link_and_leaves_no_temp_file(self):
        with self.assertRaises(ValueError):
            ct_tui.export_report(self.d, {}, "md")
        target = os.path.join(self.d, "elsewhere.txt")
        with open(target, "w") as fh:
            fh.write("keep")
        os.symlink(target, ct_tui.export_path(self.d, "md"))
        with self.assertRaises(ValueError):
            ct_tui.export_report(self.d, self.runs, "md")
        with open(target) as fh:
            self.assertEqual(fh.read(), "keep")
        ct_tui.export_report(self.d, self.runs, "json")
        self.assertEqual([n for n in os.listdir(self.d) if n.endswith(".tmp")], [])

    def test_a_non_ascii_run_id_keeps_its_error_stack(self):
        name = "caf" + chr(233) + "-1"
        ct.write_revision(self.d, run(name, {"a": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 7000))
        os.makedirs(os.path.join(self.d, "errors"))
        with open(os.path.join(self.d, "errors", "u.json"), "w") as fh:
            json.dump({"runs": [name], "errors": ["105.001 [K] boom"], "errorStacks": ["105.001 UNICODE-STACK"]}, fh)
        runs = ct.latest_runs(self.d)
        rid = next(k for k in runs if k.startswith("caf"))
        self.assertIn("UNICODE-STACK", ct_tui.detail_text(rid, runs[rid], "a", self.d))
        self.assertIn("UNICODE-STACK", ct.report_text(runs, self.d))

    def test_the_rich_detail_shows_every_part_and_never_reads_evidence_as_markup(self):
        rec = {"verdict": "pass", "attempts": [at(1, "pass", note="[bold]odd[/] note", evidence="contradicts", outcomes=[
            {"result": "fail", "why": "line [/x] seen"}, {"result": "pass", "why": "ok", "diagnostic": True}, {"result": "unverified", "why": "nothing"}],
            excerpt={"debug": ["one [red]", "two"]})]}
        os.makedirs(os.path.join(self.d, "errors"))
        with open(os.path.join(self.d, "errors", "x.json"), "w") as fh:
            json.dump({"runs": ["R-x"], "errors": ["105.001 [K] boom"], "errorStacks": ["105.001 a.lua:1 / [C]: in function 'pcall'"]}, fh)
        r = run("R-x", {"a": rec}, 8000)
        rec["attempts"][0]["verdict"] = "fail"; rec["verdict"] = "pass"
        shown = ct_tui.render_plain(ct_tui.detail_render(ct_tui.detail_data("R-x", r, "a", self.d)))
        for want in ("FAIL", "the evidence overrules this pass", "attempts", "[bold]odd[/] note", "✗", "diagnostic", "line [/x] seen", "log debug - 2 new lines", "  1   one [red]", "error 105.001", "→ a.lua:1", "→ [C]: in function 'pcall'"):
            self.assertIn(want, shown)
        self.assertEqual(ct_tui.render_plain(ct_tui.detail_render(None)).strip(), "The run has no record of this step.")

    def test_the_detail_shows_the_deciding_lines_under_each_failed_check_and_marks_them_in_the_excerpt(self):
        out = {"result": "fail", "why": "a forbidden line appeared", "rule": 'absent: contains "FAILED"', "kind": "log", "scope": "attempt", "source": "debug",
               "matched": 2, "window": 4, "hits": [{"n": 2, "line": "[kt] FAILED [x] one"}, {"n": 4, "line": "FAILED two"}]}
        seq = {"result": "unverified", "why": "sequence stopped at item 2", "rule": "sequence of 3 lines", "kind": "log-sequence", "source": "debug", "matched": 1, "window": 4,
               "stoppedAt": 2, "hits": [{"item": 1, "n": 1, "line": "a1"}]}
        st = {"result": "fail", "rule": "global-value G eq 3", "kind": "state", "observed": "2"}
        rec = {"verdict": "fail", "attempts": [at(1, "fail", outcomes=[out, seq, st, {"result": "pass"}, dict(out, hits=None, trimmed=True)],
                                                  excerpt={"debug": ["one", "[kt] FAILED [x] one", "three", "FAILED two"]})]}
        r = run("R-h", {"a": rec}, 8000)
        shown = ct_tui.render_plain(ct_tui.detail_render(ct_tui.detail_data("R-h", r, "a")))
        for want in ('check 1 - fail', 'absent: contains "FAILED"', "debug  ·  2 of 4 lines matched", "▶ line 2  [kt] FAILED [x] one", "▶ line 4  FAILED two",
                     "check 2 - unverified", "stopped at item 2", "▶ item 1 at line 1  a1", "check 3 - fail", "saw  2", "hit text dropped"):
            self.assertIn(want, shown)
        self.assertIn("  2 ▶ [kt] FAILED [x] one", shown); self.assertIn("  4 ▶ FAILED two", shown); self.assertIn("  1 ▶ one", shown); self.assertIn("  3   three", shown)   # a line carries the marker only when it decided a check
        plain = ct_tui.detail_text("R-h", r, "a")
        self.assertIn('check 1 (required, fail): absent: contains "FAILED"', plain); self.assertIn("line 2: [kt] FAILED [x] one", plain)

    def test_browse_is_the_same_viewer_and_refuses_without_a_terminal(self):
        import io, contextlib
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(ct.main(["browse", "--dest", self.d]), 2)

    def test_without_a_terminal_it_prints_the_cli_commands_and_does_not_load_textual(self):
        import io, contextlib
        saved = sys.modules.get("textual", "absent"); sys.modules["textual"] = None   # an import of it would fail
        err = io.StringIO()
        try:
            with contextlib.redirect_stderr(err):
                code = ct_tui.main(["--dest", self.d])
        finally:
            if saved == "absent":
                del sys.modules["textual"]
            else:
                sys.modules["textual"] = saved
        self.assertEqual(code, 2); self.assertIn("needs a terminal", err.getvalue()); self.assertIn("status --dest", err.getvalue()); self.assertIn("report --failed-only", err.getvalue())


@unittest.skipUnless(HAVE_TEXTUAL, "Textual (and Rich) is not installed")
class Views(unittest.TestCase):
    def setUp(self):
        self.d = make_dest(); self.addCleanup(shutil.rmtree, self.d)
        self.runs = ct.latest_runs(self.d)

    def test_runs_count_once_and_show_done_over_eligible(self):
        rows = ct_tui.run_rows(self.runs, 4000)
        bad = rows[0]
        self.assertEqual((bad["resolved"], bad["eligible"]), (3, 4))   # pass and fail count; unverified does not
        self.assertEqual(ct_tui.run_summary(rows), {"runs": 3, "failing": 1, "unverified": 1, "no_flags": 1})
        both = dict(bad, unverified=5)
        self.assertEqual(ct_tui.run_summary([both]), {"runs": 1, "failing": 1, "unverified": 0, "no_flags": 0})   # fail wins, once

    def test_run_cells_use_words_and_marks_and_a_dash_for_no_eligible_steps(self):
        rows = {r["id"]: r for r in ct_tui.run_rows(self.runs, 4000)}
        plain = lambda row, wide: [c.plain for c in ct_tui.run_cells(row, wide)]
        self.assertEqual(plain(rows["R-bad"], False), ["✗ FAIL", "R-bad", "3/4"])
        self.assertEqual(plain(rows["R-un"], False)[0], "? UNVER"); self.assertEqual(plain(rows["R-ok"], False)[0], "—")
        self.assertEqual(plain(rows["R-bad"], True), ["✗ FAIL", "R-bad", "plan R-bad", "2", "3/4", "2", "1", plain(rows["R-bad"], True)[7]])
        self.assertEqual(plain(dict(rows["R-ok"], eligible=0, resolved=0), False)[2], "—")
        self.assertEqual(len(ct_tui.RUN_COLUMNS[False]), 3); self.assertEqual(len(ct_tui.RUN_COLUMNS[True]), 8)

    def test_runs_header_counts_and_caps_the_problem_to_one_line(self):
        rows = ct_tui.run_rows(self.runs, 4000)
        text = ct_tui.render_plain(ct_tui.runs_header(rows, ["a", "b"], False), 60)
        self.assertIn("3 runs · 1 fail · 1 unver · 1 no flag", text); self.assertIn("⚠ 2 problems: a", text); self.assertNotIn("b\n", text)
        self.assertIn("1 no flags", ct_tui.render_plain(ct_tui.runs_header(rows, []), 80))

    def test_step_cells_carry_the_result_in_words_and_marks(self):
        steps = {s["id"]: s for s in ct_tui.step_rows("R-bad", self.runs["R-bad"])[0]}
        self.assertEqual([c.plain for c in ct_tui.step_cells(steps["a"], False)], ["✗ fail", "a"])
        self.assertEqual([c.plain for c in ct_tui.step_cells(steps["b"], True)], ["? unverified", "b", "c1", "no evidence"])
        self.assertEqual(ct_tui.step_cells(steps["c"], False)[0].plain, "✓ pass")

    def test_a_category_chip_follows_the_evidence_not_the_players_pass(self):
        rec = {"verdict": "pass", "attempts": [at(1, "pass", outcomes=[{"result": "fail", "why": "line seen"}])]}
        r = run("R-x", {"a": rec}, 1)
        self.assertEqual(ct_tui.category_chips("R-x", r)[0][:2], ("c1", "red"))   # the tracker would say green
        self.assertEqual(ct_tui.category_chips("R-x", r)[1][1], "grey")             # c2 has no steps in this run
        r["selected"]["c2"] = False
        self.assertEqual(ct_tui.category_chips("R-x", r)[1][1], "off")

    def test_steps_header_narrow_and_wide(self):
        r = self.runs["R-bad"]
        narrow = ct_tui.render_plain(ct_tui.steps_header("R-bad", r, "fail", None, 2, 4, False), 40)
        self.assertIn(" FAIL ", narrow); self.assertIn("R-bad  2✗ 1? 1✓", narrow); self.assertIn("f: fail   /: all categories   2/4", narrow)
        self.assertNotIn("c1", narrow)   # no chip wall at 40 columns
        wide = ct_tui.render_plain(ct_tui.steps_header("R-bad", r, "fail", "c2", 1, 4, True), 100)
        self.assertIn("✗ c1 2/3", wide); self.assertIn("✗ c2 1/1", wide); self.assertIn("category  c2", wide); self.assertIn("1/4", wide)
        self.assertIn("No matching steps", ct_tui.render_plain(ct_tui.steps_header("R-bad", r, "fail", "c2", 0, 4, True), 100))


@unittest.skipUnless(HAVE_TEXTUAL, "Textual is not installed")
class Screens(unittest.TestCase):
    def setUp(self):
        self.d = make_dest(); self.addCleanup(shutil.rmtree, self.d)

    def drive(self, script, size=(100, 30)):
        app = ct_tui.make_app(ct_tui.Store(self.d), interval=0.05)

        async def go():
            async with app.run_test(size=size) as pilot:
                await pilot.pause()
                await script(app, pilot)
        asyncio.run(go())
        return app

    def table(self, app):
        from textual.widgets import DataTable
        return app.screen.query_one(DataTable)

    def keys(self, app):
        t = self.table(app)
        return [t.coordinate_to_cell_key(t.cursor_coordinate.__class__(r, 0)).row_key.value for r in range(t.row_count)]

    def test_drill_down_filter_attempts_and_back(self):
        async def script(app, pilot):
            self.assertEqual(self.keys(app), ["R-bad", "R-un", "R-ok"])
            await pilot.press("enter"); await pilot.pause()
            self.assertEqual(self.keys(app), ["a", "b", "c", "z"])
            await pilot.press("f"); await pilot.pause()
            self.assertEqual(self.keys(app), ["a", "z"])
            await pilot.press("f"); await pilot.pause()
            self.assertEqual(self.keys(app), ["b"])
            await pilot.press("f", "slash"); await pilot.pause()   # all again, then category c1
            self.assertEqual(self.keys(app), ["a", "b", "c"])
            await pilot.press("slash"); await pilot.pause()
            self.assertEqual(self.keys(app), ["z"])
            await pilot.press("slash", "up", "up", "up", "enter"); await pilot.pause()   # all categories again; the cursor stayed on z, go up to a and open it
            body = ct_tui.render_plain(app.screen.shown)
            self.assertIn("attempt 2 of 2", body); self.assertIn("second", body)
            await pilot.press("left_square_bracket"); await pilot.pause()
            shown = ct_tui.render_plain(app.screen.shown)
            self.assertIn("attempt 1 of 2", shown); self.assertIn("first", shown)
            await pilot.press("escape", "escape"); await pilot.pause()
            self.assertEqual(self.keys(app), ["R-bad", "R-un", "R-ok"])
        self.drive(script)

    def test_a_reload_keeps_the_selected_run_when_the_order_changes(self):
        async def script(app, pilot):
            await pilot.press("down"); await pilot.pause()   # R-un, the middle row
            t = self.table(app)
            self.assertEqual(t.coordinate_to_cell_key(t.cursor_coordinate).row_key.value, "R-un")
            ct.write_revision(self.d, run("R-ok", {"a": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 9000, revision=3))   # now the newest failing run
            await pilot.press("r"); await pilot.pause()
            self.assertEqual(self.keys(app), ["R-ok", "R-bad", "R-un"])   # R-un moved from the middle to the last row ...
            t = self.table(app)
            self.assertEqual((t.cursor_row, t.coordinate_to_cell_key(t.cursor_coordinate).row_key.value), (2, "R-un"))   # ... and the cursor went with it
        self.drive(script)

    def test_the_screen_follows_the_folder_by_itself(self):
        async def script(app, pilot):
            ct.write_revision(self.d, run("R-new", {"a": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 9000))
            for _ in range(10):
                await pilot.pause(0.1)
            self.assertIn("R-new", self.keys(app))
        self.drive(script)

    def test_step_ids_with_markup_characters_do_not_break_the_screens(self):
        r = run("R-mk", {"[red]": {"verdict": "fail", "attempts": [at(1, "fail", note="[/red] note")]}, "[/red]": {"verdict": "fail", "attempts": [at(1, "fail")]}}, 8000)
        ct.write_revision(self.d, r)
        async def script(app, pilot):
            await pilot.press("enter"); await pilot.pause()   # R-mk is the newest failing run
            self.assertEqual(self.keys(app), ["[red]", "[/red]"])
            await pilot.press("enter"); await pilot.pause()
            self.assertIn("[/red] note", ct_tui.render_plain(app.screen.shown))
        self.drive(script)

    def test_a_vanished_run_closes_its_screens_and_what_is_open_over_them(self):
        async def script(app, pilot):
            await pilot.press("enter", "enter", "e"); await pilot.pause()   # Runs > Steps of R-bad > Step a > Export
            shutil.rmtree(os.path.join(self.d, "runs", "R-bad"))
            for _ in range(12):
                await pilot.pause(0.1)
            self.assertEqual(self.keys(app), ["R-un", "R-ok"])   # back on the runs screen, nothing stale left open
            self.assertEqual(len(app.screen_stack), 2)   # the default screen and the runs screen
        self.drive(script)

    def test_the_bracket_key_moves_from_the_attempt_on_screen(self):
        rec = {"verdict": "fail", "attempts": [at(1, "fail", note="one"), at(2, "fail", note="two"), {"n": 3, "started": 120}]}
        ct.write_revision(self.d, run("R-open", {"a": rec}, 8000))
        async def script(app, pilot):
            await pilot.press("enter", "enter"); await pilot.pause()
            body = lambda: ct_tui.render_plain(app.screen.shown)
            self.assertIn("attempt 2 of 3", body()); self.assertIn("two", body()); self.assertIn("a newer attempt (3) is still open", body())
            await pilot.press("left_square_bracket"); await pilot.pause()
            self.assertIn("attempt 1 of 3", body()); self.assertIn("one", body())
        self.drive(script)

    def test_a_narrow_terminal_shows_triage_columns_and_a_wide_one_brings_the_rest_back(self):
        with open(os.path.join(self.d, "runs", "R-bad", "r3.json"), "w") as fh:
            fh.write("{broken, and a very long problem line follows so that it would wrap at forty columns if it were allowed to")   # a problem to show
        async def script(app, pilot):
            await pilot.press("r"); await pilot.pause()
            t = self.table(app)
            self.assertIn("red", str(t.get_row("R-bad")[0].style))   # the styles reach the table
            self.assertEqual(app.screen.query_one("#note").size.height, 2)   # summary and one problem line, nothing wrapped
            self.assertEqual([str(c.label) for c in t.columns.values()], list(ct_tui.RUN_COLUMNS[False]))
            row = [c.plain for c in t.get_row("R-bad")]
            self.assertEqual(row, ["✗ FAIL", "R-bad", "3/4"])
            await pilot.resize_terminal(100, 30); await pilot.pause()
            t = self.table(app)
            self.assertEqual([str(c.label) for c in t.columns.values()], list(ct_tui.RUN_COLUMNS[True]))
            self.assertEqual(t.row_count, 3)
            await pilot.press("enter"); await pilot.pause()
            self.assertEqual([str(c.label) for c in self.table(app).columns.values()], list(ct_tui.STEP_COLUMNS[True]))
            await pilot.resize_terminal(40, 12); await pilot.pause()
            t = self.table(app)
            self.assertEqual([str(c.label) for c in t.columns.values()], list(ct_tui.STEP_COLUMNS[False]))
            self.assertEqual([c.plain for c in t.get_row("a")], ["✗ fail", "a"])
            await pilot.press("f", "f", "f"); await pilot.pause()
            self.assertIn("f: all", ct_tui.render_plain(app.screen.shown, 40))
        self.drive(script, size=(40, 12))

    def test_a_narrow_terminal_still_works(self):
        async def script(app, pilot):
            await pilot.press("enter", "enter"); await pilot.pause()
            self.assertIn("FAIL", ct_tui.render_plain(app.screen.shown))
        self.drive(script, size=(40, 12))

    def test_export_shows_what_it_will_do_then_writes(self):
        async def script(app, pilot):
            await pilot.press("enter", "e"); await pilot.pause()
            shown = str(app.screen.query_one("#export").render())
            self.assertIn("run R-bad", shown); self.assertIn("REPORT-R-bad.md", shown)
            await pilot.press("j"); await pilot.pause()
            shown = str(app.screen.query_one("#export").render())
            self.assertIn("REPORT-R-bad.json", shown); self.assertIn("left out", shown)
            await pilot.press("s"); await pilot.pause()
            self.assertIn("private paths", str(app.screen.query_one("#export").render()))
            self.assertFalse(os.path.exists(os.path.join(self.d, "REPORT-R-bad.json")))
            await pilot.press("enter"); await pilot.pause()
            self.assertTrue(os.path.exists(os.path.join(self.d, "REPORT-R-bad.json")))
        self.drive(script)


if __name__ == "__main__":
    unittest.main()
