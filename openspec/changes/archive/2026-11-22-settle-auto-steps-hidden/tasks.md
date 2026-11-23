## 1. Loop

- [x] 1.1 In `CheckThat/UI/Card.lua`, split `tick`: settle runs while the current step is an open auto step; `UpdateChecks` runs only when the card is shown.
- [x] 1.2 In `Card.AutoSettle`, replace the `card:IsShown()` gate with a hidden-game-interface gate; keep the Start screen gate and the note ownership check.
- [x] 1.3 Start the loop from `Card.Show`, run start, run resume after `/reload`, and step change. Stop it when no auto step is open or the run ended. Keep one `card.ticking` guard.

## 2. Tests

- [x] 2.1 Add a test that an open auto step settles with the card hidden (met checks, then timeout). Break the gate, see it fail, restore.
- [x] 2.2 Add a test that the loop stops with no open auto step and does not double up after Show.
- [x] 2.3 Keep the tests for hidden game interface, Start screen and note handling passing.

## 3. Docs

- [x] 3.1 `README.md`: change the "A hidden card..." sentence in Auto steps; keep hidden interface and Start screen.
- [x] 3.2 `docs/listing.md`: update the "only while the card is on screen" line.
- [x] 3.3 `docs/test-plan.md`: update check 7 so the result is recorded while the card is hidden; keep numbering.
- [x] 3.4 Check `/ct log` shows the auto result line while hidden.

## 4. Verify

- [x] 4.1 `make test` and `make check`.
