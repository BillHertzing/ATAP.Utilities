# AI assisted using Powershell.instructions.md as guidelines
# Updates the Windows service logon credentials for INEDOPROGETSVC and INEDOBMSVC.
function Invoke-SetInedoServiceLogonAccounts {
  <#
  .SYNOPSIS
    Updates the logon credentials for the ProGet and BuildMaster Windows services.
  .DESCRIPTION
    Interactive wizard that collects each service account password from the clipboard
    (one at a time) and calls Set-ServiceLogonAccount for INEDOPROGETSVC and
    INEDOBMSVC. The services may need to be restarted after this runs.
    When loaded as part of the module, Set-ServiceLogonAccount is already in scope;
    when run standalone it is dot-sourced from $PSScriptRoot.
  .OUTPUTS
    [PSCustomObject[]] One result object per service updated.
  .EXAMPLE
    Invoke-SetInedoServiceLogonAccounts
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://github.com/BillHertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Password is read interactively from the clipboard; plaintext exposure is intentional and ephemeral.')]
  param()

  BEGIN {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BEGIN'

    # Load Set-ServiceLogonAccount when running standalone (already in scope via module)
    if (-not (Get-Command -Name 'Set-ServiceLogonAccount' -CommandType Function -ErrorAction SilentlyContinue)) {
      $depPath = Join-Path $PSScriptRoot 'Set-ServiceLogonAccount.ps1'
      if (Test-Path $depPath) {
        . $depPath
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourced 'Set-ServiceLogonAccount' from '$depPath'."
      }
      else {
        $errMsg = "Required function 'Set-ServiceLogonAccount' not found at '$depPath'."
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
        throw $errMsg
      }
    }
  }

  PROCESS {
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # ---- ProGet service account ----------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Setting INEDOPROGETSVC logon account.'
    Write-Host '=== Set ProGet service logon account ===' -ForegroundColor Cyan
    Write-Host 'Copy the SvcProGet password to clipboard, then press Enter...'
    $null = Read-Host
    $proGetCred = [PSCredential]::new('.\SvcProGet', (ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force))
    if ($PSCmdlet.ShouldProcess('INEDOPROGETSVC', 'Set-ServiceLogonAccount')) {
      $r1 = Set-ServiceLogonAccount -ServiceName 'INEDOPROGETSVC' -Credential $proGetCred
      $r1 | Format-List
      $results.Add($r1)
    }

    # ---- BuildMaster service account -----------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Setting INEDOBMSVC logon account.'
    Write-Host '=== Set BuildMaster service logon account ===' -ForegroundColor Cyan
    Write-Host 'Copy the SvcBuildmaster password to clipboard, then press Enter...'
    $null = Read-Host
    $bmCred = [PSCredential]::new('.\SvcBuildmaster', (ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force))
    if ($PSCmdlet.ShouldProcess('INEDOBMSVC', 'Set-ServiceLogonAccount')) {
      $r2 = Set-ServiceLogonAccount -ServiceName 'INEDOBMSVC' -Credential $bmCred
      $r2 | Format-List
      $results.Add($r2)
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Done. You may need to restart INEDOPROGETSVC and INEDOBMSVC for the new logon to take effect.'
    Write-Host 'Done. You may need to restart INEDOPROGETSVC and INEDOBMSVC for the new logon to take effect.' -ForegroundColor Green
    return $results.ToArray()
  }
}
