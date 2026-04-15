function Set-ServiceLogonAccount {
  <#
    .SYNOPSIS
      Sets the Windows service logon account ('Log On As') for a named service.
    .DESCRIPTION
      Uses sc.exe config to set the obj= (logon account) and password= for a named
      Windows service. Checks the current StartName first and skips without change if
      the service already runs under the desired account (idempotent). Requires
      Administrator privileges.
    .PARAMETER ServiceName
      The Windows service name (e.g., 'INEDOPROGETSVC').
    .PARAMETER Credential
      A PSCredential whose UserName is the logon account in '.\User' or 'DOMAIN\User'
      form, and whose Password is that account's password.
    .EXAMPLE
      $cred = Get-Credential -UserName '.\SvcProGet' -Message 'Password for SvcProGet'
      Set-ServiceLogonAccount -ServiceName 'INEDOPROGETSVC' -Credential $cred
    .OUTPUTS
      PSCustomObject with ServiceName, AccountName, AlreadySet, Status.
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true)]
    [string] $ServiceName,

    [Parameter(Mandatory = $true)]
    [PSCredential] $Credential
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: Set-ServiceLogonAccount"

  try {
    $null = Get-Service -Name $ServiceName -ErrorAction Stop
  }
  catch {
    $errorMessage = "Service '$ServiceName' does not exist. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }

  try {
    $currentInfo = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    $desiredAccount = $Credential.UserName

    # Normalize both sides to dot-backslash local form for comparison
    $normalizedCurrent = $currentInfo.StartName -replace [regex]::Escape("$env:COMPUTERNAME\"), '.\'
    $normalizedDesired = $desiredAccount -replace [regex]::Escape("$env:COMPUTERNAME\"), '.\'

    if ($normalizedCurrent -ieq $normalizedDesired) {
      Write-PSFMessage -Level Important -Message "Service '$ServiceName' already runs as '$($currentInfo.StartName)'. No changes made."
      return [PSCustomObject]@{
        ServiceName = $ServiceName
        AccountName = $desiredAccount
        AlreadySet  = $true
        Status      = 'Success'
      }
    }

    if ($PSCmdlet.ShouldProcess($ServiceName, "Set logon account to '$desiredAccount'")) {
      $plainPassword = [System.Net.NetworkCredential]::new('', $Credential.Password).Password
      $scOutput = sc.exe config $ServiceName obj= $desiredAccount password= $plainPassword
      if ($LASTEXITCODE -ne 0) {
        throw "sc.exe config failed with exit code $LASTEXITCODE. Output: $($scOutput -join ' ')"
      }
      Write-PSFMessage -Level Important -Message "Service '$ServiceName' logon account changed from '$($currentInfo.StartName)' to '$desiredAccount'."
      return [PSCustomObject]@{
        ServiceName = $ServiceName
        AccountName = $desiredAccount
        AlreadySet  = $false
        Status      = 'Success'
      }
    }
  }
  catch {
    $errorMessage = "Failed to set logon account for service '$ServiceName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
  finally {
    Write-PSFMessage -Level Verbose -Message "Leaving function: Set-ServiceLogonAccount"
  }
}
