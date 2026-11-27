## Decisions

- **Three levels, 32 keys.** `GetBrowseResults` is a list of results, each with an `itemKey` table. A partial copy is marked `cut` and left out, so a sample is never taken for the whole answer.
- **Arguments stored, not parsed.** An `itemKey` cannot be read back from a label. The probe stores the arguments of a call that has a table argument, and the label reads `itemKey:<itemID>` so a person can read it. `ct.py` uses the stored arguments when they are present.
- **Arrays as lists.** A table whose keys are 1..n becomes a JSON list, so `#results` in the addon is right after decoding. An empty table reads back from saved variables as `[]` and counts as an empty object or list.
- **Structures checked like returns.** Field types are scalars, structure names or `list<T>`. A trailing `?` marks a field that may be missing, and a field the structure does not list is named. This catches a hand-written entry with a misspelled field.
- **A fresh copy per call.** The game returns a new table each call. Without a copy, an addon that changes a result would change what the next call returns.

## Non-Goals

- Recording auction pages after the first (`RequestMoreBrowseResults` is a write-like query). Owned auctions and bids.
