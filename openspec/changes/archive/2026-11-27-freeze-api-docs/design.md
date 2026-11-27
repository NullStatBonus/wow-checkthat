## Decisions

- **Developer commands stay.** Removing or renaming them would break the self-test plans that use them. A separate README table says they are not stable, which is the promise that matters.
- **Chat line, not a confirmation.** Pruning happens at run start; asking first would block the start. The chat line names the plan so a tester can export from Past runs next time, and the default stays 20.
- **`version` kept.** Dropping a key would break plans that set it. It is documented as the author's label.
- **Since 0.21.0.** The bump is held; 0.21.0 is the version these names ship under, as the results-format table already says for formatRev 5 to 7.
