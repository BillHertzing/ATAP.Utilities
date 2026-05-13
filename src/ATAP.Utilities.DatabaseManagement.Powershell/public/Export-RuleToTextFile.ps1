<#
.SYNOPSIS
    Exports a Rule from the ATAPUtilities database to a formatted text file.

.DESCRIPTION
    This function retrieves a Rule by name from the ATAPUtilities database and exports all
    its metadata including PhiloteID, Rule Name, Purpose, Language Kind, Composition details,
    and associated primitives to a formatted text file.

.PARAMETER RuleName
    The name of the Rule to export (e.g., "<cs-source-file>").

.PARAMETER LanguageKind
    Optional. The programming language kind to filter by. Valid values: 'CSharp', 'Powershell', 'SQL', 'MSBuild'.

.PARAMETER OutputPath
    The full path to the output text file. If not specified, creates a file in the current directory
    with the pattern "Rule_{RuleName}_{timestamp}.txt".

.PARAMETER DatabaseName
    The name of the database to query. Default: 'ATAPUtilities'.

.PARAMETER SqlConnection
    An already-open Microsoft.Data.SqlClient.SqlConnection.

.PARAMETER BitwardenSecretName
    Bitwarden secret name whose value is a complete SQL Server connection string.

.PARAMETER DatabaseHost
    SQL Server host used by the ConnectionParts parameter set. Default: 'localhost'.

.PARAMETER InstanceName
    SQL Server instance name used by the ConnectionParts parameter set. Accepts -SqlInstance as an alias.

.PARAMETER UseIntegratedSecurity
    Use Windows Integrated Security for authentication. Default: $true.

.PARAMETER Username
    SQL Server username (only used if UseIntegratedSecurity is $false).

.PARAMETER Password
    SQL Server password (only used if UseIntegratedSecurity is $false).

.EXAMPLE
    Export-RuleToTextFile -RuleName "<cs-source-file>" -LanguageKind "CSharp"

    Exports the C# source file rule to a text file in the current directory.

.EXAMPLE
    Export-RuleToTextFile -RuleName "MyRule" -OutputPath "C:\Temp\MyRule.txt" -SqlInstance "SQLSERVER01"

    Exports the specified rule to C:\Temp\MyRule.txt from a remote SQL Server instance.

.OUTPUTS
    System.String
    Returns the path to the created text file.

.NOTES
    Uses Resolve-DatabaseSqlConnection for connection validation.
    Author: ATAP.Utilities Database Team
    Version: 1.0.0
#>

