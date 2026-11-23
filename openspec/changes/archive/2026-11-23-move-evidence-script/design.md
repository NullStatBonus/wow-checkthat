# Design

## Context

`.pkgmeta` ignores named folders and files. Anything else at the top of the repository goes into the package, which the zip of 0.8.0 shows.

## Goals / Non-Goals

**Goals:**
- No script in the package.

**Non-Goals:**
- Reworking the ignore list. A test on the top folder is simpler and catches a new file earlier.

## Decisions

1. **Move, not ignore.** `tools/` is already ignored, and the script already lives there. Adding the `.bat` to the ignore list would leave it in the top folder, which the packager can ship by mistake.
