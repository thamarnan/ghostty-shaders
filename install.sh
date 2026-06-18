#!/usr/bin/env bash
#
# install.sh — install Ghostty cursor shaders into your config (macOS + Linux).
#
# Portable: run it from wherever you cloned the repo — it finds its own
# shaders/ folder. If `gum` (https://github.com/charmbracelet/gum) is installed
# you get a nice interactive picker; otherwise it falls back to a plain prompt.
#
# It copies the chosen shader(s) into <ghostty-config-dir>/shaders/ and writes a
# managed block of `custom-shader` lines into your Ghostty config. Multiple
# shaders are chained in the order shown. Re-running replaces the managed block.
#
# Usage:
#   ./install.sh                             interactive picker (or prompt)
#   ./install.sh <shader> [<shader> ...]     install / chain these shaders
#   ./install.sh --list                      list available shaders
#   ./install.sh --uninstall                 remove the managed block
#   ./install.sh --print                     show the resolved config path
#
# Options:
#   --config <path>        use this config file (default: auto-detect)
#   --animation <mode>     custom-shader-animation: true | false | always
#   --yes                  skip confirmation prompts
#   --dry-run              show what would change without writing
#
# `gum` is optional. Install for the fancy UI: brew install gum  (macOS) /
# https://github.com/charmbracelet/gum#installation  (Linux).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SHADERS="$SCRIPT_DIR/shaders"
BEGIN="# >>> ghostty-cursor-shaders >>>"
END="# <<< ghostty-cursor-shaders <<<"

if command -v gum >/dev/null 2>&1; then HAS_GUM=1; else HAS_GUM=0; fi

CONFIG=""
ANIMATION=""
ANIM_SET=0
ASSUME_YES=0
DRY_RUN=0
DO_LIST=0
DO_UNINSTALL=0
DO_PRINT=0
SHADERS=()

