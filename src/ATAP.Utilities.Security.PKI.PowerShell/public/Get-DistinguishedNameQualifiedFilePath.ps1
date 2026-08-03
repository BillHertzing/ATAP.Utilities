function Get-DistinguishedNameQualifiedFilePath {
  <#
  .SYNOPSIS
  Builds a certificate artifact path from a distinguished-name descriptor.
  .DESCRIPTION
  Produces a filesystem-safe name or an idempotent GUID-backed name recorded in a JSON cross-reference file.
  .PARAMETER DistinguishedNameHash
  Object returned by New-DistinguishedNameHash.
  .PARAMETER BaseFileName
  File name including its extension.
  .PARAMETER OutDirectory
  Existing destination directory.
  .PARAMETER CrossReferenceFilePath
  Optional JSON map for obfuscated file names.
  .PARAMETER Encoding
  Cross-reference file encoding.
  .OUTPUTS
  System.String
  .EXAMPLE
  Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $dn -BaseFileName 'server.csr' -OutDirectory 'C:/secure/requests'
  .NOTES
  The cross-reference contains certificate identity metadata and should inherit the destination ACL.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Named')]
  [OutputType([string])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [Alias('DN', 'DNH')]
    [PSObject] $DistinguishedNameHash,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateScript({ [IO.Path]::GetExtension($_) })]
    [string] $BaseFileName,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $OutDirectory,

    [Parameter(Mandatory, ParameterSetName = 'CrossReference')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $CrossReferenceFilePath,

    [ValidateSet('ascii', 'utf8', 'utf8BOM')]
    [string] $Encoding = 'utf8'
  )

  begin {
    $fn = 'Get-DistinguishedNameQualifiedFilePath'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    if ([string]::IsNullOrWhiteSpace($DistinguishedNameHash.DNAsFileName)) {
      throw 'DistinguishedNameHash must contain a non-empty DNAsFileName property.'
    }
    $pattern = '[' + ([IO.Path]::GetInvalidFileNameChars() -join '').Replace('\', '\\') + ']+'
    $fileName = [regex]::Replace("$($DistinguishedNameHash.DNAsFileName)-$BaseFileName", $pattern, '-')
    if ($PSCmdlet.ParameterSetName -eq 'Named') {
      return Join-Path $OutDirectory $fileName
    }

    $crossReferences = Get-Content -LiteralPath $CrossReferenceFilePath -Raw -Encoding $Encoding | ConvertFrom-Json -AsHashtable
    if ($null -eq $crossReferences) {
      $crossReferences = @{}
    }
    if (-not $crossReferences.ContainsKey($fileName)) {
      $crossReferences[$fileName] = Join-Path $OutDirectory ((New-Guid).Guid + [IO.Path]::GetExtension($BaseFileName))
      if ($PSCmdlet.ShouldProcess($CrossReferenceFilePath, "Record certificate artifact mapping for '$fileName'")) {
        $crossReferences | ConvertTo-Json | Set-Content -LiteralPath $CrossReferenceFilePath -Encoding $Encoding
      }
    }
    $crossReferences[$fileName]
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
