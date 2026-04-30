# Claude Mascot

A tiny native macOS menubar app that shows what your Claude Code session is doing.

| State | Trigger | Look |
|---|---|---|
| **idle** | no active turn | gray, slow blink |
| **working** | a turn is in progress (`UserPromptSubmit`/`PreToolUse`/`PostToolUse`) | green, active wave |
| **attention** | Claude is waiting on you (`Notification`) | orange, urgent wave |

If multiple Claude Code sessions are running, the mascot reflects the worst state across all of them (`attention > working > idle`).

The artwork is the [`leeorlandi/claude-code-mascot`](https://github.com/leeorlandi/claude-code-mascot) pixel-art SVG, recolored per state and rendered to PNGs.

## Layout

```
.
├── ClaudeMascot/         # Swift sources, Info.plist, PNG resources
├── hooks/                # Claude Code hook scripts
├── scripts/install.sh    # installs hooks + merges ~/.claude/settings.json
├── tools/render-frames.mjs  # one-time PNG renderer (Node)
└── build.sh              # swiftc → ClaudeMascot.app
```

## Build

Requires Xcode command-line tools (`xcrun swiftc`, `codesign`).

```sh
./build.sh
open build/ClaudeMascot.app
```

The app uses `LSUIElement = YES` (no Dock icon, no menu bar). Click the mascot in the status bar for the menu.

To re-render the PNG frames (only needed if you change colors or the upstream SVGs):

```sh
cd tools && npm install && node render-frames.mjs
```

## Install hooks

```sh
./scripts/install.sh
```

This:

1. Copies `hooks/*.sh` into `~/.claude-helper/hooks/`.
2. Backs up `~/.claude/settings.json` to `settings.json.bak.<timestamp>`.
3. Adds (idempotently) one hook entry per event:
   - `UserPromptSubmit`, `PreToolUse`, `PostToolUse` → `set-working.sh`
   - `Notification` → `set-attention.sh`
   - `Stop` → `clear.sh`

`SubagentStop` is **not** wired — the parent session is still in a turn.

State is communicated via files in `~/.claude-helper/sessions/<session-id>.state`. Each hook does an atomic `mktemp` + `mv`; the app watches the directory with a `DispatchSource`.

## Uninstall

```sh
# Remove hooks from settings.json
mv ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
# Remove helper dir
rm -rf ~/.claude-helper
# Quit the app via the menubar, or:
pkill -x ClaudeMascot
```

## Limitations / not yet shipped

- No login-item autostart (use `SMAppService` later).
- No popover with active-session details — just a simple menu.
- Notarization / distribution is out of scope; the build is ad-hoc signed for local use.
