#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
colors_file="${AETHER_COLORS_FILE:-$HOME/.config/aether/theme/colors.toml}"
output_file="${1:-$repo_root/apps/web/src/local-aether-theme.css}"

if [[ ! -f "$colors_file" ]]; then
  echo "Aether colors file not found: $colors_file" >&2
  exit 1
fi

color_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      gsub(/[[:space:]"]/, "", $2)
      print $2
      exit
    }
  ' "$colors_file"
}

background="$(color_value background)"
foreground="$(color_value foreground)"
accent="$(color_value accent)"
muted="$(color_value color8)"
red="$(color_value color1)"
green="$(color_value color2)"
pink="$(color_value color3)"
blue="$(color_value color4)"
magenta="$(color_value color5)"
cyan="$(color_value color6)"
bright_red="$(color_value color9)"
bright_green="$(color_value color10)"
bright_pink="$(color_value color11)"
bright_blue="$(color_value color12)"
bright_magenta="$(color_value color13)"
bright_cyan="$(color_value color14)"
bright_foreground="$(color_value color15)"

if [[ -z "$background" || -z "$foreground" || -z "$accent" ]]; then
  echo "Aether colors file is missing background, foreground, or accent." >&2
  exit 1
fi

mkdir -p "$(dirname "$output_file")"

cat >"$output_file" <<EOF
/*
 * Generated from $colors_file by scripts/generate-aether-t3code-theme.sh.
 * Use html:root specificity because this file is imported before upstream
 * default variables in apps/web/src/index.css.
 */

html:root,
html:root.dark {
  color-scheme: dark;
  --background: $background;
  --app-chrome-background: $background;
  --foreground: $foreground;
  --card: color-mix(in srgb, $background 92%, $accent);
  --card-foreground: $foreground;
  --popover: color-mix(in srgb, $background 90%, $accent);
  --popover-foreground: $foreground;
  --primary: $accent;
  --primary-foreground: $bright_foreground;
  --secondary: color-mix(in srgb, $background 72%, $blue);
  --secondary-foreground: $foreground;
  --muted: color-mix(in srgb, $background 76%, $muted);
  --muted-foreground: color-mix(in srgb, $foreground 62%, $muted);
  --accent: color-mix(in srgb, $accent 42%, $background);
  --accent-foreground: $foreground;
  --destructive: $red;
  --destructive-foreground: $bright_red;
  --border: color-mix(in srgb, $foreground 14%, transparent);
  --input: color-mix(in srgb, $foreground 18%, transparent);
  --ring: $bright_blue;
  --info: $cyan;
  --info-foreground: $bright_cyan;
  --success: $green;
  --success-foreground: $bright_green;
  --warning: $pink;
  --warning-foreground: $bright_pink;
  --aether-magenta: $magenta;
  --aether-magenta-bright: $bright_magenta;
}

html:root body,
html:root.dark body {
  background:
    radial-gradient(circle at 18% 12%, color-mix(in srgb, $bright_blue 18%, transparent), transparent 28rem),
    radial-gradient(circle at 82% 10%, color-mix(in srgb, $bright_magenta 12%, transparent), transparent 24rem),
    $background;
}
EOF

echo "Wrote $output_file"
