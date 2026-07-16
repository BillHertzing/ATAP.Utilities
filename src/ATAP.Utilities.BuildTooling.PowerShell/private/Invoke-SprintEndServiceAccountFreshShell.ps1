function Invoke-SprintEndServiceAccountFreshShell {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [pscredential]$Credential,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Identity
  )

  begin {
    $fn = 'Invoke-SprintEndServiceAccountFreshShell'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'
  }

  process {
    $userName = $Credential.UserName
    $domain = $null
    if ($userName -match '^(?<Domain>[^\\]+)\\(?<User>.+)$') {
      $domain = $Matches.Domain
      $userName = $Matches.User
    }

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = 'pwsh'
    $processInfo.Arguments = '-Command "''SERVICE_ACCOUNT_PROFILE_OK''"'
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.LoadUserProfile = $true
    $processInfo.UserName = $userName
    if (-not [string]::IsNullOrWhiteSpace($domain)) {
      $processInfo.Domain = $domain
    }
    $processInfo.Password = $Credential.Password

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo
    try {
      [void]$process.Start()
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      $process.WaitForExit()
      $stdout = $stdoutTask.GetAwaiter().GetResult()
      $stderr = $stderrTask.GetAwaiter().GetResult()
      $output = @(
        $stdout -split [Environment]::NewLine
        $stderr -split [Environment]::NewLine
      ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
      $errorText = $output -join [Environment]::NewLine
      return [PSCustomObject]@{
        Identity = $Identity
        Tested   = $true
        Ok       = ($process.ExitCode -eq 0 -and $output -contains 'SERVICE_ACCOUNT_PROFILE_OK' -and $errorText -notmatch '(?im)ParserError|not recognized|Could not find|The term .* is not recognized')
        ExitCode = $process.ExitCode
        Output   = @($output)
      }
    } catch {
      return [PSCustomObject]@{
        Identity = $Identity
        Tested   = $true
        Ok       = $false
        ExitCode = $null
        Output   = @($_.Exception.Message)
      }
    } finally {
      if ($process) {
        $process.Dispose()
      }
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
