# Claude Code sound notifications
# Plays sounds when Claude starts/completes tasks via file watchers

# Configuration - all can be overridden via environment variables
CLAUDE_DIR="$HOME/.claude"

export CLAUDE_SOUNDS_DIR="${CLAUDE_SOUNDS_DIR:-$HOME/.claude/sounds}"
export CLAUDE_SOUND_VOLUME="${CLAUDE_SOUND_VOLUME:-0.6}"  # 0-1 multiplier, 1 = full volume

# Trigger files (created by Claude hooks)
export CLAUDE_DONE_FILE="${CLAUDE_DONE_FILE:-$CLAUDE_DIR/.claude-done}"
export CLAUDE_START_FILE="${CLAUDE_START_FILE:-$CLAUDE_DIR/.claude-start}"
export CLAUDE_PROMPT_FILE="${CLAUDE_PROMPT_FILE:-$CLAUDE_DIR/.claude-prompt}"
export CLAUDE_PRECOMPACT_FILE="${CLAUDE_PRECOMPACT_FILE:-$CLAUDE_DIR/.claude-compact}"
export CLAUDE_PERMISSION_FILE="${CLAUDE_PERMISSION_FILE:-$CLAUDE_DIR/.claude-permission}"
export CLAUDE_QUESTION_FILE="${CLAUDE_QUESTION_FILE:-$CLAUDE_DIR/.claude-question}"

# Sound directories (used in random mode)
export CLAUDE_DONE_SOUNDS="${CLAUDE_DONE_SOUNDS:-$CLAUDE_SOUNDS_DIR/done}"
export CLAUDE_START_SOUNDS="${CLAUDE_START_SOUNDS:-$CLAUDE_SOUNDS_DIR/start}"
export CLAUDE_PROMPT_SOUNDS="${CLAUDE_PROMPT_SOUNDS:-$CLAUDE_SOUNDS_DIR/userpromptsubmit}"
export CLAUDE_PRECOMPACT_SOUNDS="${CLAUDE_PRECOMPACT_SOUNDS:-$CLAUDE_SOUNDS_DIR/precompact}"
export CLAUDE_PERMISSION_SOUNDS="${CLAUDE_PERMISSION_SOUNDS:-$CLAUDE_SOUNDS_DIR/permission}"
export CLAUDE_QUESTION_SOUNDS="${CLAUDE_QUESTION_SOUNDS:-$CLAUDE_SOUNDS_DIR/question}"

# Theme preset: source resolved paths from download-theme-sounds.sh output
_THEME_FILE="$CLAUDE_SOUNDS_DIR/.theme"
if [ -f "$_THEME_FILE" ]; then
  source "$_THEME_FILE"
fi

# Deterministic mode: set specific sound files per event (overrides random selection)
# To enable: set CLAUDE_SOUND_MODE=deterministic
export CLAUDE_SOUND_MODE="${CLAUDE_SOUND_MODE:-deterministic}"
export CLAUDE_START_SOUND="${CLAUDE_START_SOUND:-$CLAUDE_SOUNDS_DIR/start/carrier_has_arrived.mp3}"
export CLAUDE_DONE_SOUND="${CLAUDE_DONE_SOUND:-$CLAUDE_SOUNDS_DIR/done/jobs_finished.mp3}"
export CLAUDE_PROMPT_SOUND="${CLAUDE_PROMPT_SOUND:-$CLAUDE_SOUNDS_DIR/userpromptsubmit/go_go_go.mp3}"
export CLAUDE_PRECOMPACT_SOUND="${CLAUDE_PRECOMPACT_SOUND:-$CLAUDE_SOUNDS_DIR/precompact/we_cannot_hold.mp3}"
export CLAUDE_PERMISSION_SOUND="${CLAUDE_PERMISSION_SOUND:-$CLAUDE_SOUNDS_DIR/permission/awaiting_orders.mp3}"
export CLAUDE_QUESTION_SOUND="${CLAUDE_QUESTION_SOUND:-$CLAUDE_SOUNDS_DIR/question/whats_the_plan.mp3}"

CLAUDE_WATCHER_PID_FILE="$HOME/.claude_watcher.pid"
CLAUDE_WATCHER_LOCK_DIR="$HOME/.claude_watcher.lock"
CLAUDE_SOUNDS_ENABLED_FILE="$HOME/.claude_sounds_enabled"

