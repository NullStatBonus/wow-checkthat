## ADDED Requirements

### Requirement: Chat lines escape plan text, and /ct start is case-insensitive
`/ct categories` SHALL double each `|` in a category title before it prints the line to chat. Other callers of the category line, such as tooltips, SHALL keep the raw text. `/ct start <addon>` SHALL accept an addon that `Plan.SLASH` lists, in any letter case, and SHALL use no second list. The line for `/ct pass`, `partial`, `fail` and `skip` SHALL take each result and evidence word through `L[]`.

#### Scenario: A bar in a title
- **WHEN** a category title holds `|cffff0000` and the player types `/ct categories`
- **THEN** chat shows `||cffff0000` in that title

#### Scenario: Lower-case addon name
- **WHEN** the player types `/ct start keepthat` with a KeepThat plan imported
- **THEN** a run for KeepThat starts and no usage line shows

#### Scenario: Translated result words
- **WHEN** a locale translates "pass" and "matched"
- **THEN** the result line shows the translated words
