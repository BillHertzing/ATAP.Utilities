#############################################################################
#region Test-ModuleManifest
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
[Testing Your Module Manifest With Pester](https://mattmcnabb.github.io/pester-testing-your-module-manifest)
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
# test the module manifest - exports the right functions, processes the right formats, and is generally correct
Describe ' Powershell Manifest Unit Tests' -Tag 'UnitTests' {

  # opinionated. For a powershell module, the Module name is the tests subdirectory's parent name
  BeforeAll {
    $message = 'Starting BeforeAll in Test-ModuleManifest.Tests.ps1'
    Write-PSFMessage -Level Important -Message $message -Tag 'Trace', 'UnitTests'
    # The VSC test runner starts in the module's workspace directory
    $cwd = Get-Location
    $Script:ModuleName = Split-Path -Path $cwd -Leaf
    # The VSC test runner starts in the module's workspace directory, so the ModulePath and the Manifest Path are
    #   in the current directory
    $Script:ModulePath = "$Script:ModuleName.psm1"
    $Script:ManifestPath = "$Script:ModuleName.psd1"
    $Script:ManifestHash = Invoke-Expression (Get-Content $Script:ManifestPath -Raw)
  }

  # It 'has a valid manifest' {
  #   {
  #     $null = Test-ModuleManifest -Path $Script:ManifestPath -ErrorAction Stop -WarningAction SilentlyContinue
  #   } | Should -Not Throw
  # }

  It 'has a valid root module' {
    $ManifestHash.RootModule | Should -Be "$Script:ModulePath"
    #$ManifestHash.RootModule | Should -Be 'ATAP.Utilities.FileIO.PowerShell.psm1'
  }

  It 'has a valid Description' {
    $ManifestHash.Description | Should -Not -BeNullOrEmpty
  }

  It 'has a valid guid' {
    $ManifestHash.Guid | Should -Match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  }
  # we have not yet run into a situation where the DefaultCommandPrefix, used for namespacing functions in a module,
  #  is necessary
  # It 'has a valid prefix' {
  #   $ManifestHash.DefaultCommandPrefix | Should -Not -BeNullOrEmpty
  # }

  It 'has a valid copyright' {
    $ManifestHash.CopyRight | Should -Not -BeNullOrEmpty
  }

  It 'exports all public functions' {
    # ToDo: modify so it tests exported function, and cmdlets
    $ExFunctions = $ManifestHash.FunctionsToExport
    $FunctionFiles = Get-ChildItem 'Public' -Filter *.ps1 | Select-Object -ExpandProperty BaseName
    $FunctionNames = $FunctionFiles
    foreach ($FunctionName in $FunctionNames) {
      # ToDo: accumulate found functions into $foundFunctions
      $ExFunctions -contains $FunctionName | Should -Be $true
    }
    # Add test to ensure there are no functions in ExFunctions that are not in $foundFunctions
  }
}

# #endregion Test-ModuleManifest
# #############################################################################


