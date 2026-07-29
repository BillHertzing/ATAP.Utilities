BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  $script:privateDir = Join-Path $script:moduleRoot 'private'
  . (Join-Path $script:privateDir 'Resolve-BWSReadOnlyBootstrapIdentity.ps1')
  . (Join-Path $script:privateDir 'Invoke-BWSReadOnlyBootstrapWorker.ps1')
  . (Join-Path $script:publicDir 'New-BWSReadOnlyBootstrapEnvelope.ps1')
  . (Join-Path $script:publicDir 'Invoke-BWSReadOnlyTokenBootstrap.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    $script:createdPsfStub = $true
  }
  if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
    function global:Get-ScheduledTask { param([string]$TaskPath, [string]$TaskName, [string]$ErrorAction) }
    $script:createdGetScheduledTaskStub = $true
  }
  if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) {
    function global:Register-ScheduledTask { param($TaskPath, $TaskName, $InputObject, $User, $Password, $Force, $ErrorAction) }
    $script:createdRegisterScheduledTaskStub = $true
  }
  $script:scheduledTaskStubNames = @()
  if (-not (Get-Command Stop-ScheduledTask -ErrorAction SilentlyContinue)) {
    function global:Stop-ScheduledTask { param($TaskPath, $TaskName, $ErrorAction) }
    $script:scheduledTaskStubNames += 'Stop-ScheduledTask'
  }
  if (-not (Get-Command Unregister-ScheduledTask -ErrorAction SilentlyContinue)) {
    function global:Unregister-ScheduledTask { param($TaskPath, $TaskName, $Confirm, $ErrorAction) }
    $script:scheduledTaskStubNames += 'Unregister-ScheduledTask'
  }
  if (-not (Get-Command Start-ScheduledTask -ErrorAction SilentlyContinue)) {
    function global:Start-ScheduledTask { param($TaskPath, $TaskName, $ErrorAction) }
    $script:scheduledTaskStubNames += 'Start-ScheduledTask'
  }
  if (-not (Get-Command Get-ScheduledTaskInfo -ErrorAction SilentlyContinue)) {
    function global:Get-ScheduledTaskInfo { param($TaskPath, $TaskName, $ErrorAction) }
    $script:scheduledTaskStubNames += 'Get-ScheduledTaskInfo'
  }
  if (-not (Get-Command New-ScheduledTaskAction -ErrorAction SilentlyContinue)) {
    function global:New-ScheduledTaskAction { param($Execute, $Argument) }
    function global:New-ScheduledTaskTrigger { param([switch]$Once, $At) }
    function global:New-ScheduledTaskSettingsSet { param($ExecutionTimeLimit, $AllowStartIfOnBatteries, $DontStopIfGoingOnBatteries) }
    function global:New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel) }
    function global:New-ScheduledTask { param($Action, $Trigger, $Settings, $Principal) }
    $script:scheduledTaskStubNames += @(
      'New-ScheduledTaskAction', 'New-ScheduledTaskTrigger',
      'New-ScheduledTaskSettingsSet', 'New-ScheduledTaskPrincipal', 'New-ScheduledTask')
  }
}

AfterAll {
  if ($script:createdPsfStub) {
    Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
  }
  if ($script:createdGetScheduledTaskStub) {
    Remove-Item Function:\Get-ScheduledTask -ErrorAction SilentlyContinue
  }
  if ($script:createdRegisterScheduledTaskStub) {
    Remove-Item Function:\Register-ScheduledTask -ErrorAction SilentlyContinue
  }
  foreach ($stubName in $script:scheduledTaskStubNames) {
    Remove-Item "Function:\$stubName" -ErrorAction SilentlyContinue
  }
}

