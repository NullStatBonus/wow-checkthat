# Design

## Context

`Codec.Decode` calls `LibDeflate:DecompressDeflate(packed)`, which returns the full output string. LibDeflate keeps one table slot per output byte and flushes every 32 KB into a `result_buffer`. There is no length cap and no streaming API. DEFLATE can expand about 1032:1, so the packed size says nothing useful about the output size. `tools/ct.py` already stops at the cap with `zlib.decompressobj`.

## Goals / Non-Goals

**Goals:**
- Stop inflating soon after the output passes `Codec.LIMITS.inflated`.
- Keep the patch to the vendored library small and recorded.

**Non-Goals:**
- No change to limits, plan format or the Python tool.
- No upstream LibDeflate change in this work.
- No exact stop at the cap. The post-check in `Codec.Decode` stays exact.

## Decisions

**Patch the vendored LibDeflate.** Add `state.max_out` and a flushed-byte count in `state`. In `DecodeUntilEndOfBlock`, where the buffer already flushes 32,768 bytes, add the count and return a new status (-20) when it passes `max_out`. `DecompressDeflate(str, max_out)` takes the optional limit. Overshoot is bounded by about 64 KB plus one 258-byte match. Stored blocks need no check because their output cannot exceed their input.

Alternatives rejected:
- *Reject by packed size or header scan.* DEFLATE has no length header, and legitimate plans can exceed 2 KB packed.
- *`debug.sethook` budget.* The WoW client does not provide `debug`.
- *Own inflate in `Model/`.* About 200 lines to do what a patch of a few lines does.
- *Wrap without patching.* The loop is local to the library, so a wrapper means copying it.

**Record the patch.** `VERSIONS.txt` lists no LibDeflate entry today. Add one with upstream version 1.0.2, the patch description, and a note that sibling addons' copies will differ.

## Risks / Trade-offs

- [Patch lost on a library update] → `VERSIONS.txt` entry and the codec test, which fails if the cap stops working.
- [Sibling addons keep an unpatched copy] → Documented in `VERSIONS.txt`. Report upstream later if wanted.
