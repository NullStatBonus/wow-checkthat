# Publishing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) from `.github/workflows/release.yml` and uploaded to CurseForge and Wago, plus a GitHub release.

## One-time setup

1. Create the addon project on each site and note its ID.
2. Add the IDs to both TOC files, `CheckThat/CheckThat_Vanilla.toc` and `CheckThat/CheckThat_Camelot.toc`:

   ```
   ## X-Curse-Project-ID: <CurseForge project ID>
   ## X-Wago-ID: <Wago project ID>
   ```

   The packager skips any site whose ID is missing.
3. Add these repository secrets (Settings > Secrets and variables > Actions): `CF_API_TOKEN`, `WAGO_API_TOKEN`. `GITHUB_TOKEN` is provided by GitHub and is passed to the packager as `GITHUB_OAUTH`.
4. Pick MIT as the license on each site. The repository's `LICENSE` ships inside the package; the Ace3 libraries keep their own in `CheckThat/Libs/LICENSE-Ace3.txt`.

## Releasing

1. Archive the change and bump `## Version:` in both TOC files (see `CLAUDE.md`), and add a `## X.Y.Z` section to `CHANGELOG.md`.
2. Commit, then tag the commit `vX.Y.Z` (the version without the `v` must equal the TOC version) and push the tag.
3. The workflow runs `make test` and `make check`, checks the tag against both TOC versions with `sh tools/check-version.sh "$GITHUB_REF_NAME"`, then packages and uploads to CurseForge and Wago, then creates the GitHub release with the zip attached.

## Listing page

Upload screenshots on CurseForge and Wago with the text from `docs/listing.md`: the checklist card on a step with live checks, the plan-ready screen with the Recent plans button, and the settings window. Use the tags Development, Utility and Testing where the site offers them.

## How the package is laid out

- The addon lives in `CheckThat/` inside the repository, so `.pkgmeta` moves it to the top of the zip and ignores everything else (tests, tools, docs, openspec, captures, screenshots and the root notices and requirement files). Only `LICENSE` and `CHANGELOG.md` ship from the repository root. The Ace3 and LibDeflate license files ship inside `CheckThat/Libs`; `THIRD_PARTY.md` only points to them. `tools/test_ct.py` fails when a new top-level file is neither listed in `ignore` nor one of those two.
- The Ace3 libraries and LibDeflate are committed under `CheckThat/Libs`, so no externals are fetched.
- The packager treats `CheckThat_Camelot.toc` as the WoW Forever TOC (its name for the Forever client) and `CheckThat_Vanilla.toc` as Classic Era. A TOC named `_Forever` would not be recognized, so Forever would not be offered as a game version.
- Both TOCs list the same files in the same order (`tools/check-tocs-match.sh`).
- `CHANGELOG.md` is used as the changelog on every site (`manual-changelog` in `.pkgmeta`).

## Skills plugin

`make build-plugin` builds a Claude Code plugin of the `ct-test-plan` and `ct-verify` skills in `build/plugin/`. It is not part of the addon package and has no release step yet (#53). `make test` builds it and runs `claude plugin validate` on it when `claude` is installed.
