function New-ContentSummarySqlAdapterSet {
  <#
  .SYNOPSIS
    Creates procedure-only SqlClient adapters for ContentSummary production harvesting.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [ValidateRange(1, 300)]
    [int] $CommandTimeoutSeconds = 30
  )

  begin {
    $fn = 'New-ContentSummarySqlAdapterSet'
    $mn = 'ATAP.Utilities.BuildTooling.ContentSummary.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Entering function'
  }

  process {
    if ($null -eq $SqlConnection -or
      -not [string]::Equals($SqlConnection.GetType().FullName, 'Microsoft.Data.SqlClient.SqlConnection', [StringComparison]::Ordinal) -or
      [string]$SqlConnection.State -ne 'Open') {
      throw 'CS-SQL-001: an open Microsoft.Data.SqlClient.SqlConnection is required.'
    }
    $storedProcedureInvoker = Get-Command -Name 'Invoke-ContentSummarySqlStoredProcedure' -CommandType Function -ErrorAction Stop
    New-ContentSummarySqlAdapterSetCore `
      -SqlConnection $SqlConnection `
      -CommandTimeoutSeconds $CommandTimeoutSeconds `
      -StoredProcedureInvoker $storedProcedureInvoker
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Leaving function'
  }
}
