#
# Pester tests for the New-PesterTestFile synthesis engine.
#
# $TestFileDir is injected by Invoke-PesterForActiveFile.ps1 via New-PesterContainer -Data.
# When run directly (e.g. via tasks or plain Invoke-Pester), it falls back to $PSScriptRoot.
param($TestFileDir)

# ── Load dependencies in BeforeAll (run phase) ───────────────────────────────

BeforeAll {
  $here = if ($TestFileDir) { $TestFileDir } else { $PSScriptRoot }
  if (-not $here) { throw 'Cannot determine test file directory — $PSScriptRoot and $TestFileDir are both empty.' }
  # Resolve the public/ directory using single-string Join-Path calls (no comma-array
  # syntax) so that Pester's InvokeWithContext binding does not drop the ChildPath arg.
  $publicDir = [System.IO.Path]::GetFullPath((Join-Path $here '..\..\public'))
  . (Join-Path $publicDir 'New-PesterItBlock.ps1')
  . (Join-Path $publicDir 'New-PesterContextBlock.ps1')
  . (Join-Path $publicDir 'New-PesterDescribeBlock.ps1')
  . (Join-Path $publicDir 'New-PesterFileModel.ps1')
  . (Join-Path $publicDir 'New-PesterTestFile.ps1')
}

# ── Shared helpers (BeforeDiscovery-safe) ────────────────────────────────────

BeforeDiscovery {
  $script:itBlock = @{
    Name      = 'MyFunction_ValidInput_ReturnsTrue'
    Tags      = @()
    TestCases = $null
    ForEach   = $null
    Body      = '$result = $true; $result | Should -BeTrue'
  }
  $script:describeBlock = @{
    Name       = 'MyFunction'
    Tags       = @('Unit')
    BeforeAll  = ". Join-Path `$PSScriptRoot '..', 'public', 'MyFunction.ps1'"
    BeforeEach = $null
    AfterEach  = $null
    AfterAll   = $null
    Contexts   = @()
    Its        = @($script:itBlock)
  }
}

