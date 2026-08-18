function Initialize-BWSApplicationAccessToken {
  <#
  .SYNOPSIS
    Writes a per-application BWS ReadOnly access token as an AtapBwsDpapiEnvelope v1 file.
  .DESCRIPTION
    This is the write side of the application token slot that the .NET reader
    ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows.BwsDpapiEnvelopeReader consumes.
    It produces the `AtapBwsDpapiEnvelope` XML document, whose ciphertext element is a
    base64 DPAPI blob protected under DataProtectionScope.CurrentUser with entropy derived
    from the identity, application, and vault-grouping binding.

    The envelope is bound to five values that the reader re-derives at read time and compares
    for exact string equality: the upper-invariant machine name, the account SID, the
    lower-invariant SAM account name, the application id, and the vault grouping id. Any
    mismatch makes the reader fail with TokenIdentityMismatch, so this function MUST RUN AS
    THE ACCOUNT THAT WILL LATER READ THE FILE. DPAPI CurrentUser protection is user-bound;
    a file written by one account cannot be decrypted by another, and no amount of file
    permission fixing will recover it.

    Unlike Initialize-BWSAccessToken, which writes the legacy PowerShell PSCredential CLIXML
    slot under a common CI label, this function writes only the modern application slot and
    is ReadOnly by construction. There is deliberately no TokenPurpose parameter: a purpose
    selector on the application surface would make write-capable tokens reachable from the
    application provisioning path, so ReadOnly is a fixed policy output rather than an input.

    The plaintext token is never written to disk, not even transiently. The envelope is
    staged to a same-volume temporary file and atomically moved into place, so an interrupted
    write cannot leave a truncated envelope where the reader expects a valid one.

    After the move the file's DACL is protected with inheritance preserved, because the reader's
    StrictWindowsTokenPathSecurityValidator validates the file as well as the directory and
    rejects any file whose access rules are unprotected or inherited. Protecting the credential
    directory does not protect files created inside it, so this is a writer-side step; it
    converts the inherited ACEs to explicit copies and does not change effective permissions.
  .PARAMETER AccessToken
    SecureString containing the application access token (format `0.<uuid>.<secret>...`).
    Raw string token parameters are deliberately not supported.
  .PARAMETER ApplicationId
    Application slot identifier, for example 'AceOutpost'. Must match the ApplicationId the
    consuming application configures in its WindowsBwsTokenSourceOptions.
  .PARAMETER VaultGroupingId
    Bitwarden Secrets Manager project that scopes the token, for example 'AceOutpost'. Must
    match the VaultGroupingId the consuming application configures.
  .PARAMETER CredentialDirectory
    Absolute path to the protected credential folder. Defaults to
    `C:\ProgramData\ATAP\BitwardenCredentials\<sam-lower>`.
  .PARAMETER Force
    Replaces an existing envelope for the same slot. Without it an existing file is refused.
  .OUTPUTS
    Redacted PSCustomObject with Success, Path, ApplicationId, VaultGroupingId, TokenPurpose,
    SamAccountName, and Message. It never contains the token, plaintext, ciphertext, or entropy.
  .EXAMPLE
    $token = Read-Host 'AceOutpost ReadOnly token' -AsSecureString
    $parameters = @{
      AccessToken     = $token
      ApplicationId   = 'AceOutpost'
      VaultGroupingId = 'AceOutpost'
    }
    Initialize-BWSApplicationAccessToken @parameters

    Writes `<HOST-UPPER>_<sam-lower>_BWS_AceOutpost_ReadOnly_AccessToken.xml` for the running
    account. Run this as the account the AceOutpost service logs on as, not as an operator.
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines.
    Must run as the owning Windows account itself (DPAPI is user-bound).
    Does not create accounts, ACLs, credential directories, or Bitwarden grants.
    The BSTR-to-managed-string hop is an accepted limitation: .NET string immutability means
    that copy cannot be zeroed, so the BSTR is zero-freed and the derived byte array is
    zeroed immediately, bounding the plaintext lifetime to the enclosing try block.
  .LINK
    Initialize-BWSAccessToken
  .LINK
    https://bitwarden.com/help/secrets-manager-cli/
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNull()]
    [System.Security.SecureString]$AccessToken,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationId,

    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VaultGroupingId,

    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$CredentialDirectory,

    [switch]$Force
  )

  begin {
    $fn = 'Initialize-BWSApplicationAccessToken'
    $mn = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started.' -Tag 'bws-token'

    # Envelope constants. These mirror BwsDpapiEnvelopeReader.cs exactly; changing any of them
    # silently breaks byte compatibility with the reader, which is why they are named here
    # rather than inlined at each use.
    $envelopeRootName = 'AtapBwsDpapiEnvelope'
    $envelopeFormatVersion = '1'
    $envelopeProvider = 'BitwardenSecretsManager'
    $envelopePurpose = 'ReadOnly'
    $entropyLabel = 'ATAP.BWS.DPAPI.ENVELOPE'
    $innerLabel = 'ATAP.BWS.TOKEN'

    # Same segment policy the reader applies in WindowsDpapiBwsReadOnlyAccessTokenSource.ValidateSegment.
    $assertSegment = {
      param([string]$Value, [string]$Name)

      if ([string]::IsNullOrWhiteSpace($Value) -or
        $Value -eq '.' -or
        $Value -eq '..' -or
        $Value.EndsWith('.') -or
        $Value.EndsWith(' ') -or
        $Value.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "BWS application envelope path segment '$Name' is invalid."
      }
    }

    # BinaryWriter.Write(string) emits a 7-bit-encoded length prefix followed by UTF-8 bytes.
    # The real .NET writer is used rather than a hand-rolled prefix so the encoding cannot drift
    # from BinaryReader.ReadString on the C# side.
    $newBinaryWriter = {
      param([System.IO.MemoryStream]$Stream)

      [System.IO.BinaryWriter]::new($Stream, [System.Text.UTF8Encoding]::new($false, $true), $true)
    }
  }

  process {
    if (-not $IsWindows) {
      throw 'The BWS application DPAPI envelope writer requires Windows.'
    }

    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    # Identity comes from the process token, never from $env:USERNAME or a parameter, so the
    # envelope binding cannot be spoofed by environment manipulation.
    $samAccountName = (($windowsIdentity.Name -split '\\') | Select-Object -Last 1).ToLowerInvariant()
    $securityIdentifier = $windowsIdentity.User.Value
    $hostName = [System.Environment]::MachineName.ToUpperInvariant()

    & $assertSegment $hostName 'host'
    & $assertSegment $samAccountName 'samAccountName'
    & $assertSegment $ApplicationId 'applicationId'
    & $assertSegment $VaultGroupingId 'vaultGroupingId'

    if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
      $CredentialDirectory = "C:\ProgramData\ATAP\BitwardenCredentials\$samAccountName"
    }
    $CredentialDirectory = [IO.Path]::GetFullPath($CredentialDirectory)
    $tokenFileName = '{0}_{1}_BWS_{2}_ReadOnly_AccessToken.xml' -f $hostName, $samAccountName, $ApplicationId
    $tokenPath = Join-Path $CredentialDirectory $tokenFileName

    $baseResult = [ordered]@{
      Success         = $false
      Path            = $tokenPath
      ApplicationId   = $ApplicationId
      VaultGroupingId = $VaultGroupingId
      TokenPurpose    = $envelopePurpose
      SamAccountName  = $samAccountName
      Message         = $null
    }

    if (-not (Test-Path -LiteralPath $CredentialDirectory -PathType Container)) {
      throw "CredentialDirectory '$CredentialDirectory' does not exist. Create and ACL it first with Initialize-BWSCredentialDirectory."
    }
    if ((Test-Path -LiteralPath $tokenPath -PathType Leaf) -and -not $Force) {
      throw "A BWS application envelope already exists at '$tokenPath'; use -Force to replace it."
    }

    $actionDescription = "Write BWS $envelopePurpose DPAPI envelope for application '$ApplicationId' and vault grouping '$VaultGroupingId'"
    if (-not $PSCmdlet.ShouldProcess($tokenPath, $actionDescription)) {
      $baseResult.Message = 'Planned; no envelope was written.'
      return [PSCustomObject]$baseResult
    }

    # Entropy field order is fixed by BwsDpapiEnvelopeReader.CreateEntropy. Note that it binds
    # applicationId and omits samAccountName; the inner payload below binds both. Reordering or
    # "correcting" this list produces a file the reader cannot decrypt.
    $entropy = $null
    $entropyStream = [System.IO.MemoryStream]::new()
    try {
      $entropyWriter = & $newBinaryWriter $entropyStream
      try {
        foreach ($value in @(
            $entropyLabel,
            $envelopeFormatVersion,
            $hostName,
            $securityIdentifier,
            $ApplicationId,
            $envelopeProvider,
            $VaultGroupingId,
            $envelopePurpose)) {
          $entropyWriter.Write([string]$value)
        }
        $entropyWriter.Flush()
      } finally {
        $entropyWriter.Dispose()
      }
      $entropy = $entropyStream.ToArray()

      $ciphertext = $null
      $inner = $null
      $tokenBytes = $null
      $bstr = [IntPtr]::Zero
      $innerStream = [System.IO.MemoryStream]::new()
      try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
        $plaintextToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $tokenBytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($plaintextToken)
        $plaintextToken = $null
        if ($tokenBytes.Length -le 0) {
          throw 'The supplied BWS access token is empty.'
        }

        # Inner layout is fixed by BwsDpapiEnvelopeReader.DecodeInner. The reader asserts that the
        # declared length equals the remaining stream bytes, so nothing may follow the token bytes.
        $innerWriter = & $newBinaryWriter $innerStream
        try {
          foreach ($value in @(
              $innerLabel,
              $envelopeFormatVersion,
              $envelopePurpose,
              $hostName,
              $securityIdentifier,
              $samAccountName,
              $ApplicationId,
              $envelopeProvider,
              $VaultGroupingId)) {
            $innerWriter.Write([string]$value)
          }
          $innerWriter.Write([int]$tokenBytes.Length)
          $innerWriter.Write($tokenBytes, 0, $tokenBytes.Length)
          $innerWriter.Flush()
        } finally {
          $innerWriter.Dispose()
        }
        $inner = $innerStream.ToArray()

        $ciphertext = [System.Security.Cryptography.ProtectedData]::Protect(
          $inner,
          $entropy,
          [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
      } finally {
        if ($bstr -ne [IntPtr]::Zero) {
          [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        if ($null -ne $tokenBytes) {
          [System.Security.Cryptography.CryptographicOperations]::ZeroMemory($tokenBytes)
        }
        if ($null -ne $inner) {
          [System.Security.Cryptography.CryptographicOperations]::ZeroMemory($inner)
        }
        # ToArray copies; the stream's own buffer still holds plaintext until it is zeroed.
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory($innerStream.GetBuffer())
        $innerStream.Dispose()
      }

      # Base64 with no line breaks: the reader re-encodes and requires an exact ordinal round trip.
      $encodedCiphertext = [Convert]::ToBase64String($ciphertext)

      $elements = [ordered]@{
        formatVersion   = $envelopeFormatVersion
        purpose         = $envelopePurpose
        host            = $hostName
        sid             = $securityIdentifier
        samAccountName  = $samAccountName
        applicationId   = $ApplicationId
        provider        = $envelopeProvider
        vaultGroupingId = $VaultGroupingId
        ciphertext      = $encodedCiphertext
      }
      $rootElement = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]::Get($envelopeRootName))
      foreach ($elementName in $elements.Keys) {
        $rootElement.Add([System.Xml.Linq.XElement]::new(
            [System.Xml.Linq.XName]::Get($elementName),
            [string]$elements[$elementName]))
      }
      $envelopeDocument = [System.Xml.Linq.XDocument]::new($rootElement)

      # Same-volume staging plus an atomic move: a crash mid-write leaves either the previous
      # envelope or the new one, never a truncated file that the reader would reject at run time.
      $temporaryPath = '{0}.{1}.tmp' -f $tokenPath, [Guid]::NewGuid().ToString('N')
      try {
        $envelopeDocument.Save($temporaryPath)
        [System.IO.File]::Move($temporaryPath, $tokenPath, $true)
      } catch {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        throw
      }

      # StrictWindowsTokenPathSecurityValidator validates the FILE as well as the directory, and
      # rejects it when the DACL is unprotected or any ACE is inherited. Protecting the directory
      # does not protect its children: the directory's ACEs carry ContainerInherit|ObjectInherit,
      # so a file created here arrives with inherited ACEs and AreAccessRulesProtected = $false.
      # preserveInheritance = $true converts those already-correct inherited ACEs into explicit
      # copies, so no ACE has to be reconstructed by hand and effective permissions do not change.
      # This must run AFTER the move: a file carries the ACL of the directory it was created in.
      try {
        $acl = Get-Acl -LiteralPath $tokenPath
        $acl.SetAccessRuleProtection($true, $true)
        Set-Acl -LiteralPath $tokenPath -AclObject $acl
      } catch {
        # Fail closed. An envelope the reader would reject is worse than no envelope at all, so
        # the unreadable file is removed rather than left to fail later at service start.
        Remove-Item -LiteralPath $tokenPath -Force -ErrorAction SilentlyContinue
        throw "The BWS application envelope was written but its access rules could not be protected; the file was removed. $($_.Exception.Message)"
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Wrote BWS $envelopePurpose DPAPI envelope for application '$ApplicationId' and vault grouping '$VaultGroupingId' to '$tokenPath'." -Tag 'bws-token'
      $baseResult.Success = $true
      $baseResult.Message = "BWS $envelopePurpose application access token stored."
      [PSCustomObject]$baseResult
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "BWS application envelope write failed for application '$ApplicationId'. Exception: $($_.Exception.Message)" -Tag 'bws-token'
      throw
    } finally {
      if ($null -ne $entropy) {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory($entropy)
      }
      $entropyStream.Dispose()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed.' -Tag 'bws-token'
  }
}
