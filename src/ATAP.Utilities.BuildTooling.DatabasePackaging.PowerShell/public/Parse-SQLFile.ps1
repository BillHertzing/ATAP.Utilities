function Parse-SQLFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $FilePath,

    [Parameter(Mandatory = $true)]
    [string] $RelativePath
  )

  begin {
    $fn = 'Parse-SQLFile'
    $mn = 'ATAP.Utilities.BuildTooling.DatabasePackaging.PowerShell'
  }

  process {
    try {
      $content = Get-Content -LiteralPath $FilePath -Raw
      $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
      $purposePattern = '--\s+(.*?)(?:\r?\n--|\r?\n\r?\n)'
      $match = [regex]::Match($content, $purposePattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
      $purpose = if ($match.Success) { $match.Groups[1].Value.Trim() } else { "SQL script $fileName" }

      return @([PSCustomObject]@{ Name = $fileName; Purpose = $purpose })
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Error parsing SQL file '$FilePath': $($_.Exception.Message)"
      return $null
    }
  }

  end {
  }
}
