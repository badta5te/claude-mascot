# Claude Mascot

A tiny native macOS menu-bar app that mirrors what your Claude Code session is doing.

| State | Color | Animation | When |
|---|---|---|---|
| idle | gray | slow blink | between turns / no active session |
| working | green | floats up & down | a turn is in progress |
| attention | orange | fast blink | Claude is blocked on a permission prompt |

If multiple Claude Code sessions are running, the mascot reflects the worst state across all of them (`attention > working > idle`).

## Install

Grab the latest release from [Releases](https://github.com/badta5te/claude-mascot/releases/latest), drag `ClaudeMascot.app` to `/Applications`, run `xattr -dr com.apple.quarantine /Applications/ClaudeMascot.app`, and launch it. Click **Wire up hooks** in the first-launch alert. That's it — updates are drag-and-replace.

## Uninstall

Click the mascot → **Uninstall Claude Mascot…**, confirm, then drag the app to the Trash. This removes only Claude Mascot's hook entries from `~/.claude/settings.json`; everything else is left alone.

## How it works

The app is `LSUIElement` (menu-bar only). Hook scripts shipped inside the `.app` write `<session-id>.state` files into `~/.claude-helper/sessions/`; a `DispatchSource` on that directory wakes the app, which aggregates worst-state across files and animates an `NSStatusItem`. A 5-minute staleness cutoff and 30s periodic re-scan handle orphans from killed sessions.

`SubagentStop` is intentionally not wired — the parent session is still in a turn.

## Build from source

```sh
./build.sh        # universal binary, ad-hoc signed → build/ClaudeMascot.app
./package.sh      # → dist/ClaudeMascot-<version>.tar.gz
```

Artwork comes from [`leeorlandi/claude-code-mascot`](https://github.com/leeorlandi/claude-code-mascot); regenerate the PNGs via `tools/render-frames.mjs` if you tweak colors.

## Logs

```sh
log stream --predicate 'subsystem == "app.claude-mascot"' --info --debug
```

## Limitations

- No login-item autostart yet.
- Ad-hoc signed; not notarized — first launch requires the `xattr` step above.
