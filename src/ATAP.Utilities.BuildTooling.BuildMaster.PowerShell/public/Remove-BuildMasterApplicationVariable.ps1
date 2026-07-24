function Remove-BuildMasterApplicationVariable {
  <#
  .SYNOPSIS
    Removes one or more BuildMaster application variables.
  .DESCRIPTION
    Deletes variables from a BuildMaster application using the Variables
    Management entity endpoint. Missing variables are treated as successful
    no-ops so the cmdlet is safe to re-run.
  .PARAMETER ApplicationName
    The BuildMaster application name.
  .PARAMETER VariableName
    One or more variable names to remove.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then http://localhost:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key (Variables Management
    permission). Resolved via Get-PVal; value read with Get-SecretATAP.
  .OUTPUTS
    PSCustomObject describing removed variables and errors.
  .EXAMPLE
    Remove-BuildMasterApplicationVariable -ApplicationName 'ATAP.Utilities-CSharp' `
      -VariableName 'Branch', 'SourcePath'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    https://docs.inedo.com/docs/buildmaster/reference/api/variables
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$VariableName,

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key.utat01'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    $BuildMasterAdminApiKeySecretName = Get-PVal -ParameterName 'BuildMasterAdminApiKeySecretName' -originalPSBoundParameters $PSBoundParameters -DefaultValue $BuildMasterAdminApiKeySecretName

    function Resolve-BuildMasterApiSettings {
      param([string]$BaseUrl, [string]$AdminApiKeySecretName)
      $resolvedBaseUrl = $BaseUrl
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl) -and $null -ne $global:settings) {
        $settingsKey = 'BuildMasterBaseUrl'
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) { $settingsKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey'] }
        if ($global:settings.ContainsKey($settingsKey)) { $resolvedBaseUrl = [string]$global:settings[$settingsKey] }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User') }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) { $resolvedBaseUrl = 'http://localhost:50017' }

      # Retrieve the BuildMaster admin API key value via Get-SecretATAP using
      # the resolved secret name. The key value is never logged.
      $resolvedApiKey = $null
      $secretErrors = [System.Collections.Generic.List[string]]::new()
      foreach ($fieldName in @($null, 'token', 'key', 'password')) {
        try {
          $candidate = if ($null -eq $fieldName) {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
          } else {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -SecretField $fieldName -ErrorAction Stop
          }
          if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) { $resolvedApiKey = [string]$candidate; break }
        } catch {
          $fieldLabel = if ($null -eq $fieldName) { '<default>' } else { $fieldName }
          $secretErrors.Add("${fieldLabel}: $($_.Exception.Message)") | Out-Null
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedApiKey)) {
        $detail = if ($secretErrors.Count -gt 0) { " Last error: $($secretErrors[$secretErrors.Count - 1])" } else { '' }
        throw "Unable to resolve the BuildMaster admin API key value from secret '$AdminApiKeySecretName' via Get-SecretATAP.$detail"
      }
      return [PSCustomObject]@{ BaseUrl = $resolvedBaseUrl.TrimEnd('/'); ApiKey = $resolvedApiKey }
    }

    function Get-HttpStatusCodeFromError {
      param([object]$ErrorRecord)
      try {
        if ($null -ne $ErrorRecord.Exception.Response -and $null -ne $ErrorRecord.Exception.Response.StatusCode) {
          return [int]$ErrorRecord.Exception.Response.StatusCode
        }
      } catch {
      }
      $message = [string]$ErrorRecord.Exception.Message
      if ($message -match '\b404\b' -or $message -match 'not found') { return 404 }
      return $null
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -AdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $headers = @{ 'X-ApiKey' = $settings.ApiKey }
    $escapedApplication = [Uri]::EscapeDataString($ApplicationName)
  }

  process {
    $removed = [System.Collections.ArrayList]::new()
    $unchanged = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    foreach ($name in $VariableName) {
      $escapedVariable = [Uri]::EscapeDataString($name)
      $uri = '{0}/api/variables/application/{1}/{2}' -f $settings.BaseUrl, $escapedApplication, $escapedVariable
      $target = "$ApplicationName/$name"

      try {
        if ($PSCmdlet.ShouldProcess($target, 'Delete BuildMaster application variable')) {
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $uri" -Tag 'RestCall'
            Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -ErrorAction Stop | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $uri" -Tag 'RestCall'
            [void]$removed.Add($target)
          } catch {
            if ((Get-HttpStatusCodeFromError -ErrorRecord $_) -eq 404) {
              [void]$unchanged.Add($target)
            } else {
              throw
            }
          } finally {
          }
        }
      } catch {
        $errorMessage = "Failed to remove BuildMaster variable '$target'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        [void]$errors.Add($errorMessage)
      } finally {
      }
    }

    return [PSCustomObject]@{
      OperationName = $fn
      Succeeded     = ($errors.Count -eq 0)
      Application   = $ApplicationName
      Removed       = $removed.ToArray()
      Unchanged     = $unchanged.ToArray()
      Errors        = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
