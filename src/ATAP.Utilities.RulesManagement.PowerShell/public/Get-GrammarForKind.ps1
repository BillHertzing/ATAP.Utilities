<#
.SYNOPSIS
    Returns a structured grammar model for a given PrimitiveLanguageKind.
.DESCRIPTION
    Queries ATAPUtilities.PrimitiveLanguageKind, ATAPUtilities.RulePrimitive, and
    ATAPUtilities.RulePrimitiveComposition to reconstruct the ordered grammar for a
    named Kind. The returned GrammarModel is the agent's "read the BNF" step.
.PARAMETER KindName
    The PascalCase name of the Kind as stored in ATAPUtilities.PrimitiveLanguageKind.
.PARAMETER DatabaseHost
    The SQL Server host. Alias: HostName.
.PARAMETER DatabaseName
    The database name. Defaults to the value in global settings.
.PARAMETER IntegratedSecurity
    Use Windows Integrated Authentication (default parameter set).
.PARAMETER CredentialsKey
    Bitwarden vault key for SQL credentials (CredentialsFromVault parameter set).
.OUTPUTS
    PSCustomObject with properties: Kind, Primitives[], Compositions[] (ordered by Position).
.EXAMPLE
    Get-GrammarForKind -KindName 'InterfaceDeclaration' -IntegratedSecurity
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Get-GrammarForKind {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedSecurity')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
        [ValidateNotNullOrEmpty()]
        [string] $KindName,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'CredentialsFromVault')]
        [Alias('HostName')]
        [string] $DatabaseHost,

        [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'CredentialsFromVault')]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
        [switch] $IntegratedSecurity,

        [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
        [string] $CredentialsKey
    )

    BEGIN {
        $fn = 'Get-GrammarForKind'
        $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        try {
            if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
                . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
            }
            if (-not (Get-Command -Name 'New-ConnectionStringBuilderFromDbaTools' -CommandType Function -ErrorAction SilentlyContinue)) {
                . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.DatabaseManagement.Powershell\public\New-ConnectionStringBuilderFromDbaTools.ps1'
            }
        }
        catch {
            $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }

        # Check and populate parameters
        $KindName = Get-PVal -ParameterName 'KindName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.KindName' -DefaultValue $KindName
        $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DatabaseHost' -DefaultValue $DatabaseHost -AllowMissing:$true
        $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DatabaseName' -DefaultValue 'ATAPUtilities' -AllowMissing:$true

        if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
            $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.CredentialsKey' -DefaultValue $CredentialsKey -AllowMissing:$false
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "KindName: $KindName | DatabaseName: $DatabaseName"
    }

    PROCESS {
        $sqlConnection = $null
        try {
            $connBuilderParams = @{ DatabaseName = $DatabaseName }
            if (-not [string]::IsNullOrWhiteSpace($DatabaseHost)) { $connBuilderParams['DatabaseHost'] = $DatabaseHost }
            if ($PSCmdlet.ParameterSetName -eq 'IntegratedSecurity') {
                $connBuilderParams['IntegratedSecurity'] = $true
            }
            else {
                $connBuilderParams['CredentialsKey'] = $CredentialsKey
            }
            $connectionString = (New-ConnectionStringBuilderFromDbaTools @connBuilderParams).ToString()

            $sqlConnection = New-Object Microsoft.Data.SqlClient.SqlConnection($connectionString)
            $sqlConnection.Open()
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Connection opened to $DatabaseName"

            # Query: Kind row
            $kindCmd = $sqlConnection.CreateCommand()
            $kindCmd.CommandText = @'
SELECT Id, KindName, LanguageName, Description, GrammarFilePath
FROM   ATAPUtilities.PrimitiveLanguageKind
WHERE  KindName = @KindName
'@
            $kindCmd.Parameters.Add((New-Object Microsoft.Data.SqlClient.SqlParameter('@KindName', $KindName))) | Out-Null
            $kindReader = $kindCmd.ExecuteReader()
            if (-not $kindReader.Read()) {
                throw "Kind '$KindName' not found in ATAPUtilities.PrimitiveLanguageKind"
            }
            $kindRow = [PSCustomObject]@{
                Id              = $kindReader['Id']
                KindName        = $kindReader['KindName']
                LanguageName    = $kindReader['LanguageName']
                Description     = $kindReader['Description']
                GrammarFilePath = $kindReader['GrammarFilePath']
            }
            $kindReader.Close()
            $kindCmd.Dispose()

            # Query: Primitives
            $primCmd = $sqlConnection.CreateCommand()
            $primCmd.CommandText = @'
SELECT Id, PrimitiveName, BNFSymbol, DataType, IsTerminal
FROM   ATAPUtilities.RulePrimitive
WHERE  KindId = @KindId
ORDER  BY PrimitiveName
'@
            $primCmd.Parameters.Add((New-Object Microsoft.Data.SqlClient.SqlParameter('@KindId', $kindRow.Id))) | Out-Null
            $primReader = $primCmd.ExecuteReader()
            $primitives = [System.Collections.Generic.List[PSCustomObject]]::new()
            while ($primReader.Read()) {
                $primitives.Add([PSCustomObject]@{
                    Id           = $primReader['Id']
                    PrimitiveName = $primReader['PrimitiveName']
                    BNFSymbol    = $primReader['BNFSymbol']
                    DataType     = $primReader['DataType']
                    IsTerminal   = $primReader['IsTerminal']
                })
            }
            $primReader.Close()
            $primCmd.Dispose()

            # Query: Compositions ordered by Position
            $compCmd = $sqlConnection.CreateCommand()
            $compCmd.CommandText = @'
SELECT rpc.Id, rpc.PrimitiveId, rp.PrimitiveName, rp.BNFSymbol,
       rpc.Position, rpc.IsOptional, rpc.Cardinality
FROM   ATAPUtilities.RulePrimitiveComposition rpc
JOIN   ATAPUtilities.RulePrimitive rp ON rp.Id = rpc.PrimitiveId
WHERE  rpc.KindId = @KindId
ORDER  BY rpc.Position
'@
            $compCmd.Parameters.Add((New-Object Microsoft.Data.SqlClient.SqlParameter('@KindId', $kindRow.Id))) | Out-Null
            $compReader = $compCmd.ExecuteReader()
            $compositions = [System.Collections.Generic.List[PSCustomObject]]::new()
            while ($compReader.Read()) {
                $compositions.Add([PSCustomObject]@{
                    Id            = $compReader['Id']
                    PrimitiveId   = $compReader['PrimitiveId']
                    PrimitiveName = $compReader['PrimitiveName']
                    BNFSymbol     = $compReader['BNFSymbol']
                    Position      = $compReader['Position']
                    IsOptional    = $compReader['IsOptional']
                    Cardinality   = $compReader['Cardinality']
                })
            }
            $compReader.Close()
            $compCmd.Dispose()

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Loaded Kind '$KindName': $($primitives.Count) primitives, $($compositions.Count) composition rows"

            return [PSCustomObject]@{
                Kind         = $kindRow
                Primitives   = $primitives.ToArray()
                Compositions = $compositions.ToArray()
            }
        }
        catch {
            $errorMessage = "Get-GrammarForKind failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
        finally {
            if ($sqlConnection) {
                if ($sqlConnection.State -eq [System.Data.ConnectionState]::Open) {
                    $sqlConnection.Close()
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Database connection closed'
                }
                $sqlConnection.Dispose()
            }
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
