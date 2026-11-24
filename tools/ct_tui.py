#!/usr/bin/env python3
"""Read-only viewer for collected CheckThat evidence: runs, steps, one step's attempts.

Optional. Needs Textual (pip install -r requirements-tui.txt) and a terminal. Collection stays in ct.py.
The data rules are plain functions here and in ct.py, so they work and are tested without Textual.
"""
import argparse, glob, os, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ct

FILTERS = ("all", "fail", "unverified")
MAX_DETAIL_LINES = 400   # evidence is shown as plain text; a hostile or huge record must not flood the screen


def run_rows(runs, now=None):
    """One row per run: failures first, then unverified, then the rest; newest first inside each group."""
    now = time.time() if now is None else now
    rows = []
    for rid, r in runs.items():
        c = ct.run_model(rid, r)["counts"]
        stamp = r.get("updated") or r.get("started")
        stamp = stamp if isinstance(stamp, (int, float)) else 0
        rows.append({"id": rid, "plan": str(r.get("planTitle") or r.get("addon") or ""), "rev": r.get("revision"),
                     "fail": c.get("fail", 0), "unverified": c.get("unverified", 0), "stamp": stamp,
                     "age": ct.age(now - stamp) if stamp else "?"})
    rows.sort(key=lambda x: (0 if x["fail"] else 1 if x["unverified"] else 2, -x["stamp"], x["id"]))
    return rows


def categories(r):
    return [c.get("id") for c in r.get("categories") or [] if isinstance(c, dict)]


def step_rows(rid, r, flt="all", cat=None):
    """(rows, total): the steps of a run in plan order, narrowed by result (all, fail, unverified) and category."""
    steps = ct.run_model(rid, r)["steps"]
    rows = [s for s in steps if (flt == "all" or s["result"] == flt) and (cat is None or s["category"] == cat)]
    return rows, len(steps)


def attempt_numbers(rec):
    return [a.get("n") for a in (rec or {}).get("attempts") or []]


def shown_attempt(rec, n=None):
    """The attempt the detail shows: the one asked for, else the latest finished, else the last."""
    ats = (rec or {}).get("attempts") or []
    done = [a for a in ats if a.get("verdict")]
    return next((a for a in ats if a.get("n") == n), None) or (done[-1] if done else ats[-1] if ats else None)


def _when(t):
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t)) if isinstance(t, (int, float)) else "?"


def detail_text(rid, r, sid, dest=None, n=None):
    """The classified result first, then one attempt (the latest finished by default) with its notes, outcomes,
    log lines and the errors raised while it was open."""
    rec = (r.get("steps") or {}).get(sid)
    if rec is None:
        return "The run has no record of step %s." % sid
    result, why = ct.classify(rec)
    out = ["%s / %s" % (rid, sid), "result: %s%s" % (result.upper(), " - " + why if why else ""),
           "player verdict: %s%s" % (rec.get("verdict"), "   (the evidence says otherwise)" if rec.get("verdict") in ("pass", "partial") and result in ("fail", "unverified") else "")]
    ats = rec.get("attempts") or []
    if not ats:
        return "\n".join(out + ["", "No attempts."])
    at = shown_attempt(rec, n)
    pos = ats.index(at)
    out += ["", "attempt %s of %d  ([ and ] move)" % (at.get("n"), len(ats))]
    if pos < len(ats) - 1 and not ats[-1].get("verdict"):
        out.append("a newer attempt (%s) is still open" % ats[-1].get("n"))
    out.append("verdict: %s   claimed: %s   by: %s   evidence: %s" % (at.get("verdict"), at.get("claimed"), at.get("by"), at.get("evidence")))
    out.append("opened %s, finished %s" % (_when(at.get("started")), _when(at.get("finished"))))
    if at.get("note"):
        out.append("note: " + " ".join(str(at["note"]).split()))
    for o in at.get("outcomes") or []:
        out.append("  %s %s %s" % ("diagnostic" if o.get("diagnostic") else "required  ", o.get("result"), o.get("why", "")))
    for src, lines in sorted((at.get("excerpt") or {}).items()):
        out.append("log %s, %d new line%s:" % (src, len(lines), "" if len(lines) == 1 else "s"))
        out.extend("  " + str(line) for line in lines)
    if dest and at.get("verdict") in ("fail", "unverified"):
        errs, stks = ct.load_errors(dest, ct.stored_id(rid, r))
        hits, ambiguous = ct.stack_hits(r, stks)
        for key in hits.get((sid, at.get("n")), []):
            out.append("error %s%s: %s" % (key, " (time also fits another attempt)" if key in ambiguous else "", errs.get(key, "(error line no longer saved)")))
            out.append("  stack: " + stks[key])
    if len(out) > MAX_DETAIL_LINES:
        out = out[:MAX_DETAIL_LINES] + ["... %d more lines" % (len(out) - MAX_DETAIL_LINES)]
    return "\n".join(out)


EXPORTS = {"md": ("REPORT.md", "Markdown"), "json": ("REPORT.json", "JSON"), "junit": ("REPORT.xml", "JUnit XML")}


def export_path(dest, fmt, rid=None):
    base, ext = os.path.splitext(EXPORTS[fmt][0])
    return os.path.join(dest, base + ("-" + ct.safe_name(rid) if rid else "") + ext)


def export_report(dest, runs, fmt, stacks=False, rid=None):
    """Write the report for one run (rid) or all runs; returns the path. Markdown always carries stacks."""
    chosen = {rid: runs[rid]} if rid else runs
    if not chosen:
        raise ValueError("there are no runs to export")
    txt = ct.report_text(chosen, dest) if fmt == "md" else (ct.report_json if fmt == "json" else ct.report_junit)(chosen, dest, stacks)
    path = export_path(dest, fmt, rid)
    if os.path.islink(path):
        raise ValueError("%s is a symbolic link; not writing through it" % path)
    os.makedirs(dest, exist_ok=True)
    tmp = path + ".tmp"
    try:
        with open(tmp, "w") as fh:
            fh.write(txt)
        os.replace(tmp, path)   # an old report stays whole if the write fails
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    return path


class Store:
    """What the viewer shows, reloaded when the evidence folder changes."""

    def __init__(self, dest, clock=time.time):
        self.dest, self.clock, self.pending = dest, clock, None
        self.load()

    def signature(self):
        files = glob.glob(os.path.join(self.dest, "runs", "*", "r*.json")) + glob.glob(os.path.join(self.dest, "errors", "*.json")) + [os.path.join(self.dest, "problems.log")]
        sig = []
        for p in sorted(files):
            try:
                st = os.stat(p)
                sig.append((p, st.st_mtime_ns, st.st_size))
            except OSError:
                pass
        return tuple(sig)

    def load(self):
        self.sig = self.signature()
        self.runs = ct.latest_runs(self.dest)   # the newest readable revision, so a write in progress shows the one before
        _, self.problems, _ = ct.status_data(self.dest, self.clock())
        self.rows = run_rows(self.runs, self.clock())

    def poll(self):
        """True when the folder changed and stayed the same for one more poll (a write has finished), and it was reloaded."""
        s = self.signature()
        if s == self.sig:
            self.pending = None
            return False
        if s != self.pending:
            self.pending = s
            return False
        self.load()
        self.pending = None
        return True


