# Silver Robot

A native **Windows WPF GUI** for browsing and tailing Veeam Backup & Replication log files — Silver Robot — no web browser, no third-party tools, just PowerShell and .NET.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-informational?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-2.1-orange)
![Name](https://img.shields.io/badge/Silver-Robot-silver)

---

## Screenshot

```
+------------------+--------------------+----------------------------------------+
|  FOLDERS         |  LOG FILES         |  LOG CONTENT                           |
|                  |                    |                                        |
|  > Rescan        |  rescan.log        |  [INFO]  Starting rescan of host...    |
|    10.11.2.19     |    42 KB  5m ago   |  [INFO]  Connecting to 10.0.4.19...    |
|    10.11.2.74     |  rescan_prev.log   |  [WARN]  Retrying connection...        |
|    AD            |    18 KB  2h ago   |  [ERROR] Host unreachable              |
|                  |                    |  [OK]    Rescan completed              |
|  > Backup        |                    |                                        |
|    Job_Server01  |                    |                                        |
|    Agent_Job_8   |                    |                                        |
+------------------+--------------------+----------------------------------------+
```

---

## Features

- **3-pane layout** — folder tree, file list, and log content viewer side by side
- **Covers both log roots** automatically:
  - `C:\ProgramData\Veeam\Backup\` — job logs, agent logs, session logs
  - `C:\ProgramData\Veeam\Backup\Rescan\` — per-host rescan logs
- **Search by IP or hostname** — partial match supported (e.g. `10.0.4` or `AD`)
- **Real-time Follow mode** — live tail via `FileStream`, works while Veeam holds the file open, handles log rotation automatically
- **Keyword filter with highlight** — filter lines by any keyword, matches highlighted in yellow
- **Colour-coded log lines**:

  | Colour | Keywords matched |
  |--------|-----------------|
  | Red    | ERROR, EXCEPTION, FAILED, FAILURE, CRITICAL |
  | Orange | WARNING, WARN |
  | Green  | SUCCESS, SUCCEEDED, COMPLETED, FINISH |
  | Cyan   | INFO, START, BEGIN, INIT, CONNECT |
  | White  | Everything else |

- **Resizable panes** — drag the splitters to adjust panel widths
- **File age and size** shown in the file list (`42 KB · 5m ago`)
- **No dependencies** — pure PowerShell + built-in .NET/WPF assemblies

---

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| Windows OS | Windows 10 / Server 2016 or later | WPF requires Windows |
| PowerShell | 5.1 or later | Pre-installed on Windows 10+ |
| .NET Framework | 4.5 or later | Pre-installed on Windows 10+ |
| Veeam Backup & Replication | Any | Log path must exist |

No modules from the PowerShell Gallery are required.

---

## Installation

```powershell
# Option 1 — Clone with Git
git clone https://github.com/affanjavid/silver-robot.git
cd veeam-log-viewer

# Option 2 — Download the script directly
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/affanjavid/silver-robot/main/Get-VeeamLog-UI.ps1" -OutFile "Get-VeeamLog-UI.ps1"
```

---

## Usage

```powershell
# Open the GUI — shows all folders
powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1

# Pre-filter the folder tree by IP address
powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1 -Target 10.0.4.19

# Pre-filter by hostname
powershell -ExecutionPolicy Bypass -File .\Get-VeeamLog-UI.ps1 -Target AD
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-Target` | String | *(empty)* | IP address or hostname fragment to pre-filter the folder tree on startup |

### Get help from PowerShell

```powershell
Get-Help .\Get-VeeamLog-UI.ps1 -Full
```

---

## Toolbar Reference

| Control | Description |
|---|---|
| **Search box** | Type an IP or hostname fragment and press Enter (or click Search) to filter the folder tree |
| **Filter box** | Type a keyword and press Enter (or click Filter) to show only matching log lines, highlighted in yellow. Click **X** to clear |
| **Lines** | Number of lines to load from the end of the file on open (default: 100) |
| **Follow** | Toggle real-time tail mode on/off. Button turns green when active. Polls every 800 ms using a raw FileStream |
| **Reload** | Re-read the current log file from scratch |

---

## How It Works

```
Startup
  └── Scans C:\ProgramData\Veeam\Backup\
        ├── Rescan\  (per-host folders)
        └── *\       (job / agent folders)

Folder click
  └── Lists all .log / .txt / .xml files, newest first

File click
  └── Loads last N lines, colour-codes each line by severity

Follow mode ON
  └── DispatcherTimer polls every 800ms
        └── FileStream.Seek(lastPosition) reads only new bytes
              └── Appends new lines to viewer, scrolls to bottom
```

---

## File Structure

```
veeam-log-viewer/
├── Get-VeeamLog-UI.ps1     # Main script — WPF GUI
├── Get-VeeamLog.ps1        # CLI-only version (no GUI dependency)
├── README.md               # This file
├── LICENSE                 # MIT license
└── CHANGELOG.md            # Version history
```

---

## Changelog

### v2.1 — 2026-03-05
- Fixed XAML encoding issues (full ASCII-safe, no Unicode symbols)
- Removed invalid `LetterSpacing` XAML property
- Added MIT license and full documentation block
- Security audit — confirmed no credentials, IPs, or proprietary data

### v2.0 — 2026-03-04
- New native WPF GUI with 3-pane layout
- Real-time Follow mode via `DispatcherTimer` + `FileStream`
- Keyword filter with yellow highlight
- Colour-coded log severity
- Expanded to cover both `Backup` and `Rescan` log roots
- Resizable panes via `GridSplitter`

### v1.0 — 2026-03-03
- Initial CLI-only version
- Interactive terminal menu
- Colour-coded output
- Basic tail-follow support

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m "Add my feature"`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## Author

**Affan**
[https://affan.info](https://affan.info)

---

## License

MIT License — see [LICENSE](LICENSE) for full text.

---

## Disclaimer

This project is not affiliated with, endorsed by, or supported by Veeam Software.
Veeam is a registered trademark of Veeam Software AG.
This tool reads log files only — it does not modify any Veeam configuration or data.
