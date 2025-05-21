@echo off
start "VSCode" /d "C:\Users\Mohammed Iris\AppData\Local\Programs\Microsoft VS Code" code
timeout /nobreak /t 2 >nul
powershell -command "& {Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);';$hwnd = (Get-Process code).MainWindowHandle;[void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic');[Microsoft.VisualBasic.Interaction]::AppActivate($hwnd);[ShowWindowAsync]::ShowWindowAsync($hwnd, 2)}"


start msedge "https://chat.openai.com/"
timeout /nobreak /t 2 >nul
powershell -command "& {Add-Type '[DllImport(\"user32.dll\")]public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);';$hwnd = (Get-Process msedge).MainWindowHandle;[void] [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic');[Microsoft.VisualBasic.Interaction]::AppActivate($hwnd);[ShowWindowAsync]::ShowWindowAsync($hwnd, 1)}"



:eof