def collect_hint(dest):
    return "%s %s collect --dest %s" % (sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ct.py"), dest)


def make_app(store, interval=2.0):
    """The Textual app. Textual is imported here, so everything above works without it."""
    from textual.app import App
    from textual.binding import Binding
    from textual.containers import VerticalScroll
    from textual.coordinate import Coordinate
    from textual.screen import ModalScreen, Screen
    from textual.widgets import DataTable, Footer, Header, Static
    from rich.text import Text

    def cursor_key(table):
        if table.row_count == 0:
            return None
        try:
            return table.coordinate_to_cell_key(table.cursor_coordinate).row_key.value
        except Exception:
            return None

    def fill(table, rows, keep):
        table.clear()
        for key, cells in rows:
            table.add_row(*[Text(str(c)) for c in cells], key=key)   # Text: evidence is not markup
        if keep is not None:
            try:
                table.move_cursor(row=table.get_row_index(keep))
            except Exception:
                pass

    class Back(Screen):
        BINDINGS = [Binding("escape", "back", "Back")]

        def action_back(self):
            self.app.pop_screen()

    class RunsScreen(Screen):
        def compose(self):
            yield Header()
            yield Static("", id="note", markup=False)
            yield DataTable(id="runs", cursor_type="row", zebra_stripes=True)
            yield Footer()

        def on_mount(self):
            self.query_one(DataTable).add_columns("run", "plan", "rev", "fail", "unver", "age")
            self.refill()
            self.query_one(DataTable).focus()

        def refill(self):
            t = self.query_one(DataTable)
            fill(t, [(r["id"], (r["id"], r["plan"], str(r["rev"]), str(r["fail"]), str(r["unverified"]), r["age"])) for r in self.app.store.rows], cursor_key(t))
            p = self.app.store.problems
            self.query_one("#note", Static).update(("%d problem%s: %s" % (len(p), "" if len(p) == 1 else "s", p[0])) if p else "%d run%s, no problems" % (len(self.app.store.rows), "" if len(self.app.store.rows) == 1 else "s"))

        def on_data_table_row_selected(self, ev):
            self.app.push_screen(StepsScreen(ev.row_key.value))

    class StepsScreen(Back):
        BINDINGS = [Binding("f", "filter", "Filter"), Binding("slash", "category", "Category")]

        def __init__(self, rid):
            super().__init__()
            self.rid, self.flt, self.cat = rid, 0, None

        def compose(self):
            yield Header()
            yield Static("", id="note", markup=False)
            yield DataTable(id="steps", cursor_type="row", zebra_stripes=True)
            yield Footer()

        def on_mount(self):
            self.query_one(DataTable).add_columns("step", "category", "result", "reason")
            self.refill()
            self.query_one(DataTable).focus()

        def refill(self):
            r = self.app.store.runs.get(self.rid)
            if r is None:
                return   # the app drops this screen
            rows, total = step_rows(self.rid, r, FILTERS[self.flt], self.cat)
            t = self.query_one(DataTable)
            fill(t, [(s["id"], (s["id"], str(s["category"] or ""), s["result"], s["reason"])) for s in rows], cursor_key(t))
            self.query_one("#note", Static).update("%s   filter: %s   category: %s   showing %d of %d" % (self.rid, FILTERS[self.flt], self.cat or "all", len(rows), total))

        def action_filter(self):
            self.flt = (self.flt + 1) % len(FILTERS)
            self.refill()

        def action_category(self):
            cats = categories(self.app.store.runs.get(self.rid) or {})
            order = [None] + cats
            self.cat = order[(order.index(self.cat) + 1) % len(order)] if self.cat in order else None
            self.refill()

        def on_data_table_row_selected(self, ev):
            self.app.push_screen(DetailScreen(self.rid, ev.row_key.value))

    class DetailScreen(Back):
        BINDINGS = [Binding("left_square_bracket", "move(-1)", "Earlier attempt"), Binding("right_square_bracket", "move(1)", "Later attempt")]

        def __init__(self, rid, sid):
            super().__init__()
            self.rid, self.sid, self.n = rid, sid, None

        def compose(self):
            yield Header()
            with VerticalScroll():
                yield Static("", id="body", markup=False)
            yield Footer()

        def on_mount(self):
            self.refill()

        def refill(self):
            r = self.app.store.runs.get(self.rid)
            if r is None:
                return
            self.query_one("#body", Static).update(detail_text(self.rid, r, self.sid, self.app.store.dest, self.n))

        def action_move(self, delta):
            r = self.app.store.runs.get(self.rid) or {}
            nums = attempt_numbers((r.get("steps") or {}).get(self.sid))
            if not nums:
                return
            cur = (shown_attempt((r.get("steps") or {}).get(self.sid), self.n) or {}).get("n")   # move from the attempt on screen
            self.n = nums[max(0, min(len(nums) - 1, nums.index(cur) + int(delta)))]
            self.refill()

    class HelpScreen(ModalScreen):
        BINDINGS = [Binding("escape", "app.pop_screen", "Close"), Binding("question_mark", "app.pop_screen", "Close")]

        def compose(self):
            yield Static("Enter  open        Esc  back        r  reload        q  quit\n"
                         "f  filter steps (all, fail, unverified)        /  next category\n"
                         "[  ]  earlier or later attempt        e  export a report        c  how to collect\n"
                         "The screen reloads itself when the evidence folder changes.", id="help", markup=False)

    class ExportScreen(ModalScreen):
        BINDINGS = [Binding("escape", "app.pop_screen", "Cancel"), Binding("m", "pick('md')", "Markdown"), Binding("j", "pick('json')", "JSON"),
                    Binding("x", "pick('junit')", "JUnit"), Binding("s", "stacks", "Stacks"), Binding("enter", "write", "Write")]

        def __init__(self, rid):
            super().__init__()
            self.rid, self.fmt, self.stacks = rid, "md", False

        def compose(self):
            yield Static("", id="export", markup=False)

        def on_mount(self):
            self.show()

        def refill(self):
            self.show()

        def show(self):
            s = self.app.store
            self.query_one("#export", Static).update(
                "Export a report\n\nscope:  %s\nformat: %s   (m Markdown, j JSON, x JUnit)\nfile:   %s%s\nstacks: %s\n\nEnter writes the file. Esc cancels." % (
                    ("run " + self.rid) if self.rid else "all %d runs" % len(s.runs), EXPORTS[self.fmt][1], export_path(s.dest, self.fmt, self.rid),
                    "   (exists: Enter replaces it)" if os.path.exists(export_path(s.dest, self.fmt, self.rid)) else "",
                    "included (Markdown always has them)" if self.fmt == "md" else ("included - they can hold private paths" if self.stacks else "left out (s adds them)")))

        def action_pick(self, fmt):
            self.fmt = fmt
            self.show()

        def action_stacks(self):
            self.stacks = not self.stacks
            self.show()

        def action_write(self):
            try:
                path = export_report(self.app.store.dest, self.app.store.runs, self.fmt, self.stacks, self.rid)
            except (OSError, ValueError) as e:
                self.query_one("#export", Static).update("Could not write the report: %s\n\nEsc closes this." % e)
                return
            self.app.pop_screen()
            self.app.notify("wrote " + path)

    class CtApp(App):
        TITLE = "CheckThat evidence"
        BINDINGS = [Binding("q", "quit", "Quit"), Binding("r", "reload", "Reload"), Binding("question_mark", "help", "Help"),
                    Binding("c", "collect", "Collect"), Binding("e", "export", "Export")]

        def __init__(self):
            super().__init__()
            self.store = store

        def on_mount(self):
            self.push_screen(RunsScreen())
            self.set_interval(interval, self.poll)

        def refresh_screens(self):
            for i, s in enumerate(list(self.screen_stack)):   # a run that vanished takes its screens, and what is open over them, with it
                if getattr(s, "rid", None) is not None and s.rid not in self.store.runs:
                    while len(self.screen_stack) > i:
                        self.pop_screen()
                    break
            for s in list(self.screen_stack):
                if hasattr(s, "refill"):
                    s.refill()

        def poll(self):
            if self.store.poll():
                self.refresh_screens()

        def action_reload(self):
            self.store.load()
            self.refresh_screens()

        def action_help(self):
            self.push_screen(HelpScreen())

        def action_collect(self):
            self.notify("Collect runs in a shell, then press r: " + collect_hint(self.store.dest), timeout=15)

        def action_export(self):
            cur = next((s for s in reversed(self.screen_stack) if hasattr(s, "rid")), None)
            self.push_screen(ExportScreen(cur.rid if cur else None))

    return CtApp()


def main(argv=None):
    ap = argparse.ArgumentParser(prog="ct_tui.py", description="Browse collected CheckThat evidence. Read-only.")
    ap.add_argument("--dest", default=os.path.join(ct.ROOT, "evidence"))
    a = ap.parse_args(argv)
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ct.py")
    if not (sys.stdin.isatty() and sys.stdout.isatty()):   # checked before Textual is imported
        print("This viewer needs a terminal. The same facts, without one:\n  %s %s status --dest %s\n  %s %s report --failed-only --dest %s\n  %s %s show <run> [step] --dest %s"
              % (sys.executable, here, a.dest, sys.executable, here, a.dest, sys.executable, here, a.dest), file=sys.stderr)
        return 2
    try:
        import textual  # noqa: F401
    except ImportError:
        print("The viewer needs Textual: %s -m pip install -r %s" % (sys.executable, os.path.normpath(os.path.join(os.path.dirname(here), "..", "requirements-tui.txt"))), file=sys.stderr)
        return 2
    make_app(Store(a.dest)).run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
