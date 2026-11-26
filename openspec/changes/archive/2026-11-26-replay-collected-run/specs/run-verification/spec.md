## ADDED Requirements

### Requirement: Report's expected version defaults to the addon's TOC
`ct.py report` SHALL accept `--addon-src <folder>`. When `--expect-version` is not given and the addon's TOC is known, from `--addon-src` or from the `offline.toc` of the `--plan` file when that file exists under the addons folder, the report SHALL use the TOC's `## Version:` as the expected version and SHALL say which TOC it came from. An explicit `--expect-version` SHALL win. Without either, the report SHALL behave as before.

#### Scenario: Run of an older build
- **WHEN** the TOC says 1.13.1, the run tested 1.13.0, and the author runs `ct report --addon-src <folder>`
- **THEN** the report prints the version source and warns that the run tested 1.13.0, not the expected 1.13.1

#### Scenario: Explicit version
- **WHEN** `--expect-version 1.13.0` and `--addon-src` are both given
- **THEN** 1.13.0 is the expected version
