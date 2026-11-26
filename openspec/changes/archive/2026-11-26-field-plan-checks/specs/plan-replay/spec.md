## ADDED Requirements

### Requirement: Lines built from format strings are found
`ct.py lines` SHALL count an asserted line as found when it is part of the text a format string in the addon source can produce, with each placeholder (`%s`, `%d` and the other `string.format` conversions) read as any text and `%%` as a percent sign. At least 8 characters of the asserted line, and at least half of them, SHALL come from the format string's own literal text, so a string made mostly of placeholders, or one placeholder that takes the rest of the line, does not match everything.

#### Scenario: Asserted text spans placeholders
- **WHEN** the source has `("trigger %s%s%s (bags=%s free)"):format(...)` and the plan asserts `trigger go sell (bags=`
- **THEN** `ct lines` reports the line as found

#### Scenario: One placeholder takes the rest
- **WHEN** the source has `("trigger %s (boxes=%s"):format(...)` and the plan asserts `trigger go sell (bags=`
- **THEN** `ct lines` reports it as not found, because only 8 of its 22 characters come from the format string

#### Scenario: Placeholders alone
- **WHEN** the source has `("%s %s"):format(a, b)` and the plan asserts a line no other source text contains
- **THEN** `ct lines` still reports it as not found
