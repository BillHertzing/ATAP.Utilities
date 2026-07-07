<#
.SYNOPSIS
Maps a network share to a local drive letter.

.DESCRIPTION
Creates a persistent-scope PSDrive for a UNC share. Migrated 2026-07-07 (Sprint 0012
Task 12.46.d, PlanPowershellReorganization.md 3.b) from ATAP.IAC
`Windows\Add-NetworkShareAsLocalDriveLetter.ps1`, which was a two-line snippet relying
on `$global:creds` and a nonexistent `Get-Credentials` cmdlet; rewritten as a proper
parameterized function. Pass an explicit -Credential when the share requires one —
resolve stored credentials by SecretName via Get-SecretATAP at the call site; never
store them in globals or source.

.EXAMPLE
Add-NetworkShareAsLocalDriveLetter -Name 'Z' -Root '\\ncat016\dropbox' -Credential $cred

.OUTPUTS
The PSDriveInfo object returned by New-PSDrive.
#>
function Add-NetworkShareAsLocalDriveLetter {
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([System.Management.Automation.PSDriveInfo])]
  param(
    # Drive letter (name) to map the share to, without a colon.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z]$')]
    [string] $Name,

    # UNC path of the network share.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\\\\')]
    [string] $Root,

    # Credential for the share; omit to use the current user's context.
    [System.Management.Automation.PSCredential] $Credential,

    # Recreate the mapping if the drive name is already in use.
    [switch] $Force
  )

  begin {
    $fn = 'Add-NetworkShareAsLocalDriveLetter'
    $mn = 'ATAP.Utilities.FileIO.PowerShell'
  }

  process {
    $existing = Get-PSDrive -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
      if (-not $Force) {
        throw "Drive '$Name' is already mapped to '$($existing.Root)'. Use -Force to replace it."
      }
      if ($PSCmdlet.ShouldProcess("$Name -> $($existing.Root)", 'Remove existing PSDrive')) {
        Remove-PSDrive -Name $Name -Force
      }
    }

    $parameters = @{
      Name       = $Name
      PSProvider = 'FileSystem'
      Root       = $Root
      Scope      = 'Global'
      Persist    = $true
    }
    if ($Credential) {
      $parameters.Credential = $Credential
    }

    if ($PSCmdlet.ShouldProcess("$Name -> $Root", 'Map network share as local drive')) {
      $drive = New-PSDrive @parameters
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Mapped network share '$Root' as drive '$Name'." -Tag 'NetworkShare'
      }
      $drive
    }
  }

  end {
  }
}
