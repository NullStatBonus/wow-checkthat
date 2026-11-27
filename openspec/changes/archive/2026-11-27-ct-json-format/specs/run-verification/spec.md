## ADDED Requirements

### Requirement: ct.py JSON names its format
Every JSON output of `tools/ct.py` (`--format json` or `--json`) and every JSON file it writes for a reader SHALL carry `"format"`, a whole number that rises only when a key changes meaning or is removed. `docs/tools-guide.md` SHALL list the stable commands. The help of a maintainer tool SHALL say that its output may change.

#### Scenario: Report as JSON
- **WHEN** a tool runs `ct.py report --format json`
- **THEN** the document has `"format": 1`

#### Scenario: Maintainer tool
- **WHEN** the author reads `ct.py --help`
- **THEN** `recordings` and `census` say "maintainer tool, output may change"
