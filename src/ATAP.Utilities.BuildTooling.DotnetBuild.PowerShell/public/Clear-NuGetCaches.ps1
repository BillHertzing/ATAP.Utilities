# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Clears NuGet package caches from common locations

.DESCRIPTION
Removes NuGet package caches from the user profile packages directory, temporary NuGet scratch directory,
and local application data v3-cache directory. Includes safety checks to ensure only NuGet-related paths are removed.

.PARAMETER Path
The base path to use for relative path operations (currently unused but maintained for compatibility)

.EXAMPLE
Clear-NuGetCaches
Clears all NuGet caches with confirmation prompts

.EXAMPLE
Clear-NuGetCaches -WhatIf
Shows what cache directories would be removed without actually removing them

.INPUTS
System.String

.OUTPUTS
None

.NOTES
AI assisted using Powershell.instructions.md as guidelines
Caches may be locked! Stop any IDEs or CI processes before running.

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Clear-NuGetCaches {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [Alias()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$Path = './'
  )

  BEGIN {
    $fn = 'Clear-NuGetCaches'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Caches may be locked! Stop any IDEs or CI processes."

    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet used: "Check and populate simple parameter"
    $Path = Get-PVal -ParameterName 'Path' -originalPSBoundParameters $PSBoundParameters -dottedPath 'Path'

    # Define cache paths to clear
    $cachePaths = @(
      @{
        Path        = (Join-Path $env:USERPROFILE '.nuget/packages')
        Description = 'User profile NuGet packages cache'
      },
      @{
        Path        = (Join-Path $env:TEMP 'NuGetScratch')
        Description = 'Temporary NuGet scratch directory'
      },
      @{
        Path        = (Join-Path $env:LOCALAPPDATA 'NuGet/v3-cache')
        Description = 'Local application data NuGet v3 cache'
      }
    )
  }

  PROCESS {
    foreach ($cacheInfo in $cachePaths) {
      $cachePath = $cacheInfo.Path
      $description = $cacheInfo.Description

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Processing cache path: $cachePath"

      if ($PSCmdlet.ShouldProcess($cachePath, "Remove $description")) {
        try {
          if ((Test-Path $cachePath) -and ($cachePath -match 'nuget')) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Removing $description at: $cachePath"

            Remove-Item -Recurse -Force -Path $cachePath -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully removed $description"
          }
          else {
            $message = if (-not (Test-Path $cachePath)) {
              "Cache path does not exist: $cachePath"
            }
            else {
              "Cache path does not contain 'nuget' substring (safety check failed): $cachePath"
            }
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message $message
          }
        }
        catch {
          $errorMessage = "Failed to remove $description at $cachePath. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          # ToDo: accumulate the errors; potentially add to 'Problems'
          throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
        }
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
