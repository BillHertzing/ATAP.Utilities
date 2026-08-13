function New-RandomPassPhraseToFile {
  <#
  .SYNOPSIS
  Creates a cryptographically random passphrase file.
  .DESCRIPTION
  Writes a random passphrase without echoing or returning its value. Restrict the destination ACL before use.
  .PARAMETER PassPhrasePath
  Destination path for the passphrase.
  .PARAMETER Encoding
  Text encoding for the file.
  .PARAMETER Length
  Number of random characters.
  .PARAMETER Force
  Allows replacement of an existing file.
  .OUTPUTS
  System.IO.FileInfo
  .EXAMPLE
  New-RandomPassPhraseToFile -PassPhrasePath 'C:/secure/ca.pass' -Length 48
  .NOTES
  The passphrase file is secret material and must not be committed or written to evidence.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string] $PassPhrasePath,

    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateSet('ascii', 'utf8', 'utf8BOM')]
    [string] $Encoding = 'utf8',

    [Parameter(ValueFromPipelineByPropertyName)]
    [ValidateRange(32, 256)]
    [int] $Length = 48,

    [Parameter(ValueFromPipelineByPropertyName)]
    [switch] $Force
  )

  begin {
    $fn = 'New-RandomPassPhraseToFile'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    $parentPath = Split-Path -Path $PassPhrasePath -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
      throw "The passphrase-file parent directory does not exist: '$parentPath'."
    }
    if ((Test-Path -LiteralPath $PassPhrasePath -PathType Leaf) -and -not $Force) {
      throw "The passphrase file already exists: '$PassPhrasePath'. Use -Force to replace it."
    }
    if (-not $PSCmdlet.ShouldProcess($PassPhrasePath, "Write a new $Length-character passphrase")) {
      return
    }

    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#$%&*+-=?@^_'
    $characters = [char[]]::new($Length)
    for ($index = 0; $index -lt $Length; $index++) {
      $characters[$index] = $alphabet[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($alphabet.Length)]
    }
    (-join $characters) | Set-Content -LiteralPath $PassPhrasePath -Encoding $Encoding -NoNewline -Force:$Force
    Get-Item -LiteralPath $PassPhrasePath
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
