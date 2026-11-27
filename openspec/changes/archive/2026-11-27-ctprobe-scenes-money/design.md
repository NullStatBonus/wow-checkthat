## Context

Recordings are keyed by call label (`GetMerchantItemInfo(1)`). A second vendor or trainer would overwrite the first.

## Decisions

- **Scene prefix in the label.** Changing the key shape would break the readers, so a second scene adds new keys instead: `<scene>:<call>`. The scene name is in lower case. `ct.py` takes `api` from the part after the prefix, so the mock check "a recording must be for the mocked function" still holds. The plain scene keeps v4 labels, so existing plans are unchanged.
- **Scene choice.** A vendor is `gear` when one of its first three items has `C_Item.GetItemInfoInstant` class 2 (weapon) or 4 (armor). A trainer is `class` when `IsTradeskillTrainer()` returns false. A window that matches no free scene fills the plain one when that is free. Each scene is recorded once.
- **Money with its value at a window.** A copper balance names no character. `/ctp record` still keeps `GetMoney()` by type only. The committed-recordings test allows `GetMoney` only under a scene label with a window tag.
- **Count read first.** The count is read before the scene is chosen. It is then stored under that scene's label, so a later window does not overwrite the plain count.

## Non-Goals

- Forever auction (`C_AuctionHouse` browse results) and `C_MerchantFrame.GetItemInfo` return tables. They wait for #234.
- The in-game recording itself needs a tester on both clients. It follows this change: run `/ctp record`, `/ctp record arm`, then `ct.py recordings`.
