# Spec Delta

## MODIFIED Requirements

### Requirement: Skill finds the plan tools from any install
The skill SHALL locate `tools/wtt.py`, `schema/test-plan.schema.json` and `docs/test-plan.md` in the bundle installed beside it, else in the checkout two folders above it. A path SHALL count as a root only when the plan tools and format files all exist under it. If it cannot find them, it SHALL ask the author for the CheckThat path and SHALL NOT assume the working directory is the CheckThat repository.

#### Scenario: Installed to the user's skills folder
- **WHEN** the author ran `make install-skill`, then removed or moved the checkout, and starts the skill in another addon repository
- **THEN** the skill finds the bundled tools and drafts without asking for a path

#### Scenario: Path unknown
- **WHEN** no bundle exists beside the skill and the tools are not in a checkout above it
- **THEN** the skill asks for the CheckThat checkout path before drafting
