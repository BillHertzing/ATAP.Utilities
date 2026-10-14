<#
.SYNOPSIS
  Generate THIRD-PARTY-NOTICES.md for ATAP.Utilities from central package management.

.DESCRIPTION
  Task 15.185.j. Reads Directory.Packages.props, skips first-party ATAP.* packages,
  and emits one notice row per remaining PackageVersion. License facts are read from
  the packed .nuspec of the restored package and from any LICENSE/COPYING/NOTICE file
  the package carries; nothing is inferred. A package that is not restored on the
  current workstation is emitted with a state of UNRESOLVED rather than omitted, so a
  missing notice is always visible as a row instead of as a silent gap.

  This script reports declared bytes. It is not a license-compatibility analysis and
  it is not legal advice.

.PARAMETER RepoRoot
  Repository root. Defaults to the parent of this script's directory.

.PARAMETER GlobalPackagesFolder
  NuGet global packages folder. Defaults to $env:USERPROFILE\.nuget\packages.

.PARAMETER OutputPath
  Destination notices file. Defaults to <RepoRoot>\THIRD-PARTY-NOTICES.md.

.EXAMPLE
  pwsh -File Build\New-ThirdPartyNotices.ps1
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateNotNullOrEmpty()][string] $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateNotNullOrEmpty()][string] $GlobalPackagesFolder = (Join-Path $env:USERPROFILE '.nuget\packages'),
  [AllowEmptyString()][string] $OutputPath = ''
)

function New-ThirdPartyNotices {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $RepoRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $GlobalPackagesFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $OutputPath
  )

  begin {
    $fn = 'New-ThirdPartyNotices'
    $mn = 'ATAP.Utilities.Licensing'
    if (-not (Get-Command -Name Write-PSFMessage -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
      function Write-PSFMessage { param([string]$FunctionName, [string]$ModuleName, [string]$Level, [string]$Message, [string[]]$Tag) if ($Level -in @('Important', 'Warning', 'Error')) { [Console]::Out.WriteLine("$Level [$FunctionName] $Message") } }
    }
    $propsPath = Join-Path $RepoRoot 'Directory.Packages.props'
    if (-not (Test-Path -LiteralPath $propsPath)) { throw "Directory.Packages.props not found at '$propsPath'." }
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($OutputPath, 'Generate third-party notices')) { return $null }

    [xml] $props = Get-Content -LiteralPath $propsPath -Raw
    $entries = foreach ($pv in $props.Project.ItemGroup.PackageVersion) {
      if (-not $pv.Include) { continue }
      if ($pv.Include -like 'ATAP.*') { continue }

      $id = [string] $pv.Include
      $version = [string] $pv.Version
      $dir = Join-Path $GlobalPackagesFolder (Join-Path $id.ToLowerInvariant() $version)
      $nuspecPath = Join-Path $dir ("{0}.nuspec" -f $id.ToLowerInvariant())

      $state = 'UNRESOLVED'
      $license = ''
      $copyright = ''
      $project = ''
      $noticeFiles = @()

      if (Test-Path -LiteralPath $nuspecPath) {
        $state = 'declared'
        [xml] $nuspec = Get-Content -LiteralPath $nuspecPath -Raw
        $metadata = $nuspec.package.metadata
        if ($metadata.license) {
          $license = switch ([string] $metadata.license.type) {
            'expression' { 'SPDX ' + [string] $metadata.license.'#text' }
            'file' { 'file: ' + [string] $metadata.license.'#text' }
            default { [string] $metadata.license.'#text' }
          }
        }
        if (-not $license -and $metadata.licenseUrl) { $license = 'url: ' + [string] $metadata.licenseUrl }
        if (-not $license) { $state = 'NO-DECLARED-LICENSE' }
        $copyright = [string] $metadata.copyright
        $project = [string] $metadata.projectUrl
        $noticeFiles = @(
          Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(LICEN[CS]E|COPYING|NOTICE)' } |
            ForEach-Object { $_.Name } | Sort-Object -Unique
        )
      }

      [pscustomobject] @{
        Id          = $id
        Version     = $version
        State       = $state
        License     = $license
        Copyright   = $copyright
        ProjectUrl  = $project
        NoticeFiles = ($noticeFiles -join '; ')
      }
    }

    $sorted = $entries | Sort-Object Id, Version
    $unresolved = @($sorted | Where-Object { $_.State -ne 'declared' })

    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('# Third-party notices — ATAP.Utilities')
    $lines.Add('')
    $lines.Add('<!-- GENERATED FILE. Do not edit by hand. -->')
    $lines.Add('<!-- Regenerate with: pwsh -File Build\New-ThirdPartyNotices.ps1 -->')
    $lines.Add('')
    $lines.Add('ATAP.Utilities is distributed under the MIT License (see `LICENSE`). It depends on')
    $lines.Add('the third-party packages listed below, each of which remains subject to its own terms.')
    $lines.Add('')
    $lines.Add('Every row records what the named package version **declares** in its packed `.nuspec`')
    $lines.Add('and which notice files it carries. Rows are not a license-compatibility analysis and')
    $lines.Add('are not legal advice.')
    $lines.Add('')
    $lines.Add('> **Not every dependency here is open source.** At least one package family in this')
    $lines.Add('> list is commercially licensed with a usage quota rather than an OSI license. Read')
    $lines.Add('> the License column; do not assume the MIT license on ATAP.Utilities'' own code')
    $lines.Add('> extends to any dependency.')
    $lines.Add('')
    $lines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd')))
    $lines.Add(('Entries: {0} ({1} unresolved on the generating workstation)' -f $sorted.Count, $unresolved.Count))
    $lines.Add('')
    $lines.Add('| Package | Version | State | License as declared | Copyright | Notice files in package |')
    $lines.Add('| --- | --- | --- | --- | --- | --- |')
    foreach ($entry in $sorted) {
      $lines.Add(('| `{0}` | `{1}` | {2} | {3} | {4} | {5} |' -f
        $entry.Id, $entry.Version, $entry.State,
        ($entry.License -replace '\|', '\|'),
        ($entry.Copyright -replace '\|', '\|'),
        $entry.NoticeFiles))
    }
    $lines.Add('')
    $lines.Add('## Unresolved entries')
    $lines.Add('')
    if ($unresolved.Count -eq 0) {
      $lines.Add('None. Every listed package was restored and its declared license was read.')
    }
    else {
      $lines.Add('The following packages were **not restored** on the workstation that generated this')
      $lines.Add('file, or declare no license at all. Their licenses are **unknown, not absent**, and')
      $lines.Add('must be resolved before a distribution that includes them.')
      $lines.Add('')
      foreach ($entry in $unresolved) {
        $lines.Add(('- `{0}` `{1}` — {2}' -f $entry.Id, $entry.Version, $entry.State))
      }
    }
    $lines.Add('')

    [IO.File]::WriteAllText($OutputPath, ($lines -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote $($sorted.Count) third-party notice entries to '$OutputPath' ($($unresolved.Count) unresolved)." -Tag 'Licensing'
    [pscustomobject] @{ OutputPath = $OutputPath; Count = $sorted.Count; UnresolvedCount = $unresolved.Count }
  }

  end { }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $RepoRoot 'THIRD-PARTY-NOTICES.md' }
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  New-ThirdPartyNotices -RepoRoot $RepoRoot -GlobalPackagesFolder $GlobalPackagesFolder -OutputPath $OutputPath
}
