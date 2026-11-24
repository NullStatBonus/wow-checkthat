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
        m = ct.run_model(rid, r)
        c = m["counts"]
        eligible = [s for s in m["steps"] if s["verdict"] not in ("deselected", "inapplicable")]   # the rule status_data uses
        resolved = sum(1 for s in eligible if s["verdict"] in ("pass", "partial", "fail", "skip"))
        stamp = r.get("updated") or r.get("started")
        stamp = stamp if isinstance(stamp, (int, float)) else 0
        rows.append({"id": rid, "plan": str(r.get("planTitle") or r.get("addon") or ""), "rev": r.get("revision"),
                     "fail": c.get("fail", 0), "unverified": c.get("unverified", 0), "stamp": stamp, "resolved": resolved, "eligible": len(eligible),
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


def detail_data(rid, r, sid, dest=None, n=None):
    """What the step screen shows, as plain data: the classified result, the attempts, one attempt in full and the errors
    raised while it was open. None when the run has no record of the step."""
    rec = (r.get("steps") or {}).get(sid)
    if rec is None:
        return None
    result, why = ct.classify(rec)
    ats = rec.get("attempts") or []
    d = {"rid": rid, "sid": sid, "result": result, "why": why, "verdict": rec.get("verdict"),
         "overruled": rec.get("verdict") in ("pass", "partial") and result in ("fail", "unverified"),
         "attempts": [{"n": a.get("n"), "verdict": a.get("verdict")} for a in ats], "at": None, "pos": None, "newer_open": None, "errors": []}
    if not ats:
        return d
    at = shown_attempt(rec, n)
    d["at"], d["pos"] = at, ats.index(at)
    if d["pos"] < len(ats) - 1 and not ats[-1].get("verdict"):
        d["newer_open"] = ats[-1].get("n")
    if dest and at.get("verdict") in ("fail", "unverified"):
        errs, stks = ct.load_errors(dest, ct.stored_id(rid, r))
        hits, ambiguous = ct.stack_hits(r, stks)
        for key in hits.get((sid, at.get("n")), []):
            d["errors"].append({"key": key, "ambiguous": key in ambiguous, "text": errs.get(key, "(error line no longer saved)"), "stack": stks[key]})
    return d


def detail_text(rid, r, sid, dest=None, n=None):
    """detail_data as plain lines: for tests, and for any place that has no colors."""
    d = detail_data(rid, r, sid, dest, n)
    if d is None:
        return "The run has no record of step %s." % sid
    out = ["%s / %s" % (rid, sid), "result: %s%s" % (d["result"].upper(), " - " + d["why"] if d["why"] else ""),
           "player verdict: %s%s" % (d["verdict"], "   (the evidence says otherwise)" if d["overruled"] else "")]
    at = d["at"]
    if at is None:
        return "\n".join(out + ["", "No attempts."])
    out += ["", "attempt %s of %d  ([ and ] move)" % (at.get("n"), len(d["attempts"]))]
    if d["newer_open"] is not None:
        out.append("a newer attempt (%s) is still open" % d["newer_open"])
    out.append("verdict: %s   claimed: %s   by: %s   evidence: %s" % (at.get("verdict"), at.get("claimed"), at.get("by"), at.get("evidence")))
    out.append("opened %s, finished %s" % (_when(at.get("started")), _when(at.get("finished"))))
    if at.get("note"):
        out.append("note: " + " ".join(str(at["note"]).split()))
    for o in at.get("outcomes") or []:
        out.append("  %s %s %s" % ("diagnostic" if o.get("diagnostic") else "required  ", o.get("result"), o.get("why", "")))
    for src, lines in sorted((at.get("excerpt") or {}).items()):
        out.append("log %s, %d new line%s:" % (src, len(lines), "" if len(lines) == 1 else "s"))
        out.extend("  " + str(line) for line in lines)
    for e in d["errors"]:
        out.append("error %s%s: %s" % (e["key"], " (time also fits another attempt)" if e["ambiguous"] else "", e["text"]))
        out.append("  stack: " + e["stack"])
    if len(out) > MAX_DETAIL_LINES:
        out = out[:MAX_DETAIL_LINES] + ["... %d more lines" % (len(out) - MAX_DETAIL_LINES)]
    return "\n".join(out)


COLORS = {"fail": "red", "unverified": "yellow", "pass": "green", "partial": "cyan", "skip": "grey62", "skipped": "grey62"}
MARKS = {"pass": "✓", "fail": "✗", "unverified": "?"}
MAX_CHECK_ROWS = 200


def detail_render(d):
    """The step screen as Rich panels: a result banner, an attempt strip, the attempt's facts and checks, its log lines and
    the errors raised while it was open. Evidence goes in as Text, never as markup."""
    from rich import box
    from rich.console import Group
    from rich.panel import Panel
    from rich.table import Table
    from rich.text import Text
    if d is None:
        return Text("The run has no record of this step.")
    col = COLORS.get(d["result"], "white")
    head = Text()
    head.append(" %s " % d["result"].upper(), style="bold black on " + col)
    head.append("  " + d["sid"], style="bold")
    head.append("   " + d["rid"], style="dim")
    sub = Text()
    if d["why"]:
        sub.append(d["why"] + "\n", style=col)
    sub.append("player verdict  ", style="dim")
    sub.append(str(d["verdict"]), style="bold " + COLORS.get(d["verdict"], "white"))
    if d["overruled"]:
        sub.append("   ⚠ the evidence overrules this pass", style="bold " + col)
    parts = [Panel(Group(head, sub), border_style=col, box=box.HEAVY)]
    at = d["at"]
    if at is None:
        return Group(*parts, Text("No attempts.", style="dim"))
    strip = Text("attempts  ", style="dim")
    for a in d["attempts"]:
        c = COLORS.get(a["verdict"], "grey62")
        strip.append(" %s " % a["n"], style=("bold black on " + c) if a["n"] == at.get("n") else c)
        strip.append(" " if a["verdict"] else "◌ ", style="dim")
    strip.append("   [ earlier   ] later", style="dim")
    if d["newer_open"] is not None:
        strip.append("\na newer attempt (%s) is still open" % d["newer_open"], style="yellow")
    parts.append(strip)
    facts = Table.grid(padding=(0, 2))
    for label, value in (("verdict", at.get("verdict")), ("claimed", at.get("claimed")), ("by", at.get("by")), ("evidence", at.get("evidence")),
                         ("opened", _when(at.get("started"))), ("finished", _when(at.get("finished")))):
        facts.add_row(Text(label, style="dim"), Text(str(value)))
    body = [facts]
    s, f = at.get("started"), at.get("finished")
    if isinstance(s, (int, float)) and isinstance(f, (int, float)):
        facts.add_row(Text("took", style="dim"), Text("%ds" % max(0, f - s)))
    if at.get("note"):
        body.append(Panel(Text(" ".join(str(at["note"]).split())), title=Text("note"), title_align="left", border_style="dim"))
    outs = at.get("outcomes") or []
    if outs:
        t = Table(box=box.SIMPLE_HEAD, expand=True, pad_edge=False)
        for h in ("", "check", "result"):
            t.add_column(h, no_wrap=True)
        t.add_column("why", ratio=1)
        for o in outs[:MAX_CHECK_ROWS]:
            rc = COLORS.get(o.get("result"), "white")
            t.add_row(Text(MARKS.get(o.get("result"), "·"), style="bold " + rc), Text("diagnostic" if o.get("diagnostic") else "required", style="dim" if o.get("diagnostic") else ""),
                      Text(str(o.get("result")), style=rc), Text(str(o.get("why", ""))))
        body.append(t)
        if len(outs) > MAX_CHECK_ROWS:
            body.append(Text("... %d more checks" % (len(outs) - MAX_CHECK_ROWS), style="dim"))
    for src, lines in sorted((at.get("excerpt") or {}).items()):
        txt = Text()
        for i, line in enumerate(lines, 1):
            txt.append("%3d " % i, style="dim")
            txt.append(str(line) + ("\n" if i < len(lines) else ""))
        body.append(Panel(txt, title=Text("log %s - %d new line%s" % (src, len(lines), "" if len(lines) == 1 else "s")), title_align="left", border_style="blue"))
    for e in d["errors"]:
        txt = Text(e["text"], style="bold red")
        for frame in e["stack"].split(" / "):
            txt.append("\n  → ", style="dim")
            txt.append(frame, style="dim" if frame.startswith("[C]") else "")
        title = "error %s%s" % (e["key"], " - time also fits another attempt" if e["ambiguous"] else "")
        body.append(Panel(txt, title=Text(title), title_align="left", border_style="red"))
    parts.append(Panel(Group(*body), title=Text("attempt %s of %d" % (at.get("n"), len(d["attempts"]))), title_align="left", border_style=COLORS.get(at.get("verdict"), "grey62")))
    return Group(*parts)


def render_plain(renderable, width=100):
    """A Rich renderable as plain text, for tests and logs."""
    import io
    from rich.console import Console
    c = Console(record=True, width=width, file=io.StringIO(), force_terminal=False)
    c.print(renderable)
    return c.export_text()


WIDE = 76   # columns from which the extra columns come back; below it a screen shows only what triage needs
RESULT_MARKS = {"fail": "✗", "unverified": "?", "pass": "✓", "partial": "~", "skipped": "·"}
CATEGORY_MARKS = {"red": "✗", "yellow": "?", "green": "✓", "blue": "…", "grey": "·", "off": "–"}
CATEGORY_COLORS = {"red": "red", "yellow": "yellow", "green": "green", "blue": "blue", "grey": "grey62", "off": "grey42"}
RUN_COLUMNS = {False: ("result", "run", "done"), True: ("result", "run", "plan", "rev", "done", "fail", "unver", "age")}
STEP_COLUMNS = {False: ("result", "step"), True: ("result", "step", "category", "reason")}


def run_state(row):
    """fail, unverified or None. A run counts once, and fail wins."""
    return "fail" if row["fail"] else "unverified" if row["unverified"] else None


def run_summary(rows):
    states = [run_state(r) for r in rows]
    return {"runs": len(rows), "failing": states.count("fail"), "unverified": states.count("unverified"), "no_flags": states.count(None)}


def run_cells(row, wide):
    """The cells of one runs-table row as styled Text. The words and marks carry the meaning; color only helps."""
    from rich.text import Text
    st = run_state(row)
    badge = Text({"fail": "✗ FAIL", "unverified": "? UNVER", None: "—"}[st], style=("bold " + COLORS[st]) if st else "dim")
    done = Text("%d/%d" % (row["resolved"], row["eligible"]) if row["eligible"] else "—")
    rid = Text(str(row["id"]), style="bold" if st else "")
    if not wide:
        return [badge, rid, done]
    return [badge, rid, Text(row["plan"], style="dim"), Text(str(row["rev"]), style="dim"), done,
            Text(str(row["fail"]), style="bold red" if row["fail"] else "dim"), Text(str(row["unverified"]), style="bold yellow" if row["unverified"] else "dim"),
            Text(row["age"], style="dim")]


def runs_header(rows, problems, wide=True):
    """The line above the runs table: counts of runs by state, and one line for the problems (the first one, with a count).
    The app's CSS keeps each line to one row and ends a long one with an ellipsis."""
    from rich.text import Text
    s = run_summary(rows)
    t = Text("%d run%s" % (s["runs"], "" if s["runs"] == 1 else "s"), style="bold")
    labels = (("failing", "unverified", "no flags") if wide else ("fail", "unver", "no flag"))
    for label, n, style in zip(labels, (s["failing"], s["unverified"], s["no_flags"]), ("bold red", "bold yellow", "green")):
        t.append(" · " if not wide else "  ·  ", style="dim")
        t.append("%d %s" % (n, label), style=style if n else "dim")
    if problems:
        t.append("\n⚠ %d problem%s: %s" % (len(problems), "" if len(problems) == 1 else "s", problems[0]), style="yellow")
    return t


def step_cells(step, wide):
    from rich.text import Text
    st = step["result"]
    col = COLORS.get(st, "white")
    bad = st in ("fail", "unverified")
    result = Text("%s %s" % (RESULT_MARKS.get(st, "·"), st), style=("bold " if bad else "") + col)
    sid = Text(str(step["id"]), style="bold" if bad else "")
    if not wide:
        return [result, sid]
    return [result, sid, Text(str(step["category"] or ""), style="dim"), Text(str(step["reason"]))]


def category_chips(rid, r):
    """[(category id, state, resolved, total)]: the tracker's rule, but fed with the evidence-based result of a step
    (a pass the evidence overturned counts as fail), so a green chip never sits over a red step."""
    steps = ct.run_model(rid, r)["steps"]
    out = []
    for c in r.get("categories") or []:
        cid = c.get("id")
        counts = {}
        for s in steps:
            if s["category"] != cid or s["verdict"] in ("deselected", "inapplicable", None):
                continue
            key = s["result"] if s["result"] in ("fail", "unverified") else s["verdict"]
            counts[key] = counts.get(key, 0) + 1
        out.append((cid, ct.category_rule(counts) if (r.get("selected") or {}).get(cid) else "off",
                    sum(counts.get(k, 0) for k in ("pass", "partial", "fail", "skip")), sum(counts.values())))
    return out


def steps_header(rid, r, flt, cat, shown, total, wide):
    """Run result and counts, category chips (wide only), and the filter line."""
    from rich.text import Text
    m = ct.run_model(rid, r)
    c = m["counts"]
    st = "fail" if c.get("fail") else "unverified" if c.get("unverified") else None
    t = Text()
    t.append(" %s " % {"fail": "FAIL", "unverified": "UNVERIFIED", None: "no flags"}[st], style=("bold black on " + COLORS[st]) if st else "green")
    t.append("  " + rid, style="bold")
    n_fail, n_unver, n_pass = c.get("fail", 0), c.get("unverified", 0), c.get("pass", 0) + c.get("partial", 0)
    t.append(("   %d fail  %d unverified  %d pass" % (n_fail, n_unver, n_pass)) if wide else ("  %d✗ %d? %d✓" % (n_fail, n_unver, n_pass)), style="dim")
    if wide:
        chips = category_chips(rid, r)
        if chips:
            t.append("\n")
            for cid, state, res, tot in chips:
                t.append("%s %s %d/%d" % (CATEGORY_MARKS[state], cid, res, tot), style=CATEGORY_COLORS[state] + (" underline" if cid == cat else ""))
                t.append("   ")
        t.append("\nfilter  ", style="dim")
        for f in FILTERS:
            t.append(" %s " % f, style="bold reverse" if f == flt else "dim")
            t.append(" ")
        t.append("  category  %s" % (cat or "all"), style="dim")
    else:
        t.append("\nf: %s   /: %s" % (flt, cat or "all categories"), style="dim")
    t.append("   %d/%d" % (shown, total), style="bold")
    if not shown:
        t.append("\nNo matching steps", style="yellow")
    return t


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
            table.add_row(*[c if isinstance(c, Text) else Text(str(c)) for c in cells], key=key)   # Text: evidence is not markup
        if keep is not None:
            try:
                table.move_cursor(row=table.get_row_index(keep))
            except Exception:
                pass

    class Back(Screen):
        BINDINGS = [Binding("escape", "back", "Back")]

        def action_back(self):
            self.app.pop_screen()

    class Wide:
        """Both table screens switch columns when the terminal crosses WIDE."""
        wide = None

        def sync_columns(self, columns):
            wide = self.app.size.width >= WIDE
            if wide == self.wide:
                return False
            self.wide = wide
            t = self.query_one(DataTable)
            t.clear(columns=True)
            t.add_columns(*columns[wide])
            return True

        def on_resize(self, event):
            if self.is_mounted and self.sync_columns(self.COLUMNS):
                self.refill()

    class RunsScreen(Wide, Screen):
        COLUMNS = RUN_COLUMNS

        def compose(self):
            yield Header()
            yield Static("", id="note", markup=False)
            yield DataTable(id="runs", cursor_type="row", zebra_stripes=True)
            yield Footer()

        def on_mount(self):
            self.sync_columns(self.COLUMNS)
            self.refill()
            self.query_one(DataTable).focus()

        def refill(self):
            t = self.query_one(DataTable)
            fill(t, [(r["id"], run_cells(r, self.wide)) for r in self.app.store.rows], cursor_key(t))
            self.query_one("#note", Static).update(runs_header(self.app.store.rows, self.app.store.problems, self.wide))

        def on_data_table_row_selected(self, ev):
            self.app.push_screen(StepsScreen(ev.row_key.value))

    class StepsScreen(Wide, Back):
        COLUMNS = STEP_COLUMNS
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
            self.sync_columns(self.COLUMNS)
            self.refill()
            self.query_one(DataTable).focus()

        def refill(self):
            r = self.app.store.runs.get(self.rid)
            if r is None:
                return   # the app drops this screen
            rows, total = step_rows(self.rid, r, FILTERS[self.flt], self.cat)
            t = self.query_one(DataTable)
            fill(t, [(s["id"], step_cells(s, self.wide)) for s in rows], cursor_key(t))
            self.shown = steps_header(self.rid, r, FILTERS[self.flt], self.cat, len(rows), total, self.wide)
            self.query_one("#note", Static).update(self.shown)

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
            self.rid, self.sid, self.n, self.shown = rid, sid, None, None

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
            self.shown = detail_render(detail_data(self.rid, r, self.sid, self.app.store.dest, self.n))
            self.query_one("#body", Static).update(self.shown)

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
        CSS = "#note { height: auto; text-wrap: nowrap; text-overflow: ellipsis; padding: 0 1; }"
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
