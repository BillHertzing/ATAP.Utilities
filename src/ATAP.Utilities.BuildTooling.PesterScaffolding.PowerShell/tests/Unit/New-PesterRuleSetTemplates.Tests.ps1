#
# Pester tests for the Pester Kind RuleSet template functions:
#   New-PesterBasicUnitTestTemplate, New-PesterDataDrivenTestTemplate
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
  . (Join-Path $publicDir 'New-PesterBasicUnitTestTemplate.ps1')
  . (Join-Path $publicDir 'New-PesterDataDrivenTestTemplate.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
  }
}

Describe 'New-PesterBasicUnitTestTemplate' -Tag 'Unit', 'PesterKind' {
  BeforeEach {
    Mock Write-PSFMessage { }
  }

  BeforeAll {
    $script:sampleScenarios = @(
      @{
        Name = 'When the function succeeds'
        Its  = @(
          New-PesterItBlock -Name 'MyFunc_ValidInput_ReturnsTrue' `
            -Body '$result = $true; $result | Should -BeTrue'
        )
      }
    )
  }

  Context 'When called with required parameters and no OutputPath' {
    It 'New-PesterBasicUnitTestTemplate_RequiredParams_ReturnsHashtable' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model | Should -BeOfType [hashtable]
      $model['Name'] | Should -Be 'MyFunc'
    }

    It 'New-PesterBasicUnitTestTemplate_RequiredParams_ModelHasOneDescribe' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model['Describes'] | Should -HaveCount 1
    }

    It 'New-PesterBasicUnitTestTemplate_RequiredParams_DescribeNameMatchesFunction' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model['Describes'][0]['Name'] | Should -Be 'MyFunc'
    }

    It 'New-PesterBasicUnitTestTemplate_RequiredParams_BeforeAllContainsDotSource' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model['Describes'][0]['BeforeAll'] | Should -Match '\. Join-Path'
      $model['Describes'][0]['BeforeAll'] | Should -Match "'MyFunc.ps1'"
    }

    It 'New-PesterBasicUnitTestTemplate_RequiredParams_ContextCountMatchesScenarios' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model['Describes'][0]['Contexts'] | Should -HaveCount 1
    }

    It 'New-PesterBasicUnitTestTemplate_RequiredParams_DefaultTagsIncludeUnit' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'MyFunc' `
        -SourceRelativePath '..', 'public', 'MyFunc.ps1' `
        -Scenarios          $script:sampleScenarios
      $model['Describes'][0]['Tags'] | Should -Contain 'Unit'
    }
  }

  Context 'When generating rendered output via New-PesterTestFile' {
    It 'New-PesterBasicUnitTestTemplate_Rendered_ContainsDescribeBlock' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'GetSomething' `
        -SourceRelativePath '..', 'public', 'GetSomething.ps1' `
        -Scenarios          $script:sampleScenarios
      $text = New-PesterTestFile -Model $model
      $text | Should -Match "Describe 'GetSomething'"
    }

    It 'New-PesterBasicUnitTestTemplate_Rendered_ContainsBeforeAllBlock' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'GetSomething' `
        -SourceRelativePath '..', 'public', 'GetSomething.ps1' `
        -Scenarios          $script:sampleScenarios
      $text = New-PesterTestFile -Model $model
      $text | Should -Match 'BeforeAll \{'
    }

    It 'New-PesterBasicUnitTestTemplate_Rendered_ContainsContextBlock' {
      $model = New-PesterBasicUnitTestTemplate `
        -FunctionName       'GetSomething' `
        -SourceRelativePath '..', 'public', 'GetSomething.ps1' `
        -Scenarios          $script:sampleScenarios
      $text = New-PesterTestFile -Model $model
      $text | Should -Match "Context 'When the function succeeds'"
    }
  }

  Context 'When OutputPath is supplied' {
    BeforeAll {
      $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterKindBasic_$([System.IO.Path]::GetRandomFileName())"
      New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
      if (Test-Path $script:tempDir) {
        Remove-Item -Recurse -Force $script:tempDir
      }
    }

    It 'New-PesterBasicUnitTestTemplate_WithOutputPath_WritesTestFileOnDisk' {
      New-PesterBasicUnitTestTemplate `
        -FunctionName       'WrittenFunc' `
        -SourceRelativePath '..', 'public', 'WrittenFunc.ps1' `
        -OutputPath         $script:tempDir `
        -Force `
        -Scenarios          $script:sampleScenarios | Out-Null
      Test-Path (Join-Path $script:tempDir 'WrittenFunc.Tests.ps1') | Should -BeTrue
    }
  }
}

Describe 'New-PesterDataDrivenTestTemplate' -Tag 'Unit', 'PesterKind' {
  BeforeEach {
    Mock Write-PSFMessage { }
  }

  Context 'When called with required parameters and no OutputPath' {
    It 'New-PesterDataDrivenTestTemplate_RequiredParams_ReturnsHashtable' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'ConvertVal' `
        -SourceRelativePath '..', 'public', 'ConvertVal.ps1' `
        -ItName             'ConvertVal_<Name>_ReturnsExpected' `
        -ItBody             'ConvertVal -Input $_.Input | Should -Be $_.Expected'
      $model | Should -BeOfType [hashtable]
      $model['Name'] | Should -Be 'ConvertVal'
    }

    It 'New-PesterDataDrivenTestTemplate_RequiredParams_BeforeDiscoveryPopulated' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'ConvertVal' `
        -SourceRelativePath '..', 'public', 'ConvertVal.ps1' `
        -ItName             'ConvertVal_<Name>_ReturnsExpected' `
        -ItBody             'ConvertVal -Input $_.Input | Should -Be $_.Expected'
      $model['BeforeDiscovery'] | Should -Not -BeNullOrEmpty
    }

    It 'New-PesterDataDrivenTestTemplate_RequiredParams_HasOneContext' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'ConvertVal' `
        -SourceRelativePath '..', 'public', 'ConvertVal.ps1' `
        -ItName             'ConvertVal_<Name>_ReturnsExpected' `
        -ItBody             'ConvertVal -Input $_.Input | Should -Be $_.Expected'
      $model['Describes'][0]['Contexts'] | Should -HaveCount 1
    }

    It 'New-PesterDataDrivenTestTemplate_RequiredParams_ItHasForEachSet' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'ConvertVal' `
        -SourceRelativePath '..', 'public', 'ConvertVal.ps1' `
        -ItName             'ConvertVal_<Name>_ReturnsExpected' `
        -ItBody             'ConvertVal -Input $_.Input | Should -Be $_.Expected'
      $it = $model['Describes'][0]['Contexts'][0]['Its'][0]
      $it['ForEach'] | Should -Not -BeNullOrEmpty
    }
  }

  Context 'When TestCasesExpression is provided' {
    It 'New-PesterDataDrivenTestTemplate_WithTestCasesExpr_ExprStoredInDiscovery' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName            'Calc' `
        -SourceRelativePath      '..', 'public', 'Calc.ps1' `
        -TestCasesExpression     '@(@{Input=1;Expected=2})' `
        -ItName                  'Calc_<Name>_ReturnsExpected' `
        -ItBody                  'Calc -Input $_.Input | Should -Be $_.Expected'
      $model['BeforeDiscovery'] | Should -Match '@\(@\{Input=1;Expected=2\}\)'
    }
  }

  Context 'When rendering the model to text' {
    It 'New-PesterDataDrivenTestTemplate_Rendered_ContainsBeforeDiscovery' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'CalcTwo' `
        -SourceRelativePath '..', 'public', 'CalcTwo.ps1' `
        -ItName             'CalcTwo_It' `
        -ItBody             'true | Should -BeTrue'
      $text = New-PesterTestFile -Model $model
      $text | Should -Match 'BeforeDiscovery \{'
    }

    It 'New-PesterDataDrivenTestTemplate_Rendered_ItContainsForEach' {
      $model = New-PesterDataDrivenTestTemplate `
        -FunctionName       'CalcThree' `
        -SourceRelativePath '..', 'public', 'CalcThree.ps1' `
        -ItName             'CalcThree_It' `
        -ItBody             'true | Should -BeTrue'
      $text = New-PesterTestFile -Model $model
      $text | Should -Match '-ForEach'
    }
  }

  Context 'When OutputPath is supplied' {
    BeforeAll {
      $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PesterKindDD_$([System.IO.Path]::GetRandomFileName())"
      New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
      if (Test-Path $script:tempDir) {
        Remove-Item -Recurse -Force $script:tempDir
      }
    }

    It 'New-PesterDataDrivenTestTemplate_WithOutputPath_WritesTestFileOnDisk' {
      New-PesterDataDrivenTestTemplate `
        -FunctionName       'DataWritten' `
        -SourceRelativePath '..', 'public', 'DataWritten.ps1' `
        -ItName             'DataWritten_It' `
        -ItBody             'true | Should -BeTrue' `
        -OutputPath         $script:tempDir `
        -Force | Out-Null
      Test-Path (Join-Path $script:tempDir 'DataWritten.Tests.ps1') | Should -BeTrue
    }
  }
}
