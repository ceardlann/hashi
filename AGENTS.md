# AGENTS.md — Hashi 橋 (phone launcher)

## What this is
Tools for using apps from Joe's Pixel phone on his Windows PC via scrcpy + adb (wireless debugging).
`droid <app>` opens one phone app in its own resizable PC window on a virtual display; `phone` is an
arrow-key terminal launcher (recent / top / categories / bookmarks) built on an app database read from
the phone. README.md is the user guide — read it first; it describes every script and data file.

Goal now: publish it as a GitHub repo that installs cleanly on another Windows PC (and for a friend),
then a minimal Fedora/bash version.

## Environment
- Windows 11, PowerShell 7 + cmd `.bat` wrappers. Fedora (bash) is a later, secondary target.
- scrcpy v5.0.1 win64 (bundles adb) lives in `scrcpy\` — third-party binaries, NOT committed to git.
- Phone: Android, wireless debugging (adb over TCP). Pairing via `pair.bat`, reconnect via `connect.bat`.
- Run: `phone` (launcher), `droid <name>`, `mirror`, `pick`, `apps`.
- Test: mostly manual — needs the phone connected and unlocked. Static checks an agent CAN run:
  - PowerShell parse check: `pwsh -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('<file>.ps1',[ref]$null,[ref]$e); if($e){$e; exit 1}"`
  - `git status` / `git diff --stat` to confirm only listed files changed.

## Layout
- `phone.ps1` (+ `phone.bat`) — the launcher TUI (~440 lines)
- `appdb.ps1` (+ `appdb-refresh.bat`) — builds `appdb.csv` from the phone (packages, usage stats)
- `droid.bat`, `resolve-app.ps1`, `aliases.txt` — open one app in its own window; name → package resolution
- `pick.bat`/`pick` and `apps.bat`/`applist.ps1` — older picker and app listing
- `connect.bat`, `pair.bat`, `mirror.bat`, `phone-shell.bat`, `add-to-path.bat`, `make-shortcut.bat`
- `diag.ps1`, `diag-usage.ps1` — capture raw phone output into `diag\` for troubleshooting
- Personal data (git-ignored): `appdb.csv`, `launch-log.csv`, `apps-cache.txt`, `last-phone.txt`,
  `aliases.txt`, `bookmarks.csv`, `categories.csv`, `logs\`, `diag\`
- `_archive\` — old script versions + the scrcpy zip (git-ignored; git history replaces it)

## Rules for every agent
- Work from PLAN.md. One task per session. Touch only the files the task lists.
- Keep diffs small; don't reformat or rename scripts — users already type these names.
- `.bat` files must keep working from cmd AND when called from PowerShell. Quote paths: the parent folder name has a space ("Project Space").
- Never hard-code `C:\Users\...` or an IP address. Use `%~dp0` (bat) / `$PSScriptRoot` (ps1).
- Never commit secrets, phone addresses, app usage data, logs, or anything in .gitignore.
- Never push, never force-push. Never delete user data files — copy/rename instead.
- If something is unclear, stop and ask in your final message.
- Record design decisions in DECISIONS.md (date — decision — why).
