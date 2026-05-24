#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

custom_branch="${CUSTOM_BRANCH:-gavin/nightly-custom}"

git fetch upstream --tags
git fetch origin --tags

git switch main
git merge --ff-only upstream/main
git push origin main

git switch "$custom_branch"
git rebase main
git push --force-with-lease origin "$custom_branch"

printf 'Synced %s on top of upstream/main.\n' "$custom_branch"
