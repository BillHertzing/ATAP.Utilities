function Update-MasterPasswordSecureStringFile {
  <#
  .SYNOPSIS
  Replaces an encrypted master-password payload.
  .DESCRIPTION
  Compatibility command that delegates encryption to New-EncryptedPasswordFile.
  .PARAMETER Path
  Encrypted payload path.
  .PARAMETER PasswordSecureString
  Replacement password as a SecureString.
  .PARAMETER EncryptionKeyFilePath
  Base64 AES key file.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  Update-MasterPasswordSecureStringFile -Path 'C:/secure/master.enc' -PasswordSecureString $secret -EncryptionKeyFilePath 'C:/secure/master.key'
  .NOTES
  The plaintext password is never returned or logged.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $Path,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [SecureString] $PasswordSecureString,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $EncryptionKeyFilePath
  )

  begin {
    $fn = 'Update-MasterPasswordSecureStringFile'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    if ($PSCmdlet.ShouldProcess($Path, 'Replace encrypted master-password payload')) {
      New-EncryptedPasswordFile -PasswordSecureString $PasswordSecureString -PasswordFilePath $Path -EncryptionKeyFilePath $EncryptionKeyFilePath -Force -Confirm:$false
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
