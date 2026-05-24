# Local T3 Code Fork

This checkout is Gavin's fork of `pingdotgg/t3code`.

## Branches

- `main`: mirror of `upstream/main`. Keep this boring and fast-forward only.
- `gavin/nightly-custom`: local changes on top of current upstream. Add slash commands and other personal changes here.

## Updating From Upstream

From this repo:

```bash
./scripts/sync-gavin-fork.sh
```

The script fetches upstream, fast-forwards `main`, pushes `main` to `origin`, then rebases `gavin/nightly-custom` on top of it.

If the rebase conflicts, fix the conflicts, then run:

```bash
git rebase --continue
git push --force-with-lease origin gavin/nightly-custom
```

## Running Locally

The project expects Bun and Node versions from `.mise.toml`.

```bash
bun install
bun dev
```

If `bun` is not on `PATH`, use the same pinned Bun launcher as the desktop wrapper:

```bash
npm exec --yes --package bun@1.3.11 -- bun install
npm exec --yes --package bun@1.3.11 -- bun dev
```

For the desktop app:

```bash
bun dev:desktop
```

## Opening In T3 Code

This machine's desktop launcher runs the local checkout through:

```bash
~/.local/bin/t3code-desktop
```

That wrapper launches `bun dev:desktop` from `/home/gavin/Code/t3code`, so the app you open is this fork, not the downloaded nightly AppImage. The previous AppImage launcher is kept at:

```bash
~/.local/bin/t3code-desktop-nightly
```

The project is registered in T3 Code as `T3 Code Fork` with path `/home/gavin/Code/t3code`.

After changing branches or updating dependencies, close the running T3 Code window and open T3 Code again from the app launcher so the local desktop process restarts from this checkout.
