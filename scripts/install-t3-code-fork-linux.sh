#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

install_root="${T3_CODE_FORK_INSTALL_ROOT:-$HOME/.local/share/t3-code-fork}"
appdir="$install_root/appdir"
output_dir="${T3_CODE_FORK_BUILD_OUTPUT_DIR:-$repo_root/release-local}"
wrapper_fork="$HOME/.local/bin/t3-code-fork"
wrapper_t3code="$HOME/.local/bin/t3code"
wrapper_t3k="$HOME/.local/bin/t3k"
desktop_dir="$HOME/.local/share/applications"
icon_dir="$HOME/.local/share/icons/hicolor/1024x1024/apps"
icon_path="$icon_dir/t3-code-fork.png"
theme_source="${T3_CODE_FORK_AETHER_THEME_SOURCE:-$HOME/.config/aether/theme/t3code.css}"
theme_target="$repo_root/apps/web/src/local-aether-theme.css"

mkdir -p "$HOME/.local/bin" "$desktop_dir" "$icon_dir" "$output_dir"
cp "$repo_root/assets/nightly/blueprint-universal-1024.png" "$icon_path"

if [[ -f "$theme_source" ]]; then
  cp "$theme_source" "$theme_target"
else
  "$repo_root/scripts/generate-aether-t3code-theme.sh" "$theme_target"
fi

if [[ "${T3_CODE_FORK_SKIP_BUN_INSTALL:-0}" != "1" ]]; then
  bun install --frozen-lockfile
fi

if [[ "${T3_CODE_FORK_SKIP_BUILD:-0}" != "1" ]]; then
  T3CODE_DESKTOP_OUTPUT_DIR="$output_dir" bun run dist:desktop:linux
fi

artifact="$(
  find "$output_dir" -maxdepth 1 -type f -name '*.AppImage' -printf '%T@ %p\n' \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
)"

if [[ -z "$artifact" ]]; then
  echo "No AppImage artifact found in $output_dir." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

chmod +x "$artifact"
(
  cd "$tmpdir"
  "$artifact" --appimage-extract >/dev/null
)

pkill -TERM -f "$appdir/t3code" >/dev/null 2>&1 || true
pkill -TERM -f "$HOME/.local/share/t3k/appdir/t3code" >/dev/null 2>&1 || true
pkill -TERM -f "$HOME/.local/share/t3code-aether/appdir/t3code" >/dev/null 2>&1 || true
sleep 1

rm -rf "$appdir"
mkdir -p "$install_root"
mv "$tmpdir/squashfs-root" "$appdir"

if [[ "${T3_CODE_FORK_ARCHIVE_OLD_INSTALL:-1}" == "1" && -d "$HOME/.local/share/t3code-aether" ]]; then
  old_archive="$HOME/.local/share/t3code-aether.disabled.$(date +%Y%m%d%H%M%S)"
  mv "$HOME/.local/share/t3code-aether" "$old_archive"
fi

cat >"$wrapper_fork" <<EOF
#!/usr/bin/env bash
set -euo pipefail

appdir="\${T3CODE_APPDIR:-$appdir}"
export APPDIR="\$appdir"

focus_existing_window() {
  if command -v niri >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local window_id
    window_id="\$(
      niri msg -j windows 2>/dev/null \\
        | jq -r '.[] | select(.app_id == "t3code") | .id' 2>/dev/null \\
        | head -n 1
    )"
    if [[ -n "\$window_id" && "\$window_id" != "null" ]]; then
      niri msg action focus-window --id "\$window_id" >/dev/null 2>&1 || true
    fi
  fi
}

has_running_t3code() {
  local pid stat args
  while read -r pid stat args; do
    [[ "\$pid" == "\$\$" ]] && continue
    [[ "\$stat" == Z* ]] && continue
    case "\$args" in
      "\$appdir/t3code"*|"/home/gavin/.local/share/t3code-aether/appdir/t3code"*|"/opt/t3code-git/t3code"*)
        if [[ "\$args" != *" --type="* && "\$args" != *"resources/app/apps/server/dist/bin.mjs"* ]]; then
          return 0
        fi
        ;;
    esac
  done < <(ps -u "\$UID" -o pid=,stat=,args=)

  return 1
}

lock_file="\${XDG_RUNTIME_DIR:-/tmp}/t3-code-fork-launch.lock"
exec 9>"\$lock_file"
if ! flock -n 9; then
  focus_existing_window
  exit 0
fi

if has_running_t3code; then
  focus_existing_window
  exit 0
fi

if [[ -z "\${CODEX_CLI_PATH-}" ]] && command -v codex >/dev/null 2>&1; then
  export CODEX_CLI_PATH="\$(command -v codex)"
fi

export PATH="\$appdir:\$PATH"

exec "\$appdir/t3code" \\
  --class=t3code \\
  --no-sandbox \\
  --ozone-platform=x11 \\
  --disable-features=UseOzonePlatform \\
  "\$@"
EOF
chmod +x "$wrapper_fork"
ln -sf "$wrapper_fork" "$wrapper_t3code"
ln -sf "$wrapper_fork" "$wrapper_t3k"

cat >"$desktop_dir/t3-code-fork.desktop" <<EOF
[Desktop Entry]
Name=T3 Code Fork
Comment=Local T3 Code fork
Exec=$wrapper_fork %U
Terminal=false
Type=Application
Icon=t3-code-fork
StartupWMClass=t3code
Categories=Development;
EOF

cat >"$desktop_dir/t3code.desktop" <<EOF
[Desktop Entry]
Name=T3 Code Fork
Comment=Local T3 Code fork
Exec=$wrapper_fork %U
Terminal=false
Type=Application
NoDisplay=true
Icon=t3-code-fork
StartupWMClass=t3code
Categories=Development;
EOF

cat >"$desktop_dir/t3k.desktop" <<EOF
[Desktop Entry]
Name=T3 Code Fork
Comment=Local T3 Code fork
Exec=$wrapper_fork %U
Terminal=false
Type=Application
NoDisplay=true
Icon=t3-code-fork
StartupWMClass=t3code
Categories=Development;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Installed T3 Code Fork from $artifact to $appdir."
echo "Launchers: $wrapper_fork and $wrapper_t3code"
