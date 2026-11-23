# Tasks

## 1. Cap the inflate output

- [x] 1.1 Add a failing test in `tests/test_codec.lua`: a string under 120,000 characters that decodes to more than 3 MB is rejected with "too large" and the decoder stops early (spy on the decode flush count or output size). Verify it fails before the fix because decoding runs to the end.
- [x] 1.2 Patch `CheckThat/Libs/LibDeflate/LibDeflate.lua`: optional `max_out` on `DecompressDeflate`, flushed-byte count in `DecodeUntilEndOfBlock`, status -20 past the cap. Verify `luajit tests/test_codec.lua` passes.
- [x] 1.3 Pass `Codec.LIMITS.inflated` from `Codec.Decode` and map the failure to "decoded data too large". Verify the test passes. Temporarily remove the check and verify it fails, then restore it.
- [x] 1.4 Add a LibDeflate entry with the local patch to `CheckThat/Libs/VERSIONS.txt`, and record the budget behavior in `docs/contracts.md`. Verify `make check` passes.
- [x] 1.5 Run `make test` and `make check` and verify both pass.

## Workflow follow-up

- Archive with a 0.5.3 bump in both TOC files and a `## 0.5.3` CHANGELOG section before committing.
- Close issue #1 when the change merges.
