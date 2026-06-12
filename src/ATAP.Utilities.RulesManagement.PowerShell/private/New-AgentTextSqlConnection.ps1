<#
.SYNOPSIS
  Opens a SqlConnection for the AgentText pilot functions.
.DESCRIPTION
  Private helper shared by Save-AgentTextToDatabase and Get-AgentTextFromDatabase.
  Prefers Microsoft.Data.SqlClient when the assembly is loadable and falls back
  to System.Data.SqlClient (shipped with PowerShell 7) so the pilot does not
  require dbatools or a NuGet restore on developer workstations.
.PARAMETER ConnectionString
  Full SQL Server connection string. Callers resolve secrets via Get-SecretATAP
  or Bitwarden item names; never pass literal credentials from source files.
.OUTPUTS
  An OPEN SqlConnection object.
.NOTES
  AI assisted using .claude/Rules/Powershell.md as guidelines.
#>
function New-AgentTextSqlConnection {
  [CmdletBinding()]
  [OutputType([object])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionString
  )

  begin {
    $fn = 'New-AgentTextSqlConnection'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $connection = $null
    try {
      $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($ConnectionString)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Using Microsoft.Data.SqlClient'
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Microsoft.Data.SqlClient unavailable; falling back to System.Data.SqlClient'
      $connection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
    }

    $connection.Open()
    return $connection
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
