function Initialize-DabMcpConfiguration {
  <#
  .SYNOPSIS
  Creates a secret-free Data API Builder configuration for an MCP server.

  .DESCRIPTION
  Uses DAB's @env() configuration syntax, leaving the connection string outside the
  JSON file. Existing configuration is preserved unless Force is specified. The
  ContentSummaryExecuteOnly mode emits one deterministic stored-procedure custom tool
  with REST, GraphQL, and generic MCP DML disabled.

  .PARAMETER ConfigPath
  DAB configuration file to create.

  .PARAMETER ConnectionStringEnvironmentVariable
  Process environment variable that DAB resolves at startup.

  .PARAMETER ExposureMode
  Keeps the legacy explicit-entity initializer by default. The two all-entities modes
  configure supported objects in every schema. ContentSummaryExecuteOnly writes the
  dedicated, least-privilege ContentSummary configuration without invoking DAB or a
  secret provider.

  .PARAMETER Tier
  Database tier represented by the dedicated ContentSummary server metadata.

  .PARAMETER NativeKey
  Canonical native MCP server key. ContentSummaryExecuteOnly requires the exact key
  assigned to Tier.

  .PARAMETER CatalogPort
  Static collision-defense port assigned to the tier's MCP catalog record. DAB stdio
  does not bind this port; ContentSummaryExecuteOnly validates the catalog contract.

  .PARAMETER ConnectionStringSecretName
  SecretName reference used by the launcher. The value is validated and returned as
  metadata but is not resolved or written to the DAB configuration.

  .PARAMETER Role
  DAB role allowed to execute the ContentSummary custom tool.

  .PARAMETER ExistingNativeKeys
  Existing catalog keys used to reject duplicate reservations.

  .PARAMETER ExistingCatalogPorts
  Existing catalog ports used to reject collisions and duplicate reservations.

  .PARAMETER DabVersion
  Pinned DAB schema version used by the deterministic ContentSummary configuration.

  .PARAMETER Force
  Replaces an existing configuration. Without Force, ContentSummaryExecuteOnly
  preserves only a byte-identical configuration and rejects any wider contract.

  .OUTPUTS
  PSCustomObject.

  .EXAMPLE
  Initialize-DabMcpConfiguration -ExposureMode ContentSummaryExecuteOnly `
    -ConfigPath 'C:\Dab\dab-contentsummary-config.json' -Tier Exp `
    -NativeKey 'dab-contentsummary-ataputilities-exp' -CatalogPort 5104 `
    -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing'

  .NOTES
  ContentSummaryExecuteOnly never resolves a credential, starts DAB, registers a
  server, or binds a listener.

  .LINK
  https://learn.microsoft.com/azure/data-api-builder/mcp/how-to-configure-custom-tools
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json'),

    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string] $ConnectionStringEnvironmentVariable = 'DAB_ATAPUTILITIES_CONNECTION_STRING',

    [ValidateSet('ExplicitEntity', 'AllEntitiesReadOnly', 'AllEntitiesReadWrite', 'ContentSummaryExecuteOnly')]
    [string] $ExposureMode = 'ExplicitEntity',

    [ValidateSet('Production', 'QA', 'Integration', 'Dev', 'Exp')]
    [string] $Tier = 'Exp',

    [string] $NativeKey,

    [int] $CatalogPort,

    [string] $ConnectionStringSecretName,

    [string] $Role = 'contentsummary-mcp-reader',

    [string[]] $ExistingNativeKeys = @(),

    [int[]] $ExistingCatalogPorts = @(),

    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string] $DabVersion = '2.0.9',

    [switch] $Force
  )

  begin {
    $fn = 'Initialize-DabMcpConfiguration'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Preparing DAB MCP configuration '$ConfigPath'."
  }

  process {
    try {
      if ($ExposureMode -eq 'ContentSummaryExecuteOnly') {
        $tierCatalog = @{
          Exp = [pscustomobject]@{ Suffix = 'exp'; Port = 5104 }
          Dev = [pscustomobject]@{ Suffix = 'dev'; Port = 5114 }
          QA = [pscustomobject]@{ Suffix = 'qa'; Port = 5124 }
          Integration = [pscustomobject]@{ Suffix = 'integration'; Port = 5134 }
          Production = [pscustomobject]@{ Suffix = 'production'; Port = 5144 }
        }
        $tierDefinition = $tierCatalog[$Tier]
        $expectedNativeKey = "dab-contentsummary-ataputilities-$($tierDefinition.Suffix)"
        $expectedCatalogPort = [int] $tierDefinition.Port
        $expectedRole = 'contentsummary-mcp-reader'
        $entityName = 'QueryContentSummaryCandidatesForMcpV1'
        $entitySource = '[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]'
        $toolName = 'query_content_summary_candidates_for_mcp_v1'

        if ([string]::IsNullOrWhiteSpace($NativeKey) -or $NativeKey -cne $expectedNativeKey) {
          throw "ContentSummary tier '$Tier' requires native key '$expectedNativeKey'."
        }
        if ($CatalogPort -ne $expectedCatalogPort) {
          throw "ContentSummary tier '$Tier' requires catalog port '$expectedCatalogPort'."
        }
        if ([string]::IsNullOrWhiteSpace($ConnectionStringSecretName) -or
          $ConnectionStringSecretName -notmatch '^(?=.{3,255}$)[A-Za-z0-9][A-Za-z0-9_-]*(?:\.[A-Za-z0-9][A-Za-z0-9_-]*)+$') {
          throw 'ConnectionStringSecretName must be a non-secret dotted reference name.'
        }
        if ($Role -cne $expectedRole) {
          throw "ContentSummary configuration requires role '$expectedRole'."
        }
        if ($DabVersion -cne '2.0.9') {
          throw "ContentSummary configuration is pinned to DAB schema version '2.0.9'."
        }

        $normalizedExistingNativeKeys = @(
          foreach ($existingNativeKey in $ExistingNativeKeys) {
            if ([string]::IsNullOrWhiteSpace($existingNativeKey) -or
              $existingNativeKey -notmatch '^[a-z0-9][a-z0-9-]*$') {
              throw "Existing native key '$existingNativeKey' is malformed."
            }
            $existingNativeKey.ToLowerInvariant()
          }
        )
        $duplicateNativeKeys = @(
          $normalizedExistingNativeKeys |
            Group-Object |
            Where-Object Count -gt 1
        )
        if ($duplicateNativeKeys.Count -gt 0) {
          throw "Existing native-key reservations contain duplicate '$($duplicateNativeKeys[0].Name)'."
        }
        if ($normalizedExistingNativeKeys -contains $expectedNativeKey) {
          throw "Native key '$expectedNativeKey' is already reserved."
        }

        foreach ($existingCatalogPort in $ExistingCatalogPorts) {
          if ($existingCatalogPort -lt 1 -or $existingCatalogPort -gt 65535) {
            throw "Existing catalog port '$existingCatalogPort' is outside 1..65535."
          }
        }
        $duplicateCatalogPorts = @(
          $ExistingCatalogPorts |
            Group-Object |
            Where-Object Count -gt 1
        )
        if ($duplicateCatalogPorts.Count -gt 0) {
          throw "Existing catalog-port reservations contain duplicate '$($duplicateCatalogPorts[0].Name)'."
        }
        if ($ExistingCatalogPorts -contains $expectedCatalogPort) {
          throw "Catalog port '$expectedCatalogPort' is already reserved."
        }

        $procedureParameters = @(
          [ordered]@{
            name = 'Tags'
            description = 'Ordered ContentSummary tag selectors serialized as JSON.'
            required = $true
          }
          [ordered]@{
            name = 'Depth'
            description = 'Maximum tag traversal depth.'
            required = $false
            default = '3'
          }
          [ordered]@{
            name = 'Width'
            description = 'Maximum result width and internal query limit.'
            required = $false
            default = '2'
          }
          [ordered]@{
            name = 'Instance'
            description = 'Requested database tier; must match the routed server.'
            required = $false
            default = $tierDefinition.Suffix
          }
        )
        $entities = [ordered]@{}
        $entities[$entityName] = [ordered]@{
          description = 'Returns authorized, persisted ContentSummary rows for Tags, Depth, Width, and Instance. Authorization is derived only from the executing database identity.'
          source = [ordered]@{
            object = $entitySource
            type = 'stored-procedure'
            parameters = $procedureParameters
          }
          graphql = [ordered]@{
            enabled = $false
            operation = 'mutation'
            type = [ordered]@{
              singular = $entityName
              plural = "${entityName}s"
            }
          }
          rest = [ordered]@{
            enabled = $false
            methods = @('post')
          }
          permissions = @(
            [ordered]@{
              role = $expectedRole
              actions = @(
                [ordered]@{ action = 'execute' }
              )
            }
          )
          mcp = [ordered]@{
            'custom-tool' = $true
            'dml-tools' = $false
          }
        }
        $configuration = [ordered]@{
          '$schema' = "https://github.com/Azure/data-api-builder/releases/download/v$DabVersion/dab.draft.schema.json"
          'data-source' = [ordered]@{
            'database-type' = 'mssql'
            'connection-string' = "@env('$ConnectionStringEnvironmentVariable')"
          }
          runtime = [ordered]@{
            rest = [ordered]@{
              enabled = $false
              path = '/api'
              'request-body-strict' = $true
            }
            graphql = [ordered]@{
              enabled = $false
              path = '/graphql'
              'allow-introspection' = $false
            }
            mcp = [ordered]@{
              enabled = $true
              path = '/mcp'
              'dml-tools' = $false
            }
            host = [ordered]@{
              cors = [ordered]@{
                origins = @()
                'allow-credentials' = $false
              }
              authentication = [ordered]@{ provider = 'Simulator' }
              mode = 'production'
            }
            telemetry = [ordered]@{
              'open-telemetry' = [ordered]@{ enabled = $false }
            }
            health = [ordered]@{
              enabled = $false
              roles = @()
            }
          }
          autoentities = [ordered]@{}
          entities = $entities
        }
        $configurationJson = $configuration | ConvertTo-Json -Depth 20
        $configurationText = "$configurationJson$([Environment]::NewLine)"
        $configurationBytes = [Text.Encoding]::UTF8.GetBytes($configurationText)
        $configurationSha256 = [Convert]::ToHexString(
          [Security.Cryptography.SHA256]::HashData($configurationBytes)
        )

        if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
          if (-not $Force) {
            $existingConfigurationText = [IO.File]::ReadAllText($ConfigPath)
            if ($existingConfigurationText -cne $configurationText) {
              throw "Existing DAB config '$ConfigPath' is not the exact ContentSummary execute-only contract. Use Force only after reviewing the replacement."
            }
            return [pscustomobject]@{
              ConfigPath = $ConfigPath
              Action = 'Preserved'
              ExposureMode = $ExposureMode
              Tier = $Tier
              NativeKey = $NativeKey
              CatalogPort = $expectedCatalogPort
              ConnectionStringSecretName = $ConnectionStringSecretName
              Role = $expectedRole
              EntityName = $entityName
              EntitySource = $entitySource
              ToolName = $toolName
              ParameterNames = @($procedureParameters.name)
              ConfigurationSha256 = $configurationSha256
              WhatIf = $false
            }
          }
        }

        if (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Create exact ContentSummary execute-only DAB MCP configuration')) {
          return [pscustomobject]@{
            ConfigPath = $ConfigPath
            Action = 'Create'
            ExposureMode = $ExposureMode
            Tier = $Tier
            NativeKey = $NativeKey
            CatalogPort = $expectedCatalogPort
            ConnectionStringSecretName = $ConnectionStringSecretName
            Role = $expectedRole
            EntityName = $entityName
            EntitySource = $entitySource
            ToolName = $toolName
            ParameterNames = @($procedureParameters.name)
            ConfigurationSha256 = $configurationSha256
            WhatIf = $true
          }
        }

        $configDirectory = Split-Path -Path $ConfigPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($configDirectory)) {
          New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
        }
        [IO.File]::WriteAllText($ConfigPath, $configurationText, [Text.UTF8Encoding]::new($false))
        return [pscustomobject]@{
          ConfigPath = $ConfigPath
          Action = 'Created'
          ExposureMode = $ExposureMode
          Tier = $Tier
          NativeKey = $NativeKey
          CatalogPort = $expectedCatalogPort
          ConnectionStringSecretName = $ConnectionStringSecretName
          Role = $expectedRole
          EntityName = $entityName
          EntitySource = $entitySource
          ToolName = $toolName
          ParameterNames = @($procedureParameters.name)
          ConfigurationSha256 = $configurationSha256
          WhatIf = $false
          ExitCode = 0
        }
      }

      if ((Test-Path -LiteralPath $ConfigPath -PathType Leaf) -and -not $Force) {
        return [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Preserved'; WhatIf = $false }
      }

      $configDirectory = Split-Path -Path $ConfigPath -Parent
      if (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Create secret-free DAB MCP configuration')) {
        return [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Create'; ExposureMode = $ExposureMode; WhatIf = $true }
      }

      $dab = Get-Command -Name 'dab' -ErrorAction Stop
      New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
      if ($Force -and (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        Remove-Item -LiteralPath $ConfigPath -Force
      }
      $connectionStringReference = "@env('$ConnectionStringEnvironmentVariable')"
      $result = Invoke-DabCommand -DabPath $dab.Source -ArgumentList @(
        'init', '--database-type', 'mssql', '--host-mode', 'Development',
        '--connection-string', $connectionStringReference, '--config', $ConfigPath
      )
      if ($ExposureMode -ne 'ExplicitEntity') {
        $isReadWrite = $ExposureMode -eq 'AllEntitiesReadWrite'
        $role = if ($isReadWrite) { 'mcp-writer' } else { 'mcp-reader' }
        $actions = if ($isReadWrite) { 'create,read,update,delete' } else { 'read' }
        Invoke-DabCommand -DabPath $dab.Source -ArgumentList @(
          'auto-config', 'all-database-objects', '--config', $ConfigPath,
          '--patterns.include', '%.%', '--patterns.name', '{schema}_{object}',
          '--template.rest.enabled', 'false', '--template.graphql.enabled', 'false',
          '--permissions', "$role`:$actions"
        ) | Out-Null
        Invoke-DabCommand -DabPath $dab.Source -ArgumentList @(
          'configure', '--config', $ConfigPath,
          '--runtime.rest.enabled', 'false', '--runtime.graphql.enabled', 'false',
          '--runtime.mcp.enabled', 'true', '--runtime.mcp.dml-tools.enabled', $isReadWrite.ToString().ToLowerInvariant()
        ) | Out-Null
      }
      [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Created'; ExposureMode = $ExposureMode; WhatIf = $false; ExitCode = $result.ExitCode }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP configuration initialization failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed DAB MCP configuration initialization.'
  }
}
