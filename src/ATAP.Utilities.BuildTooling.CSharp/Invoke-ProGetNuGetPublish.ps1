<#
.SYNOPSIS
  Publishes one NuGet package to ProGet through a SecretName-only boundary.
.DESCRIPTION
  Resolves the ProGet API key with Get-SecretATAP immediately before the
  authenticated delete and push operations. The resolved value is never
  accepted as a parameter, written to output, or persisted in an environment
  variable. The dotnet CLI requires an internal --api-key argument; this script
  is the bounded leaf that performs that unavoidable handoff.
.PARAMETER NupkgPath
  Full path to the package.
.PARAMETER Source
  ProGet NuGet source URL.
.PARAMETER ProGetBaseUrl
  ProGet base URL used for the idempotent v2 delete.
.PARAMETER PackageId
  NuGet package identifier.
.PARAMETER PackageVersion
  NuGet package version.
.PARAMETER ProGetApiKeySecretName
  ATAP secret-store name. Defaults to the administrator key because deletion is
  an administrative operation.
.OUTPUTS
  None.
#>
#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$NupkgPath,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Source,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetBaseUrl,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageId,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion,
  [ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
)

function Invoke-ProGetNuGetPublish {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$NupkgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Source,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProGetBaseUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageVersion,
    [ValidateNotNullOrEmpty()][string]$ProGetApiKeySecretName = 'ProGet.Admin.API.Key'
  )

  begin {
    if (-not (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue)) {
      throw 'Get-SecretATAP is required to resolve ProGetApiKeySecretName.'
    }
  }

  process {
    if (-not $PSCmdlet.ShouldProcess("$PackageId $PackageVersion", "Replace package in $Source")) {
      return
    }

    $proGetApiKey = $null
    try {
      $proGetApiKey = Get-SecretATAP -SecretName $ProGetApiKeySecretName
      if ([string]::IsNullOrWhiteSpace([string]$proGetApiKey)) {
        throw "SecretName '$ProGetApiKeySecretName' resolved to an empty value."
      }

      $deleteUri = "$($ProGetBaseUrl.TrimEnd('/'))/nuget/nuget-experimental/v2/package/$([uri]::EscapeDataString($PackageId))/$([uri]::EscapeDataString($PackageVersion))"
      try {
        Invoke-RestMethod -Method Delete -Uri $deleteUri -Headers @{ 'X-ApiKey' = $proGetApiKey } -ErrorAction Stop | Out-Null
      }
      catch {
        if ($null -eq $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) {
          throw
        }
      }

      & dotnet nuget push $NupkgPath --source $Source --api-key $proGetApiKey
      if ($LASTEXITCODE -ne 0) {
        throw "dotnet nuget push failed with exit code $LASTEXITCODE."
      }
    }
    finally {
      $proGetApiKey = $null
    }
  }

  end {}
}

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '&') {
  Invoke-ProGetNuGetPublish @PSBoundParameters
}
