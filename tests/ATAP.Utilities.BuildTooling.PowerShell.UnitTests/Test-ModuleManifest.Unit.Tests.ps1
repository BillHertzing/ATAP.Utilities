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
# $modulePath discard from rightmost pathseperator
$ModulePath = (Split-Path -Parent $MyInvocation.MyCommand.Path) -Replace ''
$ModuleName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace '.Tests.ps1'

$ManifestPath = "$ModulePath\$ModuleName.psd1"

$ModulePath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell\'
$ModuleName = 'ATAP.Utilities.FileIO.PowerShell'

# test the module manifest - exports the right functions, processes the right formats, and is generally correct
Describe '<Manifest>' {

  $ManifestHash = Invoke-Expression (Get-Content $ManifestPath -Raw)

  It 'has a valid manifest' {
    {
      $null = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop -WarningAction SilentlyContinue
    } | Should -Not Throw
  }

  It 'has a valid root module' {
    #$ManifestHash.RootModule | Should -Be "$ModuleName.psm1"
    $ManifestHash.RootModule | Should -Be 'ATAP.Utilities.FileIO.PowerShell.psm1'
  }

  It 'has a valid Description' {
    $ManifestHash.Description | Should -Not -BeNullOrEmpty
  }

  It 'has a valid guid' {
    $ManifestHash.Guid | Should -Be '06659291-925f-4733-b4f3-7f69b5cbabda'
  }

  It 'has a valid prefix' {
    $ManifestHash.DefaultCommandPrefix | Should -Not -BeNullOrEmpty
  }

  It 'has a valid copyright' {
    $ManifestHash.CopyRight | Should -Not -BeNullOrEmpty
  }

  It 'exports all public functions' {
    $ExFunctions = $ManifestHash.FunctionsToExport
    $FunctionFiles = Get-ChildItem "$ModulePath\Public" -Filter *.ps1 | Select-Object -ExpandProperty BaseName
    $FunctionNames = $FunctionFiles
    foreach ($FunctionName in $FunctionNames) {
      $ExFunctions -contains $FunctionName | Should -Be $true
    }
  }
}

#     }
#     #endregion FunctionProcessBlock

#     #region FunctionEndBlock
#     ########################################
#     END {
#         Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
#     }
#     #endregion FunctionEndBlock
# }
# #endregion Test-ModuleManifest
# #############################################################################


