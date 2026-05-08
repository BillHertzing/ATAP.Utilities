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
        AI assisted using Powershell.instructions.md as guidelines
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

    function ConvertTo-PlainTextFromSecureString {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [SecureString] $SecureValue
        )

        $bstr = [IntPtr]::Zero
        try {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
            [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }

    function Get-LocalUserCompat {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Name
        )

        $getLocalUserCommand = Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue
        if ($null -ne $getLocalUserCommand) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "[$Name] Using LocalAccounts cmdlet path for lookup (Get-LocalUser)"
            return Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "[$Name] Using ADSI fallback path for lookup (WinNT provider)"

        try {
            $computer = [ADSI]("WinNT://{0},computer" -f $env:COMPUTERNAME)
            $user = $computer.psbase.Children.Find($Name, 'user')
            if ($null -ne $user) {
                return [PSCustomObject]@{ Name = $Name }
            }
        }
        catch {
            return $null
        }

        return $null
    }

    function New-LocalUserCompat {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Name,

            [Parameter(Mandatory)]
            [SecureString] $SecurePassword,

            [string] $DisplayName,

            [string] $AccountDescription
        )

        $newLocalUserCommand = Get-Command -Name New-LocalUser -ErrorAction SilentlyContinue
        if ($null -ne $newLocalUserCommand) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "[$Name] Using LocalAccounts cmdlet path for create (New-LocalUser)"
            New-LocalUser `
                -Name                     $Name `
                -Password                 $SecurePassword `
                -FullName                 $DisplayName `
                -Description              $AccountDescription `
                -PasswordNeverExpires `
                -UserMayNotChangePassword `
                -AccountNeverExpires `
                -ErrorAction Stop | Out-Null
            return
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "[$Name] Using ADSI fallback path for create (WinNT provider)"

        $plainPassword = ConvertTo-PlainTextFromSecureString -SecureValue $SecurePassword
        $computer = [ADSI]("WinNT://{0},computer" -f $env:COMPUTERNAME)
        $newUser = $computer.Create('user', $Name)
        try {
            $newUser.SetPassword($plainPassword)
            if (-not [string]::IsNullOrWhiteSpace($DisplayName)) {
                $null = $newUser.Put('FullName', $DisplayName)
            }
            if (-not [string]::IsNullOrWhiteSpace($AccountDescription)) {
                $null = $newUser.Put('Description', $AccountDescription)
            }

            # Set account flags equivalent to non-expiring password and user cannot change password.
            $ADS_UF_DONT_EXPIRE_PASSWD = 0x10000
            $ADS_UF_PASSWD_CANT_CHANGE = 0x40
            $newUser.UserFlags = ($ADS_UF_DONT_EXPIRE_PASSWD -bor $ADS_UF_PASSWD_CANT_CHANGE)
            $newUser.SetInfo()
        }
        finally {
            if ($null -ne $newUser -and [System.Runtime.InteropServices.Marshal]::IsComObject($newUser)) {
                [void][Runtime.InteropServices.Marshal]::ReleaseComObject($newUser)
            }
            if ($null -ne $computer -and [System.Runtime.InteropServices.Marshal]::IsComObject($computer)) {
                [void][Runtime.InteropServices.Marshal]::ReleaseComObject($computer)
            }
        }
    }

    function Remove-LocalUserCompat {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string] $Name
        )

        $removeLocalUserCommand = Get-Command -Name Remove-LocalUser -ErrorAction SilentlyContinue
        if ($null -ne $removeLocalUserCommand) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
                -Message "[$Name] Using LocalAccounts cmdlet path for remove (Remove-LocalUser)"
            Remove-LocalUser -Name $Name -ErrorAction Stop
            return
        }

        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
            -Message "[$Name] Using ADSI fallback path for remove (WinNT provider)"

        $computer = [ADSI]("WinNT://{0},computer" -f $env:COMPUTERNAME)
        try {
            $computer.Delete('user', $Name)
        }
        finally {
            if ($null -ne $computer -and [System.Runtime.InteropServices.Marshal]::IsComObject($computer)) {
                [void][Runtime.InteropServices.Marshal]::ReleaseComObject($computer)
            }
        }
    }

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
        $existingUser = Get-LocalUserCompat -Name $AccountName

        if ($State -eq 'Present') {

            # --- Create the account if it does not exist ---
            if ($null -eq $existingUser) {
                if ($PSCmdlet.ShouldProcess($AccountName, 'Create local service account')) {
                    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
                        -Message "[$AccountName] Creating local user account (FullName='$FullName')"

                    New-LocalUserCompat `
                        -Name               $AccountName `
                        -SecurePassword     $Password `
                        -DisplayName        $FullName `
                        -AccountDescription $Description

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

                    Remove-LocalUserCompat -Name $AccountName

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
