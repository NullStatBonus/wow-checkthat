## ADDED Requirements

### Requirement: Import refuses a plan whose fields have the wrong type
`Plan.Validate` SHALL refuse a plan in which a field that the card or the evidence code reads has the wrong type: a log source, a requirement or the `logs` and `requirements` tables that is not a table; a log source `global` or `path`, a requirement `text`, `preamble`, `handoff`, a section `intro`, `setup` or `title`, a step `setup` or an assertion `label` that is not text; `equals`, `contains` or `pattern` of a log assertion or sequence item that is not text; a sequence item that is not a table; `macros`, `requires`, `clients`, `assertions` or `commands` that is not a list. Optional fields stay optional. The import SHALL store nothing for such a plan.

#### Scenario: Hand-made string with a wrong type
- **WHEN** an imported plan has `logs.debug` as text, or an assertion `contains` as a number
- **THEN** the import fails with "The plan is not valid" and the plan is not stored

### Requirement: Compile refuses a string over the import cap
`ct.py compile` SHALL fail with a message that names the length and the limit when the compiled string is longer than 120000 characters, the limit the addon's `Codec.Decode` enforces.

#### Scenario: Too long
- **WHEN** a compiled plan is 130000 characters
- **THEN** `ct.py compile` exits 1 and writes no string
