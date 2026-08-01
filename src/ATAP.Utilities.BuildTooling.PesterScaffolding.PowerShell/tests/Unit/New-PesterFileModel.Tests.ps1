#
# Pester tests for the Pester Kind data-model builder functions:
#   New-PesterFileModel, New-PesterDescribeBlock, New-PesterContextBlock, New-PesterItBlock
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

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'New-PesterItBlock' -Tag 'Unit', 'PesterKind' {

  Context 'When called with required parameters' {
    It 'New-PesterItBlock_RequiredParams_ReturnsHashtableWithExpectedKeys' {
      $result = New-PesterItBlock -Name 'MyFunc_State_Expected' -Body 'true | Should -BeTrue'
      $result | Should -BeOfType [hashtable]
      $result['Name'] | Should -Be 'MyFunc_State_Expected'
      $result['Body'] | Should -Be 'true | Should -BeTrue'
    }

    It 'New-PesterItBlock_RequiredParams_TagsDefaultToEmpty' {
      $result = New-PesterItBlock -Name 'Test' -Body 'true | Should -BeTrue'
      $result['Tags'] | Should -HaveCount 0
    }

    It 'New-PesterItBlock_RequiredParams_ForEachDefaultsToNull' {
      $result = New-PesterItBlock -Name 'Test' -Body 'true | Should -BeTrue'
      $result['ForEach'] | Should -BeNullOrEmpty
    }
  }

  Context 'When called with Tags' {
    It 'New-PesterItBlock_WithTags_StoredInModel' {
      $result = New-PesterItBlock -Name 'Test' -Body 'true | Should -BeTrue' -Tags @('Unit', 'Smoke')
      $result['Tags'] | Should -Contain 'Unit'
      $result['Tags'] | Should -Contain 'Smoke'
    }
  }

  Context 'When called with ForEach' {
    It 'New-PesterItBlock_WithForEach_StoredInModel' {
      $result = New-PesterItBlock -Name 'Test' -Body '$_ | Should -Not -BeNull' -ForEach '$testCases'
      $result['ForEach'] | Should -Be '$testCases'
    }
  }

  Context 'When called with TestCases' {
    It 'New-PesterItBlock_WithTestCases_StoredInModel' {
      $result = New-PesterItBlock -Name 'Test' -Body '$_ | Should -Not -BeNull' -TestCases '@(@{X=1})'
      $result['TestCases'] | Should -Be '@(@{X=1})'
    }
  }

  Context 'When Name is empty' {
    It 'New-PesterItBlock_EmptyName_ThrowsParameterBindingException' {
      { New-PesterItBlock -Name '' -Body 'true | Should -BeTrue' } | Should -Throw
    }
  }

  Context 'When Body is empty' {
    It 'New-PesterItBlock_EmptyBody_ThrowsParameterBindingException' {
      { New-PesterItBlock -Name 'Test' -Body '' } | Should -Throw
    }
  }
}

Describe 'New-PesterContextBlock' -Tag 'Unit', 'PesterKind' {

  BeforeAll {
    $script:sampleIt = New-PesterItBlock -Name 'SampleIt' -Body 'true | Should -BeTrue'
  }

  Context 'When called with required parameters' {
    It 'New-PesterContextBlock_RequiredParams_ReturnsHashtable' {
      $result = New-PesterContextBlock -Name 'When something happens' -Its @($script:sampleIt)
      $result | Should -BeOfType [hashtable]
      $result['Name'] | Should -Be 'When something happens'
    }

    It 'New-PesterContextBlock_RequiredParams_ItsStoredCorrectly' {
      $result = New-PesterContextBlock -Name 'Context A' -Its @($script:sampleIt)
      $result['Its'] | Should -HaveCount 1
      $result['Its'][0]['Name'] | Should -Be 'SampleIt'
    }

    It 'New-PesterContextBlock_RequiredParams_SetupTeardownDefaultToNull' {
      $result = New-PesterContextBlock -Name 'Context A' -Its @($script:sampleIt)
      $result['BeforeAll']  | Should -BeNullOrEmpty
      $result['BeforeEach'] | Should -BeNullOrEmpty
      $result['AfterEach']  | Should -BeNullOrEmpty
      $result['AfterAll']   | Should -BeNullOrEmpty
    }
  }

  Context 'When called with ForEach' {
    It 'New-PesterContextBlock_WithForEach_StoredInModel' {
      $result = New-PesterContextBlock -Name 'Context FE' -Its @($script:sampleIt) -ForEach '$data'
      $result['ForEach'] | Should -Be '$data'
    }
  }

  Context 'When Name is empty' {
    It 'New-PesterContextBlock_EmptyName_Throws' {
      { New-PesterContextBlock -Name '' -Its @($script:sampleIt) } | Should -Throw
    }
  }
}

