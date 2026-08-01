#Requires -Version 7.0

# SC-0288 / Sprint 0013 Task 13.66.b — the host suffix on every ProGet/BuildMaster
# SecretName must be derived from the service placement map, never hard-coded, and
# resolution must fail closed when the placement host is unknown.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $manifestPath = Join-Path $moduleRoot 'ATAP.Utilities.BuildTooling.Common.PowerShell.psd1'
  $promotedManifest = [System.Environment]::GetEnvironmentVariable('ATAP_PROMOTED_MODULE_MANIFEST', 'Process')
  Remove-Module -Name 'ATAP.Utilities.BuildTooling.Common.PowerShell' -Force -ErrorAction SilentlyContinue
  Import-Module -Name $(if ([string]::IsNullOrWhiteSpace($promotedManifest)) { $manifestPath } else { $promotedManifest }) -Force -ErrorAction Stop
}

Describe 'Resolve-HostSuffixedSecretName' -Tag 'Unit' {
  BeforeEach {
    $script:oldConfigRootKeys = $global:configRootKeys
    $script:oldSettings = $global:Settings
    $global:configRootKeys = @{
      'ServicePlacementMapConfigRootKey' = 'ServicePlacementMap'
    }
    $global:Settings = @{
      'ServicePlacementMap' = @{
        ProGet      = 'utat022'
        BuildMaster = 'utat022'
        SqlPrimary  = 'utat022'
      }
    }
  }

  AfterEach {
    $global:configRootKeys = $script:oldConfigRootKeys
    $global:Settings = $script:oldSettings
  }

  Context 'placement-derived suffixing' {
    It 'appends the placement host to a suffixless base name' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat022'
    }

    It 'suffixes each service from its own placement entry' {
      $global:Settings['ServicePlacementMap']['BuildMaster'] = 'utat01'

      Resolve-HostSuffixedSecretName -BaseName 'BuildMaster.Admin.API.Key' -ServiceName 'BuildMaster' |
        Should -BeExactly 'BuildMaster.Admin.API.Key.utat01'
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.BuildMaster.API.Key' -ServiceName 'ProGet' |
        Should -BeExactly 'ProGet.BuildMaster.API.Key.utat022'
    }

    It 'is idempotent when the base name already carries the placement host' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key.utat022' -ServiceName 'ProGet' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat022'
    }

    It 'replaces a stale host suffix that the placement map still knows' {
      # The exact SC-0288 defect: 'BuildMaster.Admin.API.Key.utat01' baked into
      # calling code must follow the map. A partial failover leaves utat01 in the
      # map on another service, so it is a known host.
      $global:Settings['ServicePlacementMap']['SqlPrimary'] = 'utat01'

      Resolve-HostSuffixedSecretName -BaseName 'BuildMaster.Admin.API.Key.utat01' -ServiceName 'BuildMaster' |
        Should -BeExactly 'BuildMaster.Admin.API.Key.utat022'
    }

    It 'replaces a decommissioned host suffix when it is declared with -KnownHost' {
      Resolve-HostSuffixedSecretName -BaseName 'BuildMaster.Admin.API.Key.utat01' -ServiceName 'BuildMaster' `
        -KnownHost 'utat01' |
        Should -BeExactly 'BuildMaster.Admin.API.Key.utat022'
    }

    It 'leaves a trailing segment that is not a known host intact' {
      # Conservative by design: never mangle a SecretName whose last segment
      # merely looks like it could be a host.
      Resolve-HostSuffixedSecretName -BaseName 'BuildMaster.Admin.API.Key.utat01' -ServiceName 'BuildMaster' |
        Should -BeExactly 'BuildMaster.Admin.API.Key.utat01.utat022'
    }

    It 'extends to a host that is not in any hard-coded allowlist' {
      $global:Settings['ServicePlacementMap']['ProGet'] = 'utat042'

      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat042'
    }

    It 'honours an explicit placement host over the map' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' -PlacementHost 'utat01' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat01'
    }

    It 'does not treat a non-host trailing segment as a stale suffix' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' |
        Should -Not -BeExactly 'ProGet.Admin.API.utat022'
    }
  }

  Context 'authoritative setting precedence' {
    It 'returns the host-settings value unchanged when the setting resolves' {
      $global:configRootKeys['ProGetAdminApiKeySecretNameConfigRootKey'] = 'ProGetAdminApiKeySecretName'
      $global:Settings['ProGetAdminApiKeySecretName'] = 'ProGet.Admin.API.Key.utat01'

      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' `
        -SettingName 'ProGetAdminApiKeySecretName' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat01'
    }

    It 'falls back to the placement map when the setting is absent' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' `
        -SettingName 'ProGetAdminApiKeySecretName' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat022'
    }

    It 'falls back to the placement map when the setting is whitespace' {
      $global:Settings['ProGetAdminApiKeySecretName'] = '   '

      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' `
        -SettingName 'ProGetAdminApiKeySecretName' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat022'
    }
  }

  Context 'fail-closed behaviour' {
    It 'throws when no placement map is available' {
      $global:Settings = @{}

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage "*placement host for service 'ProGet' could not be determined*"
    }

    It 'throws when settings are missing but configRootKeys is loaded' {
      # Partially configured is the dangerous state: something loaded ATAP
      # configuration, so placement was expected to be there.
      $global:Settings = $null

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage '*could not be determined*'
    }

    It 'throws when configRootKeys is missing but settings are loaded' {
      $global:configRootKeys = $null

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage '*could not be determined*'
    }

    It 'throws when the service is absent from the placement map' {
      { Resolve-HostSuffixedSecretName -BaseName 'Otter.Admin.API.Key' -ServiceName 'Otter' } |
        Should -Throw -ExpectedMessage "*placement host for service 'Otter' could not be determined*"
    }

    It 'throws when the mapped placement host is empty' {
      $global:Settings['ServicePlacementMap']['ProGet'] = '  '

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage '*could not be determined*'
    }

    It 'refuses a loopback placeholder rather than naming a secret after it' {
      $global:Settings['ServicePlacementMap']['ProGet'] = 'localhost'

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage '*non-placement host*'
    }

    It 'refuses a placement host that is not a valid host token' {
      $global:Settings['ServicePlacementMap']['ProGet'] = 'utat01 ; rm -rf'

      { Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' } |
        Should -Throw -ExpectedMessage '*not a valid host name token*'
    }

    It 'never emits a suffixless name on any successful path' {
      $result = Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet'
      $result | Should -Match '\.utat022$'
    }
  }

  Context 'unconfigured shell' {
    BeforeEach {
      $global:configRootKeys = $null
      $global:Settings = $null
    }

    It 'returns the base name unchanged when no ATAP configuration exists' {
      # A bare or hermetic shell has no ProGet/BuildMaster endpoint either, so
      # it cannot authenticate anywhere; suffixing would be a guess.
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' |
        Should -BeExactly 'ProGet.Admin.API.Key'
    }

    It 'still honours an explicit placement host in an unconfigured shell' {
      Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet' -PlacementHost 'utat01' |
        Should -BeExactly 'ProGet.Admin.API.Key.utat01'
    }
  }

  Context 'secret hygiene' {
    It 'returns a name only, and its implementation never resolves a secret value' {
      $result = Resolve-HostSuffixedSecretName -BaseName 'ProGet.Admin.API.Key' -ServiceName 'ProGet'
      $result | Should -BeOfType ([string])

      # Static proof over the AST (not the help text): the resolver invokes no
      # secret-reading command on any path.
      $ast = (Get-Command -Name 'Resolve-HostSuffixedSecretName').ScriptBlock.Ast
      $invoked = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
          ForEach-Object { $_.GetCommandName() })

      $invoked | Should -Not -Contain 'Get-SecretATAP'
      $invoked | Should -Not -Contain 'Get-BitWardenSecret'
      $invoked | Should -Not -Contain 'bws'
    }
  }
}
