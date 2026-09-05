#Requires -Module Pester

BeforeAll {
  $script:moduleRoot = (Join-Path $PSScriptRoot '..\..' | Resolve-Path).Path
  $script:moduleName = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
  $script:manifestPath = Join-Path $script:moduleRoot "$script:moduleName.psd1"
  Remove-Module $script:moduleName -Force -ErrorAction SilentlyContinue
  Import-Module -Name $script:manifestPath -Force -ErrorAction Stop
}

Describe 'DAB MCP helpers' -Tag 'Unit' {
  It 'uses deterministic BWS secret names for each SQL tier' {
    InModuleScope $script:moduleName {
      Resolve-DabMcpConnectionStringSecretName -Tier 'Production' -DatabaseHost 'utat01' |
        Should -BeExactly 'dbConnectionString.ATAPUtilities.utat01.Production'
      Resolve-DabMcpConnectionStringSecretName -Tier 'Exp' -DatabaseHost 'utat01' -UserName 'whertzing' |
        Should -BeExactly 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing'
      Resolve-DabMcpConnectionStringSecretName -Tier 'Exp' -DatabaseHost 'utat01' -DatabaseName 'EXPwhertzing' -UserName 'whertzing' |
        Should -BeExactly 'dbConnectionString.EXPwhertzing.utat01.Exp.whertzing'
    }
  }

  It 'does not install DAB when WhatIf is specified' {
    $result = Install-DabGlobalTool -Version '2.0.9' -WhatIf
    $result.WhatIf | Should -BeTrue
    $result.Action | Should -BeIn @('install', 'update')
  }

  It 'does not create a DAB configuration when WhatIf is specified' {
    $configPath = Join-Path $TestDrive 'dab-config.json'
    $result = Initialize-DabMcpConfiguration -ConfigPath $configPath -ExposureMode AllEntitiesReadOnly -WhatIf
    $result.WhatIf | Should -BeTrue
    $result.ExposureMode | Should -BeExactly 'AllEntitiesReadOnly'
    Test-Path -LiteralPath $configPath | Should -BeFalse
  }

  It 'plans the exact ContentSummary contract without resolving DAB or a secret' {
    $configPath = Join-Path $TestDrive 'whatif\dab-contentsummary-config.json'
    $result = Initialize-DabMcpConfiguration `
      -ConfigPath $configPath `
      -ExposureMode ContentSummaryExecuteOnly `
      -Tier Exp `
      -NativeKey 'dab-contentsummary-ataputilities-exp' `
      -CatalogPort 5104 `
      -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing' `
      -WhatIf

    $result.WhatIf | Should -BeTrue
    $result.ToolName | Should -BeExactly 'query_content_summary_candidates_for_mcp_v1'
    $result.ParameterNames | Should -Be @('Tags', 'Depth', 'Width', 'Instance')
    Test-Path -LiteralPath $configPath | Should -BeFalse
  }

  It 'writes exactly one execute-only ContentSummary custom tool' {
    $configPath = Join-Path $TestDrive 'exact\dab-contentsummary-config.json'
    $secretName = 'dbConnectionString.ATAPUtilities.utat01.Exp.whertzing'
    $result = Initialize-DabMcpConfiguration `
      -ConfigPath $configPath `
      -ExposureMode ContentSummaryExecuteOnly `
      -Tier Exp `
      -NativeKey 'dab-contentsummary-ataputilities-exp' `
      -CatalogPort 5104 `
      -ConnectionStringSecretName $secretName `
      -Confirm:$false

    $raw = Get-Content -LiteralPath $configPath -Raw
    $config = $raw | ConvertFrom-Json
    $entityProperties = @($config.entities.PSObject.Properties)
    $entity = $config.entities.QueryContentSummaryCandidatesForMcpV1

    $result.Action | Should -BeExactly 'Created'
    $result.ConfigurationSha256 | Should -BeExactly (Get-FileHash -Algorithm SHA256 -LiteralPath $configPath).Hash
    $entityProperties.Count | Should -Be 1
    $entity.source.object | Should -BeExactly '[ATAPUtilities].[QueryContentSummaryCandidatesForMcpV1]'
    $entity.source.type | Should -BeExactly 'stored-procedure'
    @($entity.source.parameters.name) | Should -Be @('Tags', 'Depth', 'Width', 'Instance')
    $entity.source.parameters[0].required | Should -BeTrue
    @($entity.source.parameters[0].PSObject.Properties.Name) | Should -Not -Contain 'default'
    $entity.source.parameters[1].required | Should -BeFalse
    $entity.source.parameters[1].default | Should -BeExactly '3'
    $entity.source.parameters[2].required | Should -BeFalse
    $entity.source.parameters[2].default | Should -BeExactly '2'
    $entity.source.parameters[3].required | Should -BeFalse
    $entity.source.parameters[3].default | Should -BeExactly 'exp'
    @($entity.permissions).Count | Should -Be 1
    $entity.permissions[0].role | Should -BeExactly 'contentsummary-mcp-reader'
    @($entity.permissions[0].actions.action) | Should -Be @('execute')
    $entity.mcp.'custom-tool' | Should -BeTrue
    $entity.mcp.'dml-tools' | Should -BeFalse
    @($entity.mcp.PSObject.Properties.Name | Sort-Object) | Should -Be @('custom-tool', 'dml-tools')
    $entity.rest.enabled | Should -BeFalse
    $entity.graphql.enabled | Should -BeFalse
    $config.runtime.rest.enabled | Should -BeFalse
    $config.runtime.graphql.enabled | Should -BeFalse
    $config.runtime.graphql.'allow-introspection' | Should -BeFalse
    $config.runtime.mcp.enabled | Should -BeTrue
    $config.runtime.mcp.'dml-tools' | Should -BeFalse
    @($config.runtime.mcp.PSObject.Properties.Name | Sort-Object) | Should -Be @('dml-tools', 'enabled', 'path')
    @($config.autoentities.PSObject.Properties).Count | Should -Be 0
    $config.'data-source'.'connection-string' | Should -BeExactly "@env('DAB_ATAPUTILITIES_CONNECTION_STRING')"
    $raw | Should -Not -Match ([regex]::Escape($secretName))
    $raw | Should -Not -Match '(?i)(password|pwd|user\s+id)\s*='
    @($entity.source.parameters.name) | Should -Not -Contain 'Caller'
    @($entity.source.parameters.name) | Should -Not -Contain 'Principal'
    @($entity.source.parameters.name) | Should -Not -Contain 'RepositoryId'
  }

  It 'produces byte-identical output for identical inputs' {
    $firstPath = Join-Path $TestDrive 'stable\first.json'
    $secondPath = Join-Path $TestDrive 'stable\second.json'
    $parameters = @{
      ExposureMode = 'ContentSummaryExecuteOnly'
      Tier = 'Production'
      NativeKey = 'dab-contentsummary-ataputilities-production'
      CatalogPort = 5144
      ConnectionStringSecretName = 'dbConnectionString.ATAPUtilities.utat01.Production'
      Confirm = $false
    }

    $first = Initialize-DabMcpConfiguration -ConfigPath $firstPath @parameters
    $second = Initialize-DabMcpConfiguration -ConfigPath $secondPath @parameters

    $first.ConfigurationSha256 | Should -BeExactly $second.ConfigurationSha256
    [IO.File]::ReadAllBytes($firstPath) | Should -Be ([IO.File]::ReadAllBytes($secondPath))
  }

  It 'preserves only a byte-identical existing ContentSummary configuration' {
    $configPath = Join-Path $TestDrive 'preserve\config.json'
    $parameters = @{
      ConfigPath = $configPath
      ExposureMode = 'ContentSummaryExecuteOnly'
      Tier = 'QA'
      NativeKey = 'dab-contentsummary-ataputilities-qa'
      CatalogPort = 5124
      ConnectionStringSecretName = 'dbConnectionString.ATAPUtilities.utat01.QA'
      Confirm = $false
    }

    $created = Initialize-DabMcpConfiguration @parameters
    $preserved = Initialize-DabMcpConfiguration @parameters

    $preserved.Action | Should -BeExactly 'Preserved'
    $preserved.ConfigurationSha256 | Should -BeExactly $created.ConfigurationSha256
  }

  It 'rejects an existing configuration that would widen the contract' {
    $configPath = Join-Path $TestDrive 'widening\config.json'
    New-Item -ItemType Directory -Path (Split-Path -Path $configPath -Parent) -Force | Out-Null
    '{"entities":{"RawTable":{"source":{"type":"table"}}}}' |
      Set-Content -LiteralPath $configPath -Encoding utf8

    {
      Initialize-DabMcpConfiguration `
        -ConfigPath $configPath `
        -ExposureMode ContentSummaryExecuteOnly `
        -Tier Dev `
        -NativeKey 'dab-contentsummary-ataputilities-dev' `
        -CatalogPort 5114 `
        -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Dev' `
        -Confirm:$false
    } | Should -Throw '*not the exact ContentSummary execute-only contract*'
  }

  It 'Force replaces a wider configuration with the exact one-entity contract' {
    $configPath = Join-Path $TestDrive 'force\config.json'
    New-Item -ItemType Directory -Path (Split-Path -Path $configPath -Parent) -Force | Out-Null
    '{"entities":{"RawTable":{"source":{"type":"table"}},"CaptureLoader":{"source":{"type":"stored-procedure"}}}}' |
      Set-Content -LiteralPath $configPath -Encoding utf8

    Initialize-DabMcpConfiguration `
      -ConfigPath $configPath `
      -ExposureMode ContentSummaryExecuteOnly `
      -Tier Integration `
      -NativeKey 'dab-contentsummary-ataputilities-integration' `
      -CatalogPort 5134 `
      -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Integration' `
      -Force `
      -Confirm:$false | Out-Null

    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    @($config.entities.PSObject.Properties.Name) | Should -Be @('QueryContentSummaryCandidatesForMcpV1')
  }

  It 'accepts the exact native key and port and emits the correct Instance default for <Tier>' -ForEach @(
    @{ Tier = 'Exp'; NativeKey = 'dab-contentsummary-ataputilities-exp'; Port = 5104; Instance = 'exp' }
    @{ Tier = 'Dev'; NativeKey = 'dab-contentsummary-ataputilities-dev'; Port = 5114; Instance = 'dev' }
    @{ Tier = 'QA'; NativeKey = 'dab-contentsummary-ataputilities-qa'; Port = 5124; Instance = 'qa' }
    @{ Tier = 'Integration'; NativeKey = 'dab-contentsummary-ataputilities-integration'; Port = 5134; Instance = 'integration' }
    @{ Tier = 'Production'; NativeKey = 'dab-contentsummary-ataputilities-production'; Port = 5144; Instance = 'production' }
  ) {
    $configPath = Join-Path $TestDrive "$Tier.json"
    $result = Initialize-DabMcpConfiguration `
      -ConfigPath $configPath `
      -ExposureMode ContentSummaryExecuteOnly `
      -Tier $Tier `
      -NativeKey $NativeKey `
      -CatalogPort $Port `
      -ConnectionStringSecretName "dbConnectionString.ATAPUtilities.utat01.$Tier" `
      -Confirm:$false

    $result.NativeKey | Should -BeExactly $NativeKey
    $result.CatalogPort | Should -Be $Port
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $parameters = @($config.entities.QueryContentSummaryCandidatesForMcpV1.source.parameters)
    @($parameters.name) | Should -Be @('Tags', 'Depth', 'Width', 'Instance')
    $parameters[3].default | Should -BeExactly $Instance
  }

  It 'rejects mismatched tier keys and ports' {
    {
      Initialize-DabMcpConfiguration `
        -ConfigPath (Join-Path $TestDrive 'bad-key.json') `
        -ExposureMode ContentSummaryExecuteOnly `
        -Tier Exp `
        -NativeKey 'dab-contentsummary-ataputilities-production' `
        -CatalogPort 5104 `
        -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Exp' `
        -WhatIf
    } | Should -Throw "*requires native key 'dab-contentsummary-ataputilities-exp'*"

    {
      Initialize-DabMcpConfiguration `
        -ConfigPath (Join-Path $TestDrive 'bad-port.json') `
        -ExposureMode ContentSummaryExecuteOnly `
        -Tier Exp `
        -NativeKey 'dab-contentsummary-ataputilities-exp' `
        -CatalogPort 5144 `
        -ConnectionStringSecretName 'dbConnectionString.ATAPUtilities.utat01.Exp' `
        -WhatIf
    } | Should -Throw "*requires catalog port '5104'*"
  }

  It 'rejects duplicate and colliding catalog reservations' {
    $baseParameters = @{
      ConfigPath = Join-Path $TestDrive 'collision.json'
      ExposureMode = 'ContentSummaryExecuteOnly'
      Tier = 'Exp'
      NativeKey = 'dab-contentsummary-ataputilities-exp'
      CatalogPort = 5104
      ConnectionStringSecretName = 'dbConnectionString.ATAPUtilities.utat01.Exp'
      WhatIf = $true
    }

    { Initialize-DabMcpConfiguration @baseParameters -ExistingNativeKeys @('alpha', 'alpha') } |
      Should -Throw "*contain duplicate 'alpha'*"
    { Initialize-DabMcpConfiguration @baseParameters -ExistingCatalogPorts @(5102, 5102) } |
      Should -Throw "*contain duplicate '5102'*"
    { Initialize-DabMcpConfiguration @baseParameters -ExistingNativeKeys @('dab-contentsummary-ataputilities-exp') } |
      Should -Throw "*already reserved*"
    { Initialize-DabMcpConfiguration @baseParameters -ExistingCatalogPorts @(5104) } |
      Should -Throw "*already reserved*"
  }

  It 'rejects malformed identity and reservation metadata without fallback widening' {
    $baseParameters = @{
      ConfigPath = Join-Path $TestDrive 'malformed.json'
      ExposureMode = 'ContentSummaryExecuteOnly'
      Tier = 'Exp'
      NativeKey = 'dab-contentsummary-ataputilities-exp'
      CatalogPort = 5104
      ConnectionStringSecretName = 'dbConnectionString.ATAPUtilities.utat01.Exp'
      WhatIf = $true
    }

    { Initialize-DabMcpConfiguration @baseParameters -Role 'mcp-reader' } |
      Should -Throw "*requires role 'contentsummary-mcp-reader'*"
    $badSecretParameters = $baseParameters.Clone()
    $badSecretParameters.ConnectionStringSecretName = "@env('REAL_SECRET')"
    { Initialize-DabMcpConfiguration @badSecretParameters } |
      Should -Throw '*must be a non-secret dotted reference name*'
    $bareSecretParameters = $baseParameters.Clone()
    $bareSecretParameters.ConnectionStringSecretName = 'abc'
    { Initialize-DabMcpConfiguration @bareSecretParameters } |
      Should -Throw '*must be a non-secret dotted reference name*'
    { Initialize-DabMcpConfiguration @baseParameters -ExistingNativeKeys @('Bad Key') } |
      Should -Throw '*is malformed*'
    { Initialize-DabMcpConfiguration @baseParameters -ExistingCatalogPorts @(0) } |
      Should -Throw '*outside 1..65535*'
    { Initialize-DabMcpConfiguration @baseParameters -DabVersion '2.1.0' } |
      Should -Throw "*pinned to DAB schema version '2.0.9'*"

    $missingKeyParameters = $baseParameters.Clone()
    $missingKeyParameters.Remove('NativeKey')
    { Initialize-DabMcpConfiguration @missingKeyParameters } |
      Should -Throw '*requires native key*'
    $missingPortParameters = $baseParameters.Clone()
    $missingPortParameters.Remove('CatalogPort')
    { Initialize-DabMcpConfiguration @missingPortParameters } |
      Should -Throw '*requires catalog port*'
    $missingSecretParameters = $baseParameters.Clone()
    $missingSecretParameters.Remove('ConnectionStringSecretName')
    { Initialize-DabMcpConfiguration @missingSecretParameters } |
      Should -Throw '*must be a non-secret dotted reference name*'
  }

  It 'does not expose caller-controlled authorization parameters' {
    $command = Get-Command -Name Initialize-DabMcpConfiguration
    @($command.Parameters.Keys) | Should -Not -Contain 'Caller'
    @($command.Parameters.Keys) | Should -Not -Contain 'Principal'
    @($command.Parameters.Keys) | Should -Not -Contain 'RepositoryId'
    @($command.Parameters.Keys) | Should -Not -Contain 'AuthorizedRepositories'
  }
}
