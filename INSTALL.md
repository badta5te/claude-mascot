# Installing Claude Mascot

## Requirements

- macOS 11 (Big Sur) or later
- [Claude Code](https://claude.com/claude-code) already installed and used at least once

## Install (3 steps)

1. **Download** `ClaudeMascot-<version>.tar.gz` from the release page and unpack it (double-click or `tar -xzf`).
2. **Drag** `ClaudeMascot.app` into `/Applications`, then run:
   ```sh
   xattr -dr com.apple.quarantine /Applications/ClaudeMascot.app
   ```
   (The build is ad-hoc signed, not notarized — without this Gatekeeper refuses to launch it.)
3. **Launch** `ClaudeMascot.app`. On first launch you'll see an alert asking to wire up Claude Code hooks — click **Wire up hooks**. The app copies hook scripts to `~/.claude-helper/hooks/` and merges entries into `~/.claude/settings.json` (a timestamped backup is saved alongside it).

Then **restart any open Claude Code sessions** so they pick up the new hooks. New sessions get them automatically.

## What you should see

| State | Color | Animation | When |
|---|---|---|---|
| idle | gray | slow blink | between turns / no active session |
| working | green | floats up & down | a turn is in progress |
| attention | orange | fast blink | Claude is blocked on a permission prompt |

Click the mascot for the menu (status, open `~/.claude-helper`, wire up hooks, uninstall, quit).

## Updating

Drop the new `ClaudeMascot.app` into `/Applications`, replacing the old one. The app re-syncs hook scripts automatically on every launch — no extra steps.

```sh
pkill -x ClaudeMascot
xattr -dr com.apple.quarantine /Applications/ClaudeMascot.app
mv ClaudeMascot.app /Applications/
open /Applications/ClaudeMascot.app
```

## Uninstalling

Click the mascot → **Uninstall Claude Mascot…**, confirm, then drag `/Applications/ClaudeMascot.app` to the Trash.

This removes only Claude Mascot's hook entries from `~/.claude/settings.json` (other hooks are kept), deletes `~/.claude-helper/`, and quits the app. Conversation history, file history, caches, and project-local `.claude/` dirs are not touched.

## Troubleshooting

- **App won't open ("damaged" or "cannot verify developer")** — you skipped the `xattr` step. Run it and try again.
- **Mascot stays gray during a turn** — that session was running before you wired up hooks. Quit and restart Claude Code.
- **You declined the first-launch alert** — click the menu bar icon and pick **Wire up Claude Code hooks…**.
