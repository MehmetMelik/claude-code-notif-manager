#!/bin/bash
# Generates tech-themed notification sounds using ffmpeg synthesis.
# No external downloads — all audio is created locally via ffmpeg.
#
# Usage:
#   ./scripts/generate-tech-sounds.sh tech/minimal
#   ./scripts/generate-tech-sounds.sh tech/retro
#   ./scripts/generate-tech-sounds.sh tech/sci-fi

set -eo pipefail

SOUNDS_DIR="${CLAUDE_SOUNDS_DIR:-$HOME/.claude/sounds}"
THEME_FILE="$SOUNDS_DIR/.theme"
TMP=$(mktemp -d /tmp/techsounds_XXXXXX)
trap 'rm -rf "$TMP"' EXIT

# Note frequencies (Hz)
C5=523.25  D5=587.33  E5=659.25
F5=698.46  G5=783.99  A5=880.00  C6=1046.50

# ---- synthesis primitives ------------------------------------------------

# Sine-wave note -> prints wav path
gen_sine() {
  local freq=$1 dur=$2 vol=${3:-0.6}
  local out; out=$(mktemp "$TMP/s_XXXXXX")
  local fo; fo=$(awk "BEGIN{printf \"%.4f\",$dur-0.02}")
  ffmpeg -y -f lavfi -i "sine=f=${freq}:d=${dur}" \
    -af "volume=${vol},afade=t=in:d=0.008,afade=t=out:st=${fo}:d=0.02" \
    -f wav -acodec pcm_s16le -ar 44100 -ac 1 -loglevel error "$out"
  echo "$out"
}

# Square-wave note -> prints wav path
gen_square() {
  local freq=$1 dur=$2 vol=${3:-0.3}
  local out; out=$(mktemp "$TMP/q_XXXXXX")
  local fo; fo=$(awk "BEGIN{printf \"%.4f\",$dur-0.01}")
  ffmpeg -y -f lavfi \
    -i "aevalsrc=${vol}*sgn(sin(2*PI*${freq}*t)):d=${dur}:s=44100:c=mono" \
    -af "afade=t=in:d=0.003,afade=t=out:st=${fo}:d=0.01" \
    -f wav -acodec pcm_s16le -ar 44100 -ac 1 -loglevel error "$out"
  echo "$out"
}

# Silence -> prints wav path
gen_silence() {
  local dur=$1
  local out; out=$(mktemp "$TMP/z_XXXXXX")
  ffmpeg -y -f lavfi -i "anullsrc=r=44100:cl=mono" -t "$dur" \
    -f wav -acodec pcm_s16le -ar 44100 -ac 1 -loglevel error "$out"
  echo "$out"
}

# Linear frequency sweep (sine) -> prints wav path
gen_sweep() {
  local f1=$1 f2=$2 dur=$3 vol=${4:-0.5}
  local out; out=$(mktemp "$TMP/w_XXXXXX")
  local hr; hr=$(awk "BEGIN{printf \"%.4f\",($f2-$f1)/(2*$dur)}")
  local fo; fo=$(awk "BEGIN{printf \"%.4f\",$dur-0.04}")
  ffmpeg -y -f lavfi \
    -i "aevalsrc=${vol}*sin(2*PI*(${f1}*t+${hr}*t*t)):d=${dur}:s=44100:c=mono" \
    -af "afade=t=in:d=0.01,afade=t=out:st=${fo}:d=0.04" \
    -f wav -acodec pcm_s16le -ar 44100 -ac 1 -loglevel error "$out"
  echo "$out"
}

# Arbitrary aevalsrc expression -> prints wav path
gen_expr() {
  local expr=$1 dur=$2
  local out; out=$(mktemp "$TMP/e_XXXXXX")
  local fo; fo=$(awk "BEGIN{printf \"%.4f\",$dur-0.04}")
  ffmpeg -y -f lavfi \
    -i "aevalsrc=${expr}:d=${dur}:s=44100:c=mono" \
    -af "afade=t=in:d=0.01,afade=t=out:st=${fo}:d=0.04" \
    -f wav -acodec pcm_s16le -ar 44100 -ac 1 -loglevel error "$out"
  echo "$out"
}