function Export-RuleToTextFile {
  [CmdletBinding(DefaultParameterSetName = 'ConnectionParts')]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$RuleName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSharp', 'Powershell', 'SQL', 'MSBuild')]
    [string]$LanguageKind,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SqlConnection')]
    [AllowNull()]
    [object]$SqlConnection,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'BitwardenSecretName')]
    [Alias('BitwardenSecret', 'SecretName')]
    [string]$BitwardenSecretName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('HostName', 'ServerInstance')]
    [string]$DatabaseHost = 'localhost',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('SqlInstance')]
    [string]$InstanceName,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = 'ATAPUtilities',

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ConnectionMethod,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$CredentialsKey,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [string]$ApplicationName,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [Alias('UseIntegratedSecurity')]
    [bool]$IntegratedSecurity = $true,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ConnectionParts')]
    [switch]$UseTrustedConnection,

    [Parameter(Mandatory = $false)]
    [hashtable]$Settings,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password
  )

  begin {
    if (-not (Get-Command -Name 'Resolve-DatabaseSqlConnection' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path $PSScriptRoot 'Resolve-DatabaseSqlConnection.ps1')
    }
    if (-not (Get-Command -Name 'Invoke-DatabaseSqlDataSet' -CommandType Function -ErrorAction SilentlyContinue)) {
      . (Join-Path (Split-Path -Parent $PSScriptRoot) 'private\DatabaseSqlCommand.Helpers.ps1')
    }

    if ($PSBoundParameters.ContainsKey('Username') -or $PSBoundParameters.ContainsKey('Password')) {
      Write-Warning 'Username and Password are retained for backward compatibility but are not used by the shared connection resolver. Use CredentialsKey, BitwardenSecretName, or SqlConnection for SQL authentication.'
    }

    $resolvedSqlConnection = Resolve-DatabaseSqlConnection `
      -OriginalPSBoundParameters $PSBoundParameters `
      -SqlConnection $SqlConnection `
      -BitwardenSecretName $BitwardenSecretName `
      -DatabaseHost $DatabaseHost `
      -InstanceName $InstanceName `
      -DatabaseName $DatabaseName `
      -ConnectionMethod $ConnectionMethod `
      -CredentialsKey $CredentialsKey `
      -ApplicationName $ApplicationName `
      -UseTrustedConnection:$UseTrustedConnection `
      -IntegratedSecurity:$IntegratedSecurity `
      -Settings $Settings

    $resolvedConnectionOwnedByFunction = $PSCmdlet.ParameterSetName -ne 'SqlConnection'

    # Generate output path if not provided
    if ([string]::IsNullOrEmpty($OutputPath)) {
      $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
      $sanitizedRuleName = $RuleName -replace '[<>:"/\\|?*]', '_'
      $OutputPath = Join-Path (Get-Location) "Rule_${sanitizedRuleName}_${timestamp}.txt"
    }

    Write-Verbose "Output file: $OutputPath"
  }

  process {
    try {
      Write-Verbose "Using SQL connection $($resolvedSqlConnection.DataSource).$($resolvedSqlConnection.Database)"

      # Build query parameters
      $sqlParams = @{
        RuleName = $RuleName
      }
      if (-not [string]::IsNullOrEmpty($LanguageKind)) {
        $sqlParams['LanguageKindName'] = $LanguageKind
      }

      # Execute stored procedure to retrieve Rule data
      Write-Verbose "Executing stored procedure: dbo.GetRuleByName with RuleName='$RuleName'"

      $results = Invoke-DatabaseSqlDataSet `
        -SqlConnection $resolvedSqlConnection `
        -CommandText 'dbo.GetRuleByName' `
        -CommandType StoredProcedure `
        -Parameters $sqlParams

      # Check if we got any results
      if ($null -eq $results -or $results.Tables.Count -eq 0 -or $results.Tables[0].Rows.Count -eq 0) {
        Write-Warning "No Rule found with Name='$RuleName'"
        if (-not [string]::IsNullOrEmpty($LanguageKind)) {
          Write-Warning "and LanguageKind='$LanguageKind'"
        }
        return $null
      }

      # Extract result sets
      $ruleInfo = $results.Tables[0].Rows[0]
      $compositionDetails = $results.Tables[1]
      $additionalIds = if ($results.Tables.Count -gt 2) { $results.Tables[2] } else { $null }
      $timeBlocks = if ($results.Tables.Count -gt 3) { $results.Tables[3] } else { $null }

      # Build the output text
      $output = New-Object System.Text.StringBuilder
      [void]$output.AppendLine("=" * 80)
      [void]$output.AppendLine("Rule Export from ATAPUtilities Database")
      [void]$output.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
      [void]$output.AppendLine("=" * 80)
      [void]$output.AppendLine()

      # Rule basic information
      [void]$output.AppendLine("RULE INFORMATION")
      [void]$output.AppendLine("-" * 80)
      [void]$output.AppendLine("PhiloteID:            $($ruleInfo.PhiloteId)")
      [void]$output.AppendLine("Rule Name:            $($ruleInfo.RuleName)")
      [void]$output.AppendLine("Language Kind:        $($ruleInfo.PrimitiveLanguageKind)")
      [void]$output.AppendLine("Created At:           $($ruleInfo.CreatedAt)")
      if (-not [string]::IsNullOrEmpty($ruleInfo.SourceFileReference)) {
        [void]$output.AppendLine("Source Reference:     $($ruleInfo.SourceFileReference)")
      }
      [void]$output.AppendLine()

      # Purpose/Description
      if (-not [string]::IsNullOrEmpty($ruleInfo.Purpose)) {
        [void]$output.AppendLine("PURPOSE")
        [void]$output.AppendLine("-" * 80)
        [void]$output.AppendLine($ruleInfo.Purpose)
        [void]$output.AppendLine()
      }

      # Additional Philote IDs
      if ($null -ne $additionalIds -and $additionalIds.Rows.Count -gt 0) {
        [void]$output.AppendLine("ADDITIONAL PHILOTE IDs")
        [void]$output.AppendLine("-" * 80)
        foreach ($row in $additionalIds.Rows) {
          [void]$output.AppendLine("  $($row.KeyName): $($row.ValueId)")
        }
        [void]$output.AppendLine()
      }

      # Time Blocks
      if ($null -ne $timeBlocks -and $timeBlocks.Rows.Count -gt 0) {
        [void]$output.AppendLine("TIME BLOCKS")
        [void]$output.AppendLine("-" * 80)
        foreach ($row in $timeBlocks.Rows) {
          $endAt = if ($row.IsNull("EndAt")) { "Ongoing" } else { $row.EndAt }
          [void]$output.AppendLine("  Start: $($row.StartAt) | End: $endAt")
        }
        [void]$output.AppendLine()
      }

      # Rule Primitive Composition
      if ($compositionDetails.Rows.Count -gt 0) {
        [void]$output.AppendLine("RULE COMPOSITION")
        [void]$output.AppendLine("-" * 80)
        [void]$output.AppendLine()

        foreach ($comp in $compositionDetails.Rows) {
          [void]$output.AppendLine("[$($comp.SequenceKey)] $($comp.PrimitiveName)")
          [void]$output.AppendLine()

          if (-not [string]::IsNullOrEmpty($comp.PrimitiveDescription)) {
            [void]$output.AppendLine("  Description:")
            [void]$output.AppendLine("    $($comp.PrimitiveDescription)")
            [void]$output.AppendLine()
          }

          if (-not [string]::IsNullOrEmpty($comp.BnfDefinition)) {
            [void]$output.AppendLine("  BNF Definition:")
            $bnfLines = $comp.BnfDefinition -split "`r?`n"
            foreach ($line in $bnfLines) {
              [void]$output.AppendLine("    $line")
            }
            [void]$output.AppendLine()
          }

          if (-not [string]::IsNullOrEmpty($comp.BoundInputsJson)) {
            [void]$output.AppendLine("  Bound Inputs:")
            [void]$output.AppendLine("    $($comp.BoundInputsJson)")
            [void]$output.AppendLine()
          }

          if (-not [string]::IsNullOrEmpty($comp.Notes)) {
            [void]$output.AppendLine("  Notes:")
            [void]$output.AppendLine("    $($comp.Notes)")
            [void]$output.AppendLine()
          }

          if (-not [string]::IsNullOrEmpty($comp.PrimitiveAttribution)) {
            [void]$output.AppendLine("  Attribution:")
            $attrLines = $comp.PrimitiveAttribution -split "`r?`n"
            foreach ($line in $attrLines) {
              [void]$output.AppendLine("    $line")
            }
            [void]$output.AppendLine()
          }

          [void]$output.AppendLine()
        }
      }

      [void]$output.AppendLine("=" * 80)
      [void]$output.AppendLine("End of Rule Export")
      [void]$output.AppendLine("=" * 80)

      # Write to file
      $output.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
      Write-Host "Rule exported successfully to: $OutputPath" -ForegroundColor Green

      return $OutputPath
    }
    catch {
      Write-Error "Failed to export Rule: $_"
      Write-Error $_.Exception.StackTrace
      throw
    }
  }

  end {
    if ($resolvedConnectionOwnedByFunction -and $null -ne $resolvedSqlConnection) {
      $resolvedSqlConnection.Dispose()
    }
  }
}

# Export the function if this script is dot-sourced
