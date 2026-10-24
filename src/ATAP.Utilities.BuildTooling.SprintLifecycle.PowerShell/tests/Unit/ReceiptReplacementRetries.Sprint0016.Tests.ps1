BeforeAll {
  $moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $source = Join-Path $moduleRoot 'public/Remove-SprintWorktreeSafely.ps1'
  $tokens = $null; $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw 'Receipt writer source does not parse.' }
  $writers = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left.Extent.Text -eq '$writeJson'
  }, $true))
  if ($writers.Count -ne 1) { throw 'Expected one production receipt writer.' }
  $script:writer = [scriptblock]::Create($writers[0].Right.Expression.ScriptBlock.Extent.Text.TrimStart('{').TrimEnd('}'))
  $script:evidenceRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $moduleRoot '../..'))) ('_generated/Sprint0016/Task16.12Continuation/receipt-tests-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:evidenceRoot -Force | Out-Null
}
Describe 'Atomic worktree receipt replacement retries' -Tag 'Unit' {
  BeforeEach {
    $script:receiptFull = Join-Path $script:evidenceRoot ([guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($script:receiptFull, '{"Before":true}')
    $script:state = @{ After = 'verified'; Generation = 2 }
    $script:fn = 'Remove-SprintWorktreeSafely'
    $script:mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    $script:heldReceipt = $null
    Mock Write-PSFMessage {}
  }
  AfterEach { if ($script:heldReceipt) { $script:heldReceipt.Dispose() } }
  It 'commits valid complete JSON and removes its temporary file' {
    & $script:writer
    (Get-Content $receiptFull -Raw | ConvertFrom-Json).After | Should -Be 'verified'
    Get-ChildItem $script:evidenceRoot -Filter '*.tmp' | Should -BeNullOrEmpty
  }
  It 'retries only receipt replacement after a read handle releases delete sharing' {
    $script:heldReceipt = [IO.File]::Open($receiptFull, 'Open', 'Read', 'ReadWrite')
    Mock Start-Sleep {
      if ($script:heldReceipt) { $script:heldReceipt.Dispose() }
      $script:heldReceipt = $null
      [Threading.Thread]::Sleep($Milliseconds)
    }
    & $script:writer
    Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 50 }
    (Get-Content $receiptFull -Raw | ConvertFrom-Json).Generation | Should -Be 2
  }
  It 'bounds persistent denial and preserves the previous receipt bytes' {
    $before = (Get-FileHash $receiptFull).Hash
    $script:heldReceipt = [IO.File]::Open($receiptFull, 'Open', 'Read', 'ReadWrite')
    Mock Start-Sleep {}
    { & $script:writer } | Should -Throw '*denied*'
    Should -Invoke Start-Sleep -Times 5 -Exactly
    (Get-FileHash $receiptFull).Hash | Should -Be $before
    Get-ChildItem $script:evidenceRoot -Filter '*.tmp' | Should -BeNullOrEmpty
  }
  It 'does not retry invalid receipt serialization before atomic replacement' {
    $before = (Get-FileHash $receiptFull).Hash
    $script:state = @{ Value = [double]::NaN }
    Mock ConvertTo-Json { throw 'Injected serialization failure' }
    Mock Start-Sleep { throw 'No rename retry is allowed' }
    { & $script:writer } | Should -Throw '*Injected serialization failure*'
    Should -Invoke Start-Sleep -Times 0 -Exactly
    (Get-FileHash $receiptFull).Hash | Should -Be $before
  }
}