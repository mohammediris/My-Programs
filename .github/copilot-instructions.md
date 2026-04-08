# Copilot instructions for this workspace ✅

This repository is a multi-language collection of small network utilities. Be pragmatic: prefer minimal, self-contained changes and validate behavior locally (UIs, web, or CLI). Below are the essential, actionable facts an AI coding agent needs to be immediately productive.

## Quick map (what matters) 🔎
- **C# GUI**: `programs - c#/SubnetCalculator/` (WinForms, TargetFramework: `net8.0-windows`). Key files: `SubnetCalculator/Calculator.cs`, `Views/MainForm.cs`, `Program.cs`.
- **Python GUI**:
  - `programs - python/modern-subnet-scanner/src/` (ttkbootstrap/Tkinter, thread-per-host scanning). Key files: `gui.py`, `scanner.py`, `utils.py`, `main.py`.
  - `programs - python/dhcp-gui/src/` (Tkinter, DHCP server demo). Key files: `gui.py`, `dhcp_server.py`, `main.py`.
  - `programs - python/techanalys/` (Tkinter, financial analysis). Key file: `main.py`.
  - `programs - python/port scanner/` (Tkinter, ping utility). Key file: `nettest.py`.
  - `programs - python/test/ping-multi-gui/src/` (ttkbootstrap, multi-IP pinger). Key files: `gui.py`, `main.py`, `ping.py`, `utils.py`.
- **Python CLI/Web**:
  - `programs - python/trending-news/` (CLI RSS parser). Key files: `trending_news.py`, `test_trending_news.py`.
  - `programs - python/network-tools/` (Flask web app). Key files: `app.py`, `scanner.py`, `templates/subnet_scanner.html`.
  - `programs - python/netstat report/` (CLI netstat analyzer). Key file: `netstat_foreign_connections.py`.
- **PowerShell**: `programs - powershell/multiple ping/` (CSV-based multi-host monitor). Key file: `ping-multiple.ps1`.
- **Tests**: Lightweight/smoke tests in project folders (e.g., `programs - python/trending-news/test_trending_news.py`, `programs - python/dhcp-gui/src/test_smoke.py`).

## Build / run commands (exact) ▶️
- C# (build & run):
  - Build: `dotnet build` (run from `programs - c#/SubnetCalculator`)
  - Run: `dotnet run --project "programs - c#/SubnetCalculator/SubnetCalculator.csproj"`
  - For debugging, open the solution in Visual Studio.
- Python (per-project):
  - Create venv: `python -m venv .venv && .\.venv\Scripts\activate` (Windows)
  - Install deps: `pip install -r requirements.txt` (run inside each Python project folder)
  - Run commands:
    - GUI scanner (modern-subnet-scanner): `python src/main.py`
    - DHCP GUI: `python src/main.py`
    - Ping multi-GUI: `python src/main.py`
    - Port scanner: `python nettest.py`
    - Techanalys: `python main.py`
    - Trending news: `python trending_news.py --query AI --max 5`
    - Flask app (network-tools): `python app.py` — uses `app.run(debug=True)`
    - Netstat report: `python netstat_foreign_connections.py`
- PowerShell:
  - Run multiple ping: `.\ping-multiple.ps1 -CsvFile ips.csv`
- Tests: run project tests with `python -m pytest` (if pytest present) or run the test script directly (see `trending-news` smoke test).

## Code patterns & important conventions ⚙️
- Separation of concerns is explicit:
  - C#: `Calculator` holds all subnet logic, `MainForm` handles UI. Modify logic inside `Calculator.cs` and wire UI through `Views/MainForm.cs`.
  - Python GUI: `gui.py` drives UI and calls `scanner.scan_subnet(...)`. Note the signature: in `modern-subnet-scanner` the scanner mutates UI widgets (passes `output_text`, `progress_bar`, labels), while in `network-tools` the scanner is pure (returns a list of string results). Keep these semantics when editing or refactoring.
- Concurrency: 
  - Thread per host (modern-subnet-scanner, dhcp-gui): naive, avoid on large ranges (>100 hosts) to prevent memory spikes.
  - ThreadPoolExecutor (port-scanner, ping-multi-gui): better for scaling, but cap max_workers.
  - Synchronous (network-tools): single-threaded, slow for large subnets.
  - Use `Queue` for inter-thread communication; avoid shared variables.
  - Tag background threads as `daemon=True` for safe shutdown.
- Networking: socket timeouts are short (`0.5s`) across scans. CIDR parsing uses `ipaddress.ip_network(subnet, strict=False)`. When adding tests or CI runs, prefer small subnets to avoid long runs or flaky network-dependent tests.

## Integration points / templates 🧩
- Flask views render `templates/subnet_scanner.html`. Update both the form and `scanner.scan_subnet` together if you change port inputs or result format.
- The GUI `WELL_KNOWN_PORTS` appears in both `gui.py` and `scanner.py` implementations; ensure consistency if adding/removing ports.

## Testing & safety notes ⚠️
- Many tests are smoke tests that perform live network actions. Mark network-dependent tests or mock network calls during CI.
- For UI changes, test manually: run the app and try small CIDR ranges (e.g., `/30` or `/29`) before expanding.

## Small examples (copy-paste)
- Add a port to GUI and scanner (modern-subnet-scanner):
  - Add entry in `gui.py` `self.well_known_ports` and ensure `scanner.scan_subnet` handles the numeric port list.
- Make `network-tools` scanner return richer data: change `scanner.scan_subnet` to return `[{'ip': ip_str, 'open_ports': [..]}]` and update `templates/subnet_scanner.html` to iterate accordingly.

## PR guidance & priorities 📋
1. Keep changes minimal and self-contained per project (avoid cross-project refactors unless necessary).
2. Run local build/run steps and validate UIs and endpoints manually.
3. Add/adjust small tests that do not require broad network access unless explicitly intended.

---
If anything here is unclear or you want examples expanded (e.g., a suggested refactor to centralize scanning logic across GUI and Flask), tell me which part and I’ll iterate. 💡