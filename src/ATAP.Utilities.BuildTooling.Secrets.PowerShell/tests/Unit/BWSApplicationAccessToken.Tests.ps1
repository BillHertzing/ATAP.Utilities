#Requires -Version 7.0

<#
  Byte-compatibility contract tests for the AtapBwsDpapiEnvelope v1 writer.

  The authority for this format is the C# reader at
  src/ATAP.Utilities.Secrets/BitwardenSecretsManager/Windows/BwsDpapiEnvelopeReader.cs.
  These tests re-derive the entropy and re-parse the inner payload independently of the
  production code, so they fail if the writer drifts from the reader rather than merely
  agreeing with itself.

  No real access token appears anywhere in this file. Every token value is synthetic, and
  nothing is written outside $TestDrive.
#>

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  $script:privateDir = Join-Path $script:moduleRoot 'private'
  . (Join-Path $script:publicDir 'Initialize-BWSApplicationAccessToken.ps1')
  . (Join-Path $script:privateDir 'Resolve-BWSReadOnlyBootstrapIdentity.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments)]$Rest) }
    $script:createdPsfStub = $true
  }

  # Obviously synthetic. Never a real token, and never read from a vault.
  $script:syntheticToken = '0.00000000-0000-0000-0000-000000000000.SYNTHETIC-NOT-A-REAL-TOKEN-VALUE'
  $script:syntheticSecure = ConvertTo-SecureString $script:syntheticToken -AsPlainText -Force

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $script:currentSam = (($identity.Name -split '\\') | Select-Object -Last 1).ToLowerInvariant()
  $script:currentSid = $identity.User.Value
  $script:currentHost = [System.Environment]::MachineName.ToUpperInvariant()

  # Independent re-implementation of BwsDpapiEnvelopeReader.CreateEntropy. Note the field list
  # binds applicationId and omits samAccountName; that asymmetry is the reader's, and copying it
  # faithfully is the whole point of this helper.
  function script:New-ExpectedEntropy {
    param([string]$HostName, [string]$Sid, [string]$ApplicationId, [string]$VaultGroupingId)

    $stream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($stream, [System.Text.UTF8Encoding]::new($false, $true), $true)
    foreach ($value in @(
        'ATAP.BWS.DPAPI.ENVELOPE', '1', $HostName, $Sid, $ApplicationId,
        'BitwardenSecretsManager', $VaultGroupingId, 'ReadOnly')) {
      $writer.Write([string]$value)
    }
    $writer.Flush()
    $writer.Dispose()
    $bytes = $stream.ToArray()
    $stream.Dispose()
    $bytes
  }

  function script:New-TestCredentialDirectory {
    param([string]$Name)

    $path = Join-Path $TestDrive $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $path
  }

  # The three principals the credential-directory convention grants, and the ones the reader's
  # StrictWindowsTokenPathSecurityValidator expects to find on the token file.
  $script:systemSid = 'S-1-5-18'
  $script:administratorsSid = 'S-1-5-32-544'
  $script:expectedPrincipals = @($script:currentSid, $script:systemSid, $script:administratorsSid) | Sort-Object

  # Reproduces the ProgramData situation that $TestDrive does not have by default: a directory
  # whose own DACL is protected but whose ACEs are inheritable, so children arrive with inherited
  # ACEs and an unprotected DACL. This is what Initialize-BWSCredentialDirectory produces.
  function script:New-InheritingCredentialDirectory {
    param([string]$Name)

    $path = script:New-TestCredentialDirectory -Name $Name
    $acl = Get-Acl -LiteralPath $path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
      [void]$acl.RemoveAccessRule($rule)
    }
    foreach ($sid in @($script:currentSid, $script:systemSid, $script:administratorsSid)) {
      $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
          [System.Security.Principal.SecurityIdentifier]::new($sid),
          [System.Security.AccessControl.FileSystemRights]::FullControl,
          'ContainerInherit, ObjectInherit',
          'None',
          [System.Security.AccessControl.AccessControlType]::Allow))
    }
    Set-Acl -LiteralPath $path -AclObject $acl
    $path
  }

  # The file-side assertions of StrictWindowsTokenPathSecurityValidator, re-implemented so the
  # test proves the writer's output against the validator's rules rather than against itself.
  function script:Test-ValidatorFileRules {
    param([string]$Path)

    $security = Get-Acl -LiteralPath $Path
    $rules = @($security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    [PSCustomObject]@{
      IsProtected       = $security.AreAccessRulesProtected
      AnyInherited      = @($rules | Where-Object { $_.IsInherited }).Count -gt 0
      AllAllow          = @($rules | Where-Object {
          $_.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow }).Count -eq 0
      Principals        = @($rules | ForEach-Object { $_.IdentityReference.Value } | Sort-Object -Unique)
      CurrentCanRead    = @($rules | Where-Object {
          $_.IdentityReference.Value -eq $script:currentSid -and
          $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and
          ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadData) -and
          ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadAttributes) }).Count -gt 0
    }
  }
}

AfterAll {
  if ($script:createdPsfStub) {
    Remove-Item Function:\Write-PSFMessage -ErrorAction SilentlyContinue
  }
}

Describe 'Initialize-BWSApplicationAccessToken envelope shape' -Tag 'Unit', 'BWS' {
  BeforeAll {
    $script:shapeDirectory = script:New-TestCredentialDirectory -Name 'shape'
    $script:shapeResult = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $script:shapeDirectory `
      -Confirm:$false
    $script:shapeXml = [xml](Get-Content -LiteralPath $script:shapeResult.Path -Raw)
  }

  It 'reports success and writes the file it names' {
    $script:shapeResult.Success | Should -BeTrue
    Test-Path -LiteralPath $script:shapeResult.Path -PathType Leaf | Should -BeTrue
  }

  It 'uses the AtapBwsDpapiEnvelope root with no attributes' {
    $script:shapeXml.DocumentElement.LocalName | Should -BeExactly 'AtapBwsDpapiEnvelope'
    $script:shapeXml.DocumentElement.NamespaceURI | Should -BeExactly ''
    $script:shapeXml.DocumentElement.Attributes.Count | Should -Be 0
  }

  It 'writes exactly the nine allowed child elements' {
    $names = @($script:shapeXml.DocumentElement.ChildNodes | ForEach-Object { $_.LocalName })
    $names.Count | Should -Be 9
    @($names | Sort-Object) | Should -Be @(
      'applicationId', 'ciphertext', 'formatVersion', 'host', 'provider',
      'purpose', 'samAccountName', 'sid', 'vaultGroupingId')
  }

  It 'gives every child element no attributes, no child elements, and a non-empty value' {
    foreach ($child in $script:shapeXml.DocumentElement.ChildNodes) {
      $child.NamespaceURI | Should -BeExactly ''
      $child.Attributes.Count | Should -Be 0
      @($child.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }).Count | Should -Be 0
      [string]::IsNullOrEmpty($child.InnerText) | Should -BeFalse
    }
  }

  It 'fixes formatVersion, purpose, and provider as constants' {
    $script:shapeXml.AtapBwsDpapiEnvelope.formatVersion | Should -BeExactly '1'
    $script:shapeXml.AtapBwsDpapiEnvelope.purpose | Should -BeExactly 'ReadOnly'
    $script:shapeXml.AtapBwsDpapiEnvelope.provider | Should -BeExactly 'BitwardenSecretsManager'
  }

  It 'binds host upper-invariant, samAccountName lower-invariant, and the process-token SID' {
    $script:shapeXml.AtapBwsDpapiEnvelope.host | Should -BeExactly $script:currentHost
    $script:shapeXml.AtapBwsDpapiEnvelope.host | Should -BeExactly $script:currentHost.ToUpperInvariant()
    $script:shapeXml.AtapBwsDpapiEnvelope.samAccountName | Should -BeExactly $script:currentSam
    $script:shapeXml.AtapBwsDpapiEnvelope.samAccountName | Should -BeExactly $script:currentSam.ToLowerInvariant()
    $script:shapeXml.AtapBwsDpapiEnvelope.sid | Should -BeExactly $script:currentSid
  }

  It 'binds the requested application and vault grouping' {
    $script:shapeXml.AtapBwsDpapiEnvelope.applicationId | Should -BeExactly 'AceOutpost'
    $script:shapeXml.AtapBwsDpapiEnvelope.vaultGroupingId | Should -BeExactly 'AceOutpost'
  }

  It 'writes ciphertext that survives the reader base64 round-trip check' {
    $encoded = $script:shapeXml.AtapBwsDpapiEnvelope.ciphertext
    $encoded | Should -Not -Match '\s'
    $bytes = [Convert]::FromBase64String($encoded)
    [Convert]::ToBase64String($bytes) | Should -BeExactly $encoded
  }

  It 'leaves no temporary staging file behind' {
    @(Get-ChildItem -LiteralPath $script:shapeDirectory -Filter '*.tmp').Count | Should -Be 0
  }
}

Describe 'Initialize-BWSApplicationAccessToken decrypt-back byte compatibility' -Tag 'Unit', 'BWS' {
  It 'produces a payload that DecodeInner would accept field for field' {
    $directory = script:New-TestCredentialDirectory -Name 'decrypt'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $xml = [xml](Get-Content -LiteralPath $result.Path -Raw)
    $ciphertext = [Convert]::FromBase64String($xml.AtapBwsDpapiEnvelope.ciphertext)
    $entropy = script:New-ExpectedEntropy `
      -HostName $script:currentHost -Sid $script:currentSid `
      -ApplicationId 'AceOutpost' -VaultGroupingId 'AceOutpost'

    $plaintext = [System.Security.Cryptography.ProtectedData]::Unprotect(
      $ciphertext, $entropy, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

    $stream = [System.IO.MemoryStream]::new($plaintext, $false)
    $reader = [System.IO.BinaryReader]::new($stream, [System.Text.UTF8Encoding]::new($false, $true))
    try {
      # Exactly the sequence BwsDpapiEnvelopeReader.DecodeInner reads, in order.
      $reader.ReadString() | Should -BeExactly 'ATAP.BWS.TOKEN'
      $reader.ReadString() | Should -BeExactly '1'
      $reader.ReadString() | Should -BeExactly 'ReadOnly'
      $reader.ReadString() | Should -BeExactly $script:currentHost
      $reader.ReadString() | Should -BeExactly $script:currentSid
      $reader.ReadString() | Should -BeExactly $script:currentSam
      $reader.ReadString() | Should -BeExactly 'AceOutpost'
      $reader.ReadString() | Should -BeExactly 'BitwardenSecretsManager'
      $reader.ReadString() | Should -BeExactly 'AceOutpost'

      $length = $reader.ReadInt32()
      $length | Should -BeGreaterThan 0
      # The reader rejects any trailing byte; this is that assertion.
      $length | Should -Be ($stream.Length - $stream.Position)

      $tokenBytes = $reader.ReadBytes($length)
      $recovered = [System.Text.UTF8Encoding]::new($false, $true).GetString($tokenBytes)
      $recovered | Should -BeExactly $script:syntheticToken
    } finally {
      $reader.Dispose()
      $stream.Dispose()
    }
  }

  It 'refuses to decrypt under an entropy bound to a different <Field>' -ForEach @(
    @{ Field = 'applicationId'; ApplicationId = 'SomeOtherApplication'; VaultGroupingId = 'AceOutpost' }
    @{ Field = 'vaultGroupingId'; ApplicationId = 'AceOutpost'; VaultGroupingId = 'SomeOtherProject' }
  ) {
    $directory = script:New-TestCredentialDirectory -Name "negative-$Field"
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $xml = [xml](Get-Content -LiteralPath $result.Path -Raw)
    $ciphertext = [Convert]::FromBase64String($xml.AtapBwsDpapiEnvelope.ciphertext)
    $wrongEntropy = script:New-ExpectedEntropy `
      -HostName $script:currentHost -Sid $script:currentSid `
      -ApplicationId $ApplicationId -VaultGroupingId $VaultGroupingId

    {
      [System.Security.Cryptography.ProtectedData]::Unprotect(
        $ciphertext, $wrongEntropy, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    } | Should -Throw
  }
}

Describe 'Initialize-BWSApplicationAccessToken filename derivation' -Tag 'Unit', 'BWS' {
  It 'derives the application slot filename from host, SAM, and application id' {
    $directory = script:New-TestCredentialDirectory -Name 'filename'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $expected = '{0}_{1}_BWS_AceOutpost_ReadOnly_AccessToken.xml' -f $script:currentHost, $script:currentSam
    Split-Path -Leaf $result.Path | Should -BeExactly $expected
  }

  It 'derives UTAT022_svcaceoutpost_BWS_AceOutpost_ReadOnly_AccessToken.xml for the AceOutpost identity' {
    # The shared helper reads the host from $env:COMPUTERNAME, so the documented UTAT022 case is
    # exercised as a real derivation rather than a restatement of the format string.
    $originalComputerName = $env:COMPUTERNAME
    try {
      $env:COMPUTERNAME = 'utat022'
      $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName 'SvcAceOutpost'
      Get-BWSReadOnlyBootstrapTokenFileName -Identity $identity |
        Should -BeExactly 'UTAT022_svcaceoutpost_BWS_AceOutpost_ReadOnly_AccessToken.xml'
    } finally {
      $env:COMPUTERNAME = $originalComputerName
    }
  }

  It 'leaves the legacy CI filename unchanged for <AccountName>' -ForEach @(
    @{ AccountName = 'SvcBuildMaster' }
    @{ AccountName = 'SvcProGet' }
    @{ AccountName = 'SvcSQLServer' }
  ) {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName
    $expected = '{0}_{1}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml' -f
      $env:COMPUTERNAME, $identity.SamAccountName
    Get-BWSReadOnlyBootstrapTokenFileName -Identity $identity | Should -BeExactly $expected
  }
}

Describe 'Initialize-BWSApplicationAccessToken refusals' -Tag 'Unit', 'BWS' {
  It 'refuses to overwrite an existing envelope without Force' {
    $directory = script:New-TestCredentialDirectory -Name 'existing'
    $parameters = @{
      AccessToken         = $script:syntheticSecure
      ApplicationId       = 'AceOutpost'
      VaultGroupingId     = 'AceOutpost'
      CredentialDirectory = $directory
      Confirm             = $false
    }
    Initialize-BWSApplicationAccessToken @parameters | Out-Null

    { Initialize-BWSApplicationAccessToken @parameters } | Should -Throw '*use -Force to replace it*'
  }

  It 'replaces an existing envelope when Force is supplied' {
    $directory = script:New-TestCredentialDirectory -Name 'force'
    $parameters = @{
      AccessToken         = $script:syntheticSecure
      ApplicationId       = 'AceOutpost'
      VaultGroupingId     = 'AceOutpost'
      CredentialDirectory = $directory
      Confirm             = $false
    }
    Initialize-BWSApplicationAccessToken @parameters | Out-Null
    $result = Initialize-BWSApplicationAccessToken @parameters -Force

    $result.Success | Should -BeTrue
    @(Get-ChildItem -LiteralPath $directory -File).Count | Should -Be 1
  }

  It 'rejects the invalid path segment <Segment> for <Parameter>' -ForEach @(
    @{ Parameter = 'ApplicationId'; Segment = '..' }
    @{ Parameter = 'ApplicationId'; Segment = '.' }
    @{ Parameter = 'ApplicationId'; Segment = 'AceOutpost.' }
    @{ Parameter = 'ApplicationId'; Segment = 'AceOutpost ' }
    @{ Parameter = 'ApplicationId'; Segment = 'Ace\Outpost' }
    @{ Parameter = 'ApplicationId'; Segment = 'Ace:Outpost' }
    @{ Parameter = 'VaultGroupingId'; Segment = '..' }
    @{ Parameter = 'VaultGroupingId'; Segment = 'AceOutpost.' }
    @{ Parameter = 'VaultGroupingId'; Segment = 'Ace/Outpost' }
  ) {
    $directory = script:New-TestCredentialDirectory -Name 'segments'
    $parameters = @{
      AccessToken         = $script:syntheticSecure
      ApplicationId       = 'AceOutpost'
      VaultGroupingId     = 'AceOutpost'
      CredentialDirectory = $directory
      Confirm             = $false
    }
    $parameters[$Parameter] = $Segment

    { Initialize-BWSApplicationAccessToken @parameters } | Should -Throw '*is invalid*'
  }

  It 'rejects a plain-string token at the parameter boundary' {
    $directory = script:New-TestCredentialDirectory -Name 'plainstring'
    {
      Initialize-BWSApplicationAccessToken `
        -AccessToken 'plain-string-not-a-securestring' `
        -ApplicationId 'AceOutpost' `
        -VaultGroupingId 'AceOutpost' `
        -CredentialDirectory $directory `
        -Confirm:$false
    } | Should -Throw
  }

  It 'throws rather than creating a missing credential directory' {
    $missing = Join-Path $TestDrive 'no-such-directory'
    {
      Initialize-BWSApplicationAccessToken `
        -AccessToken $script:syntheticSecure `
        -ApplicationId 'AceOutpost' `
        -VaultGroupingId 'AceOutpost' `
        -CredentialDirectory $missing `
        -Confirm:$false
    } | Should -Throw '*does not exist*'
    Test-Path -LiteralPath $missing | Should -BeFalse
  }

  It 'writes nothing under WhatIf' {
    $directory = script:New-TestCredentialDirectory -Name 'whatif'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -WhatIf

    $result.Success | Should -BeFalse
    @(Get-ChildItem -LiteralPath $directory -File).Count | Should -Be 0
  }
}

Describe 'Initialize-BWSApplicationAccessToken policy surface and redaction' -Tag 'Unit', 'BWS', 'Policy' {
  It 'exposes no TokenPurpose, plaintext, or ReadWrite selector' {
    $command = Get-Command Initialize-BWSApplicationAccessToken
    $command.Parameters['AccessToken'].ParameterType | Should -Be ([System.Security.SecureString])
    @($command.Parameters.Keys | Where-Object { $_ -match 'TokenPurpose|Raw|Plain|ReadWrite|Sid|SamAccount' }).Count |
      Should -Be 0
  }

  It 'never persists the plaintext token to disk' {
    $directory = script:New-TestCredentialDirectory -Name 'nodiskplaintext'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $raw = Get-Content -LiteralPath $result.Path -Raw
    $raw | Should -Not -Match ([regex]::Escape($script:syntheticToken))
    $raw | Should -Not -Match 'SYNTHETIC'
  }

  It 'returns a redacted result object containing no part of the token' {
    $directory = script:New-TestCredentialDirectory -Name 'redaction'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $result.PSObject.Properties.Name | Should -Be @(
      'Success', 'Path', 'ApplicationId', 'VaultGroupingId', 'TokenPurpose', 'SamAccountName', 'Message')
    $result.TokenPurpose | Should -BeExactly 'ReadOnly'

    $serialized = $result | ConvertTo-Json -Compress
    $serialized | Should -Not -Match 'SYNTHETIC'
    $serialized | Should -Not -Match ([regex]::Escape($script:syntheticToken))
    $serialized | Should -Not -Match '00000000-0000-0000-0000-000000000000'
    $serialized | Should -Not -Match 'ciphertext'
    $serialized | Should -Not -Match 'entropy'
  }

  It 'defines only a function and executes nothing at file scope' {
    $sourcePath = Join-Path $script:publicDir 'Initialize-BWSApplicationAccessToken.ps1'
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$errors)
    $errors.Count | Should -Be 0
    @($ast.EndBlock.Statements | Where-Object {
        $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] }).Count | Should -Be 0
  }

  It 'exports the application writer from the module manifest' {
    $manifest = Import-PowerShellDataFile (Join-Path $script:moduleRoot 'ATAP.Utilities.BuildTooling.Secrets.PowerShell.psd1')
    $manifest.FunctionsToExport | Should -Contain 'Initialize-BWSApplicationAccessToken'
  }
}

Describe 'Initialize-BWSApplicationAccessToken file access rules (F-02)' -Tag 'Unit', 'BWS', 'Security' {
  It 'reproduces the unprotected-inherited situation for an ordinary file in a credential directory' {
    # The negative case, constructed deliberately: this is what the writer produced before the
    # F-02 fix, and what the validator rejects with TokenPathInaccessible.
    $directory = script:New-InheritingCredentialDirectory -Name 'acl-negative'
    $controlPath = Join-Path $directory 'ordinary-file.xml'
    Set-Content -LiteralPath $controlPath -Value 'not-a-token'

    $control = script:Test-ValidatorFileRules -Path $controlPath
    $control.IsProtected | Should -BeFalse
    $control.AnyInherited | Should -BeTrue
  }

  It 'writes a token file whose DACL is protected with no inherited ACE' {
    $directory = script:New-InheritingCredentialDirectory -Name 'acl-positive'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $actual = script:Test-ValidatorFileRules -Path $result.Path
    $actual.IsProtected | Should -BeTrue
    $actual.AnyInherited | Should -BeFalse
  }

  It 'grants exactly the running SID, SYSTEM, and Administrators, all Allow' {
    $directory = script:New-InheritingCredentialDirectory -Name 'acl-principals'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    $actual = script:Test-ValidatorFileRules -Path $result.Path
    $actual.Principals | Should -Be $script:expectedPrincipals
    $actual.AllAllow | Should -BeTrue
  }

  It 'leaves the running identity able to read the envelope it just wrote' {
    $directory = script:New-InheritingCredentialDirectory -Name 'acl-readback'
    $result = Initialize-BWSApplicationAccessToken `
      -AccessToken $script:syntheticSecure `
      -ApplicationId 'AceOutpost' `
      -VaultGroupingId 'AceOutpost' `
      -CredentialDirectory $directory `
      -Confirm:$false

    (script:Test-ValidatorFileRules -Path $result.Path).CurrentCanRead | Should -BeTrue
    # Effective permission, not just the ACE bit: the file must still be readable.
    { Get-Content -LiteralPath $result.Path -Raw -ErrorAction Stop } | Should -Not -Throw
  }

  It 'protects the replacement file when -Force overwrites an existing envelope' {
    $directory = script:New-InheritingCredentialDirectory -Name 'acl-force'
    $parameters = @{
      AccessToken         = $script:syntheticSecure
      ApplicationId       = 'AceOutpost'
      VaultGroupingId     = 'AceOutpost'
      CredentialDirectory = $directory
      Confirm             = $false
    }
    Initialize-BWSApplicationAccessToken @parameters | Out-Null
    $result = Initialize-BWSApplicationAccessToken @parameters -Force

    $actual = script:Test-ValidatorFileRules -Path $result.Path
    $actual.IsProtected | Should -BeTrue
    $actual.AnyInherited | Should -BeFalse
  }
}

