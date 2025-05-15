# link to the development copy if no package provide the function
if (!${get-command New-SymbolicLink}) {
  . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1"
}
Write-output " Are you sure you are in a project's base directory?"
pause
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.prettierrc.yml"  -symbolicLinkPath ".\.prettierrc.yml" -force
# create the .vscode directory
# ToDo: make the directory a junction instead of creating individual symbolic links
$null = New-Item -ItemType Directory -Force '.vscode';
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\tasks.json"  -symbolicLinkPath ".\.vscode\tasks.json" -force
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\launch.json"  -symbolicLinkPath ".\.vscode\launch.json" -force
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.vscode\cspell.json"  -symbolicLinkPath ".\.vscode\cspell.json" -force
