
function Get-RecycleBinFiles {
  <#
.SYNOPSIS
Retrieves files from the RecycleBin for specified drives and returns their details.

.DESCRIPTION
This function retrieves files from the RecycleBin for specified drives, including their names, sizes, and deletion dates.
It returns a hashtable where the keys are the drive letters and the values are arrays of files currently in the RecycleBin for those drives.

.PARAMETER Drive
Specifies the drive(s) to check for RecycleBin files. Accepts a single string or an array of strings.

.EXAMPLE
Get-RecycleBinFiles -Drive C
Retrieves files from the RecycleBin claiming to be from the C drive.

.EXAMPLE
Get-RecycleBinFiles -Drive @('C', 'D')
Retrieves files from the RecycleBin claiming to be from the C or D drives.

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
    # Retrieve RecycleBin items using Shell.Application COM object
    $shell = New-Object -ComObject Shell.Application
    # $shell.Namespace(0xA) is a system-defined ShellSpecialFolder constant for the global RecycleBin view, not per drive.
    # This returns a virtual folder showing all RecycleBin items across all drives.
    $recycleBin = $shell.Namespace(0xA)
    if (-not $recycleBin) {
      # Indicate this condition of failure
      $result['HasNoNamespace'] = $true
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Warning -Message "Failed to access the RecycleBin ShellSpecialFolder."
      return $result
    }
    $rbItems = $recycleBin.Items()
    if ($rbItems.Count -eq 0) {
      # Indicate this condition of failure
      $result['HasNoItems'] = $true
      Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Warning -Message "The RecycleBin across all drives is empty."
      return $result
    }

    foreach ($drive in $Drives) {
      $result[$drive] = @()
    }

    if ($PSCmdlet.ShouldProcess("All Drives", "Retrieve all RecycleBin files")) {
      try {
        for ($i = 0; $i -lt $rbItems.Count; $i++) {
          $item = $rbItems.Item($i)
          foreach ($drive in $Drives) {
            if ($item.Path -like "$drive*") {
              $result[$drive] += [PSCustomObject]@{
                Name         = $item.Name
                Path         = $item.Path
                Size         = $item.ExtendedProperty('Size')
                DeletionDate = $item.ExtendedProperty('Date deleted')
                Type         = $item.ExtendedProperty('Type')
              }
            }
          }
          if (($i + 1) % 25 -eq 0) {
            Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Verbose -Message "Processed $($i + 1) files from the RecycleBin on drive $drive."
          }
        }
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Successfully retrieved $($items.Count) items from the RecycleBin on drive $drive."
      }
      catch {
        $errorMessage = "An error occurred while retrieving RecycleBin files on drive $drive. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Error -Message $errorMessage
        throw
      }
      finally {
        Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Finished processing RecycleBin on drive $drive."
      }
    }
  }


  END {
    Write-PSFMessage -FunctionName 'Get-RecycleBinFiles' -ModuleName 'ATAP.Utilities.FileIO.PowerShell' -Level Debug -Message "Leaving function Get-RecycleBinFiles"
    $result

  }
}