# Concatenate wavs -> mp3
concat_mp3() {
  local out=$1; shift
  if [ $# -eq 1 ]; then
    ffmpeg -y -i "$1" -ab 192k -loglevel error "$out"; return
  fi
  local list; list=$(mktemp "$TMP/c_XXXXXX")
  for f in "$@"; do echo "file '$f'" >> "$list"; done
  ffmpeg -y -f concat -safe 0 -i "$list" -ab 192k -loglevel error "$out"
}

# Overlay/mix wavs -> mp3
mix_mp3() {
  local out=$1; shift
  local inputs=() filter="" i=0
  for f in "$@"; do inputs+=(-i "$f"); filter+="[${i}:a]"; i=$((i+1)); done
  filter+="amix=inputs=${i}:duration=longest:normalize=0"
  ffmpeg -y "${inputs[@]}" -filter_complex "$filter" -ab 192k -loglevel error "$out"
}

# ---- per-event helper ----------------------------------------------------

# emit <event> <filename> <label>  — sets OUTFILE; returns 1 to skip
emit() {
  local event=$1 fn=$2 label=$3
  OUTFILE="$SOUNDS_DIR/$event/$fn"
  mkdir -p "$SOUNDS_DIR/$event"
  if [ -f "$OUTFILE" ]; then
    echo "  [skip] $event/$fn - $label (already exists)"
    return 1
  fi
  echo "  [generate] $event/$fn - $label"
  return 0
}

ok() { echo "  [ok] $(basename "$(dirname "$OUTFILE")")/$(basename "$OUTFILE")"; }

# ===========================================================================
#  tech/minimal — Clean sine-wave pings
# ===========================================================================
generate_minimal() {
  if emit start ascending_ping.mp3 "Ascending 3-note ping"; then
    concat_mp3 "$OUTFILE" \
      "$(gen_sine $C5 0.15)" "$(gen_silence 0.05)" \
      "$(gen_sine $E5 0.15)" "$(gen_silence 0.05)" \
      "$(gen_sine $G5 0.25)"
    ok
  fi

  if emit userpromptsubmit confirm_ping.mp3 "Confirmation ping"; then
    concat_mp3 "$OUTFILE" "$(gen_sine $E5 0.2)"
    ok
  fi

  if emit done descending_chime.mp3 "Descending 3-note chime"; then
    concat_mp3 "$OUTFILE" \
      "$(gen_sine $G5 0.15)" "$(gen_silence 0.05)" \
      "$(gen_sine $E5 0.15)" "$(gen_silence 0.05)" \
      "$(gen_sine $C5 0.25)"
    ok
  fi

  if emit precompact warning_beep.mp3 "Warning double-beep"; then
    concat_mp3 "$OUTFILE" \
      "$(gen_sine $A5 0.1 0.65)" "$(gen_silence 0.08)" \
      "$(gen_sine $A5 0.1 0.65)"
    ok
  fi

  if emit permission attention_bell.mp3 "Attention bell tone"; then
    concat_mp3 "$OUTFILE" "$(gen_sine $A5 0.4 0.55)"
    ok
  fi

  if emit question rising_sweep.mp3 "Rising sweep"; then
    concat_mp3 "$OUTFILE" "$(gen_sweep $C5 $C6 0.4)"
    ok
  fi
}

# ===========================================================================
#  tech/retro — Square-wave 8-bit beeps
# ===========================================================================
generate_retro() {
  if emit start powerup_arpeggio.mp3 "8-bit power-up arpeggio"; then
    local gap; gap=$(gen_silence 0.02)
    concat_mp3 "$OUTFILE" \
      "$(gen_square $C5 0.08)" "$gap" \
      "$(gen_square $E5 0.08)" "$gap" \
      "$(gen_square $G5 0.08)" "$gap" \
      "$(gen_square $C6 0.12)"
    ok
  fi

  if emit userpromptsubmit square_blip.mp3 "Short square blip"; then
    concat_mp3 "$OUTFILE" "$(gen_square $E5 0.08)"
    ok
  fi

  if emit done victory_jingle.mp3 "8-bit victory jingle"; then
    local gap; gap=$(gen_silence 0.02)
    concat_mp3 "$OUTFILE" \
      "$(gen_square $C6 0.08)" "$gap" \
      "$(gen_square $G5 0.08)" "$gap" \
      "$(gen_square $E5 0.08)" "$gap" \
      "$(gen_square $C5 0.12)"
    ok
  fi

  if emit precompact twotone_alarm.mp3 "Two-tone alarm"; then
    local gap; gap=$(gen_silence 0.04)
    concat_mp3 "$OUTFILE" \
      "$(gen_square $A5 0.08 0.35)" "$gap" \
      "$(gen_square $F5 0.08 0.35)" "$gap" \
      "$(gen_square $A5 0.08 0.35)" "$gap" \
      "$(gen_square $F5 0.08 0.35)"
    ok
  fi

  if emit permission menu_select.mp3 "Menu select beep"; then
    local gap; gap=$(gen_silence 0.02)
    concat_mp3 "$OUTFILE" \
      "$(gen_square $G5 0.06)" "$gap" \
      "$(gen_square $C6 0.08)"
    ok
  fi

  if emit question rising_boop.mp3 "Rising 8-bit boop"; then
    local gap; gap=$(gen_silence 0.01)
    concat_mp3 "$OUTFILE" \
      "$(gen_square $C5 0.06)" "$gap" \
      "$(gen_square $D5 0.06)" "$gap" \
      "$(gen_square $E5 0.06)" "$gap" \
      "$(gen_square $G5 0.06)" "$gap" \
      "$(gen_square $C6 0.08)"
    ok
  fi
}

# ===========================================================================
#  tech/sci-fi — Layered synth tones
# ===========================================================================
generate_scifi() {
  if emit start boot_sweep.mp3 "Synth boot sweep"; then
    mix_mp3 "$OUTFILE" \
      "$(gen_sweep 220 880 0.6 0.4)" \
      "$(gen_sweep 440 1760 0.6 0.2)"
    ok
  fi

  if emit userpromptsubmit confirm_blip.mp3 "Futuristic confirm blip"; then
    mix_mp3 "$OUTFILE" \
      "$(gen_sine $E5 0.15 0.4)" \
      "$(gen_sine $C6 0.15 0.25)"
    ok
  fi

  if emit done synth_resolution.mp3 "Descending synth resolution"; then
    mix_mp3 "$OUTFILE" \
      "$(gen_sweep 880 220 0.6 0.4)" \
      "$(gen_sweep 1760 440 0.6 0.2)"
    ok
  fi

  if emit precompact pulse_alert.mp3 "Pulsing alert tone"; then
    concat_mp3 "$OUTFILE" \
      "$(gen_expr '0.5*sin(2*PI*880*t)*(0.5+0.5*sin(2*PI*8*t))' 0.6)"
    ok
  fi

  if emit permission repeating_ping.mp3 "Soft repeating ping"; then
    local gap; gap=$(gen_silence 0.1)
    concat_mp3 "$OUTFILE" \
      "$(gen_sine $E5 0.12 0.5)" "$gap" \
      "$(gen_sine $E5 0.12 0.35)" "$gap" \
      "$(gen_sine $E5 0.12 0.2)"
    ok
  fi

  if emit question vibrato_rise.mp3 "Rising synth with vibrato"; then
    concat_mp3 "$OUTFILE" \
      "$(gen_expr '0.5*sin(2*PI*(523*t+523*t*t)+3*sin(2*PI*6*t))' 0.5)"
    ok
  fi
}

# ---- .theme file writer ---------------------------------------------------

write_theme_file() {
  local theme=$1
  local events=(start userpromptsubmit done precompact permission question)
  local vars=(CLAUDE_START_SOUND CLAUDE_PROMPT_SOUND CLAUDE_DONE_SOUND
              CLAUDE_PRECOMPACT_SOUND CLAUDE_PERMISSION_SOUND CLAUDE_QUESTION_SOUND)
  local filenames

  case "$theme" in
    tech/minimal) filenames=(ascending_ping.mp3 confirm_ping.mp3 descending_chime.mp3
                             warning_beep.mp3 attention_bell.mp3 rising_sweep.mp3) ;;
    tech/retro)   filenames=(powerup_arpeggio.mp3 square_blip.mp3 victory_jingle.mp3
                             twotone_alarm.mp3 menu_select.mp3 rising_boop.mp3) ;;
    tech/sci-fi)  filenames=(boot_sweep.mp3 confirm_blip.mp3 synth_resolution.mp3
                             pulse_alert.mp3 repeating_ping.mp3 vibrato_rise.mp3) ;;
  esac

  {
    echo "# Auto-generated by generate-tech-sounds.sh — do not edit"
    echo "# Theme: $theme"
    echo "CLAUDE_SOUND_THEME_NAME=\"$theme\""
    for i in "${!events[@]}"; do
      echo "export ${vars[$i]}=\"$SOUNDS_DIR/${events[$i]}/${filenames[$i]}\""
    done
  } > "$THEME_FILE"

  echo ""
  echo "Theme file written to $THEME_FILE"
}

# ---- main -----------------------------------------------------------------

if [ $# -eq 0 ]; then
  echo "Usage: $(basename "$0") <tech/minimal|tech/retro|tech/sci-fi>"
  exit 1
fi

THEME="$1"

if ! command -v ffmpeg &>/dev/null; then
  echo "Error: ffmpeg is required. Install with: brew install ffmpeg" >&2
  exit 1
fi

case "$THEME" in
  tech/minimal) label="Minimal — clean sine-wave pings" ;;
  tech/retro)   label="Retro — square-wave 8-bit beeps" ;;
  tech/sci-fi)  label="Sci-Fi — layered synth tones" ;;
  *)
    echo "Error: unknown tech theme '$THEME'" >&2
    echo "Valid themes: tech/minimal  tech/retro  tech/sci-fi" >&2
    exit 1
    ;;
esac

echo "Generating $THEME sounds ($label)..."
echo ""

case "$THEME" in
  tech/minimal) generate_minimal ;;
  tech/retro)   generate_retro ;;
  tech/sci-fi)  generate_scifi ;;
esac

write_theme_file "$THEME"

echo ""
echo "Done! Theme '$THEME' is ready."
echo "Restart your shell or run: source claude-sounds.zsh"
