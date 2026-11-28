# Design

## Context

`probe_recordings()` already turns a CTProbe saved-variables file into a recording that names no character, drops a personal value, blanks an item link's level and specialization, and empties an auction row's bidders and sellers. `signature_problems()` already says where a call does not fit `tools/recordings/signatures.json`, and `cmd_recordings` already compares a run with the file it is about to replace (`confirmed`, `changed`, `dropped`, `--merge`). What is missing is the other direction: a developer's run compared with the bundled file, as something a maintainer can read and paste.

## Goals

- A slice a maintainer can paste into a pull request without editing: the calls alone, with the client and build of the run.
- Nothing written: a contributor works in an installed copy, where a write needs `-o`, and has no checkout to write into.
- The judgment stays with the maintainer: a call that does not fit its signature is named, never offered.

## Decisions

- **Shape, not values, decides `already recorded`.** Arguments, count, nil positions and return types compare; the values of a real run are the point of a recording, so a call whose values differ is still offered, as `changes`.
- **A signature problem withholds the call.** A slice that carries a call the signature contradicts invites a review of two things at once. The call is printed with the first problem, so the signature work starts from the output.
- **`GetBuildInfo()` is never sent.** It names the client and build, which the slice header carries; a plan never mocks it.
- **Markers, not a file.** `---8<--- contribute:<client>` and the closing `---8<---` delimit one JSON object in a terminal log or a PR body, so copying is unambiguous.
- **No bundled file for the client is not an error.** An installed copy carries none, so every call that fits is offered; the tests pin that.

## Risks

- A contributor could paste a slice recorded on a modified client. The checklist asks for the client and build in the pull request, and the header repeats both, so a maintainer can check them against the run.
- A shape change may be a client change rather than a new call. That is why it is labelled `changes` and printed beside the bundled entry's difference, not merged silently.
