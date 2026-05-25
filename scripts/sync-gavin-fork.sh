#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

upstream_remote="${T3CODE_UPSTREAM_REMOTE:-upstream}"
origin_remote="${T3CODE_ORIGIN_REMOTE:-origin}"
main_branch="${T3CODE_MAIN_BRANCH:-main}"
custom_branch="${T3CODE_CUSTOM_BRANCH:-${CUSTOM_BRANCH:-gavin/nightly-custom}}"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit, stash, or discard changes before syncing." >&2
  exit 1
fi

if ! git remote get-url "$upstream_remote" >/dev/null 2>&1; then
  git remote add "$upstream_remote" https://github.com/pingdotgg/t3code.git
fi

git fetch "$upstream_remote" --tags --prune
git fetch "$origin_remote" --tags --prune

git switch "$main_branch"
git merge --ff-only "$upstream_remote/$main_branch"
git push "$origin_remote" "$main_branch"

git switch "$custom_branch"
git rebase "$main_branch"
git push --force-with-lease -u "$origin_remote" "$custom_branch"

printf 'Synced %s on top of %s/%s.\n' "$custom_branch" "$upstream_remote" "$main_branch"
