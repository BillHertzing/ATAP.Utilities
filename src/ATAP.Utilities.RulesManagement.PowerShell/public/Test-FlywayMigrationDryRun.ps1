<#
.SYNOPSIS
    Runs 'flyway validate' against a migration file without executing it.
.DESCRIPTION
    Invokes the Flyway CLI with the 'validate' command against a given migration path
    and JDBC connection URL. This is the safety gate before New-RuleKindMigration is
    allowed to promote its SQL to the migrations folder. Does NOT run 'flyway migrate'.
.PARAMETER MigrationPath
    Full path to the folder containing migration scripts, or a single .sql file.
.PARAMETER FlywayUrl
    JDBC URL of the target database, e.g. jdbc:sqlserver://localhost;databaseName=ATAPUtilities.
.PARAMETER FlywayUser
    SQL login username. Leave empty when using Integrated Security.
.PARAMETER FlywayPassword
    SQL login password. Leave empty when using Integrated Security.
.PARAMETER FlywayExecutable
    Path to the flyway CLI executable. Defaults to 'flyway' (must be on PATH),
    or the value at global settings RulesManagement.FlywayExecutable.
.OUTPUTS
    PSCustomObject with Success (bool), ExitCode (int), Output (string[]), Errors (string[]).
.EXAMPLE
    Test-FlywayMigrationDryRun -MigrationPath 'C:\repo\migrations' -FlywayUrl 'jdbc:sqlserver://localhost;databaseName=ATAPUtilities;integratedSecurity=true'
.NOTES
    AI assisted using ./claude/Rules/Powershell.md as guidelines
.LINK
    https://github.com/whertzing/ATAP.Utilities
#>
function Test-FlywayMigrationDryRun {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $MigrationPath,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $FlywayUrl,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $FlywayUser,

        [Parameter(Mandatory = $false, Position = 3)]
        [string] $FlywayPassword,

        [Parameter(Mandatory = $false, Position = 4)]
        [string] $FlywayExecutable
    )

    BEGIN {
        $fn = 'Test-FlywayMigrationDryRun'
        $mn = 'ATAP.Utilities.RulesManagement.PowerShell'
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

        try {
            if (-not (Get-Command -Name 'Get-PVal' -CommandType Function -ErrorAction SilentlyContinue)) {
                . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
            }
        }
        catch {
            $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            throw
        }

        $MigrationPath    = Get-PVal -ParameterName 'MigrationPath'    -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.MigrationPath'    -DefaultValue $MigrationPath
        $FlywayUrl        = Get-PVal -ParameterName 'FlywayUrl'        -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.FlywayUrl'        -DefaultValue $FlywayUrl
        $FlywayUser       = Get-PVal -ParameterName 'FlywayUser'       -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.FlywayUser'       -DefaultValue $FlywayUser       -AllowMissing:$true
        $FlywayPassword   = Get-PVal -ParameterName 'FlywayPassword'   -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.FlywayPassword'   -DefaultValue $FlywayPassword   -AllowMissing:$true
        $FlywayExecutable = Get-PVal -ParameterName 'FlywayExecutable' -originalPSBoundParameters $PSBoundParameters -dottedPath 'RulesManagement.FlywayExecutable' -DefaultValue 'flyway'          -AllowMissing:$true

        if (-not (Test-Path -Path $MigrationPath)) {
            throw "MigrationPath not found: $MigrationPath"
        }

        if (-not (Get-Command -Name $FlywayExecutable -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Flyway executable '$FlywayExecutable' not found. Ensure Flyway CLI is installed and on PATH."
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "MigrationPath: $MigrationPath | FlywayUrl: $FlywayUrl | Executable: $FlywayExecutable"
    }

    PROCESS {
        try {
            $flywayArgs = @(
                'validate'
                "-url=$FlywayUrl"
                "-locations=filesystem:$MigrationPath"
            )
            if (-not [string]::IsNullOrWhiteSpace($FlywayUser))     { $flywayArgs += "-user=$FlywayUser" }
            if (-not [string]::IsNullOrWhiteSpace($FlywayPassword)) { $flywayArgs += "-password=$FlywayPassword" }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling Invoke-Expression: $FlywayExecutable $($flywayArgs -join ' ')" -Tag 'InvokeExpressionCall'
            $outputLines = & $FlywayExecutable @flywayArgs 2>&1
            $exitCode    = $LASTEXITCODE
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from Invoke-Expression: $FlywayExecutable" -Tag 'InvokeExpressionCall'

            $stdOut = $outputLines | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
            $stdErr = $outputLines | Where-Object { $_ -is  [System.Management.Automation.ErrorRecord] } |
                      ForEach-Object { $_.Exception.Message }

            $success = $exitCode -eq 0
            if ($success) {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'Flyway validate succeeded'
            }
            else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Flyway validate exited with code $exitCode"
                foreach ($line in $stdErr) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Flyway stderr: $line"
                }
            }

            return [PSCustomObject]@{
                Success  = $success
                ExitCode = $exitCode
                Output   = $stdOut
                Errors   = $stdErr
            }
        }
        catch {
            $errorMessage = "Test-FlywayMigrationDryRun failed: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    END {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
    }
}