Describe 'New-PesterDescribeBlock' -Tag 'Unit', 'PesterKind' {

  BeforeAll {
    $script:sampleIt = New-PesterItBlock -Name 'DescribeIt' -Body 'true | Should -BeTrue'
  }

  Context 'When called with only required parameters' {
    It 'New-PesterDescribeBlock_RequiredParams_ReturnsHashtable' {
      $result = New-PesterDescribeBlock -Name 'My Function'
      $result | Should -BeOfType [hashtable]
      $result['Name'] | Should -Be 'My Function'
    }

    It 'New-PesterDescribeBlock_RequiredParams_ItsDefaultsToEmpty' {
      $result = New-PesterDescribeBlock -Name 'My Function'
      $result['Its'] | Should -HaveCount 0
    }

    It 'New-PesterDescribeBlock_RequiredParams_ContextsDefaultsToEmpty' {
      $result = New-PesterDescribeBlock -Name 'My Function'
      $result['Contexts'] | Should -HaveCount 0
    }
  }

  Context 'When called with Its and Tags' {
    It 'New-PesterDescribeBlock_WithItsAndTags_StoredCorrectly' {
      $result = New-PesterDescribeBlock -Name 'My Function' `
        -Tags @('Unit') `
        -Its  @($script:sampleIt)
      $result['Tags']  | Should -Contain 'Unit'
      $result['Its']   | Should -HaveCount 1
    }
  }

  Context 'When Name is empty' {
    It 'New-PesterDescribeBlock_EmptyName_Throws' {
      { New-PesterDescribeBlock -Name '' } | Should -Throw
    }
  }
}

Describe 'New-PesterFileModel' -Tag 'Unit', 'PesterKind' {

  BeforeAll {
    $script:sampleIt = New-PesterItBlock -Name 'FileModelIt' -Body 'true | Should -BeTrue'
    $script:sampleDescribe = New-PesterDescribeBlock -Name 'FileModel Describe' -Its @($script:sampleIt)
  }

  BeforeEach {
    Mock Write-PSFMessage { }
  }

  Context 'When called with required parameters' {
    It 'New-PesterFileModel_RequiredParams_ReturnsHashtableWithCorrectKeys' {
      $result = New-PesterFileModel -Name 'MyModule' -Describes @($script:sampleDescribe)
      $result | Should -BeOfType [hashtable]
      $result['Name']      | Should -Be 'MyModule'
      $result['Extension'] | Should -Be '.Tests.ps1'
    }

    It 'New-PesterFileModel_RequiredParams_DescribesStored' {
      $result = New-PesterFileModel -Name 'MyModule' -Describes @($script:sampleDescribe)
      $result['Describes'] | Should -HaveCount 1
      $result['Describes'][0]['Name'] | Should -Be 'FileModel Describe'
    }

    It 'New-PesterFileModel_RequiredParams_BeforeDiscoveryDefaultsToNull' {
      $result = New-PesterFileModel -Name 'MyModule' -Describes @($script:sampleDescribe)
      $result['BeforeDiscovery'] | Should -BeNullOrEmpty
    }
  }

  Context 'When called with BeforeDiscovery' {
    It 'New-PesterFileModel_WithBeforeDiscovery_StoredInModel' {
      $result = New-PesterFileModel -Name 'MyModule' `
        -Describes       @($script:sampleDescribe) `
        -BeforeDiscovery '$data = @(1,2,3)'
      $result['BeforeDiscovery'] | Should -Be '$data = @(1,2,3)'
    }
  }

  Context 'When Describes is empty' {
    It 'New-PesterFileModel_EmptyDescribes_ThrowsParameterBindingException' {
      { New-PesterFileModel -Name 'MyModule' -Describes @() } | Should -Throw
    }
  }

  Context 'When a Describe block lacks a Name key' {
    It 'New-PesterFileModel_DescribeWithoutName_Throws' {
      { New-PesterFileModel -Name 'MyModule' -Describes @(@{ Tags = @('Unit') }) } | Should -Throw
    }
  }

  Context 'When custom extension supplied' {
    It 'New-PesterFileModel_CustomExtension_StoredInModel' {
      $result = New-PesterFileModel -Name 'MyModule' `
        -Describes @($script:sampleDescribe) `
        -Extension '.Spec.ps1'
      $result['Extension'] | Should -Be '.Spec.ps1'
    }
  }
}
