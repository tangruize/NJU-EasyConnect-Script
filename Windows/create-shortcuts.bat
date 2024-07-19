@echo off
set "target=%~dp0sh.exe"
set "arguments=%~dp0start-easyconnect-win.sh"
set "shortcutPath=%USERPROFILE%\Desktop\EasyConnect.lnk"

powershell -Command ^
"$WScriptShell = New-Object -ComObject WScript.Shell; ^
$Shortcut = $WScriptShell.CreateShortcut('%shortcutPath%'); ^
$Shortcut.TargetPath = '%target%'; ^
$Shortcut.Arguments = '%arguments%'; ^
$Shortcut.WorkingDirectory = '%~dp0'; ^
$Shortcut.Save(); ^
Add-Type -AssemblyName PresentationFramework; ^
[System.Windows.MessageBox]::Show('Shortcut created on desktop', 'EasyConnect')"
