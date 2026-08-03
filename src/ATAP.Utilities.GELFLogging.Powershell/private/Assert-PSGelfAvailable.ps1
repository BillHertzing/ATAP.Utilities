<#
.SYNOPSIS
  Ensures PSGELF\Send-PSGelfUDP is available, autoloading PSGELF when needed.
.DESCRIPTION
  Task 14.62. Kept private and separate from provider registration so that
  Disable-SeqGelfLogging and Get-SeqGelfLoggingStatus never pay this cost: turning the
  sink OFF, or asking whether it is on, must not require the transport module to be
  installed. Only Enable-SeqGelfLogging calls it.
.OUTPUTS
  None. Throws when PSGELF is unavailable.
#>
function Assert-PSGelfAvailable {
  [CmdletBinding()]
  [OutputType([void])]
  param()

  $fn = $MyInvocation.MyCommand.Name
  $mn = 'ATAP.Utilities.GELFLogging.Powershell'

  if (Get-Command -Name 'Send-PSGelfUDP' -ErrorAction SilentlyContinue) {
    return
  }

  if (Get-Module -ListAvailable -Name PSGELF) {
    Import-Module PSGELF -ErrorAction Stop
    return
  }

  $errorMessage = "Required module 'PSGELF' is not installed. Install it with: Install-Module -Name PSGELF -Scope AllUsers"
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
  throw $errorMessage
}