Describe 'New-PesterTestFile' -Tag 'Unit', 'PesterKind' {

  BeforeAll {
    # Build a minimal model used in multiple tests
    $script:minIt = New-PesterItBlock -Name 'Minimal_It_PassesAssertion' `
      -Body '$true | Should -BeTrue'
    $script:minDescribe = New-PesterDescribeBlock -Name 'Minimal' `
      -Its @($script:minIt)
    $script:minModel = New-PesterFileModel -Name 'Minimal' `
      -Describes @($script:minDescribe)
  }

  Context 'When given a minimal model' {
    It 'New-PesterTestFile_MinimalModel_ReturnsNonEmptyString' {
      $result = New-PesterTestFile -Model $script:minModel
      $result | Should -Not -BeNullOrEmpty
    }

    It 'New-PesterTestFile_MinimalModel_ContainsDescribeKeyword' {
      $result = New-PesterTestFile -Model $script:minModel
      $result | Should -Match "Describe 'Minimal'"
    }

    It 'New-PesterTestFile_MinimalModel_ContainsItKeyword' {
      $result = New-PesterTestFile -Model $script:minModel
      $result | Should -Match "It 'Minimal_It_PassesAssertion'"
    }

    It 'New-PesterTestFile_MinimalModel_ContainsItBody' {
      $result = New-PesterTestFile -Model $script:minModel
      $result | Should -Match '\$true \| Should -BeTrue'
    }

    It 'New-PesterTestFile_MinimalModel_StartsWithHeaderComment' {
      $result = New-PesterTestFile -Model $script:minModel
      $result.TrimStart() | Should -Match '^#'
    }
  }

  Context 'When model includes Tags on Describe' {
    It 'New-PesterTestFile_DescribeWithTags_TagsRenderedInOutput' {
      $it = New-PesterItBlock -Name 'Tagged_It' -Body 'true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'TaggedDescribe' -Tags @('Smoke') `
        -Its @($it)
      $m = New-PesterFileModel -Name 'Tagged' -Describes @($d)
      $r = New-PesterTestFile -Model $m
      $r | Should -Match "-Tag 'Smoke'"
    }
  }

  Context 'When model includes a BeforeAll block in Describe' {
    It 'New-PesterTestFile_DescribeWithBeforeAll_BeforeAllRendered' {
      $it = New-PesterItBlock -Name 'Setup_It' -Body 'true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'WithSetup' `
        -BeforeAll '. Join-Path $PSScriptRoot "src.ps1"' `
        -Its @($it)
      $m = New-PesterFileModel -Name 'WithSetup' -Describes @($d)
      $r = New-PesterTestFile -Model $m
      $r | Should -Match 'BeforeAll \{'
      $r | Should -Match '"src\.ps1"'
    }
  }

  Context 'When model includes a BeforeDiscovery block' {
    It 'New-PesterTestFile_WithBeforeDiscovery_BeforeDiscoveryRendered' {
      $it = New-PesterItBlock -Name 'Discovery_It' -Body 'true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'Discovery' -Its @($it)
      $m = New-PesterFileModel -Name 'Discovery' `
        -Describes @($d) `
        -BeforeDiscovery '$script:data = @(1,2,3)'
      $r = New-PesterTestFile -Model $m
      $r | Should -Match 'BeforeDiscovery \{'
      $r | Should -Match '\$script:data = @\(1,2,3\)'
    }
  }

  Context 'When model includes a Context block' {
    It 'New-PesterTestFile_WithContext_ContextKeywordRendered' {
      $it = New-PesterItBlock -Name 'Ctx_It' -Body 'true | Should -BeTrue'
      $ctx = New-PesterContextBlock -Name 'When conditions are met' -Its @($it)
      $d = New-PesterDescribeBlock -Name 'WithContext' -Contexts @($ctx)
      $m = New-PesterFileModel -Name 'WithContext' -Describes @($d)
      $r = New-PesterTestFile -Model $m
      $r | Should -Match "Context 'When conditions are met'"
    }
  }

  Context 'When model includes a ForEach on a Context block' {
    It 'New-PesterTestFile_ContextWithForEach_ForEachRendered' {
      $it = New-PesterItBlock -Name 'FE_It' -Body '$_ | Should -Not -BeNull'
      $ctx = New-PesterContextBlock -Name 'Cases' -Its @($it) -ForEach '$testCases'
      $d = New-PesterDescribeBlock -Name 'FEDescribe' -Contexts @($ctx)
      $m = New-PesterFileModel -Name 'FEDescribe' -Describes @($d)
      $r = New-PesterTestFile -Model $m
      $r | Should -Match '-ForEach \$testCases'
    }
  }

  Context 'When model includes an It block with ForEach' {
    It 'New-PesterTestFile_ItWithForEach_ForEachRenderedOnItLine' {
      $it = New-PesterItBlock -Name 'DD_It' -Body '$_ | Should -Be 1' `
        -ForEach '$items'
      $d = New-PesterDescribeBlock -Name 'DDDescribe' -Its @($it)
      $m = New-PesterFileModel -Name 'DDDescribe' -Describes @($d)
      $r = New-PesterTestFile -Model $m
      $r | Should -Match "It 'DD_It' -ForEach \`$items"
    }
  }

  Context 'When model has an empty Describes list' {
    It 'New-PesterTestFile_EmptyDescribes_ThrowsInvalidModel' {
      { New-PesterTestFile -Model @{ Name = 'X'; Describes = @() } } | Should -Throw
    }
  }

  Context 'When model is missing required keys' {
    It 'New-PesterTestFile_MissingNameKey_Throws' {
      { New-PesterTestFile -Model @{ Describes = @(@{ Name = 'D'; Its = @() }) } } | Should -Throw
    }

    It 'New-PesterTestFile_MissingDescribesKey_Throws' {
      { New-PesterTestFile -Model @{ Name = 'X' } } | Should -Throw
    }
  }

  Context 'When writing to disk' {
    BeforeAll {
      $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterKindTests_$([System.IO.Path]::GetRandomFileName())"
      New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
      if (Test-Path $script:tempDir) {
        Remove-Item -Recurse -Force $script:tempDir
      }
    }

    It 'New-PesterTestFile_WithOutputPath_WritesFileToCorrectLocation' {
      $it = New-PesterItBlock -Name 'Disk_It' -Body 'true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'DiskWrite' -Its @($it)
      $m = New-PesterFileModel -Name 'DiskWrite' -Describes @($d)
      New-PesterTestFile -Model $m -OutputPath $script:tempDir -Force
      $expectedPath = Join-Path $script:tempDir 'DiskWrite.Tests.ps1'
      Test-Path $expectedPath | Should -BeTrue
    }

    It 'New-PesterTestFile_ExistingFileWithoutForce_Throws' {
      $it = New-PesterItBlock -Name 'Conflict_It' -Body 'true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'Conflict' -Its @($it)
      $m = New-PesterFileModel -Name 'Conflict' -Describes @($d)
      # Write once
      New-PesterTestFile -Model $m -OutputPath $script:tempDir -Force
      # Second write without Force should throw
      { New-PesterTestFile -Model $m -OutputPath $script:tempDir } | Should -Throw
    }

    It 'New-PesterTestFile_ExistingFileWithForce_OverwritesFile' {
      $it1 = New-PesterItBlock -Name 'Overwrite_It_V1' -Body 'true | Should -BeTrue'
      $d1 = New-PesterDescribeBlock -Name 'Overwrite' -Its @($it1)
      $m1 = New-PesterFileModel -Name 'Overwrite' -Describes @($d1)
      New-PesterTestFile -Model $m1 -OutputPath $script:tempDir -Force

      $it2 = New-PesterItBlock -Name 'Overwrite_It_V2' -Body 'false | Should -BeFalse'
      $d2 = New-PesterDescribeBlock -Name 'Overwrite' -Its @($it2)
      $m2 = New-PesterFileModel -Name 'Overwrite' -Describes @($d2)
      New-PesterTestFile -Model $m2 -OutputPath $script:tempDir -Force

      $content = Get-Content (Join-Path $script:tempDir 'Overwrite.Tests.ps1') -Raw
      $content | Should -Match 'Overwrite_It_V2'
    }

    It 'New-PesterTestFile_WrittenFile_ContainsValidPesterDSL' {
      $it = New-PesterItBlock -Name 'Valid_DSL_It' -Body '$true | Should -BeTrue'
      $d = New-PesterDescribeBlock -Name 'ValidDSL' -Its @($it)
      $m = New-PesterFileModel -Name 'ValidDSL' -Describes @($d)
      New-PesterTestFile -Model $m -OutputPath $script:tempDir -Force
      $content = Get-Content (Join-Path $script:tempDir 'ValidDSL.Tests.ps1') -Raw
      $content | Should -Match "Describe 'ValidDSL'"
      $content | Should -Match "It 'Valid_DSL_It'"
      $content | Should -Match 'Should -BeTrue'
    }
  }
}
