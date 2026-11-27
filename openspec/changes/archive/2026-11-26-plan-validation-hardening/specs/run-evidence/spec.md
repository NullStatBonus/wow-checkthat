## ADDED Requirements

### Requirement: Patterns run with a step budget
`Evidence` SHALL run a plan pattern (a log `pattern`, a sequence item `pattern` or a `matches` value) on the whole line, in one of three ways that all give the answer of `string.find`: a plain search for a pattern with no special character; `string.find` itself for a pattern with at most one `*`, `+` or `-` (a leading `.*` or `.-` not counted, and dropped by trying only the first position), at most three `?` and no back reference, on a line of at most 2000 characters, when its estimated work is at most 4,000,000; and otherwise `Pattern.Match`, a plain-Lua port of the Lua 5.1 matcher that counts its steps (an item call, a character test, a set item read) and gives up at `Pattern.BUDGET` (40000 steps, 2 to 7 ms). A pattern that `Plan.PatternProblem` refuses SHALL NOT be run: the result is `unverified` with the reason and "it was not run", for presence, absence and count checks alike.

A line over the budget counts as unchecked: neither a match nor a miss. A check that needs that line (an absence, a count with an upper bound, a positive match with no other matching line, a sequence, a fact or state `matches`) SHALL be `unverified` with "a log line took too long to check with this pattern", never pass and never fail. A match on another line still passes, and more real matches than a count allows still fail. For a fact, `which: any` passes when one value matched, and `which: all` fails when one value broke the operator, whatever another value did.

One card refresh (`Evidence.Preview`) SHALL spend at most `Pattern.PASS_ALLOWANCE` (150000 steps, about 11 to 18 ms) on lines whose answer is not kept. A native call is charged its estimated work divided by 100, plus 4 and a sixteenth of the line length. When it is spent, a line not seen before is pending: not run, not kept, and the check is `unverified` with "still checking the log (the card tries again)"; the next refresh goes on. Judging that records a result (`Evidence.Check`, used by a verdict, an automatic pass and a timeout) SHALL have no allowance, so a saved result is never unverified for "still checking the log"; the budget for one line still applies. The answer for a pattern and a line, also "could not be checked", SHALL be kept in two generations of 20000 pairs; a hit in the older one moves to the newer one, and at the start of a refresh a full newer generation replaces the older one.

#### Scenario: A stored plan with an unreadable pattern
- **WHEN** a stored plan has `pattern: "(unclosed"` with `absent: true`
- **THEN** the check is unverified, never pass, and the matcher never sees the pattern

#### Scenario: A forbidden line past character 1000
- **WHEN** a line is 1100 characters and ends with " ERROR boom", and a check says `pattern: "ERROR"`, `absent: true`
- **THEN** the check fails, as it did before

#### Scenario: An adversarial line
- **WHEN** `a.-a.-a.-a.-Z` or two sets of 70 characters followed by `x` is checked against a line of `a`
- **THEN** the line is not matched, the check is unverified, and the work is bounded

#### Scenario: Ordinary long lines
- **WHEN** a pattern such as `.*failed`, `.*%d+`, `(%S+)%s+(.+)` or `%w+%s*=%s*%d+` is checked against ordinary log text of 150 to 2000 characters
- **THEN** it finds what `string.find` finds and is never left unchecked

#### Scenario: A long log
- **WHEN** a check reads more lines than one refresh may spend its allowance on
- **THEN** the first refresh shows it unverified with "still checking the log", a later refresh settles with the right verdict, and a refresh after that runs nothing

#### Scenario: A recorded result
- **WHEN** the player presses Pass on a step whose session-scope check reads 2001 lines with a pattern that needs the port
- **THEN** the saved attempt holds the real verdict and no outcome says "still checking the log"
