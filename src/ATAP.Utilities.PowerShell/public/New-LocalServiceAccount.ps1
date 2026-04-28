#Requires -RunAsAdministrator
#Requires -Modules PSFramework

function New-LocalServiceAccount {
    <#
    .SYNOPSIS
        Creates or removes a Windows local user account intended for use as a service identity.

    .DESCRIPTION
        Idempotently provisions a local Windows user account for service usage:
          - Creates the account with a non-expiring password the user cannot change.
          - Optionally grants the SeServiceLogonRight Windows privilege via the LSA API,
            enabling the account to be used as a Windows service Log On identity.
          - Removing the account (State = 'Absent') revokes nothing; clean up LSA rights
            separately if required.

        Uses built-in New-LocalUser / Remove-LocalUser cmdlets — no Carbon module dependency.
        Requires the PS_LSA C# type (Type-PSLSA.ps1 in the same public/ folder) whenever
        -GrantSeServiceLogonRight is specified.

    .PARAMETER AccountName
        Name of the local account to create or remove (e.g. 'SvcProGet').
        Must begin with a letter; may contain letters, digits, underscores, or hyphens.
        Maximum 20 characters.

    .PARAMETER FullName
        Optional display name stored on the account.

    .PARAMETER Description
        Optional description stored on the account.

    .PARAMETER Password
        SecureString password for the account. The account is configured so that the
        password never expires and the user may not change it.

    .PARAMETER State
        'Present' (default) — create the account if it does not yet exist.
        'Absent'            — remove the account if it exists.

    .PARAMETER GrantSeServiceLogonRight
        When specified, grants the SeServiceLogonRight privilege to
        COMPUTERNAME\AccountName using the Windows LSA API.
        Requires the PS_LSA type to be available (auto-loaded from Type-PSLSA.ps1
        if not already in session).

    .OUTPUTS
        PSCustomObject with fields:
          AccountName, State, UserCreated, UserAlreadyExisted, UserRemoved,
          SeServiceLogonRight, Status

    .EXAMPLE
        $pw = ConvertTo-SecureString 'S3rv!ceP@ss' -AsPlainText -Force
        New-LocalServiceAccount -AccountName SvcProGet -Password $pw -GrantSeServiceLogonRight

        Creates SvcProGet (if absent) and grants SeServiceLogonRight.

    .EXAMPLE
        New-LocalServiceAccount -AccountName SvcProGet -Password $pw -State Absent

        Removes the SvcProGet account if it exists.

    .NOTES
        Must run in an elevated (Administrator) session.
        To verify the right was granted after the call:
            Get-AccountsWithUserRight -Right SeServiceLogonRight
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9_-]{0,19}$')]
        [string] $AccountName,

        [string] $FullName = '',

        [string] $Description = '',

        [Parameter(Mandatory)]
        [SecureString] $Password,

        [ValidateSet('Present', 'Absent')]
        [string] $State = 'Present',

        [switch] $GrantSeServiceLogonRight
    )

    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message "[$AccountName] Start: State=$State GrantSeServiceLogonRight=$($GrantSeServiceLogonRight.IsPresent)"

    # Ensure the PS_LSA C# type is loaded before any LSA operations
    if ($GrantSeServiceLogonRight -and
        -not ([System.Management.Automation.PSTypeName]'PS_LSA.LsaWrapper').Type) {
        $typeScript = Join-Path $PSScriptRoot 'Type-PSLSA.ps1'
        if (-not (Test-Path $typeScript)) {
            throw "PS_LSA type is not loaded and Type-PSLSA.ps1 was not found at '$typeScript'. " +
                  "Load the full ATAP.Utilities.PowerShell module or dot-source Type-PSLSA.ps1 first."
        }
        . $typeScript
    }

    $result = [PSCustomObject]@{
        AccountName         = $AccountName
        State               = $State
        UserCreated         = $false
        UserAlreadyExisted  = $false
        UserRemoved         = $false
        SeServiceLogonRight = $null
        Status              = 'NotStarted'
    }

    try {
        $existingUser = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue

        if ($State -eq 'Present') {

            # --- Create the account if it does not exist ---
            if ($null -eq $existingUser) {
                if ($PSCmdlet.ShouldProcess($AccountName, 'Create local service account')) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Creating local user account (FullName='$FullName')"

                    New-LocalUser `
                        -Name                     $AccountName `
                        -Password                 $Password `
                        -FullName                 $FullName `
                        -Description              $Description `
                        -PasswordNeverExpires `
                        -UserMayNotChangePassword `
                        -AccountNeverExpires `
                        -ErrorAction Stop | Out-Null

                    $result.UserCreated = $true
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Local user account created"
                }
            }
            else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "[$AccountName] User already exists; skipping creation (idempotent)"
                $result.UserAlreadyExisted = $true
            }

            # --- Optionally grant SeServiceLogonRight via LSA ---
            if ($GrantSeServiceLogonRight) {
                $fqAccount = "$env:COMPUTERNAME\$AccountName"
                if ($PSCmdlet.ShouldProcess($fqAccount, 'Grant SeServiceLogonRight')) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Granting SeServiceLogonRight to '$fqAccount'"

                    $lsa = New-Object PS_LSA.LsaWrapper
                    try {
                        $lsa.AddPrivilege($fqAccount, [PS_LSA.Rights]::SeServiceLogonRight)
                        $result.SeServiceLogonRight = $true
                        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                            -Message "[$AccountName] SeServiceLogonRight granted to '$fqAccount'"
                    }
                    finally {
                        $lsa.Dispose()
                    }
                }
            }

            $result.Status = 'Success'

        }
        elseif ($State -eq 'Absent') {

            if ($null -ne $existingUser) {
                if ($PSCmdlet.ShouldProcess($AccountName, 'Remove local user account')) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Removing local user account"

                    Remove-LocalUser -Name $AccountName -ErrorAction Stop

                    $result.UserRemoved = $true
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Local user account removed"
                }
            }
            else {
                Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                    -Message "[$AccountName] User does not exist; nothing to remove (idempotent)"
            }

            $result.Status = 'Success'
        }
    }
    catch {
        $result.Status = "Error: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
            -Message "[$AccountName] $($_.Exception.Message)" -Exception $_.Exception
        throw
    }

    $result
}
