# Claude Code Notifications Manager

Use iconic sounds from StarCraft, Warcraft, AoE and more as Claude Code sound cues. Supports **deterministic mode** (one specific sound per event) and **random mode** (random sound from a directory). No server required for basic setup.

## Quick Start (Deterministic Mode - No Server)

Each Claude event plays a specific, thematically chosen StarCraft 2 sound:

| Event | Sound | Unit |
|-------|-------|------|
| **SessionStart** | "Carrier has arrived!" | Carrier |
| **UserPromptSubmit** | "Go go go!" | Marine |
| **Stop** (done) | "Job's finished." | SCV |
| **PreCompact** | "We cannot hold!" | Zealot |
| **PermissionPrompt** | "Awaiting orders." | Raven |
| **Question** | "What's the plan?" | Raynor |

```bash
brew install ffmpeg fswatch

cd claude-code-notif-manager
./scripts/download-deterministic-sounds.sh

# Add to your shell (zsh)
echo 'source /path/to/claude-code-notif-manager/claude-sounds.zsh' >> ~/.zshrc
source ~/.zshrc
```

Then add the following hooks to `~/.claude/settings.json` so Claude Code creates the trigger files that the watcher listens for:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "touch ~/.claude/.claude-start" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "touch ~/.claude/.claude-prompt" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "touch ~/.claude/.claude-done" }] }
    ],
    "PreCompact": [
      { "hooks": [{ "type": "command", "command": "touch ~/.claude/.claude-compact" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "touch ~/.claude/.claude-permission" }] }
    ]
  }
}
```

Restart Claude Code and your terminal. Sounds will play on Claude events.

## Theme Presets

Switch all 6 sounds at once using themed presets from StarCraft II, Warcraft II, and Age of Empires III. Requires `jq` in addition to `ffmpeg`:

```bash
brew install jq ffmpeg fswatch

cd claude-code-notif-manager

# List all available themes
./scripts/download-theme-sounds.sh --list

# Download a theme (downloads 6 sounds + writes ~/.claude/sounds/.theme)
./scripts/download-theme-sounds.sh sc2/protoss
```

Available themes (16 total):

| Game | Themes |
|------|--------|
| StarCraft II | `sc2/protoss`, `sc2/terran`, `sc2/zerg` |
| Warcraft II | `wc2/alliance`, `wc2/horde` |
| Age of Empires III | `aoe3/british`, `aoe3/french`, `aoe3/spanish`, `aoe3/portuguese`, `aoe3/dutch`, `aoe3/germans`, `aoe3/russians`, `aoe3/ottomans` |
| Tech | `tech/minimal`, `tech/retro`, `tech/sci-fi` |

To switch themes, just run the download script again with a different theme name, then `claude_sound_watcher_restart` to pick up the new sounds. Tech themes are generated locally via `ffmpeg` — no downloads needed.

You can also set `CLAUDE_SOUND_THEME` and run the existing download script:

```bash
CLAUDE_SOUND_THEME=wc2/horde ./scripts/download-deterministic-sounds.sh
```

Explicit `CLAUDE_*_SOUND` env vars still override theme sounds.

## Full Setup (Web UI + Random Mode)

For browsing the full catalog of 4,000+ quotes and customizing which sounds play per event:

### Prerequisites

- Node.js 18+
- `ffmpeg` (audio conversion)
- `fswatch` (watcher triggers)

```bash
brew install ffmpeg fswatch
```

### Run the Web UI

```bash
cd claude-code-notif-manager
npm run install:all
npm run dev
```

Open `http://localhost:5173` and use **One-Click Setup** on the landing page. It:

1. Installs Claude hook commands in `~/.claude/settings.json`
2. Syncs default recommended sounds to `~/.claude/sounds`
3. Installs the shell listener script and updates shell config

Restart your terminal after first setup.

### Web UI Features

- Browse quotes from StarCraft II, Warcraft II, and Age of Empires III
- Preview audio inline
- Download individual MP3s or batch ZIP archives
- Save quotes directly to hook folders
- Manage multiple named lists with drag-and-drop reordering
- Import/export list configurations as JSON
- Toggle watcher and system notifications from the UI

## Hook Events and Folders

Claude hooks write trigger files under `~/.claude`, and the watcher plays a sound from the matching folder:

| Hook Event | Trigger File | Sounds Folder |
| --- | --- | --- |
| `SessionStart` | `~/.claude/.claude-start` | `~/.claude/sounds/start` |
| `UserPromptSubmit` | `~/.claude/.claude-prompt` | `~/.claude/sounds/userpromptsubmit` |
| `Stop` | `~/.claude/.claude-done` | `~/.claude/sounds/done` |
| `PreCompact` | `~/.claude/.claude-compact` | `~/.claude/sounds/precompact` |
| `PermissionPrompt` | `~/.claude/.claude-permission` | `~/.claude/sounds/permission` |
| `Question` | `~/.claude/.claude-question` | `~/.claude/sounds/question` |

In **deterministic mode** (default), each event plays its assigned sound file. In **random mode**, a random file is picked from the event's folder.

## Shell Commands

After the listener script is sourced:

```bash
cst                           # Toggle sounds on/off (persists state)
claude_sound_watcher_status   # Show running status
claude_sound_watcher_start    # Start watcher
claude_sound_watcher_stop     # Stop watcher
claude_sound_watcher_restart  # Restart watcher
```

## Configuration

```bash
# Sound mode: "deterministic" (default) or "random"
export CLAUDE_SOUND_MODE=deterministic

# Volume multiplier (0.0 to 1.0)
export CLAUDE_SOUND_VOLUME=0.3

# Sounds root directory
export CLAUDE_SOUNDS_DIR="$HOME/.claude/sounds"

# Override individual event sounds (deterministic mode)
export CLAUDE_START_SOUND="$HOME/.claude/sounds/start/carrier_has_arrived.mp3"
export CLAUDE_DONE_SOUND="$HOME/.claude/sounds/done/jobs_finished.mp3"
export CLAUDE_PROMPT_SOUND="$HOME/.claude/sounds/userpromptsubmit/go_go_go.mp3"
export CLAUDE_PRECOMPACT_SOUND="$HOME/.claude/sounds/precompact/we_cannot_hold.mp3"
export CLAUDE_PERMISSION_SOUND="$HOME/.claude/sounds/permission/awaiting_orders.mp3"
export CLAUDE_QUESTION_SOUND="$HOME/.claude/sounds/question/whats_the_plan.mp3"
```

## Development

```bash
cd claude-code-notif-manager
npm run dev            # frontend + server
npm run dev:frontend   # frontend only (:5173)
npm run dev:server     # server only (:3001)
npm run build          # frontend production build
```

## Tests

```bash
cd claude-code-notif-manager/frontend && npm test
cd claude-code-notif-manager/server && npm test
```

Watch mode:

```bash
cd claude-code-notif-manager/frontend && npm run test:watch
cd claude-code-notif-manager/server && npm run test:watch
```
