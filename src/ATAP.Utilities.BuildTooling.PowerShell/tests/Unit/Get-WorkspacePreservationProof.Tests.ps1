# tests/Unit/Get-WorkspacePreservationProof.Tests.ps1
#
# Unit tests for the private helper Get-WorkspacePreservationProof (Task 17.66.c, G3-C4 unit 1).
#
# Written against the frozen interface in
#   G3-C4-Workspace-Support-Profile-Proposal-Rev03-20261027.json
#   /integrationPlan/units/0/frozenScope (requiredTestVectors, function) plus
#   the adoption record 8EFE230C (OB1 vector); NOT against the helper's code.
#
# Test boundary: every input is an in-memory byte[] defined in this file; the only
# dot-sourced file is ../../private/Get-WorkspacePreservationProof.ps1; there is no
# module import and no filesystem access to live or temp workspace files.
#
# Vector tags used in the It names:
#   [V1] the 32 corpus inputs        [V2] HELD lenient forms (and eligible trivia)
#   [V3] lone lookalikes             [V4] unpaired surrogates
#   [V5] numeric v1                  [V6] profile descriptor
#   [V7] resource caps               [V8] raw empty member name
#   [OB1] lenient document with non-object settings
#   [IF] interface / record shape / Compare behaviour (not a numbered vector)
#
# Where the frozen spec does not fix a reason Code, the test asserts Disposition only
# (marked "Disposition only" in the It name). Stage values are not fixed by the spec and
# are never asserted.

