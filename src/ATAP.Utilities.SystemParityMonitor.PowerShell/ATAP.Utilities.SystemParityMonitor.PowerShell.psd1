@{
  RootModule = 'ATAP.Utilities.SystemParityMonitor.PowerShell.psm1'
  ModuleVersion = '0.1.0'
  GUID = '6884a1da-0f50-4e7a-afb1-5f8dcb5965f9'
  Author = 'ATAP'
  CompanyName = 'ATAP'
  Copyright = '(c) ATAP. All rights reserved.'
  Description = 'System parity journal and audit tooling for host-pair operations (moved from ATAP.IAC Windows\Parity, Sprint 0012 Task 12.46).'
  PowerShellVersion = '7.0'
  CompatiblePSEditions = @('Core')
  FunctionsToExport = @(
    'Add-ParityChangeEntry',
    'Get-PeerPendingChanges',
    'Confirm-ParityChangeApplied',
    'Invoke-ParityAudit',
    'Compare-ParityAudits'
  )
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
  PrivateData = @{
    PSData = @{
      Tags = @('ATAP', 'SystemParityMonitor', 'Parity')
      ProjectUri = 'https://github.com/whertzing/ATAP.Utilities'
    }
  }
}
