function Get-ContentSummarySha256 {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Bytes')]
    [byte[]] $Bytes,

    [Parameter(Mandatory = $true, ParameterSetName = 'Text')]
    [AllowEmptyString()]
    [string] $Text
  )

  begin {
    $fn = 'Get-ContentSummarySha256'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    $bytesToHash = if ($PSCmdlet.ParameterSetName -eq 'Text') {
      [System.Text.UTF8Encoding]::new($false, $true).GetBytes($Text)
    } else {
      $Bytes
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hash = $sha256.ComputeHash($bytesToHash)
      -join ($hash | ForEach-Object { $_.ToString('x2', [System.Globalization.CultureInfo]::InvariantCulture) })
    } finally {
      $sha256.Dispose()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
