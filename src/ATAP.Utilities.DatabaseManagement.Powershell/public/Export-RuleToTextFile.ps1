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

.PARAMETER SqlInstance
    The SQL Server instance to connect to. Default: 'localhost'.

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
    Requires the dbatools PowerShell module.
    Author: ATAP.Utilities Database Team
    Version: 1.0.0
#>

function Export-RuleToTextFile {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$RuleName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSharp', 'Powershell', 'SQL', 'MSBuild')]
    [string]$LanguageKind,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = 'ATAPUtilities',

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'localhost',

    [Parameter(Mandatory = $false)]
    [bool]$UseIntegratedSecurity = $true,

    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password
  )

  begin {
    # Import required modules
    if (-not (Get-Module -Name dbatools -ListAvailable)) {
      Write-Error "dbatools module not found. Please install it using: Install-Module -Name dbatools"
      return
    }
    Import-Module dbatools -ErrorAction Stop

    # Configure dbatools SSL/encryption settings
    Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig
    Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig

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
      # Build connection parameters
      $connectionParams = @{
        SqlInstance = $SqlInstance
        Database    = $DatabaseName
      }

      if ($UseIntegratedSecurity) {
        Write-Verbose "Using Integrated Security"
      }
      else {
        if ([string]::IsNullOrEmpty($Username) -or $null -eq $Password) {
          Write-Error "Username and Password are required when not using Integrated Security"
          return
        }
        $connectionParams['SqlCredential'] = New-Object System.Management.Automation.PSCredential($Username, $Password)
      }

      Write-Verbose "Connecting to $SqlInstance.$DatabaseName"

      # Build query parameters
      $sqlParams = @{
        RuleName = $RuleName
      }
      if (-not [string]::IsNullOrEmpty($LanguageKind)) {
        $sqlParams['LanguageKindName'] = $LanguageKind
      }

      # Execute stored procedure to retrieve Rule data
      Write-Verbose "Executing stored procedure: dbo.GetRuleByName with RuleName='$RuleName'"

      $results = Invoke-DbaQuery @connectionParams `
        -CommandType StoredProcedure `
        -Query "dbo.GetRuleByName" `
        -SqlParameter $sqlParams `
        -As DataSet

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
}

# Export the function if this script is dot-sourced
Export-ModuleMember -Function Export-RuleToTextFile
