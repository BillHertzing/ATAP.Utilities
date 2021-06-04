function Start-DebugPowerShell
{
    PowerShell -NoProfile -NoExit -Command {
        function prompt {
            $newPrompt = "$pwd.Path [DEBUG]"
            Write-Host -NoNewline -ForegroundColor Yellow $newPrompt
            return '> '
        }
    }
}
Set-Alias -Name sdp -Value Start-DebugPowerShell
