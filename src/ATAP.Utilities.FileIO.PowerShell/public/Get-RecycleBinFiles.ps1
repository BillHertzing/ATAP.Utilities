# function Get-RecycleBinFiles
# .SYNOPSIS
# Retrieves files from the Recycle Bin and returns their details.
# .DESCRIPTION
# This function retrieves files from the Recycle Bin, including their names, sizes, and deletion dates.
# It returns a list of files that are currently in the Recycle Bin.
# .EXAMPLE
# Get-RecycleBinFiles
# Retrieves all files from the Recycle Bin and displays their details.
# .NOTES
# AI assisted using Powershell.instructions.md as guidelines

function Get-RecycleBinFiles {
  <#
  .SYNOPSIS
  Retrieves files from the Recycle Bin and returns their details.

  .DESCRIPTION
  This function retrieves files from the Recycle Bin, including their names, sizes, and deletion dates.
  It returns a list of files that are currently in the Recycle Bin.

  .EXAMPLE
  Get-RecycleBinFiles
  Retrieves all files from the Recycle Bin and displays their details.

  .INPUTS
  None

  .OUTPUTS
  PSCustomObject

  .NOTES
  AI assisted using Powershell.instructions.md as guidelines
  #>

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param ()

  BEGIN {
    Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Entering function Get-RecycleBinFiles"
  }

  PROCESS {
    try {
      # Retrieve Recycle Bin items using Shell.Application COM object
      $shell = New-Object -ComObject Shell.Application
      $recycleBin = $shell.Namespace(0xA)

      if (-not $recycleBin) {
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Error -Message "Failed to access the Recycle Bin."
        return
      }

      $items = @()
      $rbItems = $recycleBin.Items()
      if ($rbItems.Count -eq 0) {
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Warning -Message "The Recycle Bin is empty."
        return
      }
      $cnt = $rbItems.Count
      for ($i = 0; $i -lt $cnt; $i++) {
        $item = $rbItems.Item($i)

        $items += [PSCustomObject]@{
          Name         = $item.Name
          Path         = $item.Path
          Size         = $item.ExtendedProperty('Size')
          DeletionDate = $item.ExtendedProperty('Date deleted')
          Type         = $item.ExtendedProperty('Type')
        }

        if (($i + 1) % 25 -eq 0) {
          Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Verbose -Message "Processed $($i + 1) files of $cnt from the Recycle Bin."
        }
      }

      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Verbose -Message "Successfully retrieved $($items.Count) items from the Recycle Bin."

      $items
    }
    catch {
      $errorMessage = "An error occurred while retrieving Recycle Bin files. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Error -Message $errorMessage
      throw
    }
    finally {
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Exiting try-catch block in Get-RecycleBinFiles"
    }
  }

  END {
    Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Leaving function Get-RecycleBinFiles"
  }
}

