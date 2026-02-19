# Game Sounds Browser

Browse unit quotes from StarCraft II, Warcraft II, and Age of Empires III, then map them to Claude Code hook events and sync them into `~/.claude/sounds`.

## Deterministic Sound Mode

By default, each Claude event plays a specific, thematically chosen StarCraft 2 sound instead of a random one from a directory:

| Event | Sound | Unit |
|-------|-------|------|
| **SessionStart** | "Carrier has arrived!" | Carrier |
| **UserPromptSubmit** | "Go go go!" | Marine |
| **Stop** (done) | "Job's finished." | SCV |
| **PreCompact** | "We cannot hold!" | Zealot |
| **PermissionPrompt** | "Awaiting orders." | Raven |
| **Question** | "What's the plan?" | Raynor |

### Quick setup (no server needed)

```bash
brew install ffmpeg fswatch

# Download the 6 sounds
./scripts/download-deterministic-sounds.sh

# Add to your shell config
echo 'source /path/to/claude-sounds.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Configuration

Deterministic mode is the default. Override individual sounds or switch back to random:

```bash
# Switch to random mode (original behavior)
export CLAUDE_SOUND_MODE=random

# Override a specific event sound
export CLAUDE_START_SOUND="$HOME/.claude/sounds/start/my_custom_sound.mp3"

# Adjust volume (0.0-1.0)
export CLAUDE_SOUND_VOLUME=0.5
```

### Shell commands

- `cst` - Toggle sounds on/off
- `claude_sound_watcher_status` - Show watcher status
- `claude_sound_watcher_restart` - Restart the watcher

---

## Web UI (Optional)

The web UI lets you browse the full catalog of 4,000+ quotes across StarCraft II, Warcraft II, and Age of Empires III, preview sounds, and drag-and-drop them into hook categories. It is **not required** for the deterministic sound setup above.

## Tech Stack

- Frontend: React 19 + Vite + Tailwind + `@dnd-kit`
- Backend: Express + `fluent-ffmpeg` + `archiver`
- Scrapers: Node + Cheerio

## Prerequisites

- Node.js 18+
- `ffmpeg` for OGG->MP3 conversion
- `fswatch` for the shell listener scripts

```bash
# macOS
brew install ffmpeg fswatch
```

## Install and Run

```bash
npm run install:all
npm run dev
```

- Frontend: `http://localhost:5173`
- Backend API: `http://localhost:3001`

## Frontend Capabilities

- Game switcher with lazy-loaded datasets (`sc2`, `wc2`, `aoe3`)
- Unit/category browsing and quote search
- Inline quote preview via `/api/audio`
- Single MP3 download via `/api/download`
- Multi-select action bar for:
  - ZIP batch download via `/api/download-batch`
  - Save selected quotes to one hook folder via `/api/save-to-sounds`
- Recommended view with:
  - Multiple named lists
  - Drag-and-drop hook ordering
  - Move recommendations between hooks
  - Import/export JSON (`{ "hooks": [...] }`)
  - Full sync to Claude sounds via `/api/save-to-sounds-all`
- Landing page controls for:
  - One-click setup (`setup-hooks`, `save-to-sounds-all`, `setup-listener`)
  - Watcher toggle
  - Claude system notification toggles

## Backend API Summary

- `GET /api/health`
- `GET /api/audio`
- `GET /api/download`
- `POST /api/download-batch`
- `POST /api/save-to-sounds`
- `POST /api/save-to-sounds-all`
- `GET /api/sounds-info`
- `GET /api/hooks-status`
- `POST /api/setup-hooks`
- `GET /api/listener-status`
- `POST /api/setup-listener`
- `GET /api/notification-status`
- `POST /api/toggle-notifications`
- `GET /api/system-notification-hooks-status`
- `POST /api/toggle-system-notification-hook`
- `POST /api/toggle-sounds`

## Dev Scripts

```bash
npm run dev            # frontend + server
npm run dev:frontend   # frontend only
npm run dev:server     # server only
npm run build          # frontend build
npm run scrape         # refresh all game JSON datasets
```

Scraper output is written to `frontend/src/data/games/*.json`.

## Tests

```bash
cd frontend && npm test
cd server && npm test
```

Watch mode:

```bash
cd frontend && npm run test:watch
cd server && npm run test:watch
```
