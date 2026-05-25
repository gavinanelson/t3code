# Local T3 Code Fork

This checkout is Gavin's fork of `pingdotgg/t3code`.

## Branches

- `main`: mirror of `upstream/main`. Keep this boring and fast-forward only.
- `gavin/nightly-custom`: local changes on top of current upstream. Add slash commands and other personal changes here.

## Updating From Upstream

From this repo, with a clean working tree:

```bash
./scripts/sync-gavin-fork.sh
```

The script fetches upstream, fast-forwards `main`, pushes `main` to `origin`, then rebases `gavin/nightly-custom` on top of it and force-pushes the rebased custom branch with lease protection.

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

## Building And Installing T3 Code Fork

Build and install the forked desktop app:

```bash
./scripts/install-t3-code-fork-linux.sh
```

The script:

- copies the local Aether theme into the gitignored CSS hook;
- runs `bun install --frozen-lockfile`;
- builds the Linux AppImage;
- extracts it into `~/.local/share/t3-code-fork/appdir`;
- updates both `~/.local/bin/t3-code-fork` and `~/.local/bin/t3code` to launch that extracted build;
- writes user desktop entries for both `T3 Code Fork` and the `t3code.desktop` override.

Useful flags:

```bash
T3_CODE_FORK_SKIP_BUN_INSTALL=1 ./scripts/install-t3-code-fork-linux.sh
T3_CODE_FORK_SKIP_BUILD=1 ./scripts/install-t3-code-fork-linux.sh
T3_CODE_FORK_ARCHIVE_OLD_INSTALL=0 ./scripts/install-t3-code-fork-linux.sh
```

## Opening T3 Code Fork

This machine's app launcher should use the user-level desktop entries in:

```bash
~/.local/share/applications/t3-code-fork.desktop
~/.local/share/applications/t3code.desktop
```

Both route to the local wrapper:

```bash
~/.local/bin/t3-code-fork
```

`~/.local/bin/t3code` is a symlink to that same wrapper, so terminal launches also use the forked installed build.

## Aether Theme

The local app imports a gitignored generated CSS file:

```bash
apps/web/src/local-aether-theme.css
```

The install script refreshes that file from the active Aether palette:

```bash
~/.config/aether/theme/colors.toml
```

It uses `scripts/generate-aether-t3code-theme.sh`, which writes higher-specificity `html:root` variables so upstream default CSS cannot override the Aether colors. If the source theme changes, rerun:

```bash
bun run fork:install
```
