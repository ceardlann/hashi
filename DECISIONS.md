# DECISIONS.md

Newest at the bottom. One line each: date — decision — why.

- 2026-11-10 — Moved to the agent-lab workflow (Claude plans/reviews, cheap models do tasks) — first practice project for the multi-agent setup.
- 2026-11-10 — scrcpy binaries are not committed; `setup.ps1` downloads a pinned release — 26 MB of third-party binaries don't belong in git history and upgrading becomes a one-line change.
- 2026-11-10 — Personal data files (app usage DB, launch log, phone address, aliases/bookmarks/categories, logs, diag output) are git-ignored; repo ships `.example` versions — safe to publish and share with a friend.
- 2026-11-10 — `_archive\` is git-ignored — git history now does that job.
- 2026-11-10 — Windows stays the primary target; Fedora gets a minimal bash version — Joe expects to use it mainly on Windows.
- 2026-11-10 — Renamed project from "scrcpy et al" to **Hashi 橋** (Japanese: bridge — phone ↔ desktop; also chopsticks, picking one app out of the clutter). Provisional; rename again if the project changes direction. After a rename, re-run add-to-path.bat and make-shortcut.bat (they record the folder path).
- 2026-11-21 — Published as private repo ceardlann/hashi — first push; public later once a friend has tried a fresh install.
- 2026-11-21 — setup.ps1 pins scrcpy 5.0.1 and its SHA-256 (taken from the zip downloaded 2026-11-09) — a tampered or wrong download is refused instead of installed.
- 2026-11-21 — connect.bat rewritten: its mDNS loop was missing its closing parenthesis and the last-address / ask fallbacks the README described; now USB/already-connected > mDNS > last-phone.txt > ask, prompts on stderr so quiet callers still show them. Old version kept in _archive\connect-v1.bat.
