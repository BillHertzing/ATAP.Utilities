function Update-KeySecurestringFile {
  <#
  .SYNOPSIS
  Replaces an encryption key file with a newly generated key.
  .DESCRIPTION
  Compatibility command for the Security umbrella. Existing encrypted data must be re-encrypted in the same authorized operation.
  .PARAMETER Path
  Key-file path to replace.
  .PARAMETER KeySizeInt
  Key size in bytes.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  Update-KeySecurestringFile -Path 'C:/secure/value.key' -Confirm
  .NOTES
  This command does not re-encrypt dependent payloads.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [ValidateSet(16, 24, 32)]
    [int] $KeySizeInt = 32
  )

  begin {
    $fn = 'Update-KeySecurestringFile'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    if ($PSCmdlet.ShouldProcess($Path, 'Replace encryption key file')) {
      New-RandomEncryptionKeyToFile -KeyFilePath $Path -KeySizeInt $KeySizeInt -Force -Confirm:$false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
