# Installing Claude Mascot

## Requirements

- macOS 11 (Big Sur) or later
- [Claude Code](https://claude.com/claude-code) already installed and used at least once (so `~/.claude/` exists)

No additional packages — the installer and hook scripts only use tools that ship with macOS (`/bin/sh`, `python3` via Xcode Command Line Tools, `sed`).

## Install (5 steps)

1. **Download** `ClaudeMascot-<version>.tar.gz` from the release page and unpack it (double-click or `tar -xzf`).
2. **Move the app** — drag `ClaudeMascot.app` into `/Applications`.
3. **Clear the Gatekeeper quarantine** (the build is ad-hoc signed, not notarized — macOS will otherwise refuse to launch it):
   ```sh
   xattr -dr com.apple.quarantine /Applications/ClaudeMascot.app
   ```
4. **Launch** — open `ClaudeMascot.app` from `/Applications`. A small mascot appears in your menu bar (gray = idle).
5. **Wire up the Claude Code hooks** — from the unpacked folder:
   ```sh
   ./scripts/install.sh
   ```
   This copies the hook scripts to `~/.claude-helper/hooks/` and adds entries to `~/.claude/settings.json` (a backup is written to `settings.json.bak.<timestamp>`).

Then **restart any open Claude Code sessions** so they pick up the new hooks. New sessions get them automatically.

## What you should see

| State | Color | Animation | When |
|---|---|---|---|
| idle | gray | slow blink | between turns / no active session |
| working | green | floats up & down | a turn is in progress |
| attention | orange | fast blink | Claude is blocked on a permission prompt |

Click the mascot for a small menu (status, open `~/.claude-helper`, quit).

## Updating

Re-run steps 1–3 with the new release. Hooks already installed don't need re-installing unless the script paths change.

## Uninstalling

From the unpacked release folder:

```sh
./scripts/uninstall.sh
```

This is **surgical**: it removes only Claude Mascot's hook entries from `~/.claude/settings.json` (any other hooks or settings you added are kept), deletes `~/.claude-helper/`, and removes `/Applications/ClaudeMascot.app`. Your Claude Code conversation history, file history, caches, and project-local `.claude/` dirs are not touched.

## Troubleshooting

- **App won't open ("damaged" or "cannot verify developer")** — you skipped step 3. Run the `xattr` command and try again.
- **Mascot stays gray during a turn** — that session was running before `install.sh`. Quit and restart Claude Code.
- **`install.sh` errors that `python3` is missing** — run `xcode-select --install` to get the Xcode Command Line Tools.
