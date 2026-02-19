#!/bin/bash
# Downloads the 6 specific StarCraft 2 sounds for deterministic Claude event notifications.
# Requires: ffmpeg (brew install ffmpeg)
#
# Sound mapping:
#   SessionStart     -> "Carrier has arrived!" (Carrier)
#   UserPromptSubmit -> "Go go go!" (Marine)
#   Stop (done)      -> "Job's finished." (SCV)
#   PreCompact       -> "We cannot hold!" (Zealot)
#   PermissionPrompt -> "Awaiting orders." (Raven)
#   Question         -> "What's the plan?" (Raynor)

set -eo pipefail

# Delegate to theme downloader if CLAUDE_SOUND_THEME is set
if [ -n "${CLAUDE_SOUND_THEME:-}" ]; then
  exec "$(dirname "$0")/download-theme-sounds.sh" "$CLAUDE_SOUND_THEME"
fi

SOUNDS_DIR="${CLAUDE_SOUNDS_DIR:-$HOME/.claude/sounds}"

if ! command -v ffmpeg &>/dev/null; then
  echo "Error: ffmpeg is required. Install with: brew install ffmpeg" >&2
  exit 1
fi

download_sound() {
  local folder="$1" filename="$2" url="$3" label="$4"
  local dir="$SOUNDS_DIR/$folder"
  local output="$dir/${filename}.mp3"

  mkdir -p "$dir"

  if [ -f "$output" ]; then
    echo "  [skip] $folder/${filename}.mp3 - $label (already exists)"
    return 0
  fi

  echo "  [download] $folder/${filename}.mp3 - $label"
  local tmp
  tmp=$(mktemp /tmp/sc2_sound_XXXXXX.ogg)

  if curl -sL -o "$tmp" "$url" && [ -s "$tmp" ]; then
    ffmpeg -y -i "$tmp" -ab 192k -loglevel error "$output"
    rm -f "$tmp"
    echo "  [ok] $folder/${filename}.mp3"
  else
    echo "  [error] Failed to download $filename" >&2
    rm -f "$tmp"
    return 1
  fi
}

echo "Downloading StarCraft 2 sounds to $SOUNDS_DIR..."
echo ""

download_sound "start" "carrier_has_arrived" \
  "https://static.wikia.nocookie.net/starcraft/images/3/32/Carrier_Ready00.ogg/revision/latest?cb=20211013142125" \
  "Carrier has arrived!"

download_sound "userpromptsubmit" "go_go_go" \
  "https://static.wikia.nocookie.net/starcraft/images/e/ea/Marine_Yes04.ogg/revision/latest?cb=20211007134742" \
  "Go go go!"

download_sound "done" "jobs_finished" \
  "https://static.wikia.nocookie.net/starcraft/images/8/80/SCV_JobsFinished00.ogg/revision/latest?cb=20211007203851" \
  "Job's finished."

download_sound "precompact" "we_cannot_hold" \
  "https://static.wikia.nocookie.net/starcraft/images/5/56/Zealot_Help00.ogg/revision/latest?cb=20211026184128" \
  "We cannot hold!"

download_sound "permission" "awaiting_orders" \
  "https://static.wikia.nocookie.net/starcraft/images/1/18/Raven_What03.ogg/revision/latest?cb=20211007173921" \
  "Awaiting orders."

download_sound "question" "whats_the_plan" \
  "https://static.wikia.nocookie.net/starcraft/images/c/c8/Raynor_What02.ogg/revision/latest?cb=20211011143222" \
  "What's the plan?"

echo ""
echo "Done! Sound files are in $SOUNDS_DIR"
echo ""
echo "Sound mapping:"
echo "  SessionStart     -> start/carrier_has_arrived.mp3     (\"Carrier has arrived!\")"
echo "  UserPromptSubmit -> userpromptsubmit/go_go_go.mp3     (\"Go go go!\")"
echo "  Stop             -> done/jobs_finished.mp3            (\"Job's finished.\")"
echo "  PreCompact       -> precompact/we_cannot_hold.mp3     (\"We cannot hold!\")"
echo "  Permission       -> permission/awaiting_orders.mp3    (\"Awaiting orders.\")"
echo "  Question         -> question/whats_the_plan.mp3       (\"What's the plan?\")"
