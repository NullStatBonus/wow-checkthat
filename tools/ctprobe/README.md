# CTProbe

A throwaway in-game probe, not shipped. It measured the client behaviour that `tests/harness.lua` models, and the results are recorded in `docs/contracts.md`: the combat state driver, anchoring protected frames, and taint from a replaced global (issue 98). Keep it here so those measurements can be repeated.

Install by copying `tools/ctprobe/CTProbe` into the game's `Interface/AddOns` folder. It writes `CTProbeDB` to saved variables.