# Pick a random sound file from a directory
_claude_random_sound() {
  local dir="$1"
  # Use nullglob so unmatched patterns expand to nothing
  local prev_nullglob
  prev_nullglob=$(shopt -p nullglob)
  shopt -s nullglob
  local files=("$dir"/*.{mp3,wav,m4a,aiff,aac})
  eval "$prev_nullglob"
  if [ ${#files[@]} -eq 0 ]; then
    return 1
  fi
  # Use /dev/urandom for reliable randomness in subshells
  local rand=$(od -An -tu4 -N4 /dev/urandom | tr -d ' ')
  local n=${#files[@]}
  echo "${files[rand % n]}"
}

# Resolve the sound file for an event: use specific file in deterministic mode, random otherwise
_claude_get_sound() {
  local sound_dir="$1"
  local specific_file="$2"

  if [ "$CLAUDE_SOUND_MODE" = "deterministic" ] && [ -n "$specific_file" ] && [ -f "$specific_file" ]; then
    echo "$specific_file"
  else
    _claude_random_sound "$sound_dir"
  fi
}

# Regex matching just the trigger filenames, used to filter fswatch events so a
# busy $CLAUDE_DIR (session logs, project state) does not wake the watcher.
_CLAUDE_TRIGGER_RE='\.claude-(done|start|prompt|compact|permission|question)$'

# Emit one "trigger_file<TAB>sound_dir<TAB>specific_sound" row per event type.
_claude_trigger_table() {
  printf '%s\t%s\t%s\n' "$CLAUDE_DONE_FILE"       "$CLAUDE_DONE_SOUNDS"       "$CLAUDE_DONE_SOUND"
  printf '%s\t%s\t%s\n' "$CLAUDE_START_FILE"      "$CLAUDE_START_SOUNDS"      "$CLAUDE_START_SOUND"
  printf '%s\t%s\t%s\n' "$CLAUDE_PROMPT_FILE"     "$CLAUDE_PROMPT_SOUNDS"     "$CLAUDE_PROMPT_SOUND"
  printf '%s\t%s\t%s\n' "$CLAUDE_PRECOMPACT_FILE" "$CLAUDE_PRECOMPACT_SOUNDS" "$CLAUDE_PRECOMPACT_SOUND"
  printf '%s\t%s\t%s\n' "$CLAUDE_PERMISSION_FILE" "$CLAUDE_PERMISSION_SOUNDS" "$CLAUDE_PERMISSION_SOUND"
  printf '%s\t%s\t%s\n' "$CLAUDE_QUESTION_FILE"   "$CLAUDE_QUESTION_SOUNDS"   "$CLAUDE_QUESTION_SOUND"
}

# Play the sound for every trigger file that currently exists, then clear it.
_claude_dispatch() {
  local trigger sound_dir specific sound_file
  while IFS=$'\t' read -r trigger sound_dir specific; do
    [ -n "$trigger" ] || continue
    [ -f "$trigger" ] || continue
    sound_file=$(_claude_get_sound "$sound_dir" "$specific")
    if [ -n "$sound_file" ] && [ -f "$sound_file" ]; then
      if [ -n "$CLAUDE_SOUND_VOLUME" ]; then
        afplay -v "$CLAUDE_SOUND_VOLUME" "$sound_file" >/dev/null 2>&1 &
      else
        afplay "$sound_file" >/dev/null 2>&1 &
      fi
      disown 2>/dev/null
    fi
    rm -f "$trigger"
  done < <(_claude_trigger_table)
}

# Watch $CLAUDE_DIR for trigger files and play the matching sound.
#
# Deliberately NOT `fswatch ... | while read`: a backgrounded pipeline in a shell
# with no controlling terminal can busy-loop in the shell's job-control code at
# 100% CPU forever once the fswatch writer dies - which is exactly how a watcher
# survived a reboot pinning a core. Reading from a process substitution keeps the
# loop out of any pipeline job, so when fswatch exits `read` simply sees EOF and
# the loop ends.
#
# fswatch also runs continuously here rather than one-shot (`-1`): re-exec'ing it
# per event drops any trigger that lands between one exit and the next start.
# (`-1` is also incompatible with `-o`, which never terminates.)
_claude_watch_loop() {
  local watch_dir="$1" line
  local burst=0 t0=$SECONDS

  # Handle anything that landed before the watcher came up.
  _claude_dispatch

  while IFS= read -r line; do
    _claude_dispatch

    # Safety valve: triggers are written by hooks at human rates. A sustained
    # flood means something is wrong, so stop rather than burn a core.
    if [ $(( SECONDS - t0 )) -ge 1 ]; then
      t0=$SECONDS; burst=0
    else
      burst=$(( burst + 1 ))
      if [ "$burst" -ge 500 ]; then
        printf '%s\n' "claude-sounds: event flood; watcher stopping" >&2
        return 1
      fi
    fi
  done < <(fswatch -E -e '.*' -i "$_CLAUDE_TRIGGER_RE" "$watch_dir" 2>/dev/null)

  printf '%s\n' "claude-sounds: fswatch exited; watcher stopping" >&2
  return 1
}

_claude_validate() {
  # Check fswatch is installed
  if ! command -v fswatch &>/dev/null; then
    echo "claude-sounds: fswatch not installed (brew install fswatch)" >&2
    return 1
  fi

  # Warn about missing sound directories (non-fatal)
  local dirs=("$CLAUDE_DONE_SOUNDS" "$CLAUDE_START_SOUNDS" "$CLAUDE_PROMPT_SOUNDS" "$CLAUDE_PRECOMPACT_SOUNDS" "$CLAUDE_PERMISSION_SOUNDS" "$CLAUDE_QUESTION_SOUNDS")
  local names=("done" "start" "userpromptsubmit" "precompact" "permission" "question")
  local i
  for i in {0..5}; do
    if [ ! -d "${dirs[$i]}" ]; then
      echo "claude-sounds: warning - ${names[$i]} sounds dir not found: ${dirs[$i]}" >&2
    fi
  done

  return 0
}

claude_sound_watcher_start() {
  claude_sound_watcher_status >/dev/null 2>&1 && return 0
  _claude_validate || return 1

  mkdir -p "$CLAUDE_DIR" 2>/dev/null

  # Atomic single-instance guard. `mkdir` succeeds for exactly one racer, so
  # several shells starting at once can no longer each spawn a full watcher set.
  if ! mkdir "$CLAUDE_WATCHER_LOCK_DIR" 2>/dev/null; then
    local owner
    owner=$(cat "$CLAUDE_WATCHER_LOCK_DIR/pid" 2>/dev/null)
    if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
      return 0
    fi
    rm -rf "$CLAUDE_WATCHER_LOCK_DIR" 2>/dev/null
    mkdir "$CLAUDE_WATCHER_LOCK_DIR" 2>/dev/null || return 0
  fi

  # One watcher process for all six triggers (was: six, plus a wrapper).
  # bash 3.2 (the macOS system bash) has no $BASHPID, so the parent records the
  # child's pid; a watcher that dies without cleaning up is reclaimed by the
  # stale-lock check above on the next start.
  ( _claude_watch_loop "$CLAUDE_DIR" ) &
  local wpid=$!
  printf '%s\n' "$wpid" > "$CLAUDE_WATCHER_LOCK_DIR/pid"
  printf '%s\n' "$wpid" > "$CLAUDE_WATCHER_PID_FILE"
  disown 2>/dev/null
  return 0
}

claude_sound_watcher_stop() {
  local pid
  if [ -f "$CLAUDE_WATCHER_LOCK_DIR/pid" ]; then
    pid=$(cat "$CLAUDE_WATCHER_LOCK_DIR/pid" 2>/dev/null)
    [ -n "$pid" ] && { kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null; }
  fi
  if [ -f "$CLAUDE_WATCHER_PID_FILE" ]; then
    pid=$(cat "$CLAUDE_WATCHER_PID_FILE" 2>/dev/null)
    [ -n "$pid" ] && { kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null; }
    rm -f "$CLAUDE_WATCHER_PID_FILE"
  fi
  rm -rf "$CLAUDE_WATCHER_LOCK_DIR" 2>/dev/null
  pkill -f "fswatch.*\.claude-" 2>/dev/null
  return 0
}

claude_sound_watcher_restart() {
  claude_sound_watcher_stop
  # Re-source theme file so switched themes take effect without a new shell
  if [ -f "$CLAUDE_SOUNDS_DIR/.theme" ]; then
    source "$CLAUDE_SOUNDS_DIR/.theme"
  fi
  claude_sound_watcher_start
}

claude_sound_watcher_status() {
  local pid
  pid=$(cat "$CLAUDE_WATCHER_LOCK_DIR/pid" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "claude-sounds: running (PID $pid)"
    return 0
  fi
  echo "claude-sounds: not running"
  return 1
}

claude_sounds_toggle() {
  if claude_sound_watcher_status >/dev/null 2>&1; then
    claude_sound_watcher_stop
    echo "0" > "$CLAUDE_SOUNDS_ENABLED_FILE"
    echo "claude-sounds: OFF"
  else
    claude_sound_watcher_start
    echo "1" > "$CLAUDE_SOUNDS_ENABLED_FILE"
    echo "claude-sounds: ON"
  fi
}

# Short alias for quick toggling
alias cst='claude_sounds_toggle'

# Auto-start only from a real interactive terminal.
#
# Editor/tool probe shells (VS Code, Kiro and friends run `bash -ilc '...; env'`)
# are interactive but have no tty. Starting a background daemon there leaks one
# watcher set per probe that nothing ever reaps - that is how 18 stray fswatch
# processes and a 100%-CPU shell survived across a reboot on the zsh side.
case $- in
  *i*)
    if [ -t 1 ] && [ -z "${CLAUDE_SOUNDS_NO_AUTOSTART:-}" ]; then
      if [ ! -f "$CLAUDE_SOUNDS_ENABLED_FILE" ] || [ "$(cat "$CLAUDE_SOUNDS_ENABLED_FILE")" = "1" ]; then
        claude_sound_watcher_start
      fi
    fi
    ;;
esac
