## MODIFIED Requirements

### Requirement: Assertions and probes are typed
Assertions SHALL be `log` (named log source, one of equals, contains, pattern, with scope attempt, run or session, optional absent), `log-sequence` (ordered matchers), or `state` (probe from a closed registry: addon-loaded, global-value, frame-shown, money, bag-free-slots, item-count, frame-text; operator; value). A `state` assertion MAY give `name` (an addon, a global or a frame), `path` (a dotted field of a table global), `id` (the item of `item-count`, a number) and `bag` (the one bag of `bag-free-slots`, a whole number). Scope `attempt` reads the lines written after the step's attempt opened, `run` the lines written after the current run started (across `/reload`), and `session` the whole retained log. Any assertion MAY be `diagnostic`, recorded but never gating. `verify` SHALL be a set of `player`, `assertions`, `reviewer`; `assertions` requires assertions to exist and vice versa; `reviewer` requires reviewer text kept verbatim.

#### Scenario: Unknown probe
- **WHEN** an assertion names a probe absent from the registry
- **THEN** validation fails

#### Scenario: Ordered evidence
- **WHEN** a step needs "off" logged before "on"
- **THEN** a `log-sequence` passes only if the lines appear in that order inside the attempt window

#### Scenario: Run scope accepted
- **WHEN** a log assertion sets `scope: run`
- **THEN** `ct validate` and plan import accept it

#### Scenario: Unknown scope
- **WHEN** an assertion sets `scope: forever`
- **THEN** validation fails with "bad scope"

## ADDED Requirements

### Requirement: The game state probes are read-only and never guess
`money` SHALL read `GetMoney()`, the balance in copper. `bag-free-slots` SHALL read `C_Container.GetContainerNumFreeSlots`, or the older global `GetContainerNumFreeSlots`, summed over bags 0 to 4, or for the one `bag` the assertion names. `item-count` SHALL read `C_Item.GetItemCount`, or the older global `GetItemCount`, for the item `id` names. `frame-text` SHALL read a named frame's `GetText` and cut it to 80 characters. A probe SHALL answer nil for a missing function, a raising call and a value the game hides (`issecretvalue`); `frame-text` SHALL also answer nil for a value that is not text, and a `bag-free-slots` sum SHALL be nil when one bag cannot be read. No probe SHALL be protected, change any state, or write anything. `ct validate`, plan import and the schema SHALL refuse `item-count` without a numeric `id`, an `id` that is not a number, and a `bag` that is not a whole number.

#### Scenario: Money
- **WHEN** a state assertion names `money` with `op: ge` and `value: 100`
- **THEN** the check passes with at least 100 copper, and is unverified when the game cannot say

#### Scenario: One bag unknown
- **WHEN** one of bags 0 to 4 cannot be read
- **THEN** a `bag-free-slots` sum is unverified, never a smaller number

#### Scenario: Item without an id
- **WHEN** a state assertion names `item-count` and gives no numeric `id`
- **THEN** validation fails

#### Scenario: Frame text
- **WHEN** a state assertion names `frame-text` for a frame that says `Bank`, with `op: eq` and `value: Bank`
- **THEN** the check passes, and a missing or empty frame leaves it unverified
