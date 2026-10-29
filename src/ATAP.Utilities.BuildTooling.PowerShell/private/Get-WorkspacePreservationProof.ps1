function Get-WorkspacePreservationProof {
  <#
  .SYNOPSIS
    Computes one read-only C4.PreservationProof.v1 record for captured workspace JSON bytes.
  .DESCRIPTION
    Implements Sprint 0017 task 17.66.c G3-C4 integration unit 1 (Rev03
    /integrationPlan/units/0/frozenScope) for profile C4.Utf8LogicalPreservation.v1.

    Input mode proves that the original bytes satisfy the profile. Compare mode also proves that
    the candidate bytes carry exactly the original logical content plus the two managed settings
    members given in -ManagedDelta.

    Predicates run in the fixed /proposedProfile/predicatePrecedence order. Step 0 (arguments and
    profile descriptors) runs first, then steps 1-5. The first failing step fixes Disposition and
    Reasons; later steps are not evaluated. Resource caps are checked as each step proceeds.

    Reasons are {Stage,Code,Path,Kind} metadata only. Path is a JSON Pointer in which characters
    outside printable ASCII are written as \uXXXX; no raw values or bytes are emitted.

    The function has no effects: no filesystem access, no native processes, no module discovery and
    no global or script state. Every input byte array is copied before use. Parsing uses the
    existing ConvertFrom-Json backend, and the candidate is serialized only by ConvertTo-Json
    -Depth 20. The lexical token audit only classifies and never produces a value that is written
    (C-057 BC1 ruling).
  .PARAMETER OriginalBytes
    The exact captured bytes of the original workspace file.
  .PARAMETER CandidateBytes
    Compare mode: the exact candidate bytes prepared by the saver.
  .PARAMETER ManagedDelta
    Compare mode: an object with exactly the string members atap.sharedVSCode.templateRef and
    atap.sharedVSCode.profile.
  .PARAMETER InputProfile
    ProfileDescriptor with ProfileId, CharacterizationReference and CharacterizationSHA256.
  .PARAMETER SerializerProfile
    Compare mode: ProfileDescriptor for the serializer, with the same shape and ProfileId.
  .PARAMETER Mode
    Input or Compare. It must equal the bound parameter set name (Rev03 openItems AD1).
  .OUTPUTS
    PSCustomObject (C4.PreservationProof.v1)
  #>
  [CmdletBinding(DefaultParameterSetName = 'Input')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory, ParameterSetName = 'Input')]
    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [AllowEmptyCollection()]
    [byte[]]$OriginalBytes,

    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [AllowEmptyCollection()]
    [byte[]]$CandidateBytes,

    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [object]$ManagedDelta,

    [Parameter(Mandatory, ParameterSetName = 'Input')]
    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [object]$InputProfile,

    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [object]$SerializerProfile,

    [Parameter(Mandatory, ParameterSetName = 'Input')]
    [Parameter(Mandatory, ParameterSetName = 'Compare')]
    [ValidateSet('Input', 'Compare', IgnoreCase = $false)]
    [string]$Mode
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Frozen profile constants (Rev03 /proposedProfile/profileDescriptor and /resourceDefault).
    $recordKind = 'C4.PreservationProof.v1'
    $profileId = 'C4.Utf8LogicalPreservation.v1'
    $characterizationReference = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Corrected-Measurement-Coordinator-Acceptance-20261026.json'
    $characterizationSHA256 = '12E963092EED272BA2CC7D5D74F84BE97181E1552C368A0BAE849916D890C7B4'
    $profileSpecificationReference = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Workspace-Support-Profile-Proposal-Rev03-20261027.json'
    $profileSpecificationSHA256 = '4D06A4DCB1DC51289B5EE6F4404270D4EF88BB3B8209156F6158698BEC6664FA'
    $profileSpecificationBytes = [long]108421
    $adoptionRecordReference = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Support-Profile-Adoption-Record-20261027.json'
    $adoptionRecordSHA256 = '8EFE230C05F6E1334221EF7BE0B1ECDEED2A1500663947F0C54592E6866B5151'
    $contractReference = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Workspace-Transaction-Contract-Rev02-20261027.json'
    $contractSHA256 = 'A2FB662DC92B48C074E4FFDA048C9D80374E7F5FC01E561F6A52E50828FC16B2'
    $maximumInputBytes = 16777216
    $maximumLexicalTokens = 1048576
    $maximumLexicalContainerDepth = 128
    $maximumReasonsPerCategory = 32
    $managedKeys = @('atap.sharedVSCode.templateRef', 'atap.sharedVSCode.profile')
    $rootProtectedNames = @('settings')
    $replacementCharacter = [string][char]0xFFFD
    $strictNumberPattern = [regex]::new('^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $numberPartsPattern = [regex]::new('^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $lineEnds = [char[]]@([char]10, [char]13)
    $controlCharacters = [char[]](0..31)
    $doubleQuoteStops = [char[]](@([char]'"', [char]'\') + $controlCharacters)
    $singleQuoteStops = [char[]](@([char]"'", [char]'\') + $controlCharacters)

    # Steps 2-4 categories in predicatePrecedence order, with the disposition each one fixes.
    $categoryOrder = @('S2a', 'S2b', 'S2c', 'S2d', 'S3', 'S4NameRejected', 'S4NameEmpty', 'S4Number', 'S4Surrogate')
    $categoryDisposition = @{
      S2a            = 'REJECTED_INPUT'
      S2b            = 'REJECTED_INPUT'
      S2c            = 'REJECTED_INPUT'
      S2d            = 'REJECTED_INPUT'
      S3             = 'HELD_UNPROVED'
      S4NameRejected = 'REJECTED_INPUT'
      S4NameEmpty    = 'HELD_UNPROVED'
      S4Number       = 'REJECTED_INPUT'
      S4Surrogate    = 'HELD_UNPROVED'
    }

    function New-ProofReason {
      param([string]$Stage, [string]$Code, [string]$Path, [string]$Kind)
      [pscustomobject]@{ Stage = $Stage; Code = $Code; Path = $Path; Kind = $Kind }
    }

    function New-ProofOutcome {
      param([string]$Disposition, [object[]]$Reasons, [string]$SettingsState)
      @{ Disposition = $Disposition; Reasons = [object[]]$Reasons; SettingsState = $SettingsState }
    }

    function Add-ProofFinding {
      param([hashtable]$Findings, [string]$Category, [string]$Stage, [string]$Code, [string]$Path, [string]$Kind)
      $list = $Findings[$Category]
      if ($list.Count -lt $maximumReasonsPerCategory) {
        $list.Add((New-ProofReason -Stage $Stage -Code $Code -Path $Path -Kind $Kind))
      }
    }

    function Add-ProofLenientFinding {
      param([hashtable]$Findings, [string]$Path, [string]$Kind)
      Add-ProofFinding -Findings $Findings -Category 'S3' -Stage 'Step3.TriviaAndLenientForms' -Code 'LENIENT_FORM_UNPROVED' -Path $Path -Kind $Kind
    }

    function Format-ProofPointerSegment {
      # JSON Pointer escaping (~0, ~1); non-printable-ASCII code units as \uXXXX so no raw text leaks.
      param([string]$Name)
      $builder = [System.Text.StringBuilder]::new()
      $limit = [Math]::Min($Name.Length, 128)
      for ($k = 0; $k -lt $limit; $k++) {
        $c = $Name[$k]
        $code = [int]$c
        if ($c -ceq '~') { [void]$builder.Append('~0') }
        elseif ($c -ceq '/') { [void]$builder.Append('~1') }
        elseif ($code -lt 0x20 -or $code -gt 0x7E) { [void]$builder.Append(('\u{0:X4}' -f $code)) }
        else { [void]$builder.Append($c) }
      }
      if ($Name.Length -gt $limit) { [void]$builder.Append('[truncated]') }
      $builder.ToString()
    }

    function Get-ProofMember {
      # Ordinal member lookup on a dictionary or an object; PSObject member lookup is case-insensitive.
      param([object]$Container, [string]$Name)
      $member = @{ Found = $false; Value = $null; Total = 0 }
      if ($Container -is [System.Collections.IDictionary]) {
        foreach ($entry in $Container.GetEnumerator()) {
          $member.Total++
          if ($entry.Key -is [string] -and [string]::Equals($entry.Key, $Name, [System.StringComparison]::Ordinal)) {
            $member.Found = $true
            $member.Value = $entry.Value
          }
        }
      }
      elseif ($null -ne $Container) {
        foreach ($property in $Container.PSObject.Properties) {
          $member.Total++
          if ([string]::Equals($property.Name, $Name, [System.StringComparison]::Ordinal)) {
            $member.Found = $true
            $member.Value = $property.Value
          }
        }
      }
      $member
    }

    function Read-ProofProfileDescriptor {
      # BC5 descriptor check; AD5: exact Ordinal string matches, no path normalization.
      param([object]$Descriptor)
      $copy = [ordered]@{ ProfileId = $null; CharacterizationReference = $null; CharacterizationSHA256 = $null }
      $complete = $true
      foreach ($field in @('ProfileId', 'CharacterizationReference', 'CharacterizationSHA256')) {
        $member = Get-ProofMember -Container $Descriptor -Name $field
        if ($member.Found -and $member.Value -is [string]) { $copy[$field] = [string]$member.Value }
        else { $complete = $false }
      }
      $recognized = $complete -and
        [string]::Equals($copy.ProfileId, $profileId, [System.StringComparison]::Ordinal) -and
        [string]::Equals($copy.CharacterizationReference, $characterizationReference, [System.StringComparison]::Ordinal) -and
        [string]::Equals($copy.CharacterizationSHA256, $characterizationSHA256, [System.StringComparison]::Ordinal)
      @{ Copy = [pscustomobject]$copy; Recognized = $recognized }
    }

    function Read-ProofManagedDelta {
      # Exactly the two managed members, both strings, and no other member.
      param([object]$Delta)
      $values = [ordered]@{}
      $valid = $true
      $total = 0
      foreach ($key in $managedKeys) {
        $member = Get-ProofMember -Container $Delta -Name $key
        $total = $member.Total
        if ($member.Found -and $member.Value -is [string]) { $values[$key] = [string]$member.Value }
        else { $valid = $false }
      }
      if ($total -ne $managedKeys.Count) { $valid = $false }
      @{ Valid = $valid; Values = $values }
    }

    function Get-ProofSha256 {
      param([byte[]]$Bytes)
      [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Bytes))
    }

    function ConvertFrom-ProofStrictUtf8 {
      # Step 1: strict UTF-8 with at most one leading EF BB BF; UTF-16/UTF-32 marks are outside the profile.
      param([byte[]]$Bytes)
      $decoded = @{ Text = $null; Code = $null; HadBom = $false }
      $length = $Bytes.Length
      if ($length -ge 2 -and (($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) -or ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF))) {
        $decoded.Code = 'ENCODING_OUTSIDE_PROPOSED_PROFILE'
        return $decoded
      }
      if ($length -ge 4 -and $Bytes[0] -eq 0 -and $Bytes[1] -eq 0 -and $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF) {
        $decoded.Code = 'ENCODING_OUTSIDE_PROPOSED_PROFILE'
        return $decoded
      }
      $offset = 0
      if ($length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $decoded.HadBom = $true
        $offset = 3
      }
      $encoding = [System.Text.UTF8Encoding]::new($false, $true)
      try {
        $decoded.Text = $encoding.GetString($Bytes, $offset, $length - $offset)
      }
      catch {
        $decoded.Text = $null
        $decoded.Code = 'ENCODING_INVALID_UTF8'
      }
      $decoded
    }

    function Read-ProofString {
      # Reads one quoted string token starting at the quote. Decodes escapes and flags control
      # characters, unknown escapes and the I1 unpaired-surrogate predicate (BC3).
      param([string]$Text, [int]$Start, [char]$Quote, [char[]]$Stops)
      $n = $Text.Length
      $j = $Start + 1
      $builder = [System.Text.StringBuilder]::new()
      $read = @{ Value = $null; End = $n; Open = $false; Control = $false; BadEscape = $false; Unpaired = $false }
      $pendingHigh = $false
      while ($true) {
        if ($pendingHigh) {
          # A high-surrogate escape must be immediately followed by a low-surrogate escape.
          $paired = $false
          if ($j + 5 -lt $n -and $Text[$j] -ceq '\' -and $Text[$j + 1] -ceq 'u') {
            $unit = 0
            if ([int]::TryParse($Text.Substring($j + 2, 4), [System.Globalization.NumberStyles]::AllowHexSpecifier, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$unit) -and $unit -ge 0xDC00 -and $unit -le 0xDFFF) {
              $paired = $true
            }
          }
          if (-not $paired) {
            $read.Unpaired = $true
            $pendingHigh = $false
          }
        }
        if ($j -ge $n) { $read.Open = $true; return $read }
        $k = $Text.IndexOfAny($Stops, $j)
        if ($k -lt 0) { $read.Open = $true; return $read }
        if ($k -gt $j) { [void]$builder.Append($Text, $j, $k - $j) }
        $c = $Text[$k]
        if ($c -ceq $Quote) {
          $read.Value = $builder.ToString()
          $read.End = $k + 1
          return $read
        }
        if ($c -ceq '\') {
          if ($k + 1 -ge $n) { $read.Open = $true; return $read }
          $e = $Text[$k + 1]
          if ($e -ceq 'u') {
            if ($k + 5 -ge $n) { $read.Open = $true; return $read }
            $unit = 0
            if (-not [int]::TryParse($Text.Substring($k + 2, 4), [System.Globalization.NumberStyles]::AllowHexSpecifier, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$unit)) {
              $read.BadEscape = $true
              $j = $k + 2
              continue
            }
            if ($unit -ge 0xD800 -and $unit -le 0xDBFF) { $pendingHigh = $true }
            elseif ($unit -ge 0xDC00 -and $unit -le 0xDFFF) {
              if ($pendingHigh) { $pendingHigh = $false } else { $read.Unpaired = $true }
            }
            [void]$builder.Append([char]$unit)
            $j = $k + 6
            continue
          }
          if ($e -ceq '"') { [void]$builder.Append('"') }
          elseif ($e -ceq '\') { [void]$builder.Append('\') }
          elseif ($e -ceq '/') { [void]$builder.Append('/') }
          elseif ($e -ceq 'b') { [void]$builder.Append([char]8) }
          elseif ($e -ceq 'f') { [void]$builder.Append([char]12) }
          elseif ($e -ceq 'n') { [void]$builder.Append([char]10) }
          elseif ($e -ceq 'r') { [void]$builder.Append([char]13) }
          elseif ($e -ceq 't') { [void]$builder.Append([char]9) }
          else {
            $read.BadEscape = $true
            [void]$builder.Append($e)
          }
          $j = $k + 2
          continue
        }
        $read.Control = $true
        [void]$builder.Append($c)
        $j = $k + 1
      }
    }

    function Test-ProofNumberExact {
      # /preservationInvariants/numbers v1 rule (C-057 BC2 option A) for a strict JSON number lexeme:
      # the exact rational value of the lexeme must equal the exact value the backend parses to,
      # including the sign of zero.
      param([string]$Lexeme)
      $parts = $numberPartsPattern.Match($Lexeme)
      $negative = $parts.Groups[1].Length -gt 0
      $integerDigits = $parts.Groups[2].Value
      $fractionDigits = $parts.Groups[3].Value
      if (-not $parts.Groups[3].Success -and -not $parts.Groups[4].Success) {
        # Integer lexemes parse as exact Int64/BigInteger; only the sign rule can fail ("-0").
        return -not ($negative -and $integerDigits.TrimStart('0').Length -eq 0)
      }
      $parsed = [double]::Parse($Lexeme, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture)
      if ([double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) { return $false }
      $bits = [System.BitConverter]::DoubleToInt64Bits($parsed)
      $parsedNegative = $bits -lt 0
      $digits = ($integerDigits + $fractionDigits).TrimStart('0')
      if ($digits.Length -eq 0) { return ($negative -eq $parsedNegative) -and ($parsed -eq 0) }
      if ($negative -ne $parsedNegative -or $parsed -eq 0) { return $false }
      $exponent = [System.Numerics.BigInteger]::Zero
      if ($parts.Groups[4].Success) {
        $exponent = [System.Numerics.BigInteger]::Parse($parts.Groups[4].Value, [System.Globalization.NumberStyles]::AllowLeadingSign, [System.Globalization.CultureInfo]::InvariantCulture)
      }
      $significant = $digits.TrimEnd('0')
      $scale = $exponent - $fractionDigits.Length + ($digits.Length - $significant.Length)
      # A finite non-zero Double has at most 767 significant decimal digits and a decimal scale
      # within [-1074, 308]; outside these bounds equality is impossible, so no large powers are built.
      if ($significant.Length -gt 800 -or $scale -gt 330 -or $scale -lt -1100) { return $false }
      $decimalScale = [int]$scale
      $coefficient = [System.Numerics.BigInteger]::Parse($significant, [System.Globalization.CultureInfo]::InvariantCulture)
      $magnitude = $bits -band [long]0x7FFFFFFFFFFFFFFF
      $biasedExponent = [int](($magnitude -shr 52) -band 0x7FF)
      $mantissaBits = $magnitude -band [long]0xFFFFFFFFFFFFF
      if ($biasedExponent -eq 0) { $binaryExponent = -1074 }
      else {
        $mantissaBits = $mantissaBits -bor [long]0x10000000000000
        $binaryExponent = $biasedExponent - 1075
      }
      $left = $coefficient
      $right = [System.Numerics.BigInteger]::new([long]$mantissaBits)
      if ($decimalScale -ge 0) { $left = $left * [System.Numerics.BigInteger]::Pow(10, $decimalScale) }
      else { $right = $right * [System.Numerics.BigInteger]::Pow(10, -$decimalScale) }
      if ($binaryExponent -ge 0) { $right = $right * [System.Numerics.BigInteger]::Pow(2, $binaryExponent) }
      else { $left = $left * [System.Numerics.BigInteger]::Pow(2, -$binaryExponent) }
      return $left.Equals($right)
    }

    function Get-ProofChildPath {
      param([hashtable]$Frame, [hashtable]$Audit)
      if ($null -eq $Frame) {
        if ($Audit.RootBegan) { return '#trailing' }
        return ''
      }
      if ($Frame.K -ceq 'o') { return $Frame.Path + '/' + (Format-ProofPointerSegment -Name ([string]$Frame.PendingName)) }
      return $Frame.Path + '/' + $Frame.Index
    }

    function Register-ProofName {
      # /preservationInvariants/nameHandling. Per name: DUPLICATE_DECODED_NAME, else
      # CASE_LOOKALIKE_OF_PROTECTED_NAME then CASE_COLLIDING_NAME (AD2: both codes are carried, in
      # raw token order). The empty name is HELD (trueEmptyName).
      param([hashtable]$Frame, [string]$Name, [string]$Path, [hashtable]$Findings)
      if ($Name.Length -eq 0) {
        Add-ProofFinding -Findings $Findings -Category 'S4NameEmpty' -Stage 'Step4.Names' -Code 'EMPTY_MEMBER_NAME_UNPROVED' -Path $Path -Kind 'Name'
      }
      if (-not $Frame.Names.Add($Name)) {
        Add-ProofFinding -Findings $Findings -Category 'S4NameRejected' -Stage 'Step4.Names' -Code 'DUPLICATE_DECODED_NAME' -Path $Path -Kind 'Name'
        return
      }
      $protectedNames = @()
      if ($Frame.IsRoot) { $protectedNames = $rootProtectedNames }
      elseif ($Frame.IsSettings) { $protectedNames = $managedKeys }
      foreach ($protectedName in $protectedNames) {
        if ([string]::Equals($Name, $protectedName, [System.StringComparison]::OrdinalIgnoreCase) -and -not [string]::Equals($Name, $protectedName, [System.StringComparison]::Ordinal)) {
          Add-ProofFinding -Findings $Findings -Category 'S4NameRejected' -Stage 'Step4.Names' -Code 'CASE_LOOKALIKE_OF_PROTECTED_NAME' -Path $Path -Kind 'Name'
        }
      }
      if (-not $Frame.CaseInsensitiveNames.Add($Name)) {
        Add-ProofFinding -Findings $Findings -Category 'S4NameRejected' -Stage 'Step4.Names' -Code 'CASE_COLLIDING_NAME' -Path $Path -Kind 'Name'
      }
    }

    function Complete-ProofValue {
      # Attaches a raw-index node to its parent and advances the parent state.
      param([hashtable]$Audit, [hashtable]$Frame, [object]$Node, [string]$Kind, [bool]$IsContainer, [bool]$IsSettingsValue)
      if ($null -eq $Frame) {
        if (-not $Audit.RootStarted) {
          $Audit.RootStarted = $true
          $Audit.Root = $Node
          $Audit.RootKind = $Kind
          if (-not $IsContainer) { $Audit.RootDone = $true }
        }
        return
      }
      if ($Frame.K -ceq 'o') {
        $Frame.Node.Names.Add([string]$Frame.PendingName)
        if ($IsSettingsValue) {
          if ($Kind -ceq 'o') {
            if ($Audit.SettingsState -cne 'Invalid') { $Audit.SettingsState = 'Object' }
          }
          else {
            $Audit.SettingsState = 'Invalid'
            Add-ProofFinding -Findings $Audit.Findings -Category 'S2d' -Stage 'Step2.StructureAndRootShape' -Code 'SETTINGS_NOT_OBJECT' -Path '/settings' -Kind 'Settings'
          }
        }
      }
      $Frame.Node.Vals.Add($Node)
      $Frame.Index++
      $Frame.State = 'CommaOrEnd'
      $Frame.LastComma = $false
    }

    function Invoke-ProofTokenAudit {
      # Bounded read-only lexical audit (/proposedProfile/lexicalProofScope) for steps 2-4. It
      # tolerates the enumerated lenient forms so that termination and root shape (step 2) are
      # decided even for lenient input, records every finding by category, and builds a raw index
      # (names, decoded strings, number lexemes, literals) used only for the step 5 correspondence.
      # Lexical tokens counted against the cap: { } [ ] : , names, strings, numbers, literals and
      # unrecognized tokens; whitespace and comments are not counted. The root container is depth 1.
      param([string]$Text)
      $findings = @{}
      foreach ($category in $categoryOrder) { $findings[$category] = [System.Collections.Generic.List[object]]::new() }
      $audit = @{
        Findings         = $findings
        Resource         = $null
        Root             = $null
        RootKind         = $null
        RootBegan        = $false
        RootStarted      = $false
        RootDone         = $false
        SettingsState    = 'Unknown'
        Open             = $false
        TrailingReported = $false
      }
      $t = $Text
      $n = $t.Length
      $i = 0
      $tokens = 0
      $stack = [System.Collections.Generic.List[hashtable]]::new()

      while ($true) {
        if ($tokens -gt $maximumLexicalTokens) {
          $audit.Resource = New-ProofReason -Stage 'Step2-4.LexicalAudit' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path '' -Kind 'LexicalTokens'
          return $audit
        }

        # Trivia: JSON whitespace, T1 line comments and T2 block comments.
        while ($i -lt $n) {
          $ch = $t[$i]
          if ($ch -ceq ' ' -or $ch -ceq "`t" -or $ch -ceq "`n" -or $ch -ceq "`r") { $i++; continue }
          if ($ch -ceq '/' -and $i + 1 -lt $n) {
            $next = $t[$i + 1]
            if ($next -ceq '/') {
              $end = $t.IndexOfAny($lineEnds, $i + 2)
              if ($end -lt 0) { $i = $n } else { $i = $end }
              continue
            }
            if ($next -ceq '*') {
              $end = $t.IndexOf('*/', $i + 2, [System.StringComparison]::Ordinal)
              $limit = $n
              if ($end -ge 0) { $limit = $end }
              if ($t.IndexOf('/*', $i + 2, $limit - ($i + 2), [System.StringComparison]::Ordinal) -ge 0) {
                Add-ProofLenientFinding -Findings $findings -Path '' -Kind 'NestedBlockComment'
              }
              if ($end -lt 0) {
                Add-ProofLenientFinding -Findings $findings -Path '' -Kind 'UnterminatedComment'
                $i = $n
              }
              else { $i = $end + 2 }
              continue
            }
          }
          break
        }
        if ($i -ge $n) { break }

        $ch = $t[$i]
        $code = [int]$ch
        $f = $null
        if ($stack.Count -gt 0) { $f = $stack[$stack.Count - 1] }
        $isAsciiDigit = $code -ge 48 -and $code -le 57
        $isNumberStart = $isAsciiDigit -or $ch -ceq '-' -or $ch -ceq '+' -or $ch -ceq '.'
        $isIdentifierStart = (-not $isAsciiDigit) -and ([char]::IsLetterOrDigit($ch) -or $ch -ceq '_' -or $ch -ceq '$')
        $isValueStart = $isNumberStart -or $isIdentifierStart -or $ch -ceq '{' -or $ch -ceq '[' -or $ch -ceq '"' -or $ch -ceq "'"

        if ($null -eq $f) {
          if ($audit.RootDone -and -not $audit.TrailingReported) {
            Add-ProofLenientFinding -Findings $findings -Path '' -Kind 'ContentAfterRootValue'
            $audit.TrailingReported = $true
          }
          if (-not $isValueStart) {
            Add-ProofLenientFinding -Findings $findings -Path '' -Kind 'UnrecognizedToken'
            $tokens++
            $i++
            continue
          }
        }
        elseif ($f.K -ceq 'o') {
          if ($f.State -ceq 'Name') {
            if ($ch -ceq '}') {
              # T3: one trailing comma before "}" is eligible trivia.
              $tokens++
              $i++
              $stack.RemoveAt($stack.Count - 1)
              if ($stack.Count -eq 0) { $audit.RootDone = $true }
              continue
            }
            if ($ch -ceq ',') {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'LeadingOrConsecutiveComma'
              $f.LastComma = $true
              $tokens++
              $i++
              continue
            }
            if ($ch -ceq '"' -or $ch -ceq "'" -or $isIdentifierStart) {
              if ($ch -ceq '"' -or $ch -ceq "'") {
                if ($ch -ceq "'") { Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'SingleQuotedMemberName' }
                $stops = $doubleQuoteStops
                if ($ch -ceq "'") { $stops = $singleQuoteStops }
                $read = Read-ProofString -Text $t -Start $i -Quote $ch -Stops $stops
                $tokens++
                if ($read.Open) { $audit.Open = $true; $i = $n; break }
                $name = $read.Value
                $nameEnd = $read.End
              }
              else {
                Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnquotedMemberName'
                $j = $i + 1
                while ($j -lt $n -and ([char]::IsLetterOrDigit($t[$j]) -or $t[$j] -ceq '_' -or $t[$j] -ceq '$')) { $j++ }
                $tokens++
                $name = $t.Substring($i, $j - $i)
                $nameEnd = $j
                $read = @{ Control = $false; BadEscape = $false; Unpaired = $false }
              }
              $namePath = $f.Path + '/' + (Format-ProofPointerSegment -Name $name)
              if ($read.Control) { Add-ProofLenientFinding -Findings $findings -Path $namePath -Kind 'UnescapedControlCharacter' }
              if ($read.BadEscape) { Add-ProofLenientFinding -Findings $findings -Path $namePath -Kind 'UnrecognizedEscape' }
              if ($read.Unpaired) {
                Add-ProofFinding -Findings $findings -Category 'S4Surrogate' -Stage 'Step4.Surrogates' -Code 'UNICODE_SURROGATE_FIDELITY_UNPROVED' -Path $namePath -Kind 'Name'
              }
              Register-ProofName -Frame $f -Name $name -Path $namePath -Findings $findings
              $f.PendingName = $name
              $f.State = 'Colon'
              $i = $nameEnd
              continue
            }
            if ($isValueStart) {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'MissingMemberName'
              $f.PendingName = $null
              $f.State = 'Value'
              continue
            }
            Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnrecognizedToken'
            $tokens++
            $i++
            continue
          }
          if ($f.State -ceq 'Colon') {
            if ($ch -ceq ':') {
              $f.State = 'Value'
              $tokens++
              $i++
              continue
            }
            Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'MissingColon'
            $f.State = 'Value'
            continue
          }
          if ($f.State -ceq 'Value') {
            if ($ch -ceq ',' -or $ch -ceq '}') {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'MissingMemberValue'
              $f.State = 'CommaOrEnd'
              continue
            }
            if (-not $isValueStart) {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnrecognizedToken'
              $tokens++
              $i++
              continue
            }
          }
          else {
            # CommaOrEnd
            if ($ch -ceq ',') {
              $f.LastComma = $true
              $f.State = 'Name'
              $tokens++
              $i++
              continue
            }
            if ($ch -ceq '}') {
              $tokens++
              $i++
              $stack.RemoveAt($stack.Count - 1)
              if ($stack.Count -eq 0) { $audit.RootDone = $true }
              continue
            }
            if ($isValueStart) {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'MissingComma'
              $f.LastComma = $false
              $f.State = 'Name'
              continue
            }
            Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnrecognizedToken'
            $tokens++
            $i++
            continue
          }
        }
        else {
          if ($f.State -ceq 'Value') {
            if ($ch -ceq ']') {
              if ($f.LastComma) { Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'TrailingCommaBeforeArrayEnd' }
              $tokens++
              $i++
              $stack.RemoveAt($stack.Count - 1)
              if ($stack.Count -eq 0) { $audit.RootDone = $true }
              continue
            }
            if ($ch -ceq ',') {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'LeadingOrConsecutiveComma'
              $f.LastComma = $true
              $tokens++
              $i++
              continue
            }
            if (-not $isValueStart) {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnrecognizedToken'
              $tokens++
              $i++
              continue
            }
          }
          else {
            # CommaOrEnd
            if ($ch -ceq ',') {
              $f.LastComma = $true
              $f.State = 'Value'
              $tokens++
              $i++
              continue
            }
            if ($ch -ceq ']') {
              $tokens++
              $i++
              $stack.RemoveAt($stack.Count - 1)
              if ($stack.Count -eq 0) { $audit.RootDone = $true }
              continue
            }
            if ($isValueStart) {
              Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'MissingComma'
              $f.LastComma = $false
              $f.State = 'Value'
              continue
            }
            Add-ProofLenientFinding -Findings $findings -Path $f.Path -Kind 'UnrecognizedToken'
            $tokens++
            $i++
            continue
          }
        }

        # A value starts at $i.
        $isRootValue = ($null -eq $f) -and -not $audit.RootBegan
        if ($isRootValue) { $audit.RootBegan = $true }
        $isSettingsValue = ($null -ne $f) -and $f.IsRoot -and [string]::Equals([string]$f.PendingName, 'settings', [System.StringComparison]::Ordinal) -and ($null -ne $f.PendingName)

        if ($ch -ceq '{' -or $ch -ceq '[') {
          if ($stack.Count -ge $maximumLexicalContainerDepth) {
            $audit.Resource = New-ProofReason -Stage 'Step2-4.LexicalAudit' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path (Get-ProofChildPath -Frame $f -Audit $audit) -Kind 'LexicalContainerDepth'
            return $audit
          }
          $tokens++
          $childPath = Get-ProofChildPath -Frame $f -Audit $audit
          if ($ch -ceq '{') {
            $node = @{ K = 'o'; Names = [System.Collections.Generic.List[string]]::new(); Vals = [System.Collections.Generic.List[object]]::new() }
            $newFrame = @{
              K                    = 'o'
              Node                 = $node
              Path                 = $childPath
              State                = 'Name'
              LastComma            = $false
              Index                = 0
              PendingName          = $null
              Names                = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
              CaseInsensitiveNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
              IsRoot               = $isRootValue
              IsSettings           = $isSettingsValue
            }
            if ($isRootValue) { $audit.SettingsState = 'Absent' }
          }
          else {
            $node = @{ K = 'a'; Vals = [System.Collections.Generic.List[object]]::new() }
            $newFrame = @{ K = 'a'; Node = $node; Path = $childPath; State = 'Value'; LastComma = $false; Index = 0; IsRoot = $false; IsSettings = $false }
          }
          Complete-ProofValue -Audit $audit -Frame $f -Node $node -Kind $node.K -IsContainer $true -IsSettingsValue $isSettingsValue
          $stack.Add($newFrame)
          $i++
          continue
        }

        if ($ch -ceq '"' -or $ch -ceq "'") {
          $valuePath = Get-ProofChildPath -Frame $f -Audit $audit
          if ($ch -ceq "'") { Add-ProofLenientFinding -Findings $findings -Path $valuePath -Kind 'SingleQuotedString' }
          $stops = $doubleQuoteStops
          if ($ch -ceq "'") { $stops = $singleQuoteStops }
          $read = Read-ProofString -Text $t -Start $i -Quote $ch -Stops $stops
          $tokens++
          if ($read.Open) { $audit.Open = $true; $i = $n; break }
          if ($read.Control) { Add-ProofLenientFinding -Findings $findings -Path $valuePath -Kind 'UnescapedControlCharacter' }
          if ($read.BadEscape) { Add-ProofLenientFinding -Findings $findings -Path $valuePath -Kind 'UnrecognizedEscape' }
          if ($read.Unpaired) {
            Add-ProofFinding -Findings $findings -Category 'S4Surrogate' -Stage 'Step4.Surrogates' -Code 'UNICODE_SURROGATE_FIDELITY_UNPROVED' -Path $valuePath -Kind 'String'
          }
          Complete-ProofValue -Audit $audit -Frame $f -Node $read.Value -Kind 's' -IsContainer $false -IsSettingsValue $isSettingsValue
          $i = $read.End
          continue
        }

        if ($isNumberStart) {
          $j = $i + 1
          while ($j -lt $n) {
            $c = [int]$t[$j]
            if (($c -ge 48 -and $c -le 57) -or ($c -ge 65 -and $c -le 90) -or ($c -ge 97 -and $c -le 122) -or $c -eq 43 -or $c -eq 45 -or $c -eq 46) { $j++ }
            else { break }
          }
          $lexeme = $t.Substring($i, $j - $i)
          $tokens++
          if ($strictNumberPattern.IsMatch($lexeme)) {
            $node = @{ K = 'n'; L = $lexeme }
            $kind = 'n'
            if (-not (Test-ProofNumberExact -Lexeme $lexeme)) {
              Add-ProofFinding -Findings $findings -Category 'S4Number' -Stage 'Step4.Numbers' -Code 'UNMANAGED_NUMBER_NOT_EXACTLY_REPRESENTED' -Path (Get-ProofChildPath -Frame $f -Audit $audit) -Kind 'Number'
            }
          }
          else {
            Add-ProofLenientFinding -Findings $findings -Path (Get-ProofChildPath -Frame $f -Audit $audit) -Kind 'LenientNumberOrLiteral'
            $node = @{ K = 'x' }
            $kind = 'x'
          }
          Complete-ProofValue -Audit $audit -Frame $f -Node $node -Kind $kind -IsContainer $false -IsSettingsValue $isSettingsValue
          $i = $j
          continue
        }

        # Identifier: true, false, null, or a lenient literal such as NaN, Infinity, undefined or new.
        $j = $i + 1
        while ($j -lt $n -and ([char]::IsLetterOrDigit($t[$j]) -or $t[$j] -ceq '_' -or $t[$j] -ceq '$')) { $j++ }
        $word = $t.Substring($i, $j - $i)
        $tokens++
        if ($word -ceq 'true') { $node = $true; $kind = 'l' }
        elseif ($word -ceq 'false') { $node = $false; $kind = 'l' }
        elseif ($word -ceq 'null') { $node = @{ K = 'z' }; $kind = 'l' }
        else {
          if ($j -ge $n -and ('true'.StartsWith($word, [System.StringComparison]::Ordinal) -or 'false'.StartsWith($word, [System.StringComparison]::Ordinal) -or 'null'.StartsWith($word, [System.StringComparison]::Ordinal))) {
            # A literal cut off by end of input is an open value (step 2(b)).
            $audit.Open = $true
            $i = $n
            break
          }
          Add-ProofLenientFinding -Findings $findings -Path (Get-ProofChildPath -Frame $f -Audit $audit) -Kind 'LenientNumberOrLiteral'
          $node = @{ K = 'x' }
          $kind = 'x'
        }
        Complete-ProofValue -Audit $audit -Frame $f -Node $node -Kind $kind -IsContainer $false -IsSettingsValue $isSettingsValue
        $i = $j
      }

      if ($tokens -gt $maximumLexicalTokens) {
        $audit.Resource = New-ProofReason -Stage 'Step2-4.LexicalAudit' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path '' -Kind 'LexicalTokens'
        return $audit
      }
      # Step 2 (a)-(c): root presence, termination and root shape.
      if ($stack.Count -gt 0 -or $audit.Open) {
        $openPath = ''
        if ($stack.Count -gt 0) { $openPath = $stack[$stack.Count - 1].Path }
        Add-ProofFinding -Findings $findings -Category 'S2b' -Stage 'Step2.StructureAndRootShape' -Code 'PARSE_ERROR' -Path $openPath -Kind 'Input'
      }
      if (-not $audit.RootBegan) {
        Add-ProofFinding -Findings $findings -Category 'S2a' -Stage 'Step2.StructureAndRootShape' -Code 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT' -Path '' -Kind 'Input'
      }
      elseif ($audit.RootStarted -and $audit.RootKind -cne 'o') {
        Add-ProofFinding -Findings $findings -Category 'S2c' -Stage 'Step2.StructureAndRootShape' -Code 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT' -Path '' -Kind 'Root'
      }
      if ($findings['S2a'].Count -gt 0 -or $findings['S2b'].Count -gt 0 -or $findings['S2c'].Count -gt 0) { $audit.SettingsState = 'Unknown' }
      return $audit
    }

    function Test-ProofIsObject {
      param([object]$Value)
      ($null -ne $Value) -and ($Value.PSObject.BaseObject -is [System.Management.Automation.PSCustomObject])
    }

    function Test-ProofRawCorrespondence {
      # Step 5 (I2): the raw index and the parsed graph must correspond exactly (names in order,
      # decoded strings, literals, exact numbers). Returns $null on match, else the relative JSON
      # Pointer of the first mismatch ('' means this node).
      param([object]$Raw, [object]$Parsed)
      if ($Raw -is [string]) {
        if ($Parsed -is [string] -and [string]::Equals($Raw, $Parsed, [System.StringComparison]::Ordinal)) { return $null }
        return ''
      }
      if ($Raw -is [bool]) {
        if ($Parsed -is [bool] -and $Parsed -eq $Raw) { return $null }
        return ''
      }
      if ($Raw.K -ceq 'z') {
        if ($null -eq $Parsed) { return $null }
        return ''
      }
      if ($Raw.K -ceq 'n') {
        $lexeme = $Raw.L
        if ($lexeme -cnotmatch '[.eE]') {
          $expected = [System.Numerics.BigInteger]::Parse($lexeme, [System.Globalization.NumberStyles]::AllowLeadingSign, [System.Globalization.CultureInfo]::InvariantCulture)
          if (($Parsed -is [long] -or $Parsed -is [System.Numerics.BigInteger]) -and ([System.Numerics.BigInteger]$Parsed).Equals($expected)) { return $null }
          return ''
        }
        $expectedDouble = [double]::Parse($lexeme, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($Parsed -is [double] -and [System.BitConverter]::DoubleToInt64Bits($Parsed) -eq [System.BitConverter]::DoubleToInt64Bits($expectedDouble)) { return $null }
        return ''
      }
      if ($Raw.K -ceq 'o') {
        if (-not (Test-ProofIsObject -Value $Parsed)) { return '' }
        $properties = @($Parsed.PSObject.Properties)
        if ($properties.Count -ne $Raw.Names.Count) { return '' }
        for ($k = 0; $k -lt $properties.Count; $k++) {
          $segment = '/' + (Format-ProofPointerSegment -Name $Raw.Names[$k])
          if (-not [string]::Equals($properties[$k].Name, $Raw.Names[$k], [System.StringComparison]::Ordinal)) { return $segment }
          $mismatch = Test-ProofRawCorrespondence -Raw $Raw.Vals[$k] -Parsed $properties[$k].Value
          if ($null -ne $mismatch) { return $segment + $mismatch }
        }
        return $null
      }
      if ($Raw.K -ceq 'a') {
        if (-not ($Parsed -is [System.Array]) -or $Parsed.Count -ne $Raw.Vals.Count) { return '' }
        for ($k = 0; $k -lt $Parsed.Count; $k++) {
          $mismatch = Test-ProofRawCorrespondence -Raw $Raw.Vals[$k] -Parsed $Parsed[$k]
          if ($null -ne $mismatch) { return '/' + $k + $mismatch }
        }
        return $null
      }
      return ''
    }

    function Test-ProofGraphEqual {
      # Logical equality of two parsed graphs: object members compared by Ordinal name regardless
      # of order, arrays by order and count, strings Ordinal, numbers by exact type and value (Double
      # by bits, so the sign of zero counts). Returns $null on match, else a relative JSON Pointer.
      param([object]$Left, [object]$Right)
      if ($null -eq $Left -or $null -eq $Right) {
        if ($null -eq $Left -and $null -eq $Right) { return $null }
        return ''
      }
      if (Test-ProofIsObject -Value $Left) {
        if (-not (Test-ProofIsObject -Value $Right)) { return '' }
        $rightMembers = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        foreach ($property in $Right.PSObject.Properties) {
          if (-not $rightMembers.TryAdd($property.Name, $property.Value)) { return '' }
        }
        $leftTotal = 0
        foreach ($property in $Left.PSObject.Properties) {
          $leftTotal++
          $rightValue = $null
          if (-not $rightMembers.TryGetValue($property.Name, [ref]$rightValue)) { return '/' + (Format-ProofPointerSegment -Name $property.Name) }
          $mismatch = Test-ProofGraphEqual -Left $property.Value -Right $rightValue
          if ($null -ne $mismatch) { return '/' + (Format-ProofPointerSegment -Name $property.Name) + $mismatch }
        }
        if ($leftTotal -ne $rightMembers.Count) { return '' }
        return $null
      }
      if ($Left -is [System.Array]) {
        if (-not ($Right -is [System.Array]) -or $Left.Count -ne $Right.Count) { return '' }
        for ($k = 0; $k -lt $Left.Count; $k++) {
          $mismatch = Test-ProofGraphEqual -Left $Left[$k] -Right $Right[$k]
          if ($null -ne $mismatch) { return '/' + $k + $mismatch }
        }
        return $null
      }
      if ($Left -is [string]) {
        if ($Right -is [string] -and [string]::Equals($Left, $Right, [System.StringComparison]::Ordinal)) { return $null }
        return ''
      }
      if ($Left -is [bool]) {
        if ($Right -is [bool] -and $Left -eq $Right) { return $null }
        return ''
      }
      if ($Left -is [double]) {
        if ($Right -is [double] -and [System.BitConverter]::DoubleToInt64Bits($Left) -eq [System.BitConverter]::DoubleToInt64Bits($Right)) { return $null }
        return ''
      }
      if ($Left -is [long] -or $Left -is [int] -or $Left -is [System.Numerics.BigInteger]) {
        if ($Right.GetType() -eq $Left.GetType() -and $Left.Equals($Right)) { return $null }
        return ''
      }
      return ''
    }

    function Copy-ProofGraph {
      # Independent clone (/preservationInvariants/clone); not a parser or serializer round trip.
      param([object]$Node)
      if ($null -eq $Node) { return $null }
      if ($Node -is [System.Array]) {
        $copy = [object[]]::new($Node.Count)
        for ($k = 0; $k -lt $Node.Count; $k++) { $copy[$k] = Copy-ProofGraph -Node $Node[$k] }
        return , $copy
      }
      if (Test-ProofIsObject -Value $Node) {
        $copy = [pscustomobject]@{}
        foreach ($property in $Node.PSObject.Properties) {
          $copy.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($property.Name, (Copy-ProofGraph -Node $property.Value)))
        }
        return $copy
      }
      return $Node
    }

    function Set-ProofManagedDelta {
      # Applies exactly the two managed members to the clone; creates settings only when absent.
      param([object]$Graph, [System.Collections.IDictionary]$Values)
      $settings = $null
      foreach ($property in $Graph.PSObject.Properties) {
        if ([string]::Equals($property.Name, 'settings', [System.StringComparison]::Ordinal)) { $settings = $property.Value; break }
      }
      if ($null -eq $settings) {
        $settings = [pscustomobject]@{}
        $Graph.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('settings', $settings))
      }
      foreach ($key in $managedKeys) {
        $existing = $null
        foreach ($property in $settings.PSObject.Properties) {
          if ([string]::Equals($property.Name, $key, [System.StringComparison]::Ordinal)) { $existing = $property; break }
        }
        if ($null -ne $existing) { $existing.Value = $Values[$key] }
        else { $settings.PSObject.Properties.Add([System.Management.Automation.PSNoteProperty]::new($key, $Values[$key])) }
      }
    }

    function Get-ProofReplacementCount {
      # Number of U+FFFD code units in decoded names and strings of a raw index.
      param([object]$Raw)
      if ($Raw -is [string]) { return $Raw.Length - $Raw.Replace($replacementCharacter, '').Length }
      $total = 0
      if ($Raw -is [hashtable]) {
        if ($Raw.K -ceq 'o') {
          foreach ($name in $Raw.Names) { $total += $name.Length - $name.Replace($replacementCharacter, '').Length }
        }
        if ($Raw.K -ceq 'o' -or $Raw.K -ceq 'a') {
          foreach ($value in $Raw.Vals) { $total += Get-ProofReplacementCount -Raw $value }
        }
      }
      return $total
    }

    function ConvertFrom-ProofJson {
      # Existing backend only, with explicit per-call ErrorAction/WarningAction Stop.
      param([string]$Text, [string]$Stage)
      $parse = @{ Value = $null; Failure = $null; Disposition = $null }
      try {
        $output = @(ConvertFrom-Json -InputObject $Text -ErrorAction Stop -WarningAction Stop)
      }
      catch {
        $parse.Failure = New-ProofReason -Stage $Stage -Code 'BACKEND_PARSE_UNPROVED' -Path '' -Kind 'Backend'
        $parse.Disposition = 'HELD_UNPROVED'
        return $parse
      }
      if ($output.Count -ne 1 -or -not (Test-ProofIsObject -Value $output[0])) {
        $parse.Failure = New-ProofReason -Stage $Stage -Code 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT' -Path '' -Kind 'Backend'
        $parse.Disposition = 'REJECTED_INPUT'
        return $parse
      }
      $parse.Value = $output[0]
      $parse
    }

    function ConvertTo-ProofJson {
      # Existing serializer: ConvertTo-Json -Depth 20, ErrorAction/WarningAction Stop, exactly one string.
      param([object]$Graph)
      $serialized = @{ Text = $null; Failure = $null }
      try {
        $output = @(ConvertTo-Json -InputObject $Graph -Depth 20 -ErrorAction Stop -WarningAction Stop)
      }
      catch {
        $serialized.Failure = New-ProofReason -Stage 'Step5.Serializer' -Code 'SERIALIZER_WARNING_OR_UNMANAGED_MISMATCH' -Path '' -Kind 'Serializer'
        return $serialized
      }
      if ($output.Count -ne 1 -or -not ($output[0] -is [string])) {
        $serialized.Failure = New-ProofReason -Stage 'Step5.Serializer' -Code 'SERIALIZER_WARNING_OR_UNMANAGED_MISMATCH' -Path '' -Kind 'Serializer'
        return $serialized
      }
      $serialized.Text = [string]$output[0]
      $serialized
    }

    function Invoke-ProofEvaluation {
      param(
        [string]$EvaluationMode,
        [string]$ParameterSetName,
        [byte[]]$Original,
        [byte[]]$Candidate,
        [hashtable]$InputDescriptor,
        [hashtable]$SerializerDescriptor,
        [hashtable]$Delta
      )
      $isCompare = [string]::Equals($EvaluationMode, 'Compare', [System.StringComparison]::Ordinal)
      $mismatchCode = 'SERIALIZER_WARNING_OR_UNMANAGED_MISMATCH'

      # Step 0: arguments (AD1) and profile descriptors (BC5, AD5).
      if (-not [string]::Equals($EvaluationMode, $ParameterSetName, [System.StringComparison]::Ordinal)) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step0.Arguments' -Code 'MODE_PARAMETER_SET_MISMATCH' -Path '/Mode' -Kind 'Arguments') -SettingsState 'Unknown'
      }
      if (-not $InputDescriptor.Recognized) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step0.ProfileDescriptor' -Code 'PROFILE_DESCRIPTOR_UNRECOGNIZED' -Path '/InputProfile' -Kind 'ProfileDescriptor') -SettingsState 'Unknown'
      }
      if ($isCompare -and -not $SerializerDescriptor.Recognized) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step0.ProfileDescriptor' -Code 'PROFILE_DESCRIPTOR_UNRECOGNIZED' -Path '/SerializerProfile' -Kind 'ProfileDescriptor') -SettingsState 'Unknown'
      }
      if ($isCompare -and -not $Delta.Valid) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step0.Arguments' -Code 'MANAGED_DELTA_UNRECOGNIZED' -Path '/ManagedDelta' -Kind 'Arguments') -SettingsState 'Unknown'
      }

      # Step 1: resource cap on input bytes, then strict decode.
      if ($Original.Length -gt $maximumInputBytes) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step1.StrictDecode' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path '' -Kind 'InputBytes') -SettingsState 'Unknown'
      }
      $decoded = ConvertFrom-ProofStrictUtf8 -Bytes $Original
      if ($null -ne $decoded.Code) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step1.StrictDecode' -Code $decoded.Code -Path '' -Kind 'Encoding') -SettingsState 'Unknown'
      }

      # Steps 2-4: lexical audit; the first non-empty category in precedence order decides.
      $audit = Invoke-ProofTokenAudit -Text $decoded.Text
      if ($null -ne $audit.Resource) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @($audit.Resource) -SettingsState 'Unknown'
      }
      foreach ($category in $categoryOrder) {
        $list = $audit.Findings[$category]
        if ($list.Count -gt 0) {
          return New-ProofOutcome -Disposition $categoryDisposition[$category] -Reasons $list.ToArray() -SettingsState $audit.SettingsState
        }
      }
      $settingsState = $audit.SettingsState

      # Step 5 (I2): existing materializer and raw-to-parsed correspondence.
      $parse = ConvertFrom-ProofJson -Text $decoded.Text -Stage 'Step5.ParseCorrespondence'
      if ($null -ne $parse.Failure) {
        return New-ProofOutcome -Disposition $parse.Disposition -Reasons @($parse.Failure) -SettingsState $settingsState
      }
      $mismatch = Test-ProofRawCorrespondence -Raw $audit.Root -Parsed $parse.Value
      if ($null -ne $mismatch) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.ParseCorrespondence' -Code $mismatchCode -Path $mismatch -Kind 'Correspondence') -SettingsState $settingsState
      }

      # Step 5 (I3): independent in-memory candidate, serialized and re-parsed by the same backend.
      $expected = Copy-ProofGraph -Node $parse.Value
      if ($isCompare) { Set-ProofManagedDelta -Graph $expected -Values $Delta.Values }
      $serialized = ConvertTo-ProofJson -Graph $expected
      if ($null -ne $serialized.Failure) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @($serialized.Failure) -SettingsState $settingsState
      }
      $reparse = ConvertFrom-ProofJson -Text $serialized.Text -Stage 'Step5.Serializer'
      if ($null -ne $reparse.Failure) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.Serializer' -Code $mismatchCode -Path '' -Kind 'RoundTrip') -SettingsState $settingsState
      }
      $mismatch = Test-ProofGraphEqual -Left $expected -Right $reparse.Value
      if ($null -ne $mismatch) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.Serializer' -Code $mismatchCode -Path $mismatch -Kind 'RoundTrip') -SettingsState $settingsState
      }
      if (-not $isCompare) {
        return New-ProofOutcome -Disposition 'VERIFIED' -Reasons @() -SettingsState $settingsState
      }

      # Step 5 (I4) Compare: candidate bytes, candidate audit, candidate parse and full comparison.
      if ($Candidate.Length -gt $maximumInputBytes) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step5.CandidateBytes' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path '' -Kind 'CandidateBytes') -SettingsState $settingsState
      }
      $candidateDecoded = ConvertFrom-ProofStrictUtf8 -Bytes $Candidate
      if ($null -ne $candidateDecoded.Code -or $candidateDecoded.HadBom) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.CandidateBytes' -Code $mismatchCode -Path '' -Kind 'CandidateEncoding') -SettingsState $settingsState
      }
      $candidateText = $candidateDecoded.Text
      $newline = [System.Environment]::NewLine
      $newlineValid = $candidateText.Length -gt $newline.Length -and $candidateText.EndsWith($newline, [System.StringComparison]::Ordinal)
      if ($newlineValid) {
        $body = $candidateText.Substring(0, $candidateText.Length - $newline.Length)
        $newlineValid = -not ($body.EndsWith("`n", [System.StringComparison]::Ordinal) -or $body.EndsWith("`r", [System.StringComparison]::Ordinal))
      }
      if (-not $newlineValid) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.CandidateBytes' -Code $mismatchCode -Path '' -Kind 'CandidateNewline') -SettingsState $settingsState
      }
      $candidateAudit = Invoke-ProofTokenAudit -Text $candidateText
      if ($null -ne $candidateAudit.Resource) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step5.CandidateAudit' -Code 'RESOURCE_LIMIT_EXCEEDED' -Path $candidateAudit.Resource.Path -Kind $candidateAudit.Resource.Kind) -SettingsState $settingsState
      }
      foreach ($category in $categoryOrder) {
        $list = $candidateAudit.Findings[$category]
        if ($list.Count -gt 0) {
          $candidateDisposition = 'REJECTED_INPUT'
          $candidateCode = $mismatchCode
          if ($category -ceq 'S4Surrogate') {
            $candidateDisposition = 'HELD_UNPROVED'
            $candidateCode = 'UNICODE_SURROGATE_FIDELITY_UNPROVED'
          }
          $candidateReasons = foreach ($finding in $list) { New-ProofReason -Stage 'Step5.CandidateAudit' -Code $candidateCode -Path $finding.Path -Kind $finding.Code }
          return New-ProofOutcome -Disposition $candidateDisposition -Reasons @($candidateReasons) -SettingsState $settingsState
        }
      }
      # BC3: any U+FFFD in the candidate that is not an exact decoded scalar of the original or delta.
      $allowedReplacements = Get-ProofReplacementCount -Raw $audit.Root
      foreach ($key in $managedKeys) { $allowedReplacements += Get-ProofReplacementCount -Raw ([string]$Delta.Values[$key]) }
      if ((Get-ProofReplacementCount -Raw $candidateAudit.Root) -gt $allowedReplacements) {
        return New-ProofOutcome -Disposition 'HELD_UNPROVED' -Reasons @(New-ProofReason -Stage 'Step5.CandidateAudit' -Code 'UNICODE_SURROGATE_FIDELITY_UNPROVED' -Path '' -Kind 'ReplacementCharacter') -SettingsState $settingsState
      }
      $candidateParse = ConvertFrom-ProofJson -Text $candidateText -Stage 'Step5.CandidateParse'
      if ($null -ne $candidateParse.Failure) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.CandidateParse' -Code $mismatchCode -Path '' -Kind $candidateParse.Failure.Code) -SettingsState $settingsState
      }
      $mismatch = Test-ProofRawCorrespondence -Raw $candidateAudit.Root -Parsed $candidateParse.Value
      if ($null -ne $mismatch) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.CandidateParse' -Code $mismatchCode -Path $mismatch -Kind 'Correspondence') -SettingsState $settingsState
      }
      $mismatch = Test-ProofGraphEqual -Left $expected -Right $candidateParse.Value
      if ($null -ne $mismatch) {
        return New-ProofOutcome -Disposition 'REJECTED_INPUT' -Reasons @(New-ProofReason -Stage 'Step5.UnmanagedComparison' -Code $mismatchCode -Path $mismatch -Kind 'Comparison') -SettingsState $settingsState
      }
      return New-ProofOutcome -Disposition 'VERIFIED' -Reasons @() -SettingsState $settingsState
    }
  }

  process {
    # Copy every input byte array before use (/preflightAndComparisonContract/mutableRecordDefense).
    $original = [byte[]]::new($OriginalBytes.Length)
    [System.Array]::Copy($OriginalBytes, $original, $OriginalBytes.Length)
    $isCompareSet = [string]::Equals($PSCmdlet.ParameterSetName, 'Compare', [System.StringComparison]::Ordinal)
    $candidate = $null
    $serializerDescriptor = $null
    $delta = $null
    if ($isCompareSet) {
      $candidate = [byte[]]::new($CandidateBytes.Length)
      [System.Array]::Copy($CandidateBytes, $candidate, $CandidateBytes.Length)
      $serializerDescriptor = Read-ProofProfileDescriptor -Descriptor $SerializerProfile
      $delta = Read-ProofManagedDelta -Delta $ManagedDelta
    }
    $inputDescriptor = Read-ProofProfileDescriptor -Descriptor $InputProfile

    $outcome = Invoke-ProofEvaluation -EvaluationMode $Mode -ParameterSetName $PSCmdlet.ParameterSetName -Original $original -Candidate $candidate -InputDescriptor $inputDescriptor -SerializerDescriptor $serializerDescriptor -Delta $delta

    $reportCandidate = $isCompareSet -and [string]::Equals($Mode, 'Compare', [System.StringComparison]::Ordinal)
    $candidateSHA256 = $null
    $candidateLength = $null
    $serializerProfileCopy = $null
    if ($reportCandidate) {
      $candidateSHA256 = Get-ProofSha256 -Bytes $candidate
      $candidateLength = [long]$candidate.Length
      $serializerProfileCopy = $serializerDescriptor.Copy
    }
    $sourcePins = @(
      [pscustomobject]@{ Name = 'Characterization'; Reference = $characterizationReference; SHA256 = $characterizationSHA256; Bytes = $null }
      [pscustomobject]@{ Name = 'ProfileSpecification'; Reference = $profileSpecificationReference; SHA256 = $profileSpecificationSHA256; Bytes = $profileSpecificationBytes }
      [pscustomobject]@{ Name = 'ProfileAdoptionRecord'; Reference = $adoptionRecordReference; SHA256 = $adoptionRecordSHA256; Bytes = $null }
      [pscustomobject]@{ Name = 'TransactionContract'; Reference = $contractReference; SHA256 = $contractSHA256; Bytes = $null }
    )

    $firstCode = 'none'
    if ($outcome.Reasons.Count -gt 0) { $firstCode = $outcome.Reasons[0].Code }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Mode $Mode; Disposition $($outcome.Disposition); Reasons $($outcome.Reasons.Count); first code $firstCode"

    [pscustomobject]@{
      PSTypeName            = $recordKind
      RecordKind            = $recordKind
      Mode                  = $Mode
      ProfileId             = $profileId
      InputProfile          = $inputDescriptor.Copy
      SerializerProfile     = $serializerProfileCopy
      OriginalSHA256        = Get-ProofSha256 -Bytes $original
      OriginalLength        = [long]$original.Length
      CandidateSHA256       = $candidateSHA256
      CandidateLength       = $candidateLength
      ManagedKeys           = [string[]]@($managedKeys)
      OriginalSettingsState = $outcome.SettingsState
      Disposition           = $outcome.Disposition
      CoverageComplete      = [string]::Equals($outcome.Disposition, 'VERIFIED', [System.StringComparison]::Ordinal)
      Reasons               = [object[]]$outcome.Reasons
      SourcePins            = $sourcePins
      EvidenceReferences    = [object[]]@()
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
