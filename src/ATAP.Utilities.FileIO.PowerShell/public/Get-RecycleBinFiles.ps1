function Get-RecycleBinFiles {
  <#
  .SYNOPSIS
  Retrieves files from the Recycle Bin for specified drives and returns their details.

  .DESCRIPTION
  This function retrieves files from the Recycle Bin for specified drives, including their names, sizes, deletion dates, and all other available properties.
  It returns a hashtable where the keys are the drive letters and the values are arrays of files currently in the Recycle Bin for those drives.

  .PARAMETER Drives
  Specifies the drive(s) to check for Recycle Bin files. Accepts a single string or an array of strings.

  .EXAMPLE
  Get-RecycleBinFiles -Drives C
  Retrieves files from the Recycle Bin claiming to be from the C drive.

  .EXAMPLE
  Get-RecycleBinFiles -Drives @('C', 'D')
  Retrieves files from the Recycle Bin claiming to be from the C or D drives.

  .NOTES
  AI assisted using Powershell.instructions.md, PowershellSnippets.jsonc as guidelines.
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$Drives
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Entering function Get-RecycleBinFiles"
  }

  PROCESS {
    $result = @{}
    # Retrieve Recycle Bin items using Shell.Application COM object
    try {
      $shell = New-Object -ComObject Shell.Application
      $recycleBin = $shell.Namespace(0xA) # 0xA is the Recycle Bin namespace
      if (-not $recycleBin) {
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Warning -Message "Failed to access the Recycle Bin ShellSpecialFolder."
        return $result
      }

      # Retrieve all property keys from the $null (default I guess) item.
      # ToDo: try-catch-throw-finally here to handle potential issues with GetDetailsOf
      $propertyKeys = @{}
      foreach ($idx in 0..400) {
        $propertyName = $recycleBin.GetDetailsOf($null, $idx)
        if (-not [string]::IsNullOrWhiteSpace($propertyName)) {
          $propertyKeys[$idx] = $propertyName
        }
        else {
          break
        }
      }

      # Initialize result hashtable for each drive
      foreach ($drive in $Drives) {
        $result[$drive] = @()
      }

      if ($PSCmdlet.ShouldProcess("All Drives", "Retrieve all Recycle Bin files")) {
        $rbCount = $recycleBin.Items().Count
        for ($i = 0; $i -lt $rbCount; $i++) {
          $item = $recycleBin.Items().Item($i)
          $itemProperties = @{}

          # Retrieve all properties for the item
          foreach ($key in $propertyKeys.Keys) {
            $propertyName = $propertyKeys[$key]
            $propertyValue = $recycleBin.GetDetailsOf($item, $key)
            if (-not [string]::IsNullOrWhiteSpace($propertyName)) {
              $itemProperties[$propertyName] = $propertyValue
            }
          }

          # Add the item to the appropriate drive
          foreach ($drive in $Drives) {
            if ($itemProperties['Original Location'] -like "$drive*") {
              $result[$drive] += $itemProperties
            }
          }

          # Log progress every 25 items
          if (($i + 1) % 25 -eq 0) {
            Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Verbose -Message "Processed $($i + 1) files out of $($rbCount) from the Recycle Bin."
          }
        }
      }
    }
    catch {
      $errorMessage = "An error occurred while retrieving Recycle Bin files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Finished processing Recycle Bin items."
    }
  }

  END {
    Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Leaving function Get-RecycleBinFiles"
    $result
  }
}
