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

Grab the latest release from [Releases](https://github.com/badta5te/claude-mascot/releases/latest), then follow `INSTALL.md` inside the tarball. The first install runs a one-time `scripts/install.sh` to wire up Claude Code hooks; **for subsequent updates you just replace `ClaudeMascot.app` in `/Applications` — the hooks stay where they are.**

Requirements: macOS 11+ and the Xcode Command Line Tools (`xcode-select --install`). No Homebrew packages.

## Updating

```sh
# Download the new release tarball, unpack, then:
pkill -x ClaudeMascot                                   # stop the running copy
xattr -dr com.apple.quarantine ClaudeMascot.app          # clear Gatekeeper flag
mv ClaudeMascot.app /Applications/                       # overwrite
open /Applications/ClaudeMascot.app
```

The hooks in `~/.claude-helper/hooks/` are unchanged across most releases. If a release's notes mention a hook change, re-run `./scripts/install.sh` from the new tarball; it's idempotent.

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
- A `DispatchSource` watches `~/.claude-helper/sessions/`. Hook scripts atomically write `<session-id>.state` files containing `working` / `attention`, or delete them on `Stop`. The app aggregates worst-state across files.
- Hook → state-file mapping (set up by `scripts/install.sh`):
  - `UserPromptSubmit`, `PreToolUse`, `PostToolUse` → `set-working.sh`
  - `Notification` → `set-attention.sh`
  - `Stop` → `clear.sh`

`SubagentStop` is intentionally not wired — the parent session is still in a turn.

## Layout

```
.
├── ClaudeMascot/             Swift sources, Info.plist, PNG/icns resources
├── hooks/                    Claude Code hook scripts (set-working / set-attention / clear)
├── scripts/install.sh        First-time hook installer (merges ~/.claude/settings.json)
├── tools/render-frames.mjs   PNG frame renderer
├── tools/render-icon.mjs     AppIcon.icns builder
├── build.sh                  swiftc → ClaudeMascot.app
├── package.sh                build + bundle into a release tarball
└── INSTALL.md                end-user install guide (shipped inside the tarball)
```

## Uninstall

```sh
pkill -x ClaudeMascot
ls ~/.claude/settings.json.bak.*                              # find the most-recent backup
mv ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
rm -rf ~/.claude-helper
rm -rf /Applications/ClaudeMascot.app
```

## Limitations

- No login-item autostart (use `SMAppService` later).
- Just a simple `NSMenu` — no popover with active-session details.
- Ad-hoc signed; not notarized. Recipients clear quarantine with `xattr -dr com.apple.quarantine`.
