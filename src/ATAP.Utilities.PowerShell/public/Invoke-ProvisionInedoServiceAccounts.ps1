# AI assisted using Powershell.instructions.md as guidelines
# Provision SvcProGet and SvcBuildmaster, then grant db_owner on their respective PRODUCTION databases.
function Invoke-ProvisionInedoServiceAccounts {
  <#
  .SYNOPSIS
    Provisions SvcProGet and SvcBuildmaster local service accounts and grants
    db_owner on their respective PRODUCTION SQL Server databases.
  .DESCRIPTION
    Interactive wizard that:
      1. Creates the SvcProGet Windows local service account (password via clipboard).
      2. Grants SvcProGet Full Control over C:\ProgramData\ProGet\Packages.
      3. Creates the SvcBuildmaster Windows local service account (password via clipboard).
      4. Grants SvcProGet db_owner on the ProGet PRODUCTION database.
      5. Grants SvcBuildmaster db_owner on the BuildMaster PRODUCTION database.
    Must be run as Administrator. When loaded as part of the module the dependent
    functions (New-LocalServiceAccount, Initialize-SqlServiceLogin) are already in
    scope; when run standalone, they are dot-sourced from $PSScriptRoot.
  .PARAMETER SqlInstance
    SQL Server instance for the PRODUCTION database grants. Default: localhost\PRODUCTION.
  .OUTPUTS
    [PSCustomObject[]] One result object per provisioning step.
  .EXAMPLE
    Invoke-ProvisionInedoServiceAccounts
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    Requires elevation (Administrator).
  .LINK
    https://github.com/BillHertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter()]
    [string]$SqlInstance = 'localhost\PRODUCTION'
  )

  BEGIN {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'BEGIN'

    # Require elevation at runtime rather than via #Requires (which blocks module import in non-admin sessions)
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      $errMsg = 'Invoke-ProvisionInedoServiceAccounts must be run as Administrator.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
      throw $errMsg
    }

    # Load dependencies when running standalone (already in scope when loaded via module)
    foreach ($dep in @('Type-PSLSA', 'New-LocalServiceAccount', 'Initialize-SqlServiceLogin')) {
      if (-not (Get-Command -Name $dep -CommandType Function -ErrorAction SilentlyContinue)) {
        $depPath = Join-Path $PSScriptRoot "$dep.ps1"
        if (Test-Path $depPath) {
          . $depPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Dot-sourced '$dep' from '$depPath'."
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Dependency '$dep' not found at '$depPath'."
          throw "Required function '$dep' could not be loaded."
        }
      }
    }
  }

  PROCESS {
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    # ---- SvcProGet -----------------------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Creating SvcProGet local service account.'
    Write-Host '--- Creating SvcProGet ---' -ForegroundColor Cyan
    Write-Host 'Copy the SvcProGet password to your clipboard, then press Enter...' -ForegroundColor Yellow
    $null = Read-Host
    $pwProGet = ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force
    if ($PSCmdlet.ShouldProcess('SvcProGet', 'New-LocalServiceAccount')) {
      $r1 = New-LocalServiceAccount `
        -AccountName SvcProGet `
        -FullName 'ProGet Service Identity' `
        -Description 'Windows service account for Inedo ProGet' `
        -Password $pwProGet `
        -GrantSeServiceLogonRight
      $r1 | Format-List
      $results.Add($r1)
    }

    # ---- Grant SvcProGet Full Control over ProGet package store --------------
    # ProGet UI bulk-delete fails with HTTP 500 "Access to path ... is denied" unless
    # SvcProGet holds explicit Full Control on C:\ProgramData\ProGet\Packages.
    # The Inedo Hub installer does NOT set this automatically when a custom service
    # account replaces NetworkService. See Explainer 0500-New Computer setup.md §7.5.
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Granting SvcProGet Full Control over ProGet package store.'
    Write-Host '--- Granting SvcProGet Full Control over ProGet package store ---' -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess('C:\ProgramData\ProGet\Packages', 'icacls grant SvcProGet Full Control')) {
      icacls 'C:\ProgramData\ProGet\Packages' /grant 'SvcProGet:(OI)(CI)F' /T
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "icacls exit code: $LASTEXITCODE"
    }

    # ---- SvcBuildmaster ------------------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Creating SvcBuildmaster local service account.'
    Write-Host '--- Creating SvcBuildmaster ---' -ForegroundColor Cyan
    Write-Host 'Copy the SvcBuildmaster password to your clipboard, then press Enter...' -ForegroundColor Yellow
    $null = Read-Host
    $pwBM = ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force
    if ($PSCmdlet.ShouldProcess('SvcBuildmaster', 'New-LocalServiceAccount')) {
      $r2 = New-LocalServiceAccount `
        -AccountName SvcBuildmaster `
        -FullName 'BuildMaster Service Identity' `
        -Description 'Windows service account for Inedo BuildMaster' `
        -Password $pwBM `
        -GrantSeServiceLogonRight
      $r2 | Format-List
      $results.Add($r2)
    }

    # ---- Grant ProGet db_owner -----------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Granting ProGet db_owner on $SqlInstance to SvcProGet."
    Write-Host '--- Granting ProGet db_owner to SvcProGet ---' -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess("$SqlInstance / ProGet", 'Initialize-SqlServiceLogin')) {
      $r3 = Initialize-SqlServiceLogin `
        -SqlInstance $SqlInstance `
        -DatabaseName 'ProGet' `
        -ServiceAccount "$env:COMPUTERNAME\SvcProGet" `
        -Encrypt Optional `
        -TrustServerCertificate
      $r3 | Format-List
      $results.Add($r3)
    }

    # ---- Grant BuildMaster db_owner ------------------------------------------
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Granting BuildMaster db_owner on $SqlInstance to SvcBuildmaster."
    Write-Host '--- Granting BuildMaster db_owner to SvcBuildmaster ---' -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess("$SqlInstance / BuildMaster", 'Initialize-SqlServiceLogin')) {
      $r4 = Initialize-SqlServiceLogin `
        -SqlInstance $SqlInstance `
        -DatabaseName 'BuildMaster' `
        -ServiceAccount "$env:COMPUTERNAME\SvcBuildmaster" `
        -Encrypt Optional `
        -TrustServerCertificate
      $r4 | Format-List
      $results.Add($r4)
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Provisioning complete.'
    Write-Host 'Done.' -ForegroundColor Green
    return $results.ToArray()
  }
}
