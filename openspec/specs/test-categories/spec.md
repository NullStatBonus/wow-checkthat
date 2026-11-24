# test-categories Specification

## Purpose
Lets a plan group its steps into categories, lets the tester choose which categories to run, and shows progress per category in red, yellow, green or blue, so a long plan can be run in parts and read at a glance.

## Requirements

### Requirement: Steps belong to categories
A plan MAY declare `categories`, each with an `id`, a `title` and an optional `intro`. A step or section MAY name one by `category`; a section's category is the default for its steps. When a plan declares categories, every step SHALL resolve to a declared one. When it declares none, each section SHALL act as a category with the section's id and title.

#### Scenario: Plan without categories
- **WHEN** a plan declares no categories
- **THEN** the runner treats each section as a category and the plan runs as before

#### Scenario: Step in no declared category
- **WHEN** a plan declares categories and a step resolves to none or to an unknown id
- **THEN** validation fails and names the step

### Requirement: The tester chooses which categories run
When a run starts, the tester SHALL be able to pick any non-empty set of categories, and all categories SHALL be picked by default. The run SHALL record the picked set. Steps in unpicked categories SHALL have the result `deselected`, SHALL NOT be offered or counted as open, and SHALL NOT fail the run. The tester SHALL be able to add an unpicked category later. A plan with one category SHALL show no choice.

#### Scenario: Start with two of four categories
- **WHEN** the tester starts a run with two categories picked
- **THEN** only steps of those categories are offered, the others read `deselected`, and the run can finish

#### Scenario: Nothing picked
- **WHEN** the tester tries to start a run with no category picked
- **THEN** the run does not start and the player is told to pick one

#### Scenario: Add a category mid-run
- **WHEN** the tester adds a category during a run
- **THEN** its steps join the run in plan order and earlier results stay

### Requirement: A category can be added, shown and rerun
The tester SHALL be able to add an unpicked category without moving the shown step (Add to run), and to go to the first open step of a picked category (Go to first open step). `/ct run <category>` SHALL do both, and `/ct run <step id>` SHALL show that step. Rerun SHALL ask first, then reopen each of the category's steps that has a result as pending, keeping earlier attempts. Nothing SHALL send input: automatic steps settle only from their own evidence.

#### Scenario: Go to a category
- **WHEN** the tester runs `/ct run bank`
- **THEN** the card shows the first open step of `bank`, after adding it if it was not picked

#### Scenario: Add without moving
- **WHEN** the tester chooses Add to run on a category that was not picked
- **THEN** its steps join the run and the shown step does not change

#### Scenario: Rerun asks
- **WHEN** the tester starts a rerun of a category with four results
- **THEN** a question names the category and the four steps, and nothing changes until the tester accepts

#### Scenario: Nothing to rerun
- **WHEN** no step of the category has a result
- **THEN** a line says nothing is reopened and no question shows

#### Scenario: Rerun
- **WHEN** the tester accepts a rerun of a category whose steps passed
- **THEN** its steps are pending, the segment turns blue, and the earlier attempts stay in the export

#### Scenario: Ambiguous name
- **WHEN** a name matches both a category and a step
- **THEN** a line says so and the run does not change

#### Scenario: Unknown name
- **WHEN** the tester runs `/ct run nothing`
- **THEN** a line says there is no such category or step and the run is unchanged

### Requirement: Category state is red, yellow, green, blue or grey
A category SHALL read **red** when any of its picked steps has the result fail; else **yellow** when any step is partial or unverified; else **green** when no step is open and at least one passed; else **blue** when any step is still open (untested), also when others have results; else **grey**. An unpicked category SHALL read off. The overall state SHALL follow the same rules over all picked steps.

#### Scenario: One failure
- **WHEN** a category has four passed steps and one failed step
- **THEN** it reads red

#### Scenario: In progress
- **WHEN** a category has two passed steps and two pending steps and no failure
- **THEN** it reads blue, with the words "in progress"

#### Scenario: Untested
- **WHEN** no step of a category has a result
- **THEN** it reads blue, with the word "untested"

#### Scenario: Partial or unverified
- **WHEN** a category has a partial or unverified step and no failure
- **THEN** it reads yellow

#### Scenario: Retry passes
- **WHEN** a failed step is redone and passes
- **THEN** the category can turn green

#### Scenario: Only skips
- **WHEN** every step of a category is skipped
- **THEN** it reads grey, not green

### Requirement: The tracker never relies on color alone
The card SHALL show a caption with the overall result in words, naming the count behind red and yellow ("1 failed", "1 partial", "2 unverified"), and the count of passed steps over picked steps, in the full and the collapsed card. Each segment's tooltip SHALL show its category's state in words and counts. The Home page SHALL list every category with its state word and its passed, failed and open counts.

#### Scenario: Caption
- **WHEN** three of eight picked steps passed and one failed
- **THEN** the caption reads "1 failed · 3 of 8 passed"

#### Scenario: Color-blind reading
- **WHEN** a segment is red
- **THEN** its tooltip says the category failed with its counts, and the Home list says the same in words

### Requirement: A segment shows what happened to its steps
A segment SHALL show its steps by result, side by side: passed, then partial or unverified, then failed. What is left SHALL show the track.

#### Scenario: One failure among passes
- **WHEN** a category has six passed steps and one failed step
- **THEN** its segment is mostly green with a red end, its row reads "failed · 6 passed, 1 failed, 0 open", and the category state is still red

### Requirement: State words are distinct
Blue SHALL read "untested" or "in progress" (some steps have results). Yellow SHALL read "partial or unverified". Grey SHALL read "all skipped". An unpicked category SHALL read "not picked".

#### Scenario: Only skips
- **WHEN** every step of a category is skipped
- **THEN** it reads grey with the words "all skipped"

#### Scenario: Not picked
- **WHEN** the tester did not pick a category
- **THEN** it reads "not picked" in the Home list and the tooltip

### Requirement: The tracker takes no click and follows the opacity
Segments SHALL take no click. They SHALL follow the card's text opacity and draw nothing at zero.

#### Scenario: Zero opacity
- **WHEN** the text opacity is zero
- **THEN** no segment is drawn

#### Scenario: Click on a segment
- **WHEN** the tester clicks a segment
- **THEN** nothing changes in the run
