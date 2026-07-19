function Set-BuildMasterApplicationVariables {
  <#
  .SYNOPSIS
    Creates or updates BuildMaster application variables from a hashtable.
  .DESCRIPTION
    Sets BuildMaster configuration variables on a single application using the
    Variables Management API. The -Variables parameter accepts a hashtable of
    variable names to values.

    Simple values are written through the entity single-variable endpoint after
    the existing value is checked. Existing matching simple values are skipped.

    Hashtable values may include Value, Sensitive, and Evaluate keys. Sensitive
    or Evaluate variables are written through the scoped-variable endpoint so
    that the sensitivity/evaluation metadata is preserved.
  .PARAMETER ApplicationName
    The BuildMaster application name.
  .PARAMETER Variables
    Hashtable mapping variable names to values. Values may be strings or
    hashtables like @{ Value = 'secret'; Sensitive = $true }.
  .PARAMETER BuildMasterBaseUrl
    Base URL for the BuildMaster server. Defaults to $global:settings,
    BUILDMASTER_BASE_URL, then http://localhost:50017.
  .PARAMETER BuildMasterAdminApiKeySecretName
    ATAP secret name for the BuildMaster admin API key (Variables Management
    permission). Resolved via Get-PVal; value read with Get-SecretATAP.
  .OUTPUTS
    PSCustomObject describing changed, unchanged, and error entries.
  .EXAMPLE
    Set-BuildMasterApplicationVariables -ApplicationName 'ATAP.Utilities-CSharp' `
      -Variables @{ Branch = '100-Sprint-0007-work-items'; Configuration = 'Release' }
  .EXAMPLE
    Set-BuildMasterApplicationVariables -ApplicationName 'ATAP.Utilities-CSharp' `
      -Variables @{ ProGetApiKeySecretName = @{ Value = 'ProGet.BuildMaster.API.Key'; Sensitive = $false } }
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
    [ValidateNotNull()]
    [hashtable]$Variables,

    [string]$BuildMasterBaseUrl,

    [string]$BuildMasterAdminApiKeySecretName = 'BuildMaster.Admin.API.Key'
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
        if ($null -ne $global:configRootKeys -and $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']) {
          $settingsKey = $global:configRootKeys['BuildMasterBaseUrlConfigRootKey']
        }
        if ($global:settings.ContainsKey($settingsKey)) {
          $resolvedBaseUrl = [string]$global:settings[$settingsKey]
        }
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'Process')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = [Environment]::GetEnvironmentVariable('BUILDMASTER_BASE_URL', 'User')
      }
      if ([string]::IsNullOrWhiteSpace($resolvedBaseUrl)) {
        $resolvedBaseUrl = 'http://localhost:50017'
      }

      # Retrieve the BuildMaster admin API key value via Get-SecretATAP using
      # the resolved secret name. The key value is never logged.
      $resolvedApiKey = $null
      $secretErrors = [System.Collections.Generic.List[string]]::new()
      foreach ($fieldName in @($null, 'token', 'key', 'password')) {
        try {
          $candidate = if ($null -eq $fieldName) {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
          } else {
            Get-SecretATAP -SecretName $AdminApiKeySecretName -SecretField $fieldName -SecretStoreType 'BitwardenSecretsManager' -ErrorAction Stop
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
      if ($message -match '\b404\b' -or $message -match 'not found') {
        return 404
      }
      return $null
    }

    function ConvertTo-BuildMasterVariableSpec {
      param(
        [string]$Name,
        [object]$InputValue
      )

      $value = $InputValue
      $sensitive = $false
      $evaluate = $false

      if ($InputValue -is [hashtable]) {
        if ($InputValue.ContainsKey('Value')) { $value = $InputValue['Value'] }
        elseif ($InputValue.ContainsKey('value')) { $value = $InputValue['value'] }
        if ($InputValue.ContainsKey('Sensitive')) { $sensitive = [bool]$InputValue['Sensitive'] }
        elseif ($InputValue.ContainsKey('sensitive')) { $sensitive = [bool]$InputValue['sensitive'] }
        if ($InputValue.ContainsKey('Evaluate')) { $evaluate = [bool]$InputValue['Evaluate'] }
        elseif ($InputValue.ContainsKey('evaluate')) { $evaluate = [bool]$InputValue['evaluate'] }
      }

      return [PSCustomObject]@{
        Name      = $Name
        Value     = [string]$value
        Sensitive = $sensitive
        Evaluate  = $evaluate
      }
    }

    $settings = Resolve-BuildMasterApiSettings -BaseUrl $BuildMasterBaseUrl -AdminApiKeySecretName $BuildMasterAdminApiKeySecretName
    $headers = @{ 'X-ApiKey' = $settings.ApiKey }
    $escapedApplication = [Uri]::EscapeDataString($ApplicationName)
  }

  process {
    $changed = [System.Collections.ArrayList]::new()
    $unchanged = [System.Collections.ArrayList]::new()
    $errors = [System.Collections.ArrayList]::new()

    foreach ($variableName in $Variables.Keys) {
      $spec = ConvertTo-BuildMasterVariableSpec -Name ([string]$variableName) -InputValue $Variables[$variableName]
      $escapedVariable = [Uri]::EscapeDataString($spec.Name)
      $singleUri = '{0}/api/variables/application/{1}/{2}' -f $settings.BaseUrl, $escapedApplication, $escapedVariable
      $scopedUri = '{0}/api/variables/scoped/single' -f $settings.BaseUrl
      $target = "$ApplicationName/$($spec.Name)"

      try {
        if ($spec.Sensitive -or $spec.Evaluate) {
          if ($PSCmdlet.ShouldProcess($target, 'Set BuildMaster scoped application variable')) {
            $payload = [ordered]@{
              name                = $spec.Name
              value               = $spec.Value
              sensitive           = $spec.Sensitive
              evaluate            = $spec.Evaluate
              server              = $null
              role                = $null
              environment         = $null
              application         = $ApplicationName
              'application-group' = $null
            }
            $body = $payload | ConvertTo-Json -Depth 5
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $scopedUri" -Tag 'RestCall'
            Invoke-RestMethod -Uri $scopedUri -Method Post -Headers $headers -ContentType 'application/json' -Body $body -ErrorAction Stop | Out-Null
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $scopedUri" -Tag 'RestCall'
            [void]$changed.Add($target)
          }
          continue
        }

        $existingValue = $null
        $exists = $false
        try {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $singleUri" -Tag 'RestCall'
          $existingValue = Invoke-RestMethod -Uri $singleUri -Method Get -Headers $headers -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $singleUri" -Tag 'RestCall'
          $exists = $true
        } catch {
          if ((Get-HttpStatusCodeFromError -ErrorRecord $_) -ne 404) {
            throw
          }
        } finally {
        }

        if ($exists -and [string]$existingValue -eq $spec.Value) {
          [void]$unchanged.Add($target)
          continue
        }

        if ($PSCmdlet.ShouldProcess($target, 'Set BuildMaster application variable')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $singleUri" -Tag 'RestCall'
          Invoke-RestMethod -Uri $singleUri -Method Post -Headers $headers -ContentType 'text/plain' -Body $spec.Value -ErrorAction Stop | Out-Null
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $singleUri" -Tag 'RestCall'
          [void]$changed.Add($target)
        }
      } catch {
        $errorMessage = "Failed to set BuildMaster variable '$target'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        [void]$errors.Add($errorMessage)
      } finally {
      }
    }

    return [PSCustomObject]@{
      OperationName = $fn
      Succeeded     = ($errors.Count -eq 0)
      Application   = $ApplicationName
      Changed       = $changed.ToArray()
      Unchanged     = $unchanged.ToArray()
      Errors        = $errors.ToArray()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
