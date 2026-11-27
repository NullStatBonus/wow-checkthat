## Context

Recordings are keyed by call label (`GetMerchantItemInfo(1)`). A second vendor or trainer would overwrite the first.

## Decisions

- **Scene prefix in the label.** Changing the key shape would break the readers, so a second scene adds new keys instead: `<scene>:<call>`. The scene name is in lower case. `ct.py` takes `api` from the part after the prefix, so the mock check "a recording must be for the mocked function" still holds. The plain scene keeps v4 labels, so existing plans are unchanged.
- **Scene choice.** A vendor is `gear` when one of its first three items has `C_Item.GetItemInfoInstant` class 2 (weapon) or 4 (armor). A trainer is `class` when `IsTradeskillTrainer()` returns false. A window that matches no free scene fills the plain one when that is free. Each scene is recorded once.
- **Money with its value at a window.** A copper balance names no character. `/ctp record` still keeps `GetMoney()` by type only. The committed-recordings test allows `GetMoney` only under a scene label with a window tag.
- **One scene per opening.** A vendor window fires `MERCHANT_UPDATE` after `MERCHANT_SHOW`, so in the first in-game run one weapon vendor filled both `gear` and the plain scene. A window that has filled a scene records nothing more until its next `_SHOW` event. The event handler calls `capture` while any scene is armed. In the first run, a filled plain `trainer` scene stopped every trainer event, so the class trainer was never seen.
- **A nil `IsTradeskillTrainer` is a class trainer.** Era answers 1 or nil, so a check for `false` would never match.
- **Count read first.** The count is read before the scene is chosen. It is then stored under that scene's label, so a later window does not overwrite the plain count.

## Non-Goals

- Forever auction (`C_AuctionHouse` browse results) and `C_MerchantFrame.GetItemInfo` return tables. They wait for #234.
- The in-game recording itself needs a tester on both clients. It follows this change: run `/ctp record`, `/ctp record arm`, then `ct.py recordings`.
