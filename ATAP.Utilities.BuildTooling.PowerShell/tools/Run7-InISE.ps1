#
# Run7_InISE.ps1
#
# Attribution: https://ironmansoftware.com/using-powershell-core-6-and-7-in-the-windows-powershell-ise/
$Process = Start-Process PWSH -ArgumentList @("-NoExit") -PassThru -WindowStyle Hidden
function New-OutOfProcRunspace {
    param($ProcessId)

    $ci = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
    $tt = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()

    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci, $Host, $tt)

    $Runspace.Open()
    $Runspace
}
$Host.PushRunspace($Runspace)
$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Clear()
$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Switch to PowerShell 7", { 
    function New-OutOfProcRunspace {
        param($ProcessId)

        $ci = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
        $tt = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()

        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci, $Host, $tt)

        $Runspace.Open()
        $Runspace
    }

    $PowerShell = Start-Process PWSH -ArgumentList @("-NoExit") -PassThru -WindowStyle Hidden
    $Runspace = New-OutOfProcRunspace -ProcessId $PowerShell.Id
    $Host.PushRunspace($Runspace)
}, "ALT+F5") | Out-Null

$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Switch to Windows PowerShell", { 
    $Host.PopRunspace()
}, "ALT+F6") | Out-Null
