function New-ProGetApiKey {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$ApiKeyName,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [ValidateSet("view", "add", "delete", "promote")]
    [string[]]$PackagePermissions ,

    [Parameter(Mandatory)]
    [ValidateSet("utat022")]
    [string]$ProGetHost,

    [Parameter(Mandatory)]
    [int]$ProGetBasePort,

    # If present, use it, but if not, let ProGet generate an API key
    [string]$apiKey
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: New-ProGetApiKey"

  # ToDo: Fetch from Secrets vault instead of environment variable
  # TODo: Set and expiration date, and ensure a policy that rotates the key value before they expire
  $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')

  if (-not $adminApiKey) {
    $errorMessage = "ProGet admin API key is not available in environment variable."
    Write-PSFMessage -Level Error -Message $errorMessage
    throw $errorMessage
  }



  # ToDo: eventually switch to https
  $uri = "http://${ProGetHost}:${ProGetBasePort}/api/api-keys/create"

  $body = @{
    type               = 'Feed'
    keyName            = $ApiKeyName
    displayName        = $ApiKeyName
    description        = "API key for $FeedName"
    feed               = $FeedName
    feedGroup          = $null
    packagePermissions = $PackagePermissions
  }
  if ($null -ne $apiKey) {
    $body.key = $apiKey
  }
  $headers = @{ "X-ApiKey" = $adminApiKey }

  if ($PSCmdlet.ShouldProcess("ProGet", "Create API key '$ApiKeyName' for feed '$FeedName'")) {
    try {
      Write-PSFMessage -Level Verbose -Message "Calling ProGet API to create API key '$ApiKeyName' on port $ProGetBasePort"
      $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
      Write-PSFMessage -Level Important -Message "Successfully created API key '$ApiKeyName' for feed '$FeedName'"
    }
    catch {
      $errorMessage = "Failed to create API key '$ApiKeyName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
      throw $_
    }
    Write-PSFMessage -Level Verbose -Message "Exiting function: New-ProGetApiKey"
    $response
  }
}
