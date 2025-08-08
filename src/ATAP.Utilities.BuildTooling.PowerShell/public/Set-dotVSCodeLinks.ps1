# link to the development copy if no package provide the function
if (!${get-command New-SymbolicLink}) {
  . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\New-SymbolicLink.ps1"
}
Write-output " Are you sure you are in a project's base directory?"
pause
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.prettierrc.yml"  -symbolicLinkPath ".\.prettierrc.yml" -force
# this command is only needed for repositories that have projects that use javascript or typescript
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.eslintrc.js"  -symbolicLinkPath ".\.eslintrc.js" -force
# this command only for repositories that use mocha for testing JavaScript
New-SymbolicLink -targetPath "C:\Dropbox\whertzing\GitHub\SharedVSCode\.mocharc.yaml"  -symbolicLinkPath ".\.mocharc.yaml" -force

# create the .vscode directory
# ToDo: make the directory a junction instead of creating individual symbolic links
$null = New-Item -Path ./.vscode -ItemType Junction -Target $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'SharedVSCode', '.vscode')
