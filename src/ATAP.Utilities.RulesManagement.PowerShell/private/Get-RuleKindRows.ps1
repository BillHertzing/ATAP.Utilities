<#
.SYNOPSIS
  Reads all rows from ATAPUtilities.PrimitiveLanguageKind over an open SqlConnection.
.DESCRIPTION
  Private helper for Get-RuleKinds. Queries the actual deployed schema
  (PrimitiveLanguageKindId, Name, Description) and maps the rows to the
  documented public shape (Id, KindName, Description). The legacy documented
  columns LanguageName, GrammarFilePath, and PhiloteGUID do not exist in the
  deployed ATAPUtilities.PrimitiveLanguageKind table and are returned as $null
  so downstream consumers written against the documented contract do not break.
.PARAMETER SqlConnection
  An OPEN SqlConnection (Microsoft.Data.SqlClient or System.Data.SqlClient).
.OUTPUTS
  PSCustomObject[] — each object: Id, KindName, LanguageName, Description, GrammarFilePath, PhiloteGUID
.NOTES
  AI assisted using .claude/Rules/Powershell.md as guidelines.
#>
function Get-RuleKindRows {
  [CmdletBinding()]
  [OutputType([PSCustomObject[]])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [object] $SqlConnection
  )

  begin {
    $fn = 'Get-RuleKindRows'
    $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $command = $null
    $reader = $null
    try {
      $command = $SqlConnection.CreateCommand()
      $command.CommandText = @'
SELECT PrimitiveLanguageKindId, [Name], [Description]
FROM ATAPUtilities.PrimitiveLanguageKind
ORDER BY PrimitiveLanguageKindId;
'@
      $reader = $command.ExecuteReader()
      $rows = [System.Collections.Generic.List[object]]::new()
      while ($reader.Read()) {
        $rows.Add([PSCustomObject]@{
          Id              = [int]$reader['PrimitiveLanguageKindId']
          KindName        = [string]$reader['Name']
          LanguageName    = $null
          Description     = if ($reader['Description'] -is [System.DBNull]) { $null } else { [string]$reader['Description'] }
          GrammarFilePath = $null
          PhiloteGUID     = $null
        })
      }
      return $rows.ToArray()
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to read PrimitiveLanguageKind rows. Exception: $($_.Exception.Message)"
      throw
    }
    finally {
      if ($reader) { $reader.Dispose() }
      if ($command) { $command.Dispose() }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
