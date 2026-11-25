# Design

## Context

Issues #91, #90 and #95 all touch `collect`. They ship together.

## Goals / Non-Goals

**Goals:**
- `collect`, `status` and `report` run without luajit.
- Collect what the plan names.
- Make the screenshot slack adjustable.

**Non-Goals:**
- A `ct.py harvest` command (collect, status, report in one) and a Windows run of it: the reader removes the blocker, the command is separate work. Deferred in #9.
- Measuring the real skew on a network mount: it needs a client. #95 stays open.
- The luajit commands `replay` and `offline`: they run addon Lua and keep luajit.

## Decisions

1. **One reader, same output.** The reader parses the file subset the game writes (assignments of tables, strings, numbers, booleans, nil, comments, long strings), applies the same normalising rules as `sv2json.lua` (array detection, string keys, depth limit) and then the same canonical encoder (sorted keys, ASCII strings, `%d` or `%.14g` numbers). A test compares its text with luajit's byte for byte.
2. **Strings stay bytes.** Lua strings are bytes and the encoder reads UTF-8 by hand, including its handling of bad bytes. The reader does the same.
3. **Find files by content when a plan is given.** A saved-variables file is named after the addon, but a plan names globals. A file matches when its name is the plan's addon or CheckThat, or when a line starts with a wanted global and `=`. A wanted global no file defines gets a warning, and the exit code stays 0.
4. **Slack is an option, not a measurement.** Default stays 2.
5. **PowerShell takes names, not globals.** It cannot read Lua, so `-Names` lists file names.
