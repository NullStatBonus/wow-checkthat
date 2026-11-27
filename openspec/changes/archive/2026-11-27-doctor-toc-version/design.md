## Decisions

- **A warning, not an exit code.** Doctor exits 1 only when collect would find nothing; a version mismatch can be on purpose (testing an older build), so it is a warning line.
- **Version line only.** While version bumps are held, two builds can share a version; doctor cannot tell them apart without hashing files, which it does not do (it reads listings and the TOC only).
