function Get-CoordClaims {
  <#
  .SYNOPSIS
    Reads recorded claims and reservations from an established local snapshot.
  .DESCRIPTION
    Caller establishes permission, trusted lineage and physical containment before
    calling. This projection is not authority, expiry, takeover or a wire response.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $StatePath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $ResourceId
  )
  begin {
    $fn = 'Get-CoordClaims'
    $mn = 'ATAP.Utilities.BuildTooling.Orchestration.PowerShell'
    $null = Get-Command Write-PSFMessage -ErrorAction Stop
    $null = Get-Command Test-Json -ErrorAction Stop
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    function sameText([string]$Left, [string]$Right) {
      [string]::Equals($Left, $Right, [StringComparison]::Ordinal)
    }
    function sha([byte[]]$Bytes) {
      [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    }
    function checkTree([System.Text.Json.JsonElement]$Element) {
      switch ($Element.ValueKind.ToString()) {
        'Object' {
          $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
          foreach ($property in $Element.EnumerateObject()) {
            $null = $utf8.GetBytes($property.Name)
            if (-not $seen.Add($property.Name)) { throw 'InvalidState' }
            checkTree $property.Value
          }
        }
        'Array' { foreach ($item in $Element.EnumerateArray()) { checkTree $item } }
        'String' { $null = $utf8.GetBytes($Element.GetString()) }
        'Undefined' { throw 'InvalidState' }
      }
    }
    function parseBytes([byte[]]$Bytes) {
      $document = $null
      try {
        $options = [System.Text.Json.JsonDocumentOptions]::new()
        $options.MaxDepth = [int]::MaxValue
        $document = [System.Text.Json.JsonDocument]::Parse($utf8.GetString($Bytes), $options)
        checkTree $document.RootElement
        return $document.RootElement.Clone()
      } catch { throw 'InvalidState' }
      finally { if ($null -ne $document) { $document.Dispose() } }
    }
    $schemaRoot = if ((Split-Path $PSScriptRoot -Leaf) -ieq 'public') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
    try {
      [byte[]]$schemaBytes = [IO.File]::ReadAllBytes((Join-Path $schemaRoot 'schemas/state-v1.schema.json'))
      if (-not (sameText (sha $schemaBytes) '4f148321844e3f2970c7190d79fb4371e609a62bef093e43a7adb855c9bb9bfa')) { throw 'UnsupportedSchema' }
      $schemaText = $utf8.GetString($schemaBytes)
    } catch { throw 'Get-CoordClaims: InvalidSchema' }
  }
  process {
    $failure = 'UnavailableState'
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Reading recorded claims snapshot'
      if (-not [IO.Path]::IsPathFullyQualified($StatePath) -or
          -not (Test-Path -LiteralPath $StatePath -PathType Leaf -ErrorAction Stop) -or
          (Get-Item -LiteralPath $StatePath -Force -ErrorAction Stop).LinkType) { throw 'UnavailableState' }
      [byte[]]$bytes = [IO.File]::ReadAllBytes($StatePath)
      $failure = 'InvalidState'
      $state = parseBytes $bytes
      if (-not (Test-Json -Json $state.GetRawText() -Schema $schemaText -ErrorAction SilentlyContinue)) { throw 'InvalidState' }
      $failure = 'ResourceMismatch'
      if (-not (sameText $state.GetProperty('resourceId').GetString() $ResourceId)) { throw 'ResourceMismatch' }
      $failure = 'InconsistentSnapshot'
      foreach ($pair in @(@{ Name='claims'; Id='claimId' }, @{ Name='reservations'; Id='reservationId' })) {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $state.GetProperty($pair.Name).EnumerateArray()) {
          if (-not (sameText $entry.GetProperty('resourceId').GetString() $ResourceId) -or
              -not $seen.Add($entry.GetProperty($pair.Id).GetString())) { throw 'InconsistentSnapshot' }
        }
      }
      $claims = $state.GetProperty('claims')
      $reservations = $state.GetProperty('reservations')
      [PSCustomObject]@{
        ResourceId = $ResourceId
        StateSha256 = sha $bytes
        RecordedHead = [PSCustomObject]@{
          generation = $state.GetProperty('generation').GetString()
          committedRevision = $state.GetProperty('committedRevision').GetString()
          outputManifest = $state.GetProperty('committedOutputManifest').Clone()
        }
        ClaimCount = $claims.GetArrayLength()
        ReservationCount = $reservations.GetArrayLength()
        Claims = $claims.Clone()
        Reservations = $reservations.Clone()
      }
    } catch { throw ('Get-CoordClaims: ' + $failure) }
  }
}
