# Wandering Toolkit

Operations launcher for your game tooling. Run a single menu, pick a tool, and it will fetch its own prerequisites (WinGet if missing, PowerShell 7, SteamCMD into data/main/steamcmd) before showing options.

## Quick start
- Double-click menu.bat from the toolkit root.
- Choose **Tools** to see available launchers; pick one (e.g., Ark Launcher, ATS/ETS downloaders, search utilities).
- Choose **Links** to view saved reference URLs from data/main/links/links.txt.
- Exit with `Q` when you are done.

## What the tools do
- Ark Launcher: opens its own menu to update/install/start ARK: Survival Ascended servers, run backups, search logs, and start the watchdog.
- ATS/ETS Downloaders: automatically pull the listed support installers into data/downloads/ATS or data/downloads/ETS2.
- Search utilities: drive-wide text search with logging for quick triage.

## Notes
- SteamCMD lives under data/main/steamcmd; server files can be organized under data/server/*.
- Logs are written under Logs/ with timestamped names; each tool may also create its own sub-logs.
- No config editing is required to use the menu; just pick the option you need.
