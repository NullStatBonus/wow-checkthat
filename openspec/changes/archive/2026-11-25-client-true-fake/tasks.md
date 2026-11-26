## 1. Slice
- [x] 1.1 tools/client_slice.py; tools/clients/era.json, forever.json, reviewed and approved
- [x] 1.2 Tests: the committed slices hold only the reviewed keys; the slice leaves out tester data

## 2. Strict fake client
- [x] 2.1 H.clientSurface, H.applySurface, typed frames in tests/harness.lua
- [x] 2.2 tests/test_clients.lua: CheckThat on both surfaces, surface differences, frame methods, aliases, default unchanged

## 3. Level 5
- [x] 3.1 Runner: surface by TOC interface, absent mocks refused; schema, warning, bundle
- [x] 3.2 Tests, with a break check for each behaviour

## 4. Docs and follow-ups
- [x] 4.1 docs/authoring-plans.md, docs/contracts.md, docs/harvesting.md, skills/ct-test-plan/SKILL.md
- [x] 4.2 Issues #169 (templates) and #170 (both clients)
