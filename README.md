# Hashi 橋 — use your Android phone's apps from your Windows PC

*Hashi (橋) is Japanese for "bridge": the link between the phone and the desktop. It also means chopsticks, for picking the one app you want out of the clutter.*

Hashi is a small set of Windows scripts built on [scrcpy](https://github.com/Genymobile/scrcpy) and `adb`. It lets you:

- **Open any phone app in its own resizable PC window**: `droid spotify`, `droid settings`, `droid youtube big`. Each app runs on its own *virtual display*, so the phone's real screen stays locked and untouched, and you can have several apps open side by side.
- **Browse your apps from a keyboard-driven terminal launcher** (`phone`): recent apps, most-used apps, all apps, 19-ish categories you control, search-as-you-type, and **bookmarks that open straight into a deep screen** of an app or a Settings sub-page.
- **Mirror the whole phone** (`mirror`), **get a shell** on it (`phone-shell`), and **start Shizuku** over adb (`shizuku`).
- **Copy and paste between PC and phone** in both directions while a window is open, so you can type on the PC keyboard instead of the phone's.

It was built for and tested on Pixels (Pixel 9 Pro XL, then Pixel 11 Pro XL), but should work on any Android 11+ phone. Wireless debugging needs Android 11+, and scrcpy's per-app virtual displays need Android 10+.

---

## Contents

1. [Requirements](#requirements)
2. [Install](#install)
3. [Daily use](#daily-use)
4. [The `phone` launcher](#the-phone-launcher)
5. [Bookmarks and deep links](#bookmarks-and-deep-links)
6. [Your data files](#your-data-files)
7. [Audio](#audio)
8. [Shizuku](#shizuku)
9. [Away from home (USB, hotspot, other networks)](#away-from-home)
10. [Troubleshooting](#troubleshooting)
11. [Termux: real SSH into the phone](#termux-real-ssh-into-the-phone)
12. [How it works / file layout](#how-it-works--file-layout)
13. [Updating scrcpy](#updating-scrcpy)
14. [Privacy: what is and isn't in this repo](#privacy-what-is-and-isnt-in-this-repo)
15. [Credits](#credits)

---

## Requirements

| | |
|---|---|
| PC | Windows 10 or 11. Works with Windows PowerShell 5.1 (built in) or PowerShell 7. |
| Phone | Android 11+ (Wireless debugging). Over USB, older phones mirror fine, but per-app windows need Android 10+. |
| Network | PC and phone on the **same Wi-Fi network**, or a USB cable. |
| Disk | ~30 MB for scrcpy + adb (downloaded by `setup.bat`, not stored in git). |
| Optional | [Shizuku](https://shizuku.rikka.app/) on the phone; [Termux](https://f-droid.org/packages/com.termux/) for SSH. |

You do **not** need Android Studio, the Android SDK, or a separate adb install. scrcpy ships its own `adb.exe`, and Hashi only uses that one.

---

## Install

### 1. Get the code

```powershell
cd "$env:USERPROFILE\Claude\Project Space"     # or wherever you keep projects
git clone https://github.com/ceardlann/hashi.git Hashi
cd Hashi
```

(No git? Use **Code → Download ZIP** on GitHub and extract it anywhere. Paths with spaces are fine.)

### 2. Run setup

Double-click **`setup.bat`** (or run `.\setup.bat` in a terminal). It:

- downloads the pinned scrcpy release (it includes `adb.exe`) from GitHub into `scrcpy\`
- checks the download against a pinned **SHA-256 hash** and refuses to install on a mismatch
- creates your editable `aliases.txt`, `bookmarks.csv` and `categories.csv` from the shipped `*.example` files, without ever overwriting files you already have
- prints the next steps

Running it again is safe: it skips the download if scrcpy is already there. `setup.bat -Force` reinstalls.

### 3. Prepare the phone (one time)

1. **Settings → About phone →** tap **Build number** 7 times. This unlocks Developer options.
2. **Settings → System → Developer options:**
   - turn **Wireless debugging** ON, and allow it on this network when asked ("Always allow on this network")
   - optional but handy: **Stay awake** (screen stays on while charging)
3. Optional, for the smoothest `droid` experience: set up **Smart Lock → Trusted places** for home, so the phone unlocks with a swipe and `droid` can dismiss the lock screen by itself. See [Black window](#troubleshooting).

**Tip:** In Developer options, long-press **Quick settings developer tiles** and add the **Wireless debugging** tile. Then you can turn it on from the notification shade.

### 4. Pair (one time per PC)

Double-click **`pair.bat`** and follow the prompts:

1. On the phone, open **Wireless debugging → Pair device with pairing code**.
2. Type the **IP:port shown inside that pairing popup**, then the **6-digit code**.
3. Then type the **IP:port shown on the main Wireless debugging screen** (under "IP address & Port"). This is a *different port* from the pairing one.

Pairing is remembered. After this, everything reconnects by itself through `connect.bat`.

**Using USB instead?** Turn on **USB debugging** in Developer options, plug in, and tap **Allow** on the phone. No pairing is needed.

### 5. Optional conveniences

| Run once | Does |
|---|---|
| `add-to-path.bat` | Adds the Hashi folder to *your user* PATH, so `droid`, `phone`, `mirror`, `apps`, `shizuku`… work from any terminal. Open a **new** terminal afterwards. |
| `make-shortcut.bat` | Puts a **Phone Launcher** shortcut on your Desktop (pin it to the taskbar or Start if you like). |

Both record the folder's current location. If you move or rename the folder, run them again.

### 6. Try it

```bat
phone              :: the launcher
droid settings     :: Android Settings in its own window
```

---

## Daily use

Every command connects to the phone first (through `connect.bat`), so you never have to run `connect` yourself unless you want to check what's going on.

| Command | What it does |
|---|---|
| `phone` | Opens the **terminal launcher** (see below). `pick` does the same thing (old name). |
| `droid <app>` | Opens one app in its **own resizable window** on a virtual display. `<app>` can be a name (`droid youtube`), an alias from `aliases.txt` (`droid ytmusic`), or a package (`droid com.android.settings`). Run it several times to get several windows. |
| `droid <app> phone` | Same, but in a phone-shaped portrait window (1080×2400). |
| `droid <app> big` | Same, but in a large 1920×1080 window. The default is landscape, about 1280×960. Every window can be resized. Maximizing it makes Android switch to its tablet/desktop layout. |
| `mirror` | Mirrors the whole phone screen. Extra scrcpy flags pass through, e.g. `mirror --turn-screen-off` or `mirror --no-audio`. |
| `apps` · `apps youtube` | Lists installed user apps with package names, optionally filtered. `apps -All` includes system apps. `apps -Refresh` re-reads the list from the phone. |
| `connect` | Finds the phone, connects, and shows which device it's using. |
| `phone-shell` | `adb shell` on the phone, the "ssh" equivalent (`am start …`, `pm list packages`, `dumpsys …`). Type `exit` to leave. |
| `shizuku` | Starts Shizuku on the phone (see [Shizuku](#shizuku)). |
| `appdb-refresh` | Rebuilds the launcher's app table from the phone (same as **F5** in `phone`). |
| `diag` · `diag-usage` · `test` | Troubleshooting helpers (see [Troubleshooting](#troubleshooting)). |

### How `droid` finds the app

It tries these in order:

1. A package name (anything with a dot) is used as is.
2. An exact match in `aliases.txt`.
3. An exact app-name match.
4. A single partial match, preferring your own apps over system apps.
5. If several apps match, it lists them and asks once. Your pick is saved to `aliases.txt`, so it never asks again.

If nothing matches, it re-reads the app list from the phone (maybe the app is new) before giving up.

### Window controls (scrcpy)

Alt is scrcpy's "MOD" key:

| Keys | Does |
|---|---|
| Alt+F | Fullscreen |
| Alt+Q | Close the window |
| Alt+O | Turn the phone's physical screen off (mirror keeps working) |
| Alt+H / Alt+B | Home / Back |
| Alt+S | App switcher |
| Alt+↑ / Alt+↓ | Volume |
| Ctrl+V | Paste the PC clipboard into the phone |
| Right-click | Back |

The clipboard syncs both ways automatically while a window is open: copy on the phone, paste on the PC, and the reverse.

### Extra scrcpy options for `droid`

Set them in the terminal before running `droid`:

```bat
set DROID_OPTS=--no-vd-destroy-content     :: keep the app running on the phone after closing the window
set DROID_OPTS=--max-fps=30 -b8M           :: lighter on slow Wi-Fi
set DROID_AUDIO=pc                         :: see Audio
```

---

## The `phone` launcher

Run `phone` (or use the Desktop shortcut). The **Home** screen shows **Recent**, **Top used**, **All apps**, **Bookmarks**, and then your **categories**. A strip of your top 10 apps is always visible.

| Key | Does |
|---|---|
| ↑ ↓ · PgUp PgDn · Home End | Move |
| Enter | Open the selected app, category, or bookmark |
| → | **More actions** for an app: open in a specific window shape, Android **App info** page, **notification settings**, **Play Store** page, change category, copy the package name to the PC clipboard |
| ← · Backspace | Back |
| Esc | Clear the search; back; quit (on Home) |
| *type letters* | Search all apps by name, package or category |
| 1–9, 0 | Open that app from the Top-10 strip |
| Tab | Window shape for the next launch: landscape → phone → big |
| F2 | Sort: name → last used → most used → newest installed |
| F4 | Change the selected app's category (saved to `categories.csv`) |
| F5 | Re-read everything from the phone (names, install source, usage stats, install dates) |
| F6 | **Bookmark whatever screen is open on the phone right now** (best effort, see below) |
| F7 | Audio: phone only → PC only → both |
| Del | Remove the selected bookmark |

The app table rebuilds itself when it's more than 3 days old. Usage figures (minutes this week/month/year, last used, launch counts) come from Android's own `dumpsys usagestats`, so they include use on the phone, not just through Hashi.

---

## Bookmarks and deep links

Bookmarks open an app **at a specific screen** in its own window. This is the main way to avoid typing on the phone: open the exact settings page on the PC, then paste into it.

`bookmarks.csv` has four columns:

```csv
Group,Name,Package,Intent
Settings,Wi-Fi,com.android.settings,-a android.settings.WIFI_SETTINGS
Settings,Battery optimization exemptions,com.android.settings,-a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS
Examples (edit me),A web page in Chrome,com.android.chrome,-a android.intent.action.VIEW -d 'https://example.com' -p com.android.chrome
Examples (edit me),Maps search: coffee near me,com.google.android.apps.maps,"-a android.intent.action.VIEW -d 'geo:0,0?q=coffee'"
```

- **Group** is the heading the bookmark appears under in the launcher.
- **Intent** holds the arguments for `am start`, the same thing you'd type after `adb shell am start`.
- Wrap the Intent in double quotes if it contains a comma. Put single quotes around URLs.

The shipped example has about 28 Settings pages. Useful patterns:

| You want | Intent |
|---|---|
| A Settings page | `-a android.settings.<NAME>` (Android's [list of Settings actions](https://developer.android.com/reference/android/provider/Settings)) |
| One app's **App info** page | `-a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.example.app` |
| One app's **notification** settings | `-a android.settings.APP_NOTIFICATION_SETTINGS --es android.provider.extra.APP_PACKAGE com.example.app` |
| Any link an app handles | `-a android.intent.action.VIEW -d 'https://…'` (add `-p <package>` to force which app opens it) |
| A Play Store page | `-a android.intent.action.VIEW -d 'market://details?id=com.example.app'` |
| A specific activity | `-n com.example.app/.SomeActivity` (only works if the app exports it) |

**F6 "bookmark this screen"** reads the top activity from `dumpsys activity activities` and saves it. It works for many screens, but apps that don't export their inner activities will open at their main screen instead. Test the bookmark once and delete it with **Del** if it doesn't land where you wanted.

To find intents yourself: open the screen on the phone, then run `phone-shell` and `dumpsys activity activities | grep -E "topResumedActivity|Intent \{"`.

---

## Your data files

All of these are plain text or CSV files (open them in Excel or Notepad), and all are **git-ignored**, so your data never ends up in the repo. Fresh clones get starter copies from the `*.example` files.

| File | What it is | Who writes it |
|---|---|---|
| `aliases.txt` | `name=package` short names for `droid` (`ytmusic=com.google.android.apps.youtube.music`). | You, and `droid` when you pick from several matches |
| `categories.csv` | `Package,Category,Name,DisplayName`. **Wins over everything else**, so editing a category needs no phone refresh. `DisplayName` overrides how the app is labelled. New apps show up as *Uncategorized*. | You, F4 in `phone` |
| `bookmarks.csv` | Deep-link bookmarks (see above). | You, F6 / Del in `phone` |
| `appdb.csv` | The app table: name, package, category, user/system, install source, installed/updated dates, last used, minutes used (week/month/year), launch count, version. | `appdb.ps1` (F5, `appdb-refresh`, or auto every 3 days) |
| `launch-log.csv` | What you opened from the launcher (feeds Recent / Last opened). | `phone` |
| `apps-cache.txt` | Quick app list used by `droid` and `apps`. Delete it to force a refresh. | `applist.ps1` |
| `last-phone.txt` | The last IP:port that worked, used as a fallback by `connect`. | `pair`, `connect` |
| `logs\` | One scrcpy log per window the launcher opened. | `phone` |
| `diag\` | Raw phone output from `diag` / `diag-usage`. | `diag` |

**Backing up your setup:** `aliases.txt`, `categories.csv` and `bookmarks.csv` are the only files that hold work you did by hand. Copy those three to a new PC and you're set; everything else rebuilds from the phone.

---

## Audio

By default scrcpy takes the phone's sound and plays it on the PC. Hashi changes that: **`droid` and `phone` leave audio on the phone.**

- In `phone`, press **F7** to cycle: phone only → PC only → both.
- For `droid`, set it first: `set DROID_AUDIO=pc` or `set DROID_AUDIO=both`.
- `mirror` keeps scrcpy's default (PC). Use `mirror --no-audio` to keep sound on the phone.

If an app's microphone or audio seems "stuck" on the PC, a leftover scrcpy window is usually still running. Close it, or end the `scrcpy.exe` process in Task Manager.

---

## Shizuku

[Shizuku](https://shizuku.rikka.app/) gives other apps adb-level permissions without rooting the phone. Install it from the Play Store, open it once, then run:

```bat
shizuku          :: starts Shizuku over adb, then confirms shizuku_server is running
shizuku quiet    :: same, without the final pause (for scripts / shortcuts)
```

How it works: newer Shizuku versions start from a native library (`libshizuku.so`) whose install path contains random folder names, so `shizuku.bat` looks the path up with `pm path` each time. Older versions use `/sdcard/Android/data/moe.shizuku.privileged.api/start.sh`, which it falls back to.

**Shizuku stops when the phone reboots.** Run `shizuku` again after any restart. It takes about 3 seconds.

Shizuku apps that pair well with Hashi:

- **Canta / Hail**: debloat or freeze apps you rarely use, so the phone stays tidy while `phone` stays your way in.
- **App Ops / Permission Manager X**: fine-grained permission control, e.g. blocking background clipboard reads.
- **rish** (Shizuku's shell, used from Termux): run `am start` / `pm` / `settings` with adb privileges on the phone itself, so bookmark intents work without the PC.
- **Install with Options**, **ShizuStore**, **Swift Backup**, **Tasker/Automate** with Shizuku enabled.

Each app you grant Shizuku to gets adb-level power. Keep the list short and prefer open-source apps.

---

## Away from home

| Situation | What to do |
|---|---|
| **USB cable** (anywhere) | Turn on USB debugging, plug in, tap Allow. `connect` picks up USB devices first. No Wi-Fi needed at all. |
| **Another Wi-Fi network** | Turn Wireless debugging on and allow that network. `connect` finds the phone by mDNS; pairing carries over. |
| **PC on the phone's hotspot** | Android won't allow Wireless debugging when the phone *is* the hotspot. Plug in USB once and run `scrcpy\adb.exe tcpip 5555`, then unplug and run `scrcpy\adb.exe connect <phone-hotspot-ip>:5555` (usually the gateway address, e.g. `192.168.x.1`). Remote access stays on until the phone reboots. |
| **Over the internet** | Put both devices on [Tailscale](https://tailscale.com/). With `adb tcpip 5555` enabled as above, `adb connect <phone-tailscale-ip>:5555` works from anywhere. Only do this on a private tailnet, because port 5555 is unauthenticated adb. |

The wireless port changes after reboots. `connect` handles that by preferring the stable mDNS name over the IP:port.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| **Black `droid` window** | The phone is **locked**. Unlock it and the app appears instantly. `droid` wakes the phone and dismisses a swipe-only lock screen itself. Pair that with Smart Lock (trusted place) at home, or Developer options → Stay awake on the charger. |
| Black window even when unlocked | Hardware video decoding fails on some PCs. Hashi already passes `--hwdec=disabled`. Run `test` to compare four variants and see which ones show a picture. |
| `connect` can't find the phone | Wireless debugging switches off after reboots and network changes. Turn it back on (Quick Settings tile), then `connect`. If the phone says **"Not allowed"** on this network, toggle Wireless debugging off/on and accept the "allow on this network" prompt. Still nothing? Run `connect` (not quiet) and type the IP:port from the Wireless debugging screen. |
| "adb not found … run setup.bat" | scrcpy isn't installed in `scrcpy\`. Run `setup.bat`. |
| Phone shows up twice in `adb devices` | Normal: once by IP:port, once by mDNS name. `connect` picks one (the mDNS one) and sets `ANDROID_SERIAL` so every command targets the same device. |
| Launcher shows no usage data | Run `diag-usage` and look in `diag\`. Usually a second, stale device entry. Run `scrcpy\adb.exe disconnect`, then `connect`. |
| Wrong app opens for a name | `droid` remembered an earlier pick. Edit or delete that line in `aliases.txt`. |
| Audio or mic stuck on the PC | A leftover scrcpy window is still running. Close it or end `scrcpy.exe`. |
| Scripts say "running scripts is disabled" | The `.bat` wrappers already pass `-ExecutionPolicy Bypass`. Run the `.bat`, not the `.ps1` directly. |
| Anything else | Run `diag` (about 45 seconds; two test windows flash open and close). It saves raw, read-only phone output to `diag\`. scrcpy logs for each launcher window are in `logs\`. |

---

## Termux: real SSH into the phone

`phone-shell` covers most needs. For full SSH (and a file manager), install Termux from F-Droid, then in Termux:

```sh
pkg install openssh mc
termux-setup-storage      # grant storage -> ~/storage/shared = internal storage
passwd                    # set a password
sshd                      # listens on port 8022
whoami                    # your Termux username
```

From the PC: `ssh -p 8022 <user>@<phone-ip>`, then `mc`.

---

## How it works / file layout

```
Hashi\
├── setup.bat / setup.ps1        one-time install: scrcpy + adb, example data files
├── pair.bat                     one-time Wi-Fi pairing
├── connect.bat                  finds the phone (USB > mDNS > last address > ask), sets ANDROID_SERIAL
├── droid.bat                    one app → one window (virtual display)
│   └── resolve-app.ps1          name / alias / package → package
├── phone.bat / phone.ps1        the terminal launcher (TUI)
│   ├── appdb.ps1                builds appdb.csv from pm / dumpsys package / dumpsys usagestats
│   └── applist.ps1              app-list cache shared by droid, apps, appdb
├── appdb-refresh.bat            rebuild appdb.csv
├── apps.bat                     list apps
├── pick.bat                     alias for phone
├── mirror.bat                   whole-screen mirror
├── phone-shell.bat              adb shell
├── shizuku.bat                  start Shizuku over adb
├── add-to-path.bat              add folder to user PATH
├── make-shortcut.bat            Desktop shortcut
├── diag.bat/.ps1, diag-usage.bat/.ps1, test.bat    troubleshooting
├── *.example.*                  starter data files (copied on first run)
├── AGENTS.md, PLAN.md, DECISIONS.md, COSTS.md       notes for AI coding agents / project history
└── scrcpy\                      (downloaded by setup, git-ignored)
```

How the pieces fit:

- **Connection:** every wrapper calls `connect.bat quiet`, which leaves one device serial in `ANDROID_SERIAL`. All later `adb` and `scrcpy` calls use `-s %ANDROID_SERIAL%`, so a phone that shows up twice never causes "more than one device" errors.
- **Per-app windows:** `scrcpy --new-display[=WxH/dpi] --start-app=<pkg> -x --keep-active --hwdec=disabled`. Android creates a virtual display, runs the app on it, and scrcpy streams only that display. `-x` makes the virtual display follow the window size.
- **App data:** `scrcpy --list-apps` (names, user vs system), `pm list packages -i` (install source), `dumpsys package` (install/update dates, version), `dumpsys usagestats` (usage). Nothing is installed on the phone.
- **Bookmarks:** `am start --display <id> <intent>` on a fresh virtual display.

Conventions, for anyone editing: `.bat` files must work from both cmd and PowerShell. Always quote paths (the usual parent folder has a space). Never hard-code `C:\Users\…` or an IP address; use `%~dp0` / `$PSScriptRoot`. Keep scripts ASCII, because Windows PowerShell 5.1 misreads UTF-8 without a BOM. See `AGENTS.md`.

---

## Updating scrcpy

1. Edit the top of `setup.ps1`: set `$ScrcpyVersion` to the new version, and set `$ScrcpySha256` to the new zip's SHA-256 (or `''` to skip the check).
2. Close any scrcpy windows.
3. Run `setup.bat -Force`.

You can get the hash after downloading the zip with `Get-FileHash .\scrcpy-win64-vX.Y.Z.zip`. Check it against the release notes on GitHub.

---

## Privacy: what is and isn't in this repo

`.gitignore` keeps all of the following out of git: the scrcpy binaries, your app database and usage stats, your launch log, your phone's address, your aliases/categories/bookmarks, `logs\`, `diag\`, debug dumps, `.env` files, and editor/agent settings. The repo ships only scripts, docs, and generic `*.example` files.

Before pushing changes, check with `git status` (and `git ls-files` now and then) that nothing personal has slipped in.

---

## Credits

- [scrcpy](https://github.com/Genymobile/scrcpy) by Genymobile and contributors (Apache-2.0), which does all the heavy lifting. Hashi downloads it; it doesn't redistribute it.
- [Shizuku](https://github.com/RikkaApps/Shizuku) by RikkaApps.
- Android platform tools (`adb`), bundled with scrcpy.
