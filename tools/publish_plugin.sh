#!/bin/sh
# Commits the built plugin (DIR, default build/plugin) to the plugin branch of origin, the source that
# .claude-plugin/marketplace.json names. Run it from a checkout of the commit the plugin was built from.
# It publishes nothing (exit 0, with a notice) when that commit is not on origin/main, when the plugin branch
# already holds tools from a newer or unrelated commit, or when only the version changed. It never force-pushes;
# a push that loses a race with another run is retried on top of the new branch head.
set -e
dir=$(cd "${1:-build/plugin}" && pwd)
wt="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/plugin-branch.$$"
trap 'rm -rf "$wt"; git worktree prune' EXIT
version() { python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$1"; }
ver=$(version "$dir/.claude-plugin/plugin.json")
git fetch -q origin main
if ! git merge-base --is-ancestor HEAD origin/main; then
    echo "plugin not published: $(git rev-parse --short HEAD) is not on main"; exit 0
fi
for attempt in 1 2 3; do
    rm -rf "$wt"; git worktree prune; git branch -q -D plugin 2>/dev/null || true   # a lost attempt's commit
    if git ls-remote --exit-code --heads origin plugin >/dev/null; then
        git fetch -q origin +plugin:refs/remotes/origin/plugin
        git worktree add -q --detach "$wt" origin/plugin
        git -C "$wt" checkout -q -B plugin
        src=$(version "$wt/.claude-plugin/plugin.json" 2>/dev/null || true)
        case $src in *+*) src=${src#*+};; *) src=;; esac
        if [ -n "$src" ] && git cat-file -e "$src^{commit}" 2>/dev/null && ! git merge-base --is-ancestor "$src" HEAD; then
            echo "plugin not published: the plugin branch holds tools from $src, which this commit does not contain"; exit 0
        fi
    else
        git worktree add -q --detach "$wt"
        git -C "$wt" checkout -q --orphan plugin
    fi
    find "$wt" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    cp -R "$dir/." "$wt"
    git -C "$wt" add -A
    if git -C "$wt" rev-parse -q --verify HEAD >/dev/null \
        && git -C "$wt" diff --cached --quiet -- . ':(exclude).claude-plugin/plugin.json' \
        && [ "$(git -C "$wt" show HEAD:.claude-plugin/plugin.json | grep -v '"version"')" = "$(grep -v '"version"' "$wt/.claude-plugin/plugin.json")" ]; then
        echo "plugin not published: only its version changed"; exit 0
    fi
    git -C "$wt" commit -q -m "checkthat $ver"
    if git -C "$wt" push -q origin plugin; then echo "published plugin $ver"; exit 0; fi
    echo "the push lost a race with another run, retrying ($attempt)"
done
echo "publishing the plugin failed after 3 attempts" >&2
exit 1