Describe 'Bootstrap identity slot resolution' -Tag 'Unit', 'BWS', 'Policy' {
  It 'resolves SvcAceOutpost to the AceOutpost project and application slot' {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName 'SvcAceOutpost'

    $identity.SamAccountName | Should -BeExactly 'SvcAceOutpost'
    $identity.ProjectName | Should -BeExactly 'AceOutpost'
    $identity.ApplicationId | Should -BeExactly 'AceOutpost'
    $identity.TokenPurpose | Should -BeExactly 'ReadOnly'
  }

  It 'normalizes case-variant and qualified AceOutpost account forms' -ForEach @(
    @{ InputName = '.\svcaceoutpost' }
    @{ InputName = 'SVCACEOUTPOST' }
    @{ InputName = "$env:COMPUTERNAME\SvcAceOutpost" }
  ) {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $InputName
    $identity.SamAccountName | Should -BeExactly 'SvcAceOutpost'
    $identity.ApplicationId | Should -BeExactly 'AceOutpost'
  }

  It 'keeps <AccountName> on CI-Shared with no application slot' -ForEach @(
    @{ AccountName = 'SvcBuildMaster' }
    @{ AccountName = 'SvcProGet' }
    @{ AccountName = 'SvcSQLServer' }
  ) {
    $identity = Resolve-BWSReadOnlyBootstrapIdentity -AccountName $AccountName

    $identity.ProjectName | Should -BeExactly 'CI-Shared'
    $identity.TokenPurpose | Should -BeExactly 'ReadOnly'
    [string]::IsNullOrWhiteSpace($identity.ApplicationId) | Should -BeTrue
  }

  It 'still rejects unapproved identities after the AceOutpost addition' -ForEach @(
    'SvcSeq'
    'SvcAceOutpost-Backup'
    'AceOutpost'
    'whertzing'
  ) {
    { Resolve-BWSReadOnlyBootstrapIdentity -AccountName $_ } | Should -Throw '*not approved*'
  }

  It 'exposes no project or application selector parameter' {
    $command = Get-Command Resolve-BWSReadOnlyBootstrapIdentity
    @($command.Parameters.Keys | Where-Object { $_ -match 'ProjectName|ApplicationId|TokenPurpose' }).Count |
      Should -Be 0
  }
}
