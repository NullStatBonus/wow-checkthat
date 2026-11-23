# Proposal

## Why

`Codec.Decode` checks the 2 MB decoded-size cap only after LibDeflate has built the whole output. A pasted string of up to 120,000 characters can expand to about 90 MB first. That can freeze or crash the game client during import. See issue #1.

## What Changes

- **Stop inflating at the cap.** Import stops unpacking as soon as the output passes the 2 MB cap and reports "decoded data too large".
- Patch the vendored LibDeflate so `DecompressDeflate` accepts an optional output limit. Record the patch in `CheckThat/Libs/VERSIONS.txt`.
- Pass the cap from `Codec.Decode`. The existing post-check stays as an exact backstop.
- Add a test with a highly compressible input.

## Capabilities

### New Capabilities

### Modified Capabilities
- `plan-transport`: import must bound the work it does on a string whose decoded size exceeds the cap.

## Impact

- `CheckThat/Model/Codec.lua`, `CheckThat/Libs/LibDeflate/LibDeflate.lua`, `CheckThat/Libs/VERSIONS.txt`.
- `tests/test_codec.lua`.
- Addon code changes, so the version bumps to 0.5.3 with a CHANGELOG entry at archive.
- No settings, commands or plan format change. README, listing and test plan need no edit; `docs/contracts.md` gets the LibDeflate budget behavior.
