# Death Valley ASA Server Pack

A collection of batch and PowerShell tools to run, monitor, update, and back up the Death Valley ARK: Survival Ascended cluster.

## What you get
- Launchers: start individual maps from [start files/](start%20files/) (start_*.bat) and orchestrators ([Main/start_servers.bat](Main/start_servers.bat), [Main/start_servers_FullSend.bat](Main/start_servers_FullSend.bat)).
- Updaters: per-map scripts in [update files/](update%20files/) plus batch updater [Main/Update-Ark-Servers.bat](Main/Update-Ark-Servers.bat).
- Watchdog: The All Seeing Eye (folder [Main/AllKnowingEye](Main/AllKnowingEye)) with watchdog.ps1, eye-log.ps1, state files (eye.json, eye.txt), and the double-click launcher [Main/AllKnowingEye/RunWatchdog.cmd](Main/AllKnowingEye/RunWatchdog.cmd).
 - Watchdog: The All Seeing Eye (folder [Main/AllKnowingEye](Main/AllKnowingEye)) with watchdog.ps1, eye-log.ps1, state files (eye.json, eye.txt), and the double-click launcher [Main/AllKnowingEye/RunWatchdog.cmd](Main/AllKnowingEye/RunWatchdog.cmd). Includes [discover-servers.ps1](Main/AllKnowingEye/discover-servers.ps1) to auto-seed eye.json with detected server executables.
- Menu: console UI [Ark Menu.bat](Ark%20Menu.bat) for common tasks (now at repo root) with selectable start/update/install flows.
- Backups: cluster mirror [Main/ClusterBackup.bat](Main/ClusterBackup.bat).
- Search utility: [Main/SearchEngine.ps1](Main/SearchEngine.ps1) with wrapper [Main/RunSearch.cmd](Main/RunSearch.cmd) and backup tracer [Main/EchoTrace.bat](Main/EchoTrace.bat).

## Prereqs
- Windows with PowerShell 5+ (scripts will attempt to fetch PowerShell 7 automatically if `pwsh.exe` is missing).
- SteamCMD at `C:\steamcmd` (auto-downloaded if missing). Game files expected under `C:\Ark_SA` (update paths if your layout differs).

## Quick start
1) Run the menu: double-click [Ark Menu.bat](Ark%20Menu.bat) from the repo root (it checks SteamCMD/Pwsh and installs if missing). When using the Wandering Toolkit, open the toolkit menu and pick **Tools > Ark Launcher By Wanderer**.
2) Choose an action: **Install Servers** (same as updater, lets you pick maps), **Update Server**, **Start Servers**, **Backup**, search, or watchdog.
3) When prompted, type map names separated by spaces or `ALL` to run every script found (e.g., `TheIsland TheCenter`).
4) To run The All Seeing Eye directly without policy changes, double-click [Main/AllKnowingEye/RunWatchdog.cmd](Main/AllKnowingEye/RunWatchdog.cmd) or run:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<repo-path>\Main\AllKnowingEye\watchdog.ps1" -PollSeconds 60 -AutoRestart`

If you prefer a persistent policy change (per user):
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## How monitoring works
- Server start scripts call eye-log.ps1 to record status in eye.json and eye.txt.
- Watchdog polls eye.json for entries with `Status = Started`, verifies processes are running, and marks crashes. Optional Discord webhook is supported via watchdog parameters.
- Watchdog ingests `ServerAdminPassword` from each GameUserSettings.ini and writes it into eye.json so RCON/admin passwords stay in sync.
- When AutoRestart is set, watchdog calls matching start_<ServerName>.bat located at the repo root.

## Launcher details
- Map registry: numbered maps with NAME/TOKEN/MOD; selections accept space-separated numbers or `ALL`.
- Ports auto-derive from bases (GP 7777, QP 27015, RCON 32390) and increment by map index.
- COMMON_FLAGS hook lives near the top of Main/start_servers.bat for cluster-wide flags.
- Inline debug path tees server output to per-map logs (`Main/logs/server-<TOKEN>.log`); background path appends to the same log without console spam.

## Logs and data
- Menu orchestrators log to [Main/logs/updates.log](Main/logs/updates.log) (updates/install) and [Main/logs/starts.log](Main/logs/starts.log).
- Watchdog writes to `Main/AllKnowingEye/watchdog.log` and respects a `STOP` file in the same folder to exit.
- Crash markers append to `C:\Ark_SA\logs\Death-Valley-Reborn\UpdateLogs\crashlog.txt` from each start script.
- Backups log via robocopy in [Main/ClusterBackup.bat](Main/ClusterBackup.bat).
- SearchEngine writes timestamped logs under `Main/ArkMenu/SearchLogs`.

## Wandering Toolkit integration
- The Wandering Toolkit loads this launcher via `tools/Ark Launcher Lite By Wanderer/tool.ps1`. If the folder lacks tool.ps1, the toolkit auto-wraps common launchers (menu/start/run) as a tool entry.
- Toolkit menu now uses a two-level UI (Tools, Links); select **Tools** first, then **Ark Launcher By Wanderer** to open Ark Menu.

## Recent changes
- 2026-01-05: Toolkit menu redesigned (Tools/Links), added auto-discovery for launchers, stabilized Ark launcher invocation, separated transcript logging to avoid file locks.

## Updating and starting servers
- Update/install: run [Main/Update-Ark-Servers.bat](Main/Update-Ark-Servers.bat) (prompts for maps, accepts `ALL`) or menu option 1 (Update) / option 7 (Install alias).
- Start: run [Main/start_servers.bat](Main/start_servers.bat) (prompts for maps, accepts `ALL`) or menu option 2.
- Individual map: run the corresponding start_*.bat in [start files/](start%20files/).

## Backups
- Run [Main/ClusterBackup.bat](Main/ClusterBackup.bat) or menu option 3. Destination path is dated and can be tuned inside the batch file.

## Known paths to adjust
If you relocate anything, update these constants in the start_*.bat files (located under [start files/](start%20files/)):
- `EYE_LOG` (points to AllKnowingEye/eye-log.ps1)
- `InstallDir` per map
- `ClusterDirOverride`, `ClusterID`, and mod lists per map

## Support
- For execution policy issues, use the provided RunWatchdog.cmd or set CurrentUser policy to RemoteSigned.
  
## Coding notes
- for coding notes i put a file named Coding-Notes.txt in Main\Info for coding notes i used