die() {
  if [ "$HAS_GUM" = 1 ]; then gum style --foreground 196 "error: $*" >&2; else echo "error: $*" >&2; fi
  exit 1
}
usage() { sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
interactive() { [ -t 0 ] && [ -t 1 ]; }
gum_ui() { [ "$HAS_GUM" = 1 ] && interactive; }
say() { # say <color> <text...> ; colored line via gum, plain echo otherwise
  local c="$1"; shift
  if [ "$HAS_GUM" = 1 ]; then gum style --foreground "$c" "$*"; else echo "$*"; fi
}

resolve_config() {
  if [ -n "$CONFIG" ]; then echo "$CONFIG"; return; fi
  if [ -n "${GHOSTTY_CONFIG:-}" ]; then echo "$GHOSTTY_CONFIG"; return; fi
  # Linux/macOS XDG, then the macOS app-support location.
  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
  local mac="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  [ -f "$xdg" ] && { echo "$xdg"; return; }
  [ -f "$mac" ] && { echo "$mac"; return; }
  echo "$xdg"
}

available() { for f in "$SRC_SHADERS"/*.glsl; do basename "$f" .glsl; done; }

strip_block() {  # prints config with any existing managed block removed
  [ -f "$CONFIG" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '
    $0==b { skip=1; next } $0==e { skip=0; next } skip==0 { print }
  ' "$CONFIG"
}

trim_blanks() { awk 'NF{p=NR} {a[NR]=$0} END{for(i=1;i<=p;i++) print a[i]}'; }

write_config() {  # $1 = full new contents
  if [ "$DRY_RUN" = 1 ]; then
    echo "--- dry run: $CONFIG would become ---"
    printf '%s\n' "$1"
    return 0
  fi
  mkdir -p "$(dirname "$CONFIG")"
  if [ -f "$CONFIG" ]; then cp "$CONFIG" "$CONFIG.bak"; echo "backed up -> $CONFIG.bak"; fi
  printf '%s\n' "$1" > "$CONFIG"
}

confirm() {  # $1 = prompt; honours --yes
  [ "$ASSUME_YES" = 1 ] && return 0
  if gum_ui; then gum confirm "$1"; return; fi
  interactive || return 0   # non-interactive, no gum: proceed
  printf '%s [y/N]: ' "$1"
  local a; IFS= read -r a || true
  case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# plain-bash multi-select fallback (no gum)
choose_shaders_plain() {
  local arr=() i=1 name
  while IFS= read -r name; do arr+=("$name"); done < <(available)
  echo "Available shaders:" >&2
  i=1
  for name in "${arr[@]}"; do printf '%3d) %s\n' "$i" "$name" >&2; i=$((i + 1)); done
  printf 'Enter numbers and/or names (space-separated): ' >&2
  local reply tok idx; IFS= read -r reply || true
  SHADERS=()
  for tok in $reply; do
    case "$tok" in
      ''|*[!0-9]*) SHADERS+=("${tok%.glsl}") ;;                 # treat as a name
      *) idx=$((tok - 1)); if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#arr[@]}" ]; then SHADERS+=("${arr[$idx]}"); fi ;;
    esac
  done
}

# ---- parse args ----
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --list) DO_LIST=1; shift ;;
    --uninstall) DO_UNINSTALL=1; shift ;;
    --print) DO_PRINT=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --config) CONFIG="${2:-}"; [ -n "$CONFIG" ] || die "--config needs a path"; shift 2 ;;
    --animation) ANIMATION="${2:-}"; ANIM_SET=1; shift 2 ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *) SHADERS+=("${1%.glsl}"); shift ;;
  esac
done

[ -d "$SRC_SHADERS" ] || die "shaders dir not found next to script: $SRC_SHADERS"

if [ "$DO_LIST" = 1 ]; then
  say 212 "Available shaders ($SRC_SHADERS):"
  available | sed 's/^/  - /'
  exit 0
fi

CONFIG="$(resolve_config)"

if [ "$DO_PRINT" = 1 ]; then
  echo "config file : $CONFIG  ($([ -f "$CONFIG" ] && echo exists || echo 'will be created'))"
  echo "shaders dir : $(dirname "$CONFIG")/shaders"
  echo "gum         : $([ "$HAS_GUM" = 1 ] && echo 'found (interactive)' || echo 'not found (plain mode)')"
  exit 0
fi

# ---- uninstall ----
if [ "$DO_UNINSTALL" = 1 ]; then
  [ -f "$CONFIG" ] || { echo "nothing to do: $CONFIG does not exist"; exit 0; }
  grep -qF "$BEGIN" "$CONFIG" || { echo "no managed block found in $CONFIG"; exit 0; }
  confirm "Remove the managed shader block from $CONFIG?" || { echo "cancelled."; exit 0; }
  write_config "$(strip_block | trim_blanks)"
  say 78 "removed managed shader block (copied .glsl files left in $(dirname "$CONFIG")/shaders)."
  echo "reload Ghostty config to apply."
  exit 0
fi

# ---- banner ----
if gum_ui; then
  gum style --border double --border-foreground 212 --padding "1 3" --margin "1 0" --align center \
    "Ghostty Cursor Shader Installer"
fi

# ---- choose shaders ----
if [ "${#SHADERS[@]}" -eq 0 ]; then
  interactive || die "no shaders given (and not a TTY). Pass shader names or use --list."
  if gum_ui; then
    selection="$(available | gum filter --no-limit \
      --height 18 \
      --header "Select shader(s) — type to search, Tab to multi-select, Enter to confirm" \
      --placeholder "filter shaders..." \
      --indicator "*" --selected-prefix "[x] " --unselected-prefix "[ ] ")" || true
    SHADERS=()
    while IFS= read -r line; do [ -n "$line" ] && SHADERS+=("$line"); done <<< "$selection"
  else
    choose_shaders_plain
  fi
  [ "${#SHADERS[@]}" -gt 0 ] || { echo "nothing selected."; exit 0; }
fi

# ---- validate ----
for s in "${SHADERS[@]}"; do
  [ -f "$SRC_SHADERS/$s.glsl" ] || die "shader not found: $s  (run --list to see options)"
done

# ---- choose animation mode ----
if [ "$ANIM_SET" = 0 ]; then
  if gum_ui; then
    ANIMATION="$(gum choose --header "Animation mode (custom-shader-animation):" true always false)" || true
  elif interactive; then
    printf 'Animation mode [true / always / false] (default: true): '
    IFS= read -r ANIMATION || true
  fi
fi
[ -n "$ANIMATION" ] || ANIMATION="true"
case "$ANIMATION" in true|false|always) ;; *) die "--animation must be true, false, or always" ;; esac

# ---- build the exact managed block first (so we can show it) ----
dest="$(dirname "$CONFIG")/shaders"
BLOCK="$BEGIN"$'\n'"custom-shader-animation = $ANIMATION"
for s in "${SHADERS[@]}"; do BLOCK="$BLOCK"$'\n'"custom-shader = shaders/$s.glsl"; done
BLOCK="$BLOCK"$'\n'"$END"

# ---- figure out what will actually happen ----
if [ -f "$CONFIG" ]; then
  cfg_state="exists — backup saved to config.bak first"
  if grep -qF "$BEGIN" "$CONFIG"; then
    block_action="UPDATE the existing managed block (your other settings are untouched)"
  else
    block_action="APPEND a new managed block (your existing config is kept)"
  fi
else
  cfg_state="does not exist — will be created"
  block_action="CREATE the file with this managed block"
fi

# ---- summary + confirm ----
SUMMARY="Config file:   $CONFIG
               ($cfg_state)
Shaders copied to:
               $dest/

What will change:
  - copy ${#SHADERS[@]} shader file(s) into the shaders/ folder above
  - $block_action

Exact lines written to your config:
- - - - - - - - - - - - - - - - - - - - - - - -
$BLOCK
- - - - - - - - - - - - - - - - - - - - - - - -
(custom-shader = ... loads each shader, chained top-to-bottom;
 custom-shader-animation = $ANIMATION controls animation.)"

if [ -f "$CONFIG" ] && strip_block | grep -qE '^[[:space:]]*custom-shader[[:space:]]*='; then
  SUMMARY="$SUMMARY

note: you already have custom-shader line(s) outside this block —
they are left as-is and will chain together with these."
fi

if gum_ui; then
  gum style --border rounded --border-foreground 212 --padding "1 2" "$SUMMARY"
else
  printf '%s\n' "$SUMMARY"
fi

confirm "Apply these changes?" || { echo "cancelled."; exit 0; }

# ---- copy shaders ----
if [ "$DRY_RUN" = 0 ]; then
  mkdir -p "$dest"
  for s in "${SHADERS[@]}"; do
    cp "$SRC_SHADERS/$s.glsl" "$dest/"
    echo "  copied $s.glsl -> $dest/"
  done
fi

# ---- write config ----
BASE="$(strip_block | trim_blanks)"
if [ -n "$BASE" ]; then NEW="$BASE"$'\n\n'"$BLOCK"; else NEW="$BLOCK"; fi
write_config "$NEW"

# ---- done ----
if [ "$DRY_RUN" = 0 ]; then
  say 78 "installed ${#SHADERS[@]} shader(s)"
  case "$(uname -s)" in
    Darwin) echo "reload Ghostty config (Cmd+Shift+,) or fully restart Ghostty to apply." ;;
    *)      echo "reload Ghostty config (Ctrl+Shift+,) or restart Ghostty to apply." ;;
  esac
fi
