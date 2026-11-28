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
3. The workflow runs `make test` and `make check`, and checks the tag against both TOC versions with `sh tools/check-version.sh "$GITHUB_REF_NAME"`. It builds the plugin and the toolkit and checks them with `claude plugin validate` (the CLI version is pinned in the workflow: raise it on purpose). Then it packages and uploads to CurseForge and Wago, creates the GitHub release with the addon zip, attaches the toolkit zip, and commits the plugin to the `plugin` branch last. A failed test or check stops the run before anything is published. A failed toolkit validation holds back only the toolkit zip and the plugin: the addon release goes on.

## Listing page

Upload screenshots on CurseForge and Wago with the text from `docs/listing.md`: the checklist card on a step with live checks, the plan-ready screen with the Choose a plan list, and the settings window. Use the tags Development, Utility and Testing where the site offers them.

## How the package is laid out

- The addon lives in `CheckThat/` inside the repository, so `.pkgmeta` moves it to the top of the zip and ignores everything else (tests, tools, docs, openspec, captures, screenshots and the root notices and requirement files). Only `LICENSE` and `CHANGELOG.md` ship from the repository root. The Ace3 and LibDeflate license files ship inside `CheckThat/Libs`; `THIRD_PARTY.md` only points to them. `tools/test_ct.py` fails when a new top-level file is neither listed in `ignore` nor one of those two.
- The Ace3 libraries and LibDeflate are committed under `CheckThat/Libs`, so no externals are fetched.
- The packager treats `CheckThat_Camelot.toc` as the WoW Forever TOC (its name for the Forever client) and `CheckThat_Vanilla.toc` as Classic Era. A TOC named `_Forever` would not be recognized, so Forever would not be offered as a game version.
- Both TOCs list the same files in the same order (`tools/check-tocs-match.sh`).
- `CHANGELOG.md` is used as the changelog on every site (`manual-changelog` in `.pkgmeta`).

## Developer toolkit

The skills and the plan tools ship outside the addon package, in two forms:

- **Claude Code plugin.** `.claude-plugin/marketplace.json` on `main` names the `checkthat` plugin with the `plugin` branch as its source. Each publish adds one commit to that branch with the built plugin (`checkthat <version>`). The plugin version is the addon version plus the commit it was built from (`1.0.0+3f9c2a1b7d4e`), so Claude Code sees every publish as an update. The branch is never force-pushed, so an earlier version stays reachable. The workflow creates the branch on the first release.
- **Toolkit zip.** `CheckThat-toolkit-<version>.zip` on the GitHub release holds `ct-test-plan` and `ct-verify` for any agent.

`make test` builds both and runs `claude plugin validate` on the plugin and the marketplace when `claude` is installed.

**Without a tag.** A change to the tools or skills alone gets no version bump and no tag. To publish it, run the Release workflow by hand on `main` (Actions, Release, Run workflow) and tick `publish`. It runs the tests, builds and validates the plugin and the toolkit, replaces the toolkit zip on the release of the current version, then commits the plugin to the `plugin` branch. When that release does not exist yet (a version bump that is not tagged), the run fails before the plugin is published. A manual run never packages the addon or creates a release, even when it runs from a tag. Without `publish` it is a dry run: it uploads both as the `developer-toolkit` workflow artifact and publishes nothing.

`tools/publish_plugin.sh` makes the plugin commit. It publishes nothing when the commit is not on `main`, when the branch already holds tools from a newer commit, or when only the version changed. When another run pushed first, it retries on top of that push.

`.claude-plugin` is in the `.pkgmeta` ignore list, so it never ships in the addon zip.
