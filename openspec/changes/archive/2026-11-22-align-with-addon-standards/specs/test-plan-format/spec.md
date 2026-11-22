## ADDED Requirements

### Requirement: Steps and sections may request a share point
A step MAY set `share` to `none`, `reload` or `export`; a section MAY set it, and compilation SHALL apply it to the section's last step. Any other value fails validation.

#### Scenario: Section share
- **WHEN** a section sets `share: export`
- **THEN** its last step carries `share: export` after compilation
