## ADDED Requirements

### Requirement: A category without results can be removed from a run
The tester SHALL be able to remove a picked category from a running run when none of its steps has a result or a finished attempt. Its steps SHALL read `deselected` again and SHALL NOT count as open. The shown step SHALL stay shown unless it belongs to the removed category, when the card SHALL show the next open step. A category with a result SHALL NOT be removed, and the last picked category SHALL NOT be removed. The player SHALL be told why in both cases. A removed category SHALL be addable again.

#### Scenario: Picked by mistake
- **WHEN** the tester removes a picked category whose steps are all pending
- **THEN** its segment turns grey, its steps are no longer open and no result changes

#### Scenario: A category with a result
- **WHEN** the tester tries to remove a category that has a passed step
- **THEN** a line says it has results and the run does not change

#### Scenario: The last category
- **WHEN** only one category is picked
- **THEN** it cannot be removed and a line says so

#### Scenario: The shown step leaves
- **WHEN** the shown step belongs to the removed category
- **THEN** the card shows the next open step of another category
