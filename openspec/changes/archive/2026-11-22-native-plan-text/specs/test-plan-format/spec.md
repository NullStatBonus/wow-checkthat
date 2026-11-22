## ADDED Requirements

### Requirement: Display text uses native formatting
Text a player sees (preamble, handoff, section and step titles, setup, action text, expect, intro, notes) SHALL use the game's own formatting: color codes such as |cffffd100text|r for emphasis. It SHALL NOT use Markdown. Validation SHALL reject backticks and double asterisks in those fields, in the compiler and on import. Titles and section names SHALL be plain text. A literal pipe SHALL be written as two pipes.

#### Scenario: Markdown rejected
- **WHEN** a step's action text contains a backtick or double asterisks
- **THEN** validation fails and names the field

#### Scenario: Converter output
- **WHEN** a legacy item contains bold text and a code span
- **THEN** the converted step uses a gold color code for the bold text and a light blue color code for the code span