Describe 'BWS ReadOnly bootstrap identity policy' -Tag 'Unit', 'BWS' {
  It 'allows exactly <AccountName>' -ForEach @(
    @{ AccountName = 'SvcBuildMaster' }
    @{ AccountName = '.\SvcProGet' }
    @{ AccountName = "$env:COMPUTERNAME\SvcSQLServer" }
  ) {
    $result = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName
    $result.AccountName | Should -Match '^[^\\]+\\Svc(BuildMaster|ProGet|SQLServer)$'
    $result.ProjectName | Should -BeExactly 'CI-Shared'
    $result.TokenPurpose | Should -BeExactly 'ReadOnly'
  }

  It 'rejects <AccountName> before mutation' -ForEach @(
    @{ AccountName = 'SvcSeq' }
    @{ AccountName = 'SvcParityAudit' }
    @{ AccountName = 'ansibleAdmin' }
    @{ AccountName = 'SvcArbitrary' }
    @{ AccountName = 'FOREIGNHOST\SvcProGet' }
  ) {
    { Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName } | Should -Throw
  }
}

Describe 'New-BWSReadOnlyBootstrapEnvelope policy contract' -Tag 'Unit', 'BWS' {
  It 'has no raw string token parameter and supports only SecureString input' {
    $command = Get-Command New-BWSReadOnlyBootstrapEnvelope
    $command.Parameters.ContainsKey('AccessToken') | Should -BeTrue
    $command.Parameters['AccessToken'].ParameterType | Should -Be ([System.Security.SecureString])
    @($command.Parameters.Keys | Where-Object { $_ -match 'Raw|Plain|ReadWrite|Project' }).Count | Should -Be 0
  }

  It 'rejects a certificate whose simple name does not match the account' {
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    $certificate = $null
    try {
      $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=SvcSeq',
        $rsa,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
      $oids = [Security.Cryptography.OidCollection]::new()
      [void]$oids.Add([Security.Cryptography.Oid]::new('1.3.6.1.4.1.311.80.1'))
      $eku = [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($oids, $false)
      $request.CertificateExtensions.Add($eku)
      $certificate = $request.CreateSelfSigned((Get-Date).AddMinutes(-1), (Get-Date).AddDays(1))
      $certificatePath = Join-Path $TestDrive 'wrong-account.cer'
      $certificateBytes = $certificate.Export(
        [Security.Cryptography.X509Certificates.X509ContentType]::Cert)
      [IO.File]::WriteAllBytes($certificatePath, $certificateBytes)

      $parameters = @{
        AccountName              = 'SvcProGet'
        AccessToken              = ConvertTo-SecureString 'placeholder-not-a-real-token' -AsPlainText -Force
        RecipientCertificatePath = $certificatePath
        OutputPath               = Join-Path $TestDrive 'output.cms'
        Confirm                  = $false
      }
      { New-BWSReadOnlyBootstrapEnvelope @parameters } |
        Should -Throw '*does not match approved account*'
    } finally {
      if ($certificate) {
        $certificate.Dispose()
      }
      $rsa.Dispose()
    }
  }
}

Describe 'Invoke-BWSReadOnlyTokenBootstrap orchestration policy' -Tag 'Unit', 'BWS' {
  BeforeEach {
    $script:envelopePath = Join-Path $TestDrive 'bootstrap.cms'
    Set-Content -LiteralPath $script:envelopePath -Value 'cms-ciphertext-fixture'
    $script:credentialDirectory = Join-Path $TestDrive 'credentials'
    New-Item -ItemType Directory -Path $script:credentialDirectory -Force | Out-Null
    $script:credential = [PSCredential]::new(
      "$env:COMPUTERNAME\SvcProGet",
      (ConvertTo-SecureString 'placeholder-service-password' -AsPlainText -Force))
  }

  It 'rejects mismatched service-logon identity before task registration' {
    $wrongCredential = [PSCredential]::new(
      "$env:COMPUTERNAME\SvcSQLServer",
      (ConvertTo-SecureString 'placeholder-service-password' -AsPlainText -Force))
    Mock Get-ScheduledTask { throw 'must not be called' }

    $parameters = @{
      AccountName              = 'SvcProGet'
      ServiceLogonCredential   = $wrongCredential
      EnvelopePath             = $script:envelopePath
      CertificateThumbprint    = 'A' * 40
      CredentialDirectory      = $script:credentialDirectory
      Confirm                  = $false
    }
    { Invoke-BWSReadOnlyTokenBootstrap @parameters } | Should -Throw '*does not match*'
    Should -Invoke Get-ScheduledTask -Times 0
  }

  It 'returns a redacted fixed-policy plan under WhatIf without task mutation' {
    Mock Get-ScheduledTask { $null }
    Mock Register-ScheduledTask { throw 'must not be called' }
    Mock Test-Path {
      if ($LiteralPath -eq $script:envelopePath) { return $true }
      if ($PathType -eq 'Container') { return $true }
      return $false
    }

    $parameters = @{
      AccountName              = 'SvcProGet'
      ServiceLogonCredential   = $script:credential
      EnvelopePath             = $script:envelopePath
      CertificateThumbprint    = 'A' * 40
      WhatIf                   = $true
    }
    $result = Invoke-BWSReadOnlyTokenBootstrap @parameters

    $result.Status | Should -BeExactly 'Planned'
    $result.ProjectName | Should -BeExactly 'CI-Shared'
    $result.TokenPurpose | Should -BeExactly 'ReadOnly'
    ($result | ConvertTo-Json -Compress) | Should -Not -Match 'placeholder-service-password'
    Should -Invoke Register-ScheduledTask -Times 0
  }

  It 'rejects a non-canonical account credential directory before task mutation' {
    Mock Get-ScheduledTask { throw 'must not be called' }

    $parameters = @{
      AccountName              = 'SvcProGet'
      ServiceLogonCredential   = $script:credential
      EnvelopePath             = $script:envelopePath
      CertificateThumbprint    = 'A' * 40
      CredentialDirectory      = $script:credentialDirectory
      Confirm                  = $false
    }
    { Invoke-BWSReadOnlyTokenBootstrap @parameters } | Should -Throw '*canonical path*'
    Should -Invoke Get-ScheduledTask -Times 0
  }

  It 'stops and verifies a running failed task before unregistering or deleting its envelope' {
    $script:taskLookup = 0
    $script:cleanupOrder = [Collections.Generic.List[string]]::new()
    Mock Test-Path {
      if ($LiteralPath -eq $script:envelopePath) { return $true }
      if ($PathType -eq 'Container') { return $true }
      return $false
    }
    Mock Get-ScheduledTask {
      $script:taskLookup++
      switch ($script:taskLookup) {
        1 { return $null }
        2 { return [PSCustomObject]@{ State = 'Running' } }
        3 { return [PSCustomObject]@{ State = 'Running' } }
        default { return [PSCustomObject]@{ State = 'Ready' } }
      }
    }
    # Build the task definition with the real in-memory ScheduledTasks cmdlets. PowerShell
    # 7.6 validates their CIM-typed parameters before Pester can pass PSCustomObject mock
    # results through the command proxies.
    Mock Register-ScheduledTask { [PSCustomObject]@{} }
    Mock Start-ScheduledTask { }
    Mock Get-ScheduledTaskInfo { throw 'simulated worker failure' }
    Mock Stop-ScheduledTask { [void]$script:cleanupOrder.Add('Stop') }
    Mock Unregister-ScheduledTask { [void]$script:cleanupOrder.Add('Unregister') }
    Mock Remove-Item {
      if ($LiteralPath -eq $script:envelopePath) {
        [void]$script:cleanupOrder.Add('RemoveEnvelope')
      }
    }

    $parameters = @{
      AccountName              = 'SvcProGet'
      ServiceLogonCredential   = $script:credential
      EnvelopePath             = $script:envelopePath
      CertificateThumbprint    = 'A' * 40
      Confirm                  = $false
    }
    { Invoke-BWSReadOnlyTokenBootstrap @parameters } | Should -Throw '*failed closed*'
    $script:cleanupOrder | Should -Be @('Stop', 'Unregister', 'RemoveEnvelope')
    Should -Invoke Stop-ScheduledTask -Times 1 -ParameterFilter { $TaskPath -eq '\ATAP\' }
    Should -Invoke Unregister-ScheduledTask -Times 1 -ParameterFilter { $TaskPath -eq '\ATAP\' }
    Should -Invoke Register-ScheduledTask -Times 1 -ParameterFilter { $TaskPath -eq '\ATAP\' }
    Should -Invoke Start-ScheduledTask -Times 1 -ParameterFilter { $TaskPath -eq '\ATAP\' }
  }

  It 'contains no token-bearing task argument or ReadWrite fallback in source' {
    $sourcePath = Join-Path $script:publicDir 'Invoke-BWSReadOnlyTokenBootstrap.ps1'
    $source = Get-Content -LiteralPath $sourcePath -Raw
    $source | Should -Not -Match '-AccessToken'
    $source | Should -Not -Match 'BWS_ACCESS_TOKEN'
    $source | Should -Not -Match 'TokenPurpose ReadWrite'
    $source | Should -Not -Match '-NoProfile'
    $source | Should -Match "-LogonType Password"
  }

  It 'exports both public bootstrap commands from the module manifest' {
    $manifest = Import-PowerShellDataFile (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Secrets.PowerShell.psd1')
    $manifest.FunctionsToExport | Should -Contain 'New-BWSReadOnlyBootstrapEnvelope'
    $manifest.FunctionsToExport | Should -Contain 'Invoke-BWSReadOnlyTokenBootstrap'
  }
}

Describe 'Invoke-BWSReadOnlyBootstrapWorker certificate policy' -Tag 'Unit', 'BWS' {
  BeforeEach {
    $script:workerEnvelopePath = Join-Path $TestDrive 'worker.cms'
    Set-Content -LiteralPath $script:workerEnvelopePath -Value 'cms-ciphertext-fixture'
    $script:workerCredentialDirectory = 'C:\ProgramData\ATAP\BitwardenCredentials\SvcProGet'
    Mock Get-BWSReadOnlyBootstrapCurrentIdentityName { "$env:COMPUTERNAME\SvcProGet" }
    Mock Test-Path { $true }
  }

  It 'rejects a private certificate without the document-encryption EKU before decryption' {
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    $certificate = $null
    try {
      $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=SvcProGet', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
      $certificate = $request.CreateSelfSigned((Get-Date).AddMinutes(-1), (Get-Date).AddDays(1))
      Mock Get-Item { $certificate }
      Mock Unprotect-CmsMessage { throw 'must not decrypt' }

      $parameters = @{
        EnvelopePath          = $script:workerEnvelopePath
        AccountName           = 'SvcProGet'
        CertificateThumbprint = 'A' * 40
        CredentialDirectory   = $script:workerCredentialDirectory
        Force                 = $true
      }
      { Invoke-BWSReadOnlyBootstrapWorker @parameters } | Should -Throw '*document encryption*'
      Should -Invoke Unprotect-CmsMessage -Times 0
    } finally {
      if ($certificate) { $certificate.Dispose() }
      $rsa.Dispose()
    }
  }

  It 'binds CMS decryption to the validated account certificate' {
    $rsa = [Security.Cryptography.RSA]::Create(2048)
    $certificate = $null
    try {
      $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=SvcProGet', $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
      $oids = [Security.Cryptography.OidCollection]::new()
      [void]$oids.Add([Security.Cryptography.Oid]::new('1.3.6.1.4.1.311.80.1'))
      $request.CertificateExtensions.Add(
        [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($oids, $false))
      $certificate = $request.CreateSelfSigned((Get-Date).AddMinutes(-1), (Get-Date).AddDays(1))
      Mock Get-Item { $certificate }
      Mock Unprotect-CmsMessage { 'placeholder-not-a-real-token' }
      Mock Remove-Item { }
      Mock Initialize-BWSAccessToken {
        [PSCustomObject]@{ Success = $true; Path = 'redacted-token-path.xml' }
      }

      $parameters = @{
        EnvelopePath          = $script:workerEnvelopePath
        AccountName           = 'SvcProGet'
        CertificateThumbprint = 'A' * 40
        CredentialDirectory   = $script:workerCredentialDirectory
        Force                 = $true
      }
      $result = Invoke-BWSReadOnlyBootstrapWorker @parameters

      $result.TokenPurpose | Should -BeExactly 'ReadOnly'
      Should -Invoke Unprotect-CmsMessage -Times 1 -ParameterFilter { $null -ne $To }
      Should -Invoke Initialize-BWSAccessToken -Times 1 -ParameterFilter { $TokenPurpose -eq 'ReadOnly' }
    } finally {
      if ($certificate) { $certificate.Dispose() }
      $rsa.Dispose()
    }
  }
}
