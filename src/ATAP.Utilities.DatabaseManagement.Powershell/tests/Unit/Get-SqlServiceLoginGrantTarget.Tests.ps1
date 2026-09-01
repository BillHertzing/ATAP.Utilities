# Get-SqlServiceLoginGrantTarget.Tests.ps1

Describe 'Get-SqlServiceLoginGrantTarget' -Tag 'Unit' {
  BeforeAll {
    $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
    . (Join-Path $publicDir 'Get-SqlServiceLoginGrantTarget.ps1')

    $script:instance = 'UTAT022\Production'
    $script:hostName = 'UTAT022'
    $script:account = 'UTAT022\SvcBuildMaster'
    $script:allowed = @('Expwhertzing', 'Devwhertzing', 'Integration', 'QA', 'Production')
  }

  BeforeEach {
    Mock -CommandName Invoke-DbaQuery -MockWith {
      @(
        [pscustomobject]@{ DatabaseName = 'master'; DatabaseId = 1; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
        [pscustomobject]@{ DatabaseName = 'ATAPUtilities'; DatabaseId = 5; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
        [pscustomobject]@{ DatabaseName = 'AceSnapshot'; DatabaseId = 6; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $true; SourceDatabaseId = 5 }
        [pscustomobject]@{ DatabaseName = 'OfflineDb'; DatabaseId = 7; State = 'OFFLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
        [pscustomobject]@{ DatabaseName = 'ReadOnlyDb'; DatabaseId = 8; State = 'ONLINE'; UserAccess = 'MULTI_USER'; IsReadOnly = $true; SourceDatabaseId = $null }
        [pscustomobject]@{ DatabaseName = 'RestrictedDb'; DatabaseId = 9; State = 'ONLINE'; UserAccess = 'RESTRICTED_USER'; IsReadOnly = $false; SourceDatabaseId = $null }
      )
    }
  }

  Context 'Metadata inventory' {
    It 'queries master exactly once without issuing mutation SQL' {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
        -ServiceAccount $script:account -AllowedInstanceName $script:allowed | Out-Null

      Should -Invoke Invoke-DbaQuery -Exactly 1 -ParameterFilter {
        $Database -eq 'master' -and
        $Query -match 'FROM sys\.databases' -and
        $Query -notmatch '(?i)\b(CREATE|ALTER|DROP|GRANT|DENY|REVOKE)\b' -and
        $EnableException -eq $true -and
        $ErrorAction -eq 'Stop'
      }
    }

    It 'includes an online writable multi-user user database' {
      $result = @(Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed)

      $target = $result | Where-Object DatabaseName -EQ 'ATAPUtilities'
      $target.Include | Should -BeTrue
      $target.ExclusionReason | Should -BeNullOrEmpty
      $target.ServiceAccount | Should -Be $script:account
    }

    It 'classifies every non-actionable database with an explicit reason' {
      $result = @(Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed)

      ($result | Where-Object DatabaseName -EQ 'master').ExclusionReason | Should -Be 'SystemDatabase'
      ($result | Where-Object DatabaseName -EQ 'AceSnapshot').ExclusionReason | Should -Be 'DatabaseSnapshot'
      ($result | Where-Object DatabaseName -EQ 'OfflineDb').ExclusionReason | Should -Be 'State:OFFLINE'
      ($result | Where-Object DatabaseName -EQ 'ReadOnlyDb').ExclusionReason | Should -Be 'ReadOnly'
      ($result | Where-Object DatabaseName -EQ 'RestrictedDb').ExclusionReason | Should -Be 'UserAccess:RESTRICTED_USER'
      @($result | Where-Object { -not $_.Include -and [string]::IsNullOrEmpty($_.ExclusionReason) }).Count | Should -Be 0
    }

    It 'returns rows in deterministic database-name order' {
      $result = @(Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed)

      ($result.DatabaseName -join ',') | Should -Be 'AceSnapshot,ATAPUtilities,master,OfflineDb,ReadOnlyDb,RestrictedDb'
    }

    It 'passes explicit connection encryption options' {
      Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
        -ServiceAccount $script:account -AllowedInstanceName $script:allowed `
        -Encrypt Mandatory -TrustServerCertificate | Out-Null

      Should -Invoke Invoke-DbaQuery -Exactly 1 -ParameterFilter {
        $AppendConnectionString -match 'Encrypt=Mandatory' -and
        $AppendConnectionString -match 'Trust Server Certificate=True'
      }
    }
  }

  Context 'Fail-closed identity and topology checks' {
    It 'rejects a remote SQL host before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance 'UTAT01\Production' -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed
      } | Should -Throw '*not local*'
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rejects a service account owned by another host before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount 'UTAT01\SvcBuildMaster' -AllowedInstanceName $script:allowed
      } | Should -Throw '*not a host-local account*'
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rejects generic Experimental before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance 'localhost\Experimental' -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName @('Experimental')
      } | Should -Throw "*Generic SQL instance name 'Experimental'*"
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rejects a whitespace-suffixed generic Experimental close variant before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance 'localhost\Experimental ' -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName @('Experimental ')
      } | Should -Throw '*leading or trailing whitespace*'
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rejects an instance absent from the explicit allow-list before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance 'localhost\Unknown' -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed
      } | Should -Throw '*not present in the explicit allow-list*'
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rejects a target without an explicit named instance before querying' {
      {
        Get-SqlServiceLoginGrantTarget -SqlInstance 'localhost' -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed
      } | Should -Throw '*explicit Server\Instance form*'
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }
  }

  Context 'WhatIf and failures' {
    It 'does not query SQL under WhatIf and returns an explicit status row' {
      $result = Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
        -ServiceAccount $script:account -AllowedInstanceName $script:allowed -WhatIf

      $result.ExclusionReason | Should -Be 'WhatIf'
      $result.Include | Should -BeFalse
      Should -Invoke Invoke-DbaQuery -Exactly 0
    }

    It 'rethrows metadata query failures' {
      Mock -CommandName Invoke-DbaQuery -MockWith { throw [System.Exception] 'metadata unavailable' }

      {
        Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed
      } | Should -Throw '*metadata unavailable*'
    }

    It 'rejects an empty metadata result instead of reporting an empty target set' {
      Mock -CommandName Invoke-DbaQuery -MockWith { @() }

      {
        Get-SqlServiceLoginGrantTarget -SqlInstance $script:instance -ExpectedHostName $script:hostName `
          -ServiceAccount $script:account -AllowedInstanceName $script:allowed
      } | Should -Throw '*returned no sys.databases metadata rows*'
    }
  }
}
