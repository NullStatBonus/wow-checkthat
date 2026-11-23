## ADDED Requirements

### Requirement: End run from the card
The card header SHALL offer a "Run" menu, in both the expanded and the collapsed card, with an "End run..." item. The menu SHALL use the game's context menu when it exists, then the older dropdown, then a plain button in the same place. Choosing End run SHALL ask for confirmation first, including when no step is resolved. The question SHALL say that recorded results are kept and that the run cannot resume. Escape or a missing dialog SHALL leave the run active.

#### Scenario: Player confirms
- **WHEN** a run is active and the player chooses End run and confirms
- **THEN** the run ends, the card shows "Run ended" with Export results and Main window, and Resume and Undo are not offered

#### Scenario: Player cancels
- **WHEN** the player chooses End run and presses Escape on the question
- **THEN** the run stays active and unchanged

#### Scenario: No steps resolved
- **WHEN** the player ends a run with every step pending
- **THEN** the question still appears

### Requirement: An ended run is read-only
An ended run SHALL keep every recorded verdict. Pending and unverified steps SHALL stay as they are, and progress SHALL count only resolved steps. The card SHALL NOT accept a verdict, Undo or Resume for it. Starting the plan again SHALL create a new run.

#### Scenario: Verdict on an ended run
- **WHEN** a run has ended and the player runs `/ct pass`
- **THEN** no verdict is recorded and a line says the run has ended
