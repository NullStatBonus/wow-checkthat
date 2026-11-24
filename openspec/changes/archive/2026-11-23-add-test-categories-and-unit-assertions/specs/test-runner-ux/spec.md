# Spec Delta

## ADDED Requirements

### Requirement: The card shows a progress tracker
With two to eight categories the card SHALL show one segment per category in plan order, in the slot of the progress bar, and a caption under it. With one category it SHALL keep the plain bar. With more than eight it SHALL show one bar colored by the overall state. The count SHALL include unpicked categories. Content SHALL move down by the caption row only when the tracker shows.

#### Scenario: Four categories
- **WHEN** a plan has four categories
- **THEN** the card shows four segments and a caption

#### Scenario: Nine categories
- **WHEN** a plan has nine categories
- **THEN** the card shows one bar and the caption

#### Scenario: Collapsed
- **WHEN** the card is collapsed
- **THEN** the strip keeps the caption

### Requirement: The start flow offers categories
The Home page and the card start screen SHALL list each category of the chosen plan with a checkbox in plan order, all checked, with its step count. Start run SHALL be off, with a line saying why, when none is checked. A plan with one category SHALL show no list. The card start screen SHALL list up to eight categories and the Home page up to twenty-four; a plan with more SHALL say where to choose.

#### Scenario: Pick two
- **WHEN** the tester clears two checkboxes and selects Start run
- **THEN** the run starts with the other categories picked

#### Scenario: None picked
- **WHEN** the tester clears every checkbox
- **THEN** Start run is off and a line says "Select at least one category."

### Requirement: A Categories window lists every category
The card SHALL show a Categories control that opens a second movable window with one row per category: a colored square, the title, the state in words, and its passed, failed and open counts. The header SHALL show no overall count. It SHALL show up to 14 rows. A longer list SHALL scroll with the mouse wheel and with page buttons, and a line SHALL say which rows show. Each row SHALL show an arrow and the hint "Click for actions". Esc SHALL close the window.

#### Scenario: Many categories
- **WHEN** a plan has twelve categories
- **THEN** the window shows twelve rows, each with its color and state in words

#### Scenario: Long list
- **WHEN** a plan has twenty categories
- **THEN** the window shows fourteen, says which it shows, and the mouse wheel moves the list

### Requirement: A row in the Categories window offers add, go and rerun
A click on a row SHALL offer Add to run (not picked), Go to first open step (steps open) and Rerun category (steps have results). Rerun SHALL ask first. Where the game has no menu API, a click SHALL run the first item.

#### Scenario: Rerun from the window
- **WHEN** the tester chooses Rerun category on a green category and accepts
- **THEN** its steps reopen and the segment turns blue

#### Scenario: No menu
- **WHEN** the game has no menu API and the tester clicks a row
- **THEN** the first item of that row runs

### Requirement: The Categories window follows the card's appearance
The window SHALL keep its place, follow the card's opacity, draw nothing at zero background opacity, and reopen after a reload if it was open.

#### Scenario: Header
- **WHEN** the window is open during a run
- **THEN** its header shows the title and the buttons, and no overall count

#### Scenario: Esc
- **WHEN** the tester presses Esc with the window open
- **THEN** the window closes and stays closed after a reload

#### Scenario: Zero opacity
- **WHEN** the background opacity is zero
- **THEN** the window draws no fill or border