#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeDiscovery {
  $mk = '"atap.sharedVSCode.templateRef":"sprint","atap.sharedVSCode.profile":"default"'
  # Standard frame whose payload member is the thing under test.
  $frame = { param($payload) '{"folders":[],"settings":{},"payload":' + $payload + '}' }
  $std = { param($payload) '{"folders":[],"settings":{' + $mk + '},"payload":' + $payload + '}' }

  $nest = {
    param($n)
    $std.Invoke(('{"k":' * $n) + '"deep"' + ('}' * $n))[0]
  }

  # ---- [V1] the 32 corpus inputs (Corpus.proposed.json 98CDA257) with Rev03 caseClassification dispositions.
  # Enc: utf8 | utf8bom | utf16le | utf16be. {LF}/{CR}/{CRLF} are replaced when bytes are built; {HEX} marks invalid bytes.
  $ok = 'VERIFIED'
  $rej = 'REJECTED_INPUT'
  $held = 'HELD_UNPROVED'
  $numCode = 'UNMANAGED_NUMBER_NOT_EXACTLY_REPRESENTED'
  $corpus = @(
    @{ Id = 'C01'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = '{{LF}"folders":[],{LF}"settings":{' + $mk + '},{LF}"payload":"caf\u00e9 e\u0301 \ud83d\ude80"{LF}}{LF}' }
    @{ Id = 'C02'; Enc = 'utf8bom'; Disp = $ok;   Code = $null; Text = '{{CRLF}"folders":[],{CRLF}"settings":{' + $mk + '},{CRLF}"payload":1{CRLF}}{CRLF}' }
    @{ Id = 'C03'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('1')[0] }
    @{ Id = 'C04'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = '{{CR}"folders":[],"settings":{' + $mk + '},"payload":1{CR}}' }
    @{ Id = 'C05'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('1')[0] + '{LF}{LF}' }
    @{ Id = 'C06'; Enc = 'utf8';    Disp = $rej;  Code = 'ENCODING_INVALID_UTF8'; Hex = 'C328'; Text = '{"folders":[],"settings":{' + $mk + '},"payload":"{HEX}"}' }
    @{ Id = 'C07'; Enc = 'utf8';    Disp = $rej;  Code = 'ENCODING_INVALID_UTF8'; Hex = 'E282'; Text = '{"folders":[],"settings":{' + $mk + '},"payload":"{HEX}"}' }
    @{ Id = 'C08'; Enc = 'utf16le'; Disp = $rej;  Code = 'ENCODING_OUTSIDE_PROPOSED_PROFILE'; Text = $std.Invoke('1')[0] }
    @{ Id = 'C09'; Enc = 'utf16be'; Disp = $rej;  Code = 'ENCODING_OUTSIDE_PROPOSED_PROFILE'; Text = $std.Invoke('1')[0] }
    @{ Id = 'C10'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = '{"folders":[],"settings":{' + $mk + '},"payload":/*comment*/1 //line{LF}}' }
    @{ Id = 'C11'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('{"v":1,}')[0] }
    @{ Id = 'C12'; Enc = 'utf8';    Disp = $rej;  Code = 'DUPLICATE_DECODED_NAME'; Text = $std.Invoke('{"v":1,"v":2}')[0] }
    @{ Id = 'C13'; Enc = 'utf8';    Disp = $rej;  Code = 'DUPLICATE_DECODED_NAME'; Text = $std.Invoke('{"keep":1,"\u006beep":2}')[0] }
    @{ Id = 'C14'; Enc = 'utf8';    Disp = $rej;  Code = 'CASE_COLLIDING_NAME'; Text = $std.Invoke('{"Keep":1,"keep":2}')[0] }
    @{ Id = 'C15'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('{"a/b":true,"~x":null,"\u03bb":"ok"}')[0] }
    @{ Id = 'C16'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('[9007199254740993,9223372036854775808,1234567890123456789012345678901234567890]')[0] }
    @{ Id = 'C17'; Enc = 'utf8';    Disp = $rej;  Code = $numCode; Text = $std.Invoke('0.123456789012345678901234567890123456789')[0] }
    @{ Id = 'C18'; Enc = 'utf8';    Disp = $rej;  Code = $numCode; Text = $std.Invoke('[1e30,1e-30,-0.0]')[0] }
    @{ Id = 'C19'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $nest.Invoke(19)[0] }
    @{ Id = 'C20'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $nest.Invoke(20)[0] }
    @{ Id = 'C21'; Enc = 'utf8';    Disp = $rej;  Code = 'SERIALIZER_WARNING_OR_UNMANAGED_MISMATCH'; Text = $nest.Invoke(21)[0] }
    @{ Id = 'C22'; Enc = 'utf8';    Disp = $rej;  Code = 'SERIALIZER_WARNING_OR_UNMANAGED_MISMATCH'; Text = $nest.Invoke(22)[0] }
    @{ Id = 'C23'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('{"a":[null,true,false,"",{},[]]}')[0] }
    @{ Id = 'C24'; Enc = 'utf8';    Disp = $rej;  Code = 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT'; Text = '[{"settings":{}},{"settings":{}}]' }
    @{ Id = 'C25'; Enc = 'utf8';    Disp = $rej;  Code = 'SETTINGS_NOT_OBJECT'; Text = '{"folders":[],"settings":null,"payload":1}' }
    @{ Id = 'C26'; Enc = 'utf8';    Disp = $rej;  Code = 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT'; Text = 'null' }
    @{ Id = 'C27'; Enc = 'utf8';    Disp = $rej;  Code = 'PARSE_ERROR'; Text = '{"folders":[],"settings":{},"payload":' }
    @{ Id = 'C28'; Enc = 'utf8';    Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED'; Text = $std.Invoke('"\ud800"')[0] }
    @{ Id = 'C29'; Enc = 'utf8';    Disp = $rej;  Code = 'DUPLICATE_DECODED_NAME'; Text = $std.Invoke('{"outer":{"n":1,"n":2}}')[0] }
    @{ Id = 'C30'; Enc = 'utf8';    Disp = $ok;   Code = $null; Text = $std.Invoke('[1.25,-2.5,1000.00]')[0] }
    @{ Id = 'C31'; Enc = 'utf8';    Disp = $rej;  Code = 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT'; Text = " `t{CR}{LF} " }
    @{ Id = 'C32'; Enc = 'utf8';    Disp = $rej;  Code = 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT'; Text = '"synthetic scalar"' }
  )

  # ---- [V2] enumerated HELD lenient forms (Disposition only: the spec fixes HELD_UNPROVED but no Code).
  $lenient = @(
    @{ Form = 'trailing comma before ]';            Text = $frame.Invoke('[1,]')[0] }
    @{ Form = 'consecutive commas in array';        Text = $frame.Invoke('[1,,2]')[0] }
    @{ Form = 'consecutive commas in object';       Text = $frame.Invoke('{"a":1,,}')[0] }
    @{ Form = 'leading comma in array';             Text = $frame.Invoke('[,1]')[0] }
    @{ Form = 'single-quoted string';               Text = $frame.Invoke('''x''')[0] }
    @{ Form = 'unquoted member name';               Text = $frame.Invoke('{a:1}')[0] }
    @{ Form = 'NaN';                                Text = $frame.Invoke('NaN')[0] }
    @{ Form = 'Infinity';                           Text = $frame.Invoke('Infinity')[0] }
    @{ Form = '-Infinity';                          Text = $frame.Invoke('-Infinity')[0] }
    @{ Form = 'undefined';                          Text = $frame.Invoke('undefined')[0] }
    @{ Form = 'hexadecimal number';                 Text = $frame.Invoke('0x10')[0] }
    @{ Form = 'octal number 0o';                    Text = $frame.Invoke('0o10')[0] }
    @{ Form = 'leading-zero number';                Text = $frame.Invoke('010')[0] }
    @{ Form = 'leading plus number';                Text = $frame.Invoke('+1')[0] }
    @{ Form = 'number .5';                          Text = $frame.Invoke('.5')[0] }
    @{ Form = 'number 5.';                          Text = $frame.Invoke('5.')[0] }
    @{ Form = 'constructor form new Date()';       Text = $frame.Invoke('new Date(0)')[0] }
    @{ Form = 'nested block comment';               Text = '{"folders":[],"settings":{},/* a /* b */ c */"payload":1}' }
    @{ Form = 'orphan */ inside root object';       Text = '{"folders":[],"settings":{},"payload":1 */}' }
    @{ Form = 'orphan */ after root value';         Text = $frame.Invoke('1')[0] + ' */' }
    @{ Form = 'unterminated comment after root';    Text = $frame.Invoke('1')[0] + ' /* never closed' }
    @{ Form = 'unescaped TAB inside string';        Text = $frame.Invoke('"a{TAB}b"')[0] }
    @{ Form = 'unescaped LF inside string';         Text = $frame.Invoke('"a{LF}b"')[0] }
    @{ Form = 'second root value after root';       Text = $frame.Invoke('1')[0] + '{}' }
    @{ Form = 'stray token after root value';       Text = $frame.Invoke('1')[0] + ' x' }
    @{ Form = 'comma after root value';             Text = $frame.Invoke('1')[0] + ',' }
  )

  # ---- [V2] eligible trivia T1-T3 and comment-like text inside strings (positive controls).
  $trivia = @(
    @{ Form = 'T1 line comment ended by LF';       Text = '{"folders":[],"settings":{},"payload":1 //c{LF}}' }
    @{ Form = 'T1 line comment ended by CR';       Text = '{"folders":[],"settings":{},"payload":1 //c{CR}}' }
    @{ Form = 'T2 block comment';                  Text = '{"folders":[],"settings":{},"payload":/*c*/1}' }
    @{ Form = 'T3 trailing comma before }';        Text = $frame.Invoke('{"a":1,}')[0] }
    @{ Form = 'T3 comma, comments, whitespace';    Text = $frame.Invoke('{"a":1, /*c*/ //d{LF} }')[0] }
    @{ Form = 'comment-like text inside a string'; Text = $frame.Invoke('"http://x /*y*/"')[0] }
  )

  # ---- [V3] lookalikes. Code is fixed only for the lone forms; with an exact sibling see open item AD2.
  $lookalike = @(
    @{ Form = 'root "Settings" without "settings"';                  Text = '{"folders":[],"Settings":{},"payload":1}';                                   Sibling = $false }
    @{ Form = 'root "SETTINGS" without "settings"';                  Text = '{"folders":[],"SETTINGS":{},"payload":1}';                                   Sibling = $false }
    @{ Form = 'settings "ATAP.sharedVSCode.profile" without exact';  Text = '{"folders":[],"settings":{"ATAP.sharedVSCode.profile":"x"},"payload":1}';     Sibling = $false }
    @{ Form = 'settings "atap.sharedvscode.templateref" without exact'; Text = '{"folders":[],"settings":{"atap.sharedvscode.templateref":"x"},"payload":1}'; Sibling = $false }
    @{ Form = 'root "Settings" with exact "settings" sibling';       Text = '{"folders":[],"settings":{},"Settings":{},"payload":1}';                     Sibling = $true }
    @{ Form = 'settings "ATAP.sharedVSCode.profile" with exact sibling'; Text = '{"folders":[],"settings":{"atap.sharedVSCode.profile":"default","ATAP.sharedVSCode.profile":"x"},"payload":1}'; Sibling = $true }
    @{ Form = 'settings "Atap.sharedVSCode.templateRef" with exact sibling'; Text = '{"folders":[],"settings":{"atap.sharedVSCode.templateRef":"sprint","Atap.sharedVSCode.templateRef":"x"},"payload":1}'; Sibling = $true }
  )

  # ---- [V4] surrogates.
  $surrogate = @(
    @{ Form = 'lone high surrogate';     Payload = '"\ud800"';          Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED' }
    @{ Form = 'lone high at string end'; Payload = '"abc\udbff"';       Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED' }
    @{ Form = 'lone low surrogate';      Payload = '"\udc00"';          Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED' }
    @{ Form = 'reversed pair';           Payload = '"\udc00\ud800"';    Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED' }
    @{ Form = 'high followed by non-low'; Payload = '"\ud800\u0041"';   Disp = $held; Code = 'UNICODE_SURROGATE_FIDELITY_UNPROVED' }
    @{ Form = 'valid pair';              Payload = '"\ud83d\ude80"';    Disp = $ok;   Code = $null }
    @{ Form = 'valid pair in member name'; Payload = '{"\ud83d\ude80":1}'; Disp = $ok; Code = $null }
  )

  # ---- [V5] numeric v1.
  $numeric = @(
    @{ Lexeme = '0.1';   Disp = $rej; Code = $numCode }
    @{ Lexeme = '1.2';   Disp = $rej; Code = $numCode }
    @{ Lexeme = '1.25';  Disp = $ok;  Code = $null }
    @{ Lexeme = '1e2';   Disp = $ok;  Code = $null }
    @{ Lexeme = '1e30';  Disp = $rej; Code = $numCode }
    @{ Lexeme = '-0';    Disp = $rej; Code = $numCode }
    @{ Lexeme = '-0.0';  Disp = $ok;  Code = $null }
  )

  # ---- [V6] profile descriptor faults (helperRefusal: HELD_UNPROVED PROFILE_DESCRIPTOR_UNRECOGNIZED).
  $descriptor = @(
    @{ Fault = 'wrong ProfileId';                       Member = 'ProfileId';                Value = 'C4.Utf8LogicalPreservation.v2' }
    @{ Fault = 'ProfileId differs only by case';        Member = 'ProfileId';                Value = 'c4.utf8logicalpreservation.v1' }
    @{ Fault = 'ProfileId with .proposed suffix';       Member = 'ProfileId';                Value = 'C4.Utf8LogicalPreservation.v1.proposed' }
    @{ Fault = 'wrong CharacterizationSHA256';          Member = 'CharacterizationSHA256';   Value = '12E963092EED272BA2CC7D5D74F84BE97181E1552C368A0BAE849916D890C7B5' }
    @{ Fault = 'CharacterizationSHA256 empty';          Member = 'CharacterizationSHA256';   Value = '' }
    @{ Fault = 'wrong CharacterizationReference';       Member = 'CharacterizationReference'; Value = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/Other.json' }
    @{ Fault = 'CharacterizationReference .proposed suffix'; Member = 'CharacterizationReference'; Value = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Corrected-Measurement-Coordinator-Acceptance-20261026.json.proposed' }
    @{ Fault = 'CharacterizationReference with backslashes (no normalization)'; Member = 'CharacterizationReference'; Value = 'InformationForTheFuture\Sprint0017\SprintStartRemediation\G3-C4-Corrected-Measurement-Coordinator-Acceptance-20261026.json' }
  )

  # ---- [OB1] lenient documents whose settings value is not an object: step 2(d) precedes step 3, so REJECTED_INPUT.
  $ob1 = @(
    @{ Form = 'settings array with trailing comma before ]'; Text = '{"folders":[],"settings":[1,],"payload":1}' }
    @{ Form = 'settings string with block comment';          Text = '{"folders":[],"settings":/*c*/"x","payload":1}' }
    @{ Form = 'settings number with trailing comma in root'; Text = '{"folders":[],"settings":5,"payload":1,}' }
    @{ Form = 'settings null with line comment';             Text = '{"folders":[],"settings":null //c{LF},"payload":1}' }
    @{ Form = 'settings single-quoted string';              Text = '{"folders":[],"settings":''x'',"payload":1}' }
  )
}

BeforeAll {
  . (Join-Path $PSScriptRoot '..\..\private\Get-WorkspacePreservationProof.ps1')

  $script:FrozenProfileId = 'C4.Utf8LogicalPreservation.v1'
  $script:FrozenReference = 'InformationForTheFuture/Sprint0017/SprintStartRemediation/G3-C4-Corrected-Measurement-Coordinator-Acceptance-20261026.json'
  $script:FrozenSha = '12E963092EED272BA2CC7D5D74F84BE97181E1552C368A0BAE849916D890C7B4'
  $script:MkTemplate = 'atap.sharedVSCode.templateRef'
  $script:MkProfile = 'atap.sharedVSCode.profile'
  $script:StdMk = '"atap.sharedVSCode.templateRef":"sprint","atap.sharedVSCode.profile":"default"'

  function script:New-Descriptor {
    param([string] $Member, [string] $Value)
    $d = [ordered]@{
      ProfileId                = $script:FrozenProfileId
      CharacterizationReference = $script:FrozenReference
      CharacterizationSHA256   = $script:FrozenSha
    }
    if ($Member) { $d[$Member] = $Value }
    [pscustomobject] $d
  }

  function script:Expand-Text {
    param([string] $Text)
    $Text.Replace('{CRLF}', "`r`n").Replace('{LF}', "`n").Replace('{CR}', "`r").Replace('{TAB}', "`t")
  }

  function script:New-Bytes {
    param([string] $Text, [string] $Enc = 'utf8', [string] $Hex)
    $t = Expand-Text $Text
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    switch ($Enc) {
      # UTF8Encoding(false).GetPreamble() is empty, so the EF BB BF prefix is spelled out explicitly.
      'utf8bom' { return [byte[]] (([byte[]] (0xEF, 0xBB, 0xBF)) + $utf8.GetBytes($t)) }
      'utf16le' { $e = [System.Text.Encoding]::Unicode; return [byte[]] ($e.GetPreamble() + $e.GetBytes($t)) }
      'utf16be' { $e = [System.Text.Encoding]::BigEndianUnicode; return [byte[]] ($e.GetPreamble() + $e.GetBytes($t)) }
      default {
        if ($Hex) {
          $parts = $t.Split([string[]] @('{HEX}'), [System.StringSplitOptions]::None)
          $raw = [byte[]] (0..(($Hex.Length / 2) - 1) | ForEach-Object { [Convert]::ToByte($Hex.Substring(2 * $_, 2), 16) })
          return [byte[]] ($utf8.GetBytes($parts[0]) + $raw + $utf8.GetBytes($parts[1]))
        }
        return [byte[]] $utf8.GetBytes($t)
      }
    }
  }

  # Calls the helper in Input mode and insists on exactly one output record.
  function script:Invoke-InputProof {
    param([byte[]] $Bytes, $InputProfile = (New-Descriptor))
    $out = @(Get-WorkspacePreservationProof -Mode Input -OriginalBytes $Bytes -InputProfile $InputProfile)
    if ($out.Count -ne 1) { throw "Expected exactly one proof record, got $($out.Count)." }
    $out[0]
  }

  function script:Invoke-CompareProof {
    param([byte[]] $Original, [byte[]] $Candidate, $Delta, $SerializerProfile = (New-Descriptor))
    $out = @(Get-WorkspacePreservationProof -Mode Compare -OriginalBytes $Original -CandidateBytes $Candidate `
        -ManagedDelta $Delta -InputProfile (New-Descriptor) -SerializerProfile $SerializerProfile)
    if ($out.Count -ne 1) { throw "Expected exactly one proof record, got $($out.Count)." }
    $out[0]
  }

  function script:New-ManagedDelta {
    param([string] $Template = 'sprint', [string] $ProfileName = 'default')
    [pscustomobject] @{ 'atap.sharedVSCode.templateRef' = $Template; 'atap.sharedVSCode.profile' = $ProfileName }
  }

  # Candidate bytes: strict UTF-8 without BOM, serializer text plus one Environment.NewLine (spec: candidateBytes).
  function script:New-CandidateBytes {
    param($Object)
    $text = ($Object | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    [byte[]] ([System.Text.UTF8Encoding]::new($false)).GetBytes($text)
  }

  function script:Get-StdText {
    param([string] $Payload)
    '{"folders":[],"settings":{' + $script:StdMk + '},"payload":' + $Payload + '}'
  }

  function script:Assert-Reject {
    param($Proof, [string] $Disposition, [string] $Code)
    $Proof.Disposition | Should -Be $Disposition
    if ($Code) { @($Proof.Reasons).Count | Should -BeGreaterThan 0; $Proof.Reasons[0].Code | Should -BeExactly $Code }
  }
}

Describe 'Get-WorkspacePreservationProof' {

  Context '[IF] interface and record shape' {

    It '[IF] declares exactly the Input and Compare parameter sets' {
      $names = (Get-Command Get-WorkspacePreservationProof).ParameterSets.Name | Sort-Object
      $names | Should -Be @('Compare', 'Input')
    }

    It '[IF] Input set: OriginalBytes, InputProfile and Mode are mandatory' {
      $set = (Get-Command Get-WorkspacePreservationProof).ParameterSets | Where-Object Name -EQ 'Input'
      foreach ($n in 'OriginalBytes', 'InputProfile', 'Mode') {
        ($set.Parameters | Where-Object Name -EQ $n).IsMandatory | Should -BeTrue -Because "$n is mandatory in the Input set"
      }
    }

    It '[IF] Compare set: OriginalBytes, CandidateBytes, ManagedDelta, InputProfile, SerializerProfile and Mode are mandatory' {
      $set = (Get-Command Get-WorkspacePreservationProof).ParameterSets | Where-Object Name -EQ 'Compare'
      foreach ($n in 'OriginalBytes', 'CandidateBytes', 'ManagedDelta', 'InputProfile', 'SerializerProfile', 'Mode') {
        ($set.Parameters | Where-Object Name -EQ $n).IsMandatory | Should -BeTrue -Because "$n is mandatory in the Compare set"
      }
    }

    It '[IF] Input mode returns exactly one C4.PreservationProof.v1 record with exactly the contract fields' {
      $bytes = New-Bytes (Get-StdText '1')
      $out = @(Get-WorkspacePreservationProof -Mode Input -OriginalBytes $bytes -InputProfile (New-Descriptor))
      $out.Count | Should -Be 1
      $expected = @('RecordKind', 'Mode', 'ProfileId', 'InputProfile', 'SerializerProfile', 'OriginalSHA256', 'OriginalLength',
        'CandidateSHA256', 'CandidateLength', 'ManagedKeys', 'OriginalSettingsState', 'Disposition', 'CoverageComplete',
        'Reasons', 'SourcePins', 'EvidenceReferences')
      ($out[0].PSObject.Properties.Name | Sort-Object) | Should -Be ($expected | Sort-Object)
      $out[0].RecordKind | Should -BeExactly 'C4.PreservationProof.v1'
    }

    It '[IF] Input record: Mode, ProfileId, hash, length, ManagedKeys and null candidate/serializer fields' {
      $bytes = New-Bytes (Get-StdText '1')
      $r = Invoke-InputProof $bytes
      $r.Mode | Should -BeExactly 'Input'
      $r.ProfileId | Should -BeExactly 'C4.Utf8LogicalPreservation.v1'
      $r.OriginalLength | Should -Be ([int64] $bytes.Length)
      $r.OriginalSHA256 | Should -Be ([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))) -Because 'hash compare is case-insensitive'
      $r.CandidateSHA256 | Should -BeNullOrEmpty
      $r.CandidateLength | Should -BeNullOrEmpty
      $r.SerializerProfile | Should -BeNullOrEmpty
      $r.InputProfile | Should -Not -BeNullOrEmpty
      @($r.ManagedKeys) | Should -Be @('atap.sharedVSCode.templateRef', 'atap.sharedVSCode.profile')
      $r.CoverageComplete | Should -BeOfType [bool]
      $r.CoverageComplete | Should -BeTrue
      $r.Disposition | Should -BeExactly 'VERIFIED'
      @($r.Reasons).Count | Should -Be 0
    }

    It '[IF] OriginalSettingsState is Object for an existing settings object, Absent when settings is missing' {
      (Invoke-InputProof (New-Bytes (Get-StdText '1'))).OriginalSettingsState | Should -BeExactly 'Object'
      (Invoke-InputProof (New-Bytes '{"folders":[],"payload":1}')).OriginalSettingsState | Should -BeExactly 'Absent'
      (Invoke-InputProof (New-Bytes '{"folders":[],"settings":{},"payload":1}')).OriginalSettingsState | Should -BeExactly 'Object'
    }

    It '[IF] a missing settings member is eligible (settings may be created as the named delta)' {
      (Invoke-InputProof (New-Bytes '{"folders":[],"payload":1}')).Disposition | Should -BeExactly 'VERIFIED'
    }

    It '[IF] settings:null is OriginalSettingsState Invalid (interpretation of the state enum)' {
      (Invoke-InputProof (New-Bytes '{"folders":[],"settings":null,"payload":1}')).OriginalSettingsState | Should -BeExactly 'Invalid'
    }

    It '[IF] Reasons are Stage/Code/Path/Kind metadata only and never carry raw values' {
      $text = '{"folders":[],"settings":{},"payload":{"v":"SENTINEL-RAW-VALUE-7731","v":2}}'
      $r = Invoke-InputProof (New-Bytes $text)
      $r.Disposition | Should -BeExactly 'REJECTED_INPUT'
      @($r.Reasons).Count | Should -BeGreaterThan 0
      foreach ($reason in @($r.Reasons)) {
        ($reason.PSObject.Properties.Name | Sort-Object) | Should -Be @('Code', 'Kind', 'Path', 'Stage')
      }
      ($r | ConvertTo-Json -Depth 10) | Should -Not -Match 'SENTINEL-RAW-VALUE-7731'
    }

    It '[IF] does not mutate the caller byte array and is deterministic across calls' {
      $bytes = New-Bytes (Get-StdText '[1,2,3]')
      $before = [byte[]] $bytes.Clone()
      $a = Invoke-InputProof $bytes
      $b = Invoke-InputProof $bytes
      [Convert]::ToHexString($bytes) | Should -BeExactly ([Convert]::ToHexString($before))
      ($a | ConvertTo-Json -Depth 10) | Should -BeExactly ($b | ConvertTo-Json -Depth 10)
    }

    It '[IF] a different byte array yields a different OriginalSHA256 (hash follows the bytes)' {
      $a = Invoke-InputProof (New-Bytes (Get-StdText '1'))
      $b = Invoke-InputProof (New-Bytes (Get-StdText '2'))
      $a.OriginalSHA256 | Should -Not -BeExactly $b.OriginalSHA256
    }
  }

  Context '[IF] Compare mode (in-memory candidates)' {

    BeforeAll {
      $script:origText = '{"folders":[],"settings":{"atap.sharedVSCode.templateRef":"old","atap.sharedVSCode.profile":"old"},"payload":1}'
      $script:orig = New-Bytes $script:origText
      function script:New-CandidateObject {
        param($Payload = 1, $Template = 'sprint', $ProfileName = 'default')
        [ordered]@{
          folders  = @()
          settings = [ordered]@{ 'atap.sharedVSCode.templateRef' = $Template; 'atap.sharedVSCode.profile' = $ProfileName }
          payload  = $Payload
        }
      }
    }

    It '[IF] Compare VERIFIED when only the two managed members differ' {
      $cand = New-CandidateBytes (New-CandidateObject)
      $r = Invoke-CompareProof $script:orig $cand (New-ManagedDelta)
      $r.Mode | Should -BeExactly 'Compare'
      $r.Disposition | Should -BeExactly 'VERIFIED'
      $r.CoverageComplete | Should -BeTrue
      @($r.Reasons).Count | Should -Be 0
      $r.CandidateLength | Should -Be ([int64] $cand.Length)
      $r.CandidateSHA256 | Should -Be ([Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($cand)))
      $r.OriginalLength | Should -Be ([int64] $script:orig.Length)
      $r.SerializerProfile | Should -Not -BeNullOrEmpty
      @($r.ManagedKeys) | Should -Be @('atap.sharedVSCode.templateRef', 'atap.sharedVSCode.profile')
    }

    It '[IF] Compare refuses an unmanaged change (payload differs) - Disposition only' {
      $cand = New-CandidateBytes (New-CandidateObject -Payload 2)
      (Invoke-CompareProof $script:orig $cand (New-ManagedDelta)).Disposition | Should -BeExactly 'REJECTED_INPUT'
    }

    It '[IF] Compare is not VERIFIED when the candidate does not carry the ManagedDelta values' {
      $cand = New-CandidateBytes (New-CandidateObject -Template 'other')
      (Invoke-CompareProof $script:orig $cand (New-ManagedDelta)).Disposition | Should -Not -BeExactly 'VERIFIED'
    }

    It '[IF] Compare with an unsupported original is REJECTED_INPUT with the original-side Code' {
      $cand = New-CandidateBytes (New-CandidateObject)
      $r = Invoke-CompareProof (New-Bytes 'null') $cand (New-ManagedDelta)
      Assert-Reject $r 'REJECTED_INPUT' 'ROOT_NOT_SINGLE_WORKSPACE_OBJECT'
    }

    It '[V6] Compare with an unrecognized SerializerProfile is HELD_UNPROVED PROFILE_DESCRIPTOR_UNRECOGNIZED' {
      $cand = New-CandidateBytes (New-CandidateObject)
      $r = Invoke-CompareProof $script:orig $cand (New-ManagedDelta) (New-Descriptor 'ProfileId' 'C4.Utf8LogicalPreservation.v2')
      Assert-Reject $r 'HELD_UNPROVED' 'PROFILE_DESCRIPTOR_UNRECOGNIZED'
    }

    It '[V6] Compare with an unrecognized InputProfile is HELD_UNPROVED PROFILE_DESCRIPTOR_UNRECOGNIZED' {
      $cand = New-CandidateBytes (New-CandidateObject)
      $out = @(Get-WorkspacePreservationProof -Mode Compare -OriginalBytes $script:orig -CandidateBytes $cand `
          -ManagedDelta (New-ManagedDelta) -InputProfile (New-Descriptor 'CharacterizationSHA256' ('0' * 64)) `
          -SerializerProfile (New-Descriptor))
      $out.Count | Should -Be 1
      Assert-Reject $out[0] 'HELD_UNPROVED' 'PROFILE_DESCRIPTOR_UNRECOGNIZED'
    }
  }

  Context '[V1] corpus inputs (32, expected dispositions of /caseClassification/cases)' {

    It '[V1] corpus <Id> -> <Disp> <Code>' -ForEach $corpus {
      $bytes = New-Bytes -Text $Text -Enc $Enc -Hex $Hex
      $prefix = @{ utf8bom = @(0xEF, 0xBB, 0xBF); utf16le = @(0xFF, 0xFE); utf16be = @(0xFE, 0xFF) }[$Enc]
      if ($prefix) {
        # The real byte-order mark must be present on the in-memory input (F01a).
        @($bytes[0..($prefix.Count - 1)]) | Should -Be $prefix -Because "$Enc input must start with its real BOM bytes"
      }
      else {
        $bytes[0] | Should -Be ([byte][char] $Text[0]) -Because 'no BOM on the other inputs'
      }
      # Frozen raw escapes must stay escapes in the in-memory source (F01 b/c): ASCII view of the bytes.
      $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
      $escaped = @{ C01 = '\u00e9 e\u0301 \ud83d\ude80'; C13 = '"keep":1,"\u006beep":2'; C15 = '"\u03bb":"ok"' }[$Id]
      if ($escaped) { $ascii.Contains($escaped) | Should -BeTrue -Because "$Id keeps its raw JSON escape spelling" }
      $r = Invoke-InputProof $bytes
      if ($Code) {
        Assert-Reject $r $Disp $Code
      }
      else {
        $r.Disposition | Should -BeExactly $Disp
        @($r.Reasons).Count | Should -Be 0
        $r.CoverageComplete | Should -BeTrue
      }
    }
  }

  Context '[V2] enumerated lenient forms' {

    It '[V2] HELD lenient form: <Form> (Disposition only)' -ForEach $lenient {
      $r = Invoke-InputProof (New-Bytes $Text)
      $r.Disposition | Should -BeExactly 'HELD_UNPROVED'
      $r.CoverageComplete | Should -BeFalse
    }

    It '[V2] eligible trivia: <Form> is VERIFIED' -ForEach $trivia {
      $r = Invoke-InputProof (New-Bytes $Text)
      $r.Disposition | Should -BeExactly 'VERIFIED'
      @($r.Reasons).Count | Should -Be 0
    }
  }

  Context '[V3] lookalikes of protected names' {

    It '[V3] <Form> is REJECTED_INPUT (Code fixed only when no exact sibling; AD2 otherwise)' -ForEach $lookalike {
      $r = Invoke-InputProof (New-Bytes $Text)
      $r.Disposition | Should -BeExactly 'REJECTED_INPUT'
      @($r.Reasons).Count | Should -BeGreaterThan 0
      if ($Sibling) {
        # AD2 open: either or both codes may be present; the first must be one of the two.
        $r.Reasons[0].Code | Should -BeIn @('CASE_LOOKALIKE_OF_PROTECTED_NAME', 'CASE_COLLIDING_NAME')
        @($r.Reasons.Code) | Should -Contain 'CASE_LOOKALIKE_OF_PROTECTED_NAME' -Because 'the lookalike is a protected-name lookalike even with an exact sibling'
      }
      else {
        $r.Reasons[0].Code | Should -BeExactly 'CASE_LOOKALIKE_OF_PROTECTED_NAME'
      }
    }

    It '[V3] a name that differs from a protected name beyond case is an ordinary unmanaged name (VERIFIED)' {
      $t = '{"folders":[],"settings":{"atap.sharedVSCode.profile2":"x","atap.sharedVSCode":"y"},"settings2":{},"payload":1}'
      (Invoke-InputProof (New-Bytes $t)).Disposition | Should -BeExactly 'VERIFIED'
    }
  }

  Context '[V4] unpaired surrogates' {

    It '[V4] <Form> -> <Disp>' -ForEach $surrogate {
      $r = Invoke-InputProof (New-Bytes (Get-StdText $Payload))
      if ($Code) { Assert-Reject $r $Disp $Code } else { $r.Disposition | Should -BeExactly $Disp }
    }
  }

  Context '[V5] numeric v1 rule' {

    It '[V5] payload number <Lexeme> -> <Disp>' -ForEach $numeric {
      $r = Invoke-InputProof (New-Bytes (Get-StdText $Lexeme))
      if ($Code) { Assert-Reject $r $Disp $Code } else { $r.Disposition | Should -BeExactly $Disp }
    }

    It '[V5] -0.0 and 1e2 together stay eligible while 0.1 anywhere in the document rejects the whole input' {
      (Invoke-InputProof (New-Bytes (Get-StdText '[-0.0,1e2,1.25]'))).Disposition | Should -BeExactly 'VERIFIED'
      (Invoke-InputProof (New-Bytes (Get-StdText '[-0.0,1e2,0.1]'))).Disposition | Should -BeExactly 'REJECTED_INPUT'
    }

    It '[V5] a managed-key sibling cannot launder a refused number' {
      $t = '{"folders":[],"settings":{"atap.sharedVSCode.templateRef":"sprint"},"payload":{"n":1.2}}'
      Assert-Reject (Invoke-InputProof (New-Bytes $t)) 'REJECTED_INPUT' 'UNMANAGED_NUMBER_NOT_EXACTLY_REPRESENTED'
    }
  }

  Context '[V6] profile descriptor' {

    It '[V6] InputProfile <Fault> -> HELD_UNPROVED PROFILE_DESCRIPTOR_UNRECOGNIZED' -ForEach $descriptor {
      $r = Invoke-InputProof (New-Bytes (Get-StdText '1')) (New-Descriptor -Member $Member -Value $Value)
      Assert-Reject $r 'HELD_UNPROVED' 'PROFILE_DESCRIPTOR_UNRECOGNIZED'
    }

    It '[V6] the frozen descriptor is accepted' {
      (Invoke-InputProof (New-Bytes (Get-StdText '1')) (New-Descriptor)).Disposition | Should -BeExactly 'VERIFIED'
    }
  }

  Context '[V7] resource caps' {

    It '[V7] input of exactly 16777216 bytes is not limited (VERIFIED)' {
      $prefix = '{"folders":[],"settings":{},"payload":"'
      $suffix = '"}'
      $pad = 16777216 - $prefix.Length - $suffix.Length
      $bytes = [System.Text.Encoding]::ASCII.GetBytes($prefix + ('A' * $pad) + $suffix)
      $bytes.Length | Should -Be 16777216
      $r = Invoke-InputProof $bytes
      $r.Disposition | Should -BeExactly 'VERIFIED'
      @($r.Reasons).Count | Should -Be 0
    }

    It '[V7] input of 16777217 bytes is HELD_UNPROVED RESOURCE_LIMIT_EXCEEDED' {
      $prefix = '{"folders":[],"settings":{},"payload":"'
      $suffix = '"}'
      $pad = 16777217 - $prefix.Length - $suffix.Length
      $bytes = [System.Text.Encoding]::ASCII.GetBytes($prefix + ('A' * $pad) + $suffix)
      $bytes.Length | Should -Be 16777217
      Assert-Reject (Invoke-InputProof $bytes) 'HELD_UNPROVED' 'RESOURCE_LIMIT_EXCEEDED'
    }

    It '[V7] container depth 128 (root object counted as depth 1) is not RESOURCE_LIMIT_EXCEEDED' {
      # ASSUMPTION (Rev03 does not define the depth origin): root object = depth 1, so 127 nested arrays reach 128.
      $text = '{"folders":[],"settings":{},"payload":' + ('[' * 127) + (']' * 127) + '}'
      $r = Invoke-InputProof (New-Bytes $text)
      if (@($r.Reasons).Count -gt 0) { $r.Reasons[0].Code | Should -Not -BeExactly 'RESOURCE_LIMIT_EXCEEDED' }
    }

    It '[V7] container depth 129 is HELD_UNPROVED RESOURCE_LIMIT_EXCEEDED' {
      $text = '{"folders":[],"settings":{},"payload":' + ('[' * 128) + (']' * 128) + '}'
      Assert-Reject (Invoke-InputProof (New-Bytes $text)) 'HELD_UNPROVED' 'RESOURCE_LIMIT_EXCEEDED'
    }

    It '[V7] more than 1048576 lexical tokens is HELD_UNPROVED RESOURCE_LIMIT_EXCEEDED' {
      # 1048577 array elements exceed the cap under any reading of what counts as a token.
      $text = '{"folders":[],"settings":{},"payload":[' + ('1,' * 1048576) + '1]}'
      Assert-Reject (Invoke-InputProof (New-Bytes $text)) 'HELD_UNPROVED' 'RESOURCE_LIMIT_EXCEEDED'
    }

    It '[V7] exactly 1048576 lexical tokens (TR1: 2N+10 with N=524283) is not RESOURCE_LIMIT_EXCEEDED' {
      # Coordinator ruling TR1: whitespace/comments excluded; each punctuation, name and scalar token counts once.
      # {"p":[N scalars],"q":[]} = { "p" : [  N scalars  (N-1) commas  ]  ,  "q" : [ ]  }  = 2N + 10 tokens.
      $n = 524283
      $text = '{"p":[' + ('1,' * ($n - 1)) + '1],"q":[]}'
      (2 * $n + 10) | Should -Be 1048576
      $r = Invoke-InputProof (New-Bytes $text)
      $r.Disposition | Should -BeExactly 'VERIFIED'
      @($r.Reasons).Count | Should -Be 0
    }

    It '[V7] 1048577 lexical tokens (TR1: one scalar more) is HELD_UNPROVED RESOURCE_LIMIT_EXCEEDED' {
      $n = 524283
      $text = '{"p":[' + ('1,' * ($n - 1)) + '1],"q":[1]}'
      (2 * $n + 10 + 1) | Should -Be 1048577
      Assert-Reject (Invoke-InputProof (New-Bytes $text)) 'HELD_UNPROVED' 'RESOURCE_LIMIT_EXCEEDED'
    }
  }

  Context '[V8] raw empty member name' {

    It '[V8] payload object with a member named "" is HELD_UNPROVED (Disposition only)' {
      $r = Invoke-InputProof (New-Bytes '{"folders":[],"settings":{},"payload":{"":1}}')
      $r.Disposition | Should -BeExactly 'HELD_UNPROVED'
      $r.CoverageComplete | Should -BeFalse
    }

    It '[V8] empty member name at the root and inside settings is HELD_UNPROVED (Disposition only)' {
      (Invoke-InputProof (New-Bytes '{"":1,"folders":[],"settings":{},"payload":1}')).Disposition | Should -BeExactly 'HELD_UNPROVED'
      (Invoke-InputProof (New-Bytes '{"folders":[],"settings":{"":1},"payload":1}')).Disposition | Should -BeExactly 'HELD_UNPROVED'
    }
  }

  Context '[OB1] lenient document with non-object settings' {

    It '[OB1] <Form> -> REJECTED_INPUT (not HELD)' -ForEach $ob1 {
      $r = Invoke-InputProof (New-Bytes $Text)
      $r.Disposition | Should -BeExactly 'REJECTED_INPUT'
      @($r.Reasons).Count | Should -BeGreaterThan 0
      $r.Reasons[0].Code | Should -BeExactly 'SETTINGS_NOT_OBJECT'
    }
  }
}
