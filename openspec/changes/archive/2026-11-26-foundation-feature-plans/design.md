## Context

Issue #219 came from ClosestVendor's plans. Its release gate was three plans of 53 steps that no single character could run, written in technical words. #162 (PR #175) already added the 25-step warning, scoping before drafting and plan sets by area. This change replaces "sample or release" with "foundation or feature" and adds the wording rules.

## Goals / Non-Goals

**Goals:**
- The skill drafts a release gate that one character runs in one sitting per client.
- Feature plans go deep, and are not run before every release by default.
- `validate` catches the technical wording, for plans that opt in.

**Non-Goals:**
- A validate check that each step of a foundation plan is doable by the stated character. The plan format cannot say "needs a Mage" today; #173 (step requires class, profession, addon or entry) adds that. Until then the skill's review does it.
- A run-level error scope for the foundation plan's clean-load step. That is #161; until it ships the step uses `scope: session`, as plan sets do.
- A second example plan for the foundation kind. The shape is the same as `example.yaml`; the rules are in the skill text.

## Decisions

- **The key is `purpose`, not `kind`.** A plan already has `kind: plan` at the top (the compiled string and `example.yaml` both carry it). `purpose: foundation | feature` is tools-only, like `covers` and `offline`: the schema lists it and `merge_sections` drops it, so the game never sees it and the compiled string does not change.
- **The new warnings are opt-in through `purpose`.** AGENTS.md lets a stricter check apply only to a plan that opts in. Existing plans, `from-md` output and the repository's own plans keep their exact validate output. The skill sets `purpose` on every new plan, so new plans get the rules.
- **Warnings, never errors.** Same as the size and version warnings: the rules are advice, exit codes stay.
- **What counts as technical.** A slash command in action text or Expect, found with the same allow-list match as the unlisted-command warning (color codes stripped first). In Expect, the words log, logs, logged and logging, except when followed by in, out or on, so "you log in" passes. Plain color codes are not flagged: the format spec makes them the way to highlight a button or a name. A `copy-slash` step is exempt from the command check in its action text, because its text is the command.
- **Foundation size: warn above 12.** The issue asks for roughly 8 to 12 steps. Counted after `cases` expand, like the 25-step warning. No lower bound: a small addon can have fewer pillars.
- **Pillars as sections.** The skill suggests one section per pillar, titled with the pillar's name, so the review can see each pillar's step count. The format needs no change for this.
- **Example plan.** `example.yaml` becomes `purpose: feature` with player-language action text, so the skill's own example passes the new warnings. A test keeps it free of warnings.

## Risks / Trade-offs

- An author who adds `purpose` to an old plan sees many warnings at once. → That is the point of opting in. Each warning names the step and the fix.
- The log-word match can miss a phrasing such as "a line is written". → The skill's review rule covers what the regex does not.
- Moving class and profession steps out of the gate leaves them untested before a release. → The preamble names each one and where it went, so the author accepts the gap knowingly.
