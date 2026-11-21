# PLAN.md — Hashi 橋 (phone launcher)

Goal: a GitHub repo anyone can clone onto a Windows PC, run one setup script, pair a phone, and use
`droid` / `phone` — without any of Joe's personal data in it. Then a minimal Fedora version.

Status values: todo · doing · review · done · blocked
Tiers: human (Joe) · claude (judgment) · worker (cheap model, checkable) · scout (local, read-only)

## Questions for Joe
1. ~~Repo name and visibility?~~ Done: `ceardlann/hashi`, **private**. Make public later if wanted.
2. Fedora picker: OK to use `fzf` (a standard fuzzy-picker tool) instead of porting the 440-line PowerShell TUI? Much smaller, and Linux users expect it.
3. Keep the Termux/SSH section in the public README, or move it to `docs/`?

---

## T1 — Put the folder under git (learning task)
- **Files**: `.gitignore` (already written), the repo itself
- **Steps** (PowerShell, in `Project Space\Hashi`):
  1. `git init`
  2. `git status` — read the list. Nothing from `scrcpy\`, `_archive\`, `logs\`, `diag\` or the personal CSVs should appear. If something personal does, add it to `.gitignore` and run `git status` again.
  3. `git add -A` then `git status` again (green = staged)
  4. `git commit -m "Initial commit: launcher scripts"`
  5. Practice the undo: change one word in README.md, run `git diff` (see the change), then `git restore README.md` (gone).
- **Done when**:
  - [x] `git log --oneline` shows 1 commit
  - [x] `git ls-files | Select-String -Pattern 'scrcpy/|_archive|appdb.csv|launch-log|last-phone|logs/|diag/'` returns nothing
- **Tier**: human
- **Status**: done (2026-11-21)

## T2 — `setup.ps1`: download scrcpy instead of committing it
- **Files**: `setup.ps1` (new), `setup.bat` (new, 3-line wrapper like `phone.bat`)
- **Steps**:
  1. Download `scrcpy-win64-v5.0.1.zip` from `https://github.com/Genymobile/scrcpy/releases/download/v5.0.1/` into `$env:TEMP`.
  2. Extract so that `scrcpy\scrcpy.exe` and `scrcpy\adb.exe` exist directly under the repo (the zip contains a versioned top folder — flatten it).
  3. If `scrcpy\scrcpy.exe` already exists, print "already installed" and skip the download.
  4. Put the version in one variable at the top so upgrading is a one-line change.
  5. At the end print next steps: "run pair.bat", "optional: add-to-path.bat".
- **Done when**:
  - [ ] PowerShell parse check passes on `setup.ps1` (see AGENTS.md)
  - [ ] Human check: in a fresh clone (`git clone . "$env:TEMP\launcher-test"`), `setup.bat` creates `scrcpy\scrcpy.exe`, and `scrcpy\scrcpy.exe --version` prints 5.0.1
  - [ ] Running `setup.bat` a second time skips the download
- **Tier**: worker
- **Status**: review — written 2026-11-21; needs the fresh-clone check on Windows

## T3 — Find every script that reads the personal data files
- **Files**: none (read-only)
- **Steps**: list every place that reads or writes `aliases.txt`, `bookmarks.csv`, `categories.csv`, `appdb.csv`, `launch-log.csv`, `apps-cache.txt`, `last-phone.txt`, with file:line and what happens if the file is missing.
- **Done when**: answer pasted under T4 as "Findings".
- **Tier**: scout
- **Status**: done (2026-11-21)

## T4 — Example data files + first-run copy
- **Files**: `aliases.example.txt`, `bookmarks.example.csv`, `categories.example.csv` (new); the scripts T3 found that read those three files
- **Steps**:
  1. Create the three `.example` files: same headers as the real ones; a few generic entries only (Settings, Chrome, YouTube, Wi-Fi / Bluetooth settings bookmarks). No personal apps.
  2. Where a script reads one of the three files: if it's missing, copy the `.example` version to the real name first. Never overwrite an existing real file.
  3. Make sure every script that writes `appdb.csv`, `launch-log.csv`, `apps-cache.txt`, `last-phone.txt` creates it if missing (no crash on a fresh clone).
- **Findings** (from T3): every reader already tolerates a missing file (Test-Path guards in phone.ps1, appdb.ps1, applist.ps1, resolve-app.ps1; connect.bat/pair.bat create last-phone.txt). Seeding from *.example added once in applist.ps1 (dot-sourced by appdb.ps1/phone.ps1 and resolve-app.ps1) and in setup.ps1.
- **Done when**:
  - [ ] Parse check passes on every changed `.ps1`
  - [x] `git diff --stat` shows only the files listed above
  - [ ] Human check: in a fresh clone after `setup.bat` + `connect`, `phone` opens and `droid settings` works
- **Tier**: worker
- **Status**: review — written 2026-11-21; needs the fresh-clone check on Windows

## T5 — Public README
- **Files**: `README.md`
- **Steps**: add an **Install** section at the top (clone, `setup.bat`, phone Developer options, `pair.bat`, `add-to-path.bat`); replace "Original zip in `_archive\`" with "`setup.bat` downloads it"; mention that `aliases.txt`/`bookmarks.csv`/`categories.csv` are created from `.example` files on first run and are yours to edit. Don't rewrite the rest.
- **Done when**:
  - [x] `Select-String -Path README.md -Pattern '_archive'` returns nothing
  - [x] Install section exists and lists the steps in order
- **Tier**: worker
- **Status**: done (2026-11-21)

## T6 — Using it away from home (design)
- **Files**: `DECISIONS.md`, then add T7 below
- **Steps**: decide how `connect` should behave on USB, on a phone hotspot, and on other Wi-Fi networks; whether Tailscale can carry adb (and what wireless debugging allows); write the decision and a worker-sized task for it.
- **Done when**: DECISIONS.md has the decision; T7 is written with checkable "Done when" items.
- **Tier**: claude
- **Status**: todo

## T7 — (written by T6)

## T8 — Fedora port (design)
- **Files**: `DECISIONS.md`, then add worker tasks below (expected: `linux/connect.sh`, `linux/droid.sh`, `linux/phone.sh` with fzf, reusing the same CSV files)
- **Depends on**: answer to Question 2
- **Tier**: claude
- **Status**: todo

## T9 — Publish to GitHub
- **Depends on**: T2, T4, T5 reviewed PASS
- **Steps**:
  1. `git ls-files` one last time — read the whole list.
  2. `gh repo create hashi --private --source . --push`
  3. Clone it on the Fedora laptop or another PC to prove it works.
- **Done when**: repo exists (done) on GitHub, fresh clone + `setup.bat` + `pair.bat` works on a second machine.
- **Tier**: human
- **Status**: doing — pushed 2026-11-21; second-machine test still to do
