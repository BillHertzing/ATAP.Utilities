<#
.SYNOPSIS
    Returns all RulePrimitiveInput rows for a given RulePrimitive.
.DESCRIPTION
    Queries ATAPUtilities.RulePrimitiveInput for all input definitions bound to the
    specified primitive. Used by the new-rule-kind skill to display what inputs each
    primitive requires when an agent is designing a new Kind.
.PARAMETER PrimitiveId
    The integer Id of the RulePrimitive row.
.PARAMETER DatabaseHost
    The SQL Server host. Alias: HostName.
.PARAMETER DatabaseName
    The database name. Defaults to the value in global settings.
.PARAMETER IntegratedSecurity
    Use Windows Integrated Authentication (default parameter set).
.PARAMETER CredentialsKey
    Bitwarden vault key for SQL credentials (CredentialsFromVault parameter set).
.OUTPUTS
    PSCustomObject[] — each with Id, PrimitiveId, InputName, InputType, IsRequired, DefaultValue.
.EXAMPLE
    Get-RulePrimitiveInputs -PrimitiveId 42 -IntegratedSecurity
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Get-RulePrimitiveInputs {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'IntegratedSecurity')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CredentialsFromVault')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $PrimitiveId,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'CredentialsFromVault')]
        [Alias('HostName')]
        [string] $DatabaseHost,

        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'IntegratedSecurity')]
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'CredentialsFromVault')]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true, ParameterSetName = 'IntegratedSecurity')]
        [switch] $IntegratedSecurity,

        [Parameter(Mandatory = $true, ParameterSetName = 'CredentialsFromVault')]
        [string] $CredentialsKey
    )

    BEGIN {
        $fn = 'Get-RulePrimitiveInputs'
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

        $PrimitiveId  = Get-PVal -ParameterName 'PrimitiveId'  -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.PrimitiveId'  -DefaultValue $PrimitiveId  -AsType [int]
        $DatabaseHost = Get-PVal -ParameterName 'DatabaseHost' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DatabaseHost' -DefaultValue $DatabaseHost -AllowMissing:$true
        $DatabaseName = Get-PVal -ParameterName 'DatabaseName' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.DatabaseName' -DefaultValue 'ATAPUtilities' -AllowMissing:$true

        if ($PSCmdlet.ParameterSetName -eq 'CredentialsFromVault') {
            $CredentialsKey = Get-PVal -ParameterName 'CredentialsKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.CredentialsKey' -DefaultValue $CredentialsKey -AllowMissing:$false
        }
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "PrimitiveId: $PrimitiveId | DatabaseName: $DatabaseName"
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

            $cmd = $sqlConnection.CreateCommand()
            $cmd.CommandText = @'
SELECT Id, PrimitiveId, InputName, InputType, IsRequired, DefaultValue
FROM   ATAPUtilities.RulePrimitiveInput
WHERE  PrimitiveId = @PrimitiveId
ORDER  BY InputName
'@
            $cmd.Parameters.Add((New-Object Microsoft.Data.SqlClient.SqlParameter('@PrimitiveId', $PrimitiveId))) | Out-Null
            $reader = $cmd.ExecuteReader()

            $inputs = [System.Collections.Generic.List[PSCustomObject]]::new()
            while ($reader.Read()) {
                $inputs.Add([PSCustomObject]@{
                    Id           = $reader['Id']
                    PrimitiveId  = $reader['PrimitiveId']
                    InputName    = $reader['InputName']
                    InputType    = $reader['InputType']
                    IsRequired   = $reader['IsRequired']
                    DefaultValue = if ($reader.IsDBNull($reader.GetOrdinal('DefaultValue'))) { $null } else { $reader['DefaultValue'] }
                })
            }
            $reader.Close()
            $cmd.Dispose()

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Loaded $($inputs.Count) input(s) for PrimitiveId $PrimitiveId"
            return $inputs.ToArray()
        }
        catch {
            $errorMessage = "Get-RulePrimitiveInputs failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
        finally {
            if ($sqlConnection) {
                if ($sqlConnection.State -eq [System.Data.ConnectionState]::Open) { $sqlConnection.Close() }
                $sqlConnection.Dispose()
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Database connection disposed'
            }
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
