# Spec Delta

## ADDED Requirements

### Requirement: Import bounds decoded size while decoding
Import SHALL stop decompressing once the decoded output passes 2,000,000 bytes and reject the string as too large. The work and memory used before rejection SHALL stay bounded by that cap, not by the size the string claims to expand to.

#### Scenario: Highly compressible string
- **WHEN** a pasted string of under 120,000 characters would decode to far more than 2,000,000 bytes
- **THEN** import fails with a "too large" message and no state changes
- **AND** decoding stops shortly after the cap instead of producing the full output

#### Scenario: Normal plan
- **WHEN** a plan whose decoded size is under the cap is pasted
- **THEN** import succeeds exactly as before
