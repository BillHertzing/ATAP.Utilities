function New-ProGetApiKey {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$KeyName,

    [Parameter(Mandatory)]
    [string]$FeedName,

    [Parameter(Mandatory)]
    [ValidateSet("ViewFeed", "AddPackages", "DeletePackages", "AdministerFeed")]
    [string[]]$Permissions,

    [int]$ProGetPort = 81
  )

  Write-PSFMessage -Level Verbose -Message "Entering function: New-ProGetApiKey"

  # ToDo: Fetch from Secrets vault instead of environment variable
  $adminApiKey = [Environment]::GetEnvironmentVariable($global:configRootKeys['ProGetAdminApiKeyConfigRootKey'], 'Process')

  if (-not $adminApiKey) {
    $errorMessage = "ProGet admin API key is not available in environment variable."
    Write-PSFMessage -Level Error -Message $errorMessage
    throw $errorMessage
  }

  $uri = "http://localhost:$ProGetPort/api/apikeys"

  $body = @{
    KeyName           = $KeyName
    Description       = "Auto-generated API key for feed '$FeedName'"
    MayAccessAllFeeds = $false
    FeedPermissions   = @(@{
        FeedName = $FeedName
        Roles    = $Permissions
      })
  }

  $headers = @{ "X-ApiKey" = $adminApiKey }

  if ($PSCmdlet.ShouldProcess("ProGet", "Create API key '$KeyName' for feed '$FeedName'")) {
    try {
      Write-PSFMessage -Level Verbose -Message "Calling ProGet API to create API key '$KeyName' on port $ProGetPort"
      Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json"
      Write-PSFMessage -Level Important -Message "Successfully created API key '$KeyName' for feed '$FeedName'"
    }
    catch {
      $errorMessage = "Failed to create API key '$KeyName'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
      throw $_
    }
    finally {
      Write-PSFMessage -Level Verbose -Message "Exiting function: New-ProGetApiKey"
    }
  }
}
