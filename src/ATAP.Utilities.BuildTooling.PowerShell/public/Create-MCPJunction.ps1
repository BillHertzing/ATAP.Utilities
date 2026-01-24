<#
.SYNOPSIS
Creates a directory junction to the SharedVSCode MCP servers folder.

.DESCRIPTION
Creates a junction link from the repository root to the SharedVSCode mcp-servers folder,
making MCP servers accessible from any location within the repository.

.PARAMETER SharedVSCodePathToMCPServers
Path to the SharedVSCode MCP servers directory. Default is '../SharedVSCode/mcp-servers'.

.PARAMETER JunctionName
Name for the junction in the repository root. Default is '.mcp-servers'.

.OUTPUTS
System.IO.DirectoryInfo
Returns the created junction directory info.

.EXAMPLE
.\Create-MCPJunction.ps1
Creates .mcp-servers junction in repository root.

.EXAMPLE
.\Create-MCPJunction.ps1 -SharedVSCodePathToMCPServers 'C:\Dropbox\whertzing\GitHub\SharedVSCode\mcp-servers' -JunctionName 'mcp'
Creates junction with custom paths.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function New-MCPServerJunction {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$SharedVSCodePathToMCPServers,

    [Parameter(Mandatory = $true)]
    [string]$JunctionName
  )

  BEGIN {
    $fn = 'New-MCPServerJunction'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
        $getPValPath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
        if (Test-Path $getPValPath) {
          . $getPValPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded Get-PVal from: $getPValPath"
        }
        else {
          $errorMessage = "Required function Get-PVal not found and could not be loaded from: $getPValPath"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
      }

      # Load Get-RepositoryRoot helper function
      if (-not (Get-Command -Name 'Get-RepositoryRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        $getRepoRootPath = Join-Path $PSScriptRoot 'Get-RepositoryRoot.ps1'
        if (Test-Path $getRepoRootPath) {
          . $getRepoRootPath
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded Get-RepositoryRoot from: $getRepoRootPath"
        }
        else {
          $errorMessage = "Required function Get-RepositoryRoot not found and could not be loaded from: $getRepoRootPath"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }

    # Snippet: Check and populate simple parameter - SharedVSCodePathToMCPServers
    $SharedVSCodePathToMCPServers = Get-PVal -ParameterName 'SharedVSCodePathToMCPServers' -originalPSBoundParameters $PSBoundParameters -dottedPath 'SharedVSCodePathToMCPServers' -DefaultValue $SharedVSCodePathToMCPServers

    # Snippet: Check and populate simple parameter - JunctionName
    $JunctionName = Get-PVal -ParameterName 'JunctionName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'JunctionName' -DefaultValue $JunctionName

    # Get repository root using helper function
    $repositoryRoot = Get-RepositoryRoot -StartPath $PSScriptRoot
    $junctionPath = Join-Path $repositoryRoot $JunctionName
    $targetPath = Resolve-Path $SharedVSCodePathToMCPServers

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Repository root: $repositoryRoot"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Junction path: $junctionPath"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Target path: $targetPath"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Validate target path exists
      if (-not (Test-Path $targetPath)) {
        $errorMessage = "Target MCP servers path does not exist: $targetPath"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      # Check if junction already exists
      if (Test-Path $junctionPath) {
        $existingItem = Get-Item $junctionPath

        if ($existingItem.LinkType -eq 'Junction') {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Junction already exists: $junctionPath"

          # Verify it points to the correct location
          $existingTarget = $existingItem.Target
          if ($existingTarget -eq $targetPath) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Junction points to correct target'
            return $existingItem
          }
          else {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Junction points to wrong target: $existingTarget"

            if ($PSCmdlet.ShouldProcess($junctionPath, 'Remove and recreate junction')) {
              Remove-Item $junctionPath -Force -ErrorAction Stop
              Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Removed existing junction'
            }
          }
        }
        else {
          $errorMessage = "Path exists but is not a junction: $junctionPath"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
          throw $errorMessage
        }
      }

      # Create the junction
      if ($PSCmdlet.ShouldProcess($junctionPath, "Create junction to $targetPath")) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Creating junction: $junctionPath -> $targetPath"

        $junction = New-Item -ItemType Junction -Path $junctionPath -Target $targetPath -ErrorAction Stop

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully created junction: $junctionPath"

        return $junction
      }
    }
    catch {
      $errorMessage = "Failed to create MCP server junction. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}

# Execute if run as script
# if ($MyInvocation.InvocationName -ne '.') {
#   New-MCPServerJunction
# }
