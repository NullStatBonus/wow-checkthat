# Spec Delta

## MODIFIED Requirements

### Requirement: A row in the Categories window offers add, go and rerun
A click on a row SHALL offer Add to run (not picked), Go to first open step (steps open), Rerun category (steps have results) and the other items of the row menu. Rerun SHALL ask first. Where the game has no menu API, or its menu fails, a click SHALL show a small list with one button per item, and no item SHALL run until the tester picks it. Picking an item, or pressing Esc, SHALL close the list. Esc SHALL close only the list while it shows, not the window behind it.

#### Scenario: Rerun from the window
- **WHEN** the tester chooses Rerun category on a green category and accepts
- **THEN** its steps reopen and the segment turns blue

#### Scenario: No menu
- **WHEN** the game has no menu API and the tester clicks a row of a category with results
- **THEN** a list shows every item of that row and none runs yet

#### Scenario: Pick one
- **WHEN** the tester picks an item in the list
- **THEN** that item runs and the list closes

#### Scenario: Esc with the list open
- **WHEN** the tester presses Esc while the list shows
- **THEN** the list closes and the Categories window stays open
