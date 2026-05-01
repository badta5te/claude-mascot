# Claude Mascot

A tiny native macOS menu-bar app that mirrors what your Claude Code session is doing.

| State | Color | Animation | When |
|---|---|---|---|
| idle | gray | slow blink | between turns / no active session |
| working | green | floats up & down | a turn is in progress |
| attention | orange | fast blink | Claude is blocked on a permission prompt |

If multiple Claude Code sessions are running, the mascot reflects the worst state across all of them (`attention > working > idle`).

Artwork: [`leeorlandi/claude-code-mascot`](https://github.com/leeorlandi/claude-code-mascot) — pixel-art SVG recolored per state and rendered to PNGs.

## Install

Grab the latest release from [Releases](https://github.com/badta5te/claude-mascot/releases/latest), unpack the tarball, drag `ClaudeMascot.app` into `/Applications`, run `xattr -dr com.apple.quarantine /Applications/ClaudeMascot.app`, then launch it. On first launch the app asks to wire up Claude Code hooks — click **Wire up hooks** and you're done. Full step-by-step in `INSTALL.md` inside the tarball.

Updates are drag-and-replace: the app re-syncs hooks from its bundle on every launch, so dropping a new `.app` into `/Applications` is the entire upgrade procedure.

Requirements: macOS 11+ and the Xcode Command Line Tools (`xcode-select --install`). No Homebrew packages.

## Build from source

```sh
./build.sh                          # swiftc + ad-hoc codesign → build/ClaudeMascot.app
open build/ClaudeMascot.app
```

To re-render the PNG frames (only if you tweak colors or the upstream SVGs):

```sh
cd tools && npm install && node render-frames.mjs
```

To rebuild the app icon:

```sh
node tools/render-icon.mjs
```

To produce a release archive (`dist/ClaudeMascot-<version>.tar.gz`):

```sh
./package.sh
```

## How it works

- The app is `LSUIElement` (no Dock icon, no menu bar) — just an `NSStatusItem`.
- A `DispatchSource` watches `~/.claude-helper/sessions/`. Hook scripts atomically write `<session-id>.state` files containing `working` / `attention`, or delete them on `Stop`. The app aggregates worst-state across files (with a 5-min staleness cutoff so orphans from killed sessions self-clear).
- Hook → state-file mapping (set up at first launch by `Installer.swift`):
  - `UserPromptSubmit`, `PreToolUse`, `PostToolUse` → `set-working.sh`
  - `Notification` → `set-attention.sh`
  - `Stop` → `clear.sh`
- Hook scripts ship inside `ClaudeMascot.app/Contents/Resources/hooks/` and are copied to `~/.claude-helper/hooks/` on every launch, so updating the app updates the hooks.

`SubagentStop` is intentionally not wired — the parent session is still in a turn.

## Layout

```
.
├── ClaudeMascot/             Swift sources, Info.plist, PNG/icns resources
├── hooks/                    Hook scripts (set-working / set-attention / clear) — bundled into the .app
├── scripts/uninstall.sh      Power-user rescue uninstall (the in-app menu does the same thing)
├── tools/render-frames.mjs   PNG frame renderer
├── tools/render-icon.mjs     AppIcon.icns builder
├── build.sh                  swiftc → ClaudeMascot.app (universal binary, hooks bundled)
└── package.sh                build + bundle into a release tarball
```

## Uninstall

Click the mascot → **Uninstall Claude Mascot…**, confirm, then drag `/Applications/ClaudeMascot.app` to the Trash.

This removes only Claude Mascot's hook entries from `~/.claude/settings.json` (other entries are kept), deletes `~/.claude-helper/`, and quits the app. Conversation history, caches, project-local `.claude/` dirs, etc. are untouched.

If the app won't launch (e.g. unsigned-build issues), `scripts/uninstall.sh` in this repo does the same thing from the shell.

## Logs

```sh
log stream --predicate 'subsystem == "app.claude-mascot"' --info --debug
```

## Limitations

- No login-item autostart (use `SMAppService` later).
- Just a simple `NSMenu` — no popover with active-session details.
- Ad-hoc signed; not notarized. Recipients clear quarantine with `xattr -dr com.apple.quarantine`.
