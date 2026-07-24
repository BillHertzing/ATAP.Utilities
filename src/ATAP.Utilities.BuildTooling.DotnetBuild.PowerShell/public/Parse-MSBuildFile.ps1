function Parse-MSBuildFile {
  <#
  .SYNOPSIS
  Extracts rule metadata from an MSBuild project file.

  .DESCRIPTION
  Reads an MSBuild XML document and returns its assembly/project name and
  description in the normalized shape consumed by rule extraction.

  .PARAMETER FilePath
  Path to the MSBuild project file.

  .PARAMETER RelativePath
  Repository-relative source path retained for caller context.

  .OUTPUTS
  PSCustomObject containing Name and Purpose.

  .EXAMPLE
  Parse-MSBuildFile -FilePath '.\src\App\App.csproj' -RelativePath 'src/App/App.csproj'

  .NOTES
  Split from Read-SourceAndCreateRules.ps1 during Task 13.72.6.

  .LINK
  https://learn.microsoft.com/visualstudio/msbuild/msbuild-project-file-schema-reference
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $FilePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $RelativePath
  )

  begin {
    $fn = 'Parse-MSBuildFile'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($RelativePath, 'Parse MSBuild metadata')) {
      return
    }

    try {
      $content = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop
      $xml = [xml] $content
      $projectName = $xml.Project.PropertyGroup.AssemblyName | Select-Object -First 1
      if (-not $projectName) {
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
      }

      $description = $xml.Project.PropertyGroup.Description | Select-Object -First 1
      [PSCustomObject]@{
        Name = [string] $projectName
        Purpose = if ($description) { [string] $description } else { "MSBuild project $projectName" }
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Error parsing MSBuild file '$FilePath': $($_.Exception.Message)" -ErrorRecord $_
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
