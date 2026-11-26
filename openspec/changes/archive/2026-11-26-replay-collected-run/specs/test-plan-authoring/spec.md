## ADDED Requirements

### Requirement: Revise mode replays the revised plan against the failing run
In "Revise after a run" the skill SHALL run `ct.py replay <plan> --run <run id>` with the revised plan and fix every check that the replay fails before it asks the author for another in-game run. It SHALL say that a replay pass proves only the checks that read the whole log; checks that need the step's own window are not judged offline. It SHALL pass `--addon-src` to `report` when the addon source is at hand.

#### Scenario: A revised sequence check is wrong
- **WHEN** a revised `log-sequence` check expects lines in an order the real log does not have
- **THEN** the replay against the run fails it, and the skill fixes it before the next in-game run
