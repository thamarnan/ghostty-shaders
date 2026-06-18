#!/usr/bin/env bash
#
# demo.sh — make the terminal cursor "dance" and mimic typing, so you can watch
# your Ghostty cursor shader do its thing. It moves the cursor all over the
# screen (trails/smear/blaze/sparks), and toggles block<->bar cursor shapes
# (ripple/boom effects), in a loop until you press Ctrl-C.
#
# Usage:
#   ./demo.sh                 run forever (Ctrl-C to stop)
#   ./demo.sh --once          run a single pass and exit
#   ./demo.sh --fast          quicker movements
#   ./demo.sh --slow          calmer movements
#
# Tip: install a shader first, e.g.  ./install.sh cursor_blaze  (then reload Ghostty).

set -u

# ---- speed (seconds) ----
CHAR=0.045     # delay between typed characters
STEP=0.05      # delay between dance steps
PAUSE=0.5      # pause between scenes
LOOPS=0        # 0 = forever

for a in "$@"; do
  case "$a" in
    --once)  LOOPS=1 ;;
    --fast)  CHAR=0.02; STEP=0.025; PAUSE=0.25 ;;
    --slow)  CHAR=0.08; STEP=0.09;  PAUSE=0.8 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

# ---- terminal geometry (validate; fall back to 80x24) ----
COLS=$(tput cols 2>/dev/null); case "$COLS" in ''|*[!0-9]*) COLS=80 ;; esac
ROWS=$(tput lines 2>/dev/null); case "$ROWS" in ''|*[!0-9]*) ROWS=24 ;; esac
ESC=$'\e'

# ---- low-level helpers ----
cup()   { printf '%s[%d;%dH' "$ESC" "$1" "$2"; }   # move cursor to row col
home()  { printf '%s[H' "$ESC"; }
clear() { printf '%s[2J%s[H' "$ESC" "$ESC"; }
block() { printf '%s[2 q' "$ESC"; }                # steady block cursor
bar()   { printf '%s[6 q' "$ESC"; }                # steady bar (insert) cursor
uline() { printf '%s[4 q' "$ESC"; }                # steady underline cursor
color() { printf '%s[%sm' "$ESC" "$1"; }
reset() { printf '%s[0m' "$ESC"; }
rnd()   { echo $(( RANDOM % $1 + 1 )); }

cleanup() {
  printf '%s[0 q' "$ESC"   # restore default cursor style
  printf '%s[?25h' "$ESC"  # ensure cursor visible
  reset
  cup "$ROWS" 1
  printf '\n'
  exit 0
}
trap cleanup INT TERM

# type a string one char at a time at the current position
type_text() {
  local s="$1" i ch
  for (( i=0; i<${#s}; i++ )); do
    ch="${s:$i:1}"
    printf '%s' "$ch"
    sleep "$CHAR"
  done
}

# ---------------------------------------------------------------------------
# Scene 1 — mimic typing a little coding session
# ---------------------------------------------------------------------------
scene_type() {
  clear; block
  local prompts=(
    "$ "
    "~/dev/ghostty $ "
    "user@ghostty $ "
  )
  local lines=(
    "cargo run --release"
    "git commit -m \"make the cursor sparkle\""
    "nvim src/main.rs"
    "fn main() { println!(\"ghostty shaders ✨\"); }"
    "ls -la ~/.config/ghostty/shaders/"
    "echo \"the cursor is dancing\""
    "for i in 1 2 3; do echo \$i; done"
  )
  local r=2
  local n; n=$(( ${#lines[@]} ))
  local i
  for (( i=0; i<n; i++ )); do
    cup "$r" 3
    color "38;5;78"; type_text "${prompts[$(( RANDOM % ${#prompts[@]} ))]}"; reset
    type_text "${lines[$i]}"
    r=$(( r + 2 ))
    [ "$r" -ge $(( ROWS - 2 )) ] && r=2 && { sleep "$PAUSE"; clear; }
    sleep "$CHAR"
  done
  sleep "$PAUSE"
}

# ---------------------------------------------------------------------------
# Scene 2 — bouncing "dance" across the whole screen (trails / smear / blaze)
# ---------------------------------------------------------------------------
scene_dance() {
  clear; block
  local x y dx dy steps
  x=$(rnd "$COLS"); y=$(rnd "$ROWS"); dx=2; dy=1
  steps=$(( COLS + ROWS ))
  local glyphs='@#*o+.=>~'
  local k g
  for (( k=0; k<steps; k++ )); do
    cup "$y" "$x"
    g="${glyphs:$(( RANDOM % ${#glyphs} )):1}"
    color "38;5;$(( 196 + RANDOM % 50 ))"; printf '%s' "$g"; reset
    x=$(( x + dx )); y=$(( y + dy ))
    (( x <= 1 || x >= COLS )) && dx=$(( -dx ))
    (( y <= 1 || y >= ROWS )) && dy=$(( -dy ))
    (( x < 1 )) && x=1; (( x > COLS )) && x=$COLS
    (( y < 1 )) && y=1; (( y > ROWS )) && y=$ROWS
    sleep "$STEP"
  done
  sleep "$PAUSE"
}

# ---------------------------------------------------------------------------
# Scene 3 — random teleporting around the screen (long jumps = big trails)
# ---------------------------------------------------------------------------
scene_teleport() {
  clear; block
  local k r c
  for (( k=0; k<24; k++ )); do
    r=$(rnd "$ROWS"); c=$(rnd "$COLS")
    cup "$r" "$c"
    color "38;5;$(( 39 + RANDOM % 180 ))"; printf '●'; reset
    sleep "$STEP"; sleep "$STEP"
  done
  sleep "$PAUSE"
}

# ---------------------------------------------------------------------------
# Scene 4 — insert-mode storm: toggle block<->bar to fire ripple/boom shaders
# ---------------------------------------------------------------------------
scene_modes() {
  clear; block
  cup $(( ROWS / 2 )) $(( COLS / 2 - 12 ))
  color "38;5;213"; printf '%s' '-- block <-> bar --'; reset
  local k r c
  for (( k=0; k<14; k++ )); do
    r=$(rnd "$ROWS"); c=$(rnd "$COLS")
    cup "$r" "$c"
    bar;   printf 'I'; sleep "$STEP"     # insert (bar)  -> ripple
    block; printf '#'; sleep "$STEP"     # normal (block)-> ripple
  done
  sleep "$PAUSE"
}

# ---------------------------------------------------------------------------
printf '%s[?25h' "$ESC"   # make sure the cursor is visible
count=0
while :; do
  scene_type
  scene_dance
  scene_teleport
  scene_modes
  count=$(( count + 1 ))
  [ "$LOOPS" -ne 0 ] && [ "$count" -ge "$LOOPS" ] && break
done
cleanup
