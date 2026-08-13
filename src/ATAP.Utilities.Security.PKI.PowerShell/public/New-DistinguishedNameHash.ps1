function New-DistinguishedNameHash {
  <#
  .SYNOPSIS
  Creates a normalized distinguished-name and certificate-extension descriptor.
  .DESCRIPTION
  Returns OpenSSL-compatible subject, SAN, basic-constraints, key-usage, and EKU strings without invoking OpenSSL.
  .PARAMETER CN
  Certificate common name.
  .PARAMETER emailAddress
  Optional subject email address retained for compatibility.
  .PARAMETER SubjectAlternateName
  SAN entries such as DNS:utat01, DNS:utat01.example, or IP:10.0.0.10.
  .OUTPUTS
  System.Management.Automation.PSCustomObject
  .EXAMPLE
  New-DistinguishedNameHash -CN 'utat01' -O 'ATAP Foundation' -C 'US' -SubjectAlternateName 'DNS:utat01','DNS:utat01.atap.local' -ExtendedkeyUsage 'serverAuth'
  .NOTES
  SANs, not CN fallback, are authoritative for TLS name validation.
  .LINK
  https://github.com/whertzing/ATAP.Utilities
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [Alias('CommonName')]
    [ValidateNotNullOrEmpty()]
    [string] $CN,
    [Parameter(ValueFromPipelineByPropertyName)] [string] $emailAddress,
    [Parameter(ValueFromPipelineByPropertyName)] [Alias('Country')] [string] $C,
    [Parameter(ValueFromPipelineByPropertyName)] [Alias('StateOrTerritory')] [string] $ST,
    [Parameter(ValueFromPipelineByPropertyName)] [Alias('Locality')] [string] $L,
    [Parameter(ValueFromPipelineByPropertyName)] [Alias('Organization')] [string] $O,
    [Parameter(ValueFromPipelineByPropertyName)] [Alias('OrganizationUnit')] [string] $OU,
    [Parameter(ValueFromPipelineByPropertyName)] [string] $Environment,
    [Parameter(ValueFromPipelineByPropertyName)] [string[]] $BasicConstraints = @('critical', 'CA:FALSE'),
    [Parameter(ValueFromPipelineByPropertyName)] [string[]] $KeyUsage = @('critical', 'digitalSignature', 'keyEncipherment'),
    [Parameter(ValueFromPipelineByPropertyName)] [string[]] $ExtendedkeyUsage,
    [Parameter(ValueFromPipelineByPropertyName)] [string[]] $SubjectAlternateName,
    [Parameter(ValueFromPipelineByPropertyName)] [string[]] $FriendlyName,
    [Parameter(ValueFromPipelineByPropertyName)] [string] $DNAsFileNameReplacementPattern,
    [Parameter(ValueFromPipelineByPropertyName)] [string] $SANAsParameterReplacementPattern
  )

  begin {
    $fn = 'New-DistinguishedNameHash'
    $mn = 'ATAP.Utilities.Security.PKI.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function.' -Tag 'Trace'
  }

  process {
    $subjectValues = [ordered]@{ CN = $CN; OU = $OU; O = $O; L = $L; ST = $ST; C = $C; emailAddress = $emailAddress }
    $escapeSubject = { param([string]$Value) $Value.Replace('\', '\\').Replace('/', '\/') }
    $subjectParts = foreach ($entry in $subjectValues.GetEnumerator()) {
      if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
        "/$($entry.Key)=$(& $escapeSubject $entry.Value)"
      }
    }
    $fileParts = foreach ($entry in $subjectValues.GetEnumerator()) {
      if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
        "$($entry.Key)_$($entry.Value)"
      }
    }
    if ($Environment -and $Environment -ne 'Production') {
      $fileParts += "Environment_$Environment"
    }

    $normalizedSans = @($SubjectAlternateName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    foreach ($san in $normalizedSans) {
      if ($san -notmatch '^(DNS|IP|email|URI):[^,\s]+$') {
        throw "Invalid SubjectAlternativeName '$san'. Use DNS:, IP:, email:, or URI: entries."
      }
    }

    [PSCustomObject]@{
      CN = $CN
      C = $C
      ST = $ST
      L = $L
      O = $O
      OU = $OU
      emailAddress = $emailAddress
      Environment = $Environment
      DNAsFileName = ($fileParts -join '__')
      DNAsParameter = ($subjectParts -join '')
      BasicConstraints = if ($BasicConstraints.Count) { 'basicConstraints=' + ($BasicConstraints -join ',') } else { $null }
      KeyUsage = if ($KeyUsage.Count) { 'keyUsage=' + ($KeyUsage -join ',') } else { $null }
      ExtendedkeyUsage = if ($ExtendedkeyUsage.Count) { 'extendedKeyUsage=' + ($ExtendedkeyUsage -join ',') } else { $null }
      SubjectAlternateName = if ($normalizedSans.Count) { 'subjectAltName=' + ($normalizedSans -join ',') } else { $null }
      FriendlyName = if ($FriendlyName.Count) { $FriendlyName -join ',' } else { $null }
      SANAsParameter = if ($normalizedSans.Count) { 'subjectAltName=' + ($normalizedSans -join ',') } else { $null }
      SANAsFilename = if ($normalizedSans.Count) { $normalizedSans -join '_' } else { $null }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function.' -Tag 'Trace'
  }
}
