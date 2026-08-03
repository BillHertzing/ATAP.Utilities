BeforeAll {
  $script:moduleRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
  $script:moduleName = 'ATAP.Utilities.GELFLogging.Powershell'
  $script:manifestPath = Join-Path $script:moduleRoot "$($script:moduleName).psd1"
}

Describe 'ATAP.Utilities.GELFLogging.Powershell module contract' -Tag 'Unit' {

  It 'has a valid module manifest' {
    { Test-ModuleManifest -Path $script:manifestPath -ErrorAction Stop } | Should -Not -Throw
  }

  It 'ships at the Task 14.62 initial version 0.1.1' {
    (Import-PowerShellDataFile -Path $script:manifestPath).ModuleVersion | Should -Be '0.1.1'
  }

  It 'keeps version.json in step with the manifest' {
    # A drifted pair silently publishes a package whose folder version and manifest version
    # disagree, which the installer resolves inconsistently.
    $versionJson = Get-Content -LiteralPath (Join-Path $script:moduleRoot 'version.json') -Raw | ConvertFrom-Json
    $versionJson.version | Should -Be (Import-PowerShellDataFile -Path $script:manifestPath).ModuleVersion
  }

  It 'exports exactly the enable/disable/query trio' {
    $expected = @('Disable-SeqGelfLogging', 'Enable-SeqGelfLogging', 'Get-SeqGelfLoggingStatus')
    $manifest = Import-PowerShellDataFile -Path $script:manifestPath
    @($manifest.FunctionsToExport | Sort-Object) | Should -Be @($expected | Sort-Object)
  }

  It 'declares the same export list in the manifest and the psm1' {
    $manifest = Import-PowerShellDataFile -Path $script:manifestPath
    $psm1 = Get-Content -LiteralPath (Join-Path $script:moduleRoot "$($script:moduleName).psm1") -Raw
    foreach ($fn in $manifest.FunctionsToExport) {
      $psm1 | Should -BeLike "*'$fn'*" -Because "the psm1 Export-ModuleMember must list $fn"
    }
  }

  It 'backs every exported function with a file in public\' {
    $manifest = Import-PowerShellDataFile -Path $script:manifestPath
    foreach ($fn in $manifest.FunctionsToExport) {
      Test-Path -LiteralPath (Join-Path $script:moduleRoot "public\$fn.ps1") | Should -BeTrue -Because "$fn must have a public source file"
    }
  }

  It 'exports no aliases, so AliasesToExport cannot name an undefined alias' {
    (Import-PowerShellDataFile -Path $script:manifestPath).AliasesToExport | Should -BeNullOrEmpty
  }

  It 'requires PSFramework but NOT PSGELF' {
    # PSGELF is the UDP transport, needed only to ENABLE. Requiring it would force a host
    # that merely wants to disable or query the sink to install the transport first.
    $manifest = Import-PowerShellDataFile -Path $script:manifestPath
    @($manifest.RequiredModules.ModuleName) | Should -Contain 'PSFramework'
    @($manifest.RequiredModules.ModuleName) | Should -Not -Contain 'PSGELF'
    @($manifest.PrivateData.PSData.ExternalModuleDependencies) | Should -Contain 'PSGELF'
  }

  It 'parses every source file' {
    $errors = $null
    foreach ($file in (Get-ChildItem -LiteralPath $script:moduleRoot -Filter '*.ps1' -Recurse -File)) {
      $parseErrors = $null
      [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
      if ($parseErrors) { $errors = "$($file.Name): $($parseErrors[0].Message)"; break }
    }
    $errors | Should -BeNullOrEmpty
  }

  It 'names this module, not the parent, in every PSFramework message' {
    # Copy/paste from ATAP.Utilities.PowerShell would leave $mn pointing at the parent, so
    # SEQ would attribute this module's telemetry to the umbrella.
    foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $script:moduleRoot 'public') -Filter '*.ps1' -File)) {
      $content = Get-Content -LiteralPath $file.FullName -Raw
      if ($content -match "\`$mn\s*=\s*'([^']+)'") {
        $Matches[1] | Should -Be $script:moduleName -Because "$($file.Name) must report its own module name"
      }
    }
  }

  It 'ships the documentation set a child module is expected to carry' {
    foreach ($doc in 'ReadMe.md', 'ReleaseNotes.md', 'INDEX.md', 'Documentation\Overview.md') {
      Test-Path -LiteralPath (Join-Path $script:moduleRoot $doc) | Should -BeTrue -Because "$doc is part of the child-module contract"
    }
  }

  It 'never contains a literal SEQ API key' {
    # The key is referenced by SecretName only and resolved through Get-SecretATAP.
    foreach ($file in (Get-ChildItem -LiteralPath $script:moduleRoot -Filter '*.ps1' -Recurse -File)) {
      $content = Get-Content -LiteralPath $file.FullName -Raw
      $content | Should -Not -Match "X-Seq-ApiKey'\s*=\s*'[A-Za-z0-9]{8,}"
    }
  }
}
