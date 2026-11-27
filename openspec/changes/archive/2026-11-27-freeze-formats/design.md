## Decisions

- **Long names stay canonical.** Released plans and runs use `classic-era` and `forever-camelot`; the run record keeps them, and `compile` turns short names into long ones, so no plan revision (`needs`) is required: a compiled plan never carries a short name. A hand-made string with a short name is refused by an older CheckThat as an unknown client.
- **Unknown client is nil.** Only the two interface ranges CheckThat ships TOCs for are named. With nil, `Plan.Steps` keeps the steps without `clients`; the run record has no `client` key, which the run schema already allows.
- **Which lists are open.** `verdict` and `result` drive every reader's counts and colours; a new value there would be misread, so they stay closed (a new value needs `ct: 2`). The others describe how a result was reached; a reader can show an unknown value as text. A test feeds unknown values to `report` (text, JSON, JUnit) to prove the readers do.
