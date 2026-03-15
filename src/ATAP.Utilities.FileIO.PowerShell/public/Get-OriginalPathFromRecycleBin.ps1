function Get-OriginalPathFromRecycleBin {
  <#
  .SYNOPSIS
  Retrieves the original path of a file from the Recycle Bin.

  .DESCRIPTION
  This function extracts the SID from the Recycle Bin path and queries the Windows Registry
  to retrieve the original path of the file.

  .PARAMETER RecycleBinPath
  The full path of the file in the Recycle Bin.

  .EXAMPLE
  Get-OriginalPathFromRecycleBin -RecycleBinPath 'C:\$Recycle.Bin\S-1-5-21-670621561-2583097644-1836932750-1001\$RZV1LFK.png'

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines.
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]

    [string]$RecycleBinPath
  )

  BEGIN {
    $fn = 'Get-OriginalPathFromRecycleBin'
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    $RecycleBinPath = Get-PVal -ParameterName 'RecycleBinPath' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RecycleBinPath' -DefaultValue $RecycleBinPath
  }

  PROCESS {
    try {
      # Extract the SID from the Recycle Bin path
      $sid = ($RecycleBinPath -split '\\')[3]
      Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Debug -Message "Extracted SID: $sid"

      # Construct the registry path
      $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecycleBin\$sid"
      if (-not (Test-Path $registryPath)) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Warning -Message "Registry path does not exist: $registryPath"
        return $null
      }

      # Query the registry for the original path
      $originalPath = Get-ItemProperty -Path $registryPath -Name OriginalPath -ErrorAction SilentlyContinue
      if ($null -ne $originalPath) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Debug -Message "Original path retrieved: $($originalPath.OriginalPath)"
        return $originalPath.OriginalPath
      }
      else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Warning -Message "Original path not found in the registry for $RecycleBinPath"
        return $null
      }
    }
    catch {
      $errorMessage = "An error occurred while retrieving the original path. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Error -Message $errorMessage
      throw
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn  -Level Debug -Message "Leaving function Get-OriginalPathFromRecycleBin"
  }
}
