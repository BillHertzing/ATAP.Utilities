function Get-DatabaseLFSourceProof {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$SourcePath)
  BEGIN { $fn='Get-DatabaseLFSourceProof'; $mn='ATAP.Utilities.BuildTooling.BuildMaster' }
  PROCESS {
    $commit=(& git -C $SourcePath rev-parse HEAD | Select-Object -First 1)
    if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '\A[0-9a-f]{40}\z'){throw 'LF source commit unavailable.'}
    $paths=@('Database/Flyway/version.json','Database/Flyway/flyway.toml','Database/Flyway/package-content-allowlist.json','Database/Verify/AceCommander/Verify_Login_V00160_ExactCatalog.sql','src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Invoke-DatabasePackageBuildMasterStage.ps1','src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/DatabasePackageLFReleaseGate.ps1')
    $allow=Get-Content -LiteralPath (Join-Path $SourcePath $paths[2]) -Raw|ConvertFrom-Json
    if($allow.sourceVersion -cne '0.1.21' -or @($allow.files).Count -ne 31){throw 'LF payload boundary mismatch.'}
    foreach($entry in $allow.files){
      $relative='Database/Flyway/'+$entry.path
      if($relative.Contains('..') -or [IO.Path]::IsPathRooted($entry.path)){throw 'LF payload path invalid.'}
      if((Get-FileHash -LiteralPath (Join-Path $SourcePath $relative)).Hash -ine $entry.sha256){throw 'LF payload hash mismatch.'}
      $paths+=$relative
    }
    $paths=@($paths|Sort-Object -Unique)
    & git -C $SourcePath diff --quiet HEAD -- @paths
    if($LASTEXITCODE -ne 0){throw 'LF source has uncommitted release changes.'}
    foreach($path in $paths){
      $null=& git -C $SourcePath ls-files --error-unmatch -- $path 2>$null
      if($LASTEXITCODE -ne 0){throw 'LF source file is not committed.'}
    }
    $lines=@($paths|ForEach-Object{$_+'='+ (Get-FileHash -LiteralPath (Join-Path $SourcePath $_)).Hash})
    [pscustomobject]@{Commit=$commit;Fingerprint=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lines -join "`n")))}
  }
  END {}
}

function Write-DatabaseLFReceipt {
  [CmdletBinding(SupportsShouldProcess)]
  param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)]$Value)
  BEGIN { $fn='Write-DatabaseLFReceipt'; $mn='ATAP.Utilities.BuildTooling.BuildMaster' }
  PROCESS {
    if($PSCmdlet.ShouldProcess($Path,'Create once-only LF release receipt')){
      $bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 12).Replace("`r`n","`n").Replace("`r","`n"))
      $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
    }
  }
  END {}
}

function Enter-DatabaseLFReleaseGate {
  <#
  .SYNOPSIS
    Binds only the exceptional 0.1.21 release to a reviewed capture/resume phase.
  .DESCRIPTION
    Capture returns pending without rehearsal/apply. Resume requires exact captured
    bytes, approved passed evidence, and a new once-only tier attempt. Receipt hashes
    are admission inputs, not a claim that the operator approved them automatically.
  .NOTES
    No SQL, feed publication, or database repair runs in this helper.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Phase,[Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Stage,[Parameter(Mandatory)][string]$DatabasePackageId,
    [Parameter(Mandatory)][string]$BuildId,[Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$ContextDirectory,[Parameter(Mandatory)][string]$SqlInstance,
    [Parameter(Mandatory)][string]$ConnectionSecretName,
    [AllowEmptyString()][string]$ApprovalPath='', [AllowEmptyString()][string]$ApprovalSha256=''
  )
  BEGIN { $fn='Enter-DatabaseLFReleaseGate'; $mn='ATAP.Utilities.BuildTooling.BuildMaster' }
  PROCESS {
    if($Version -cne '0.1.21'){
      if($Phase -cne 'Normal'){throw 'LF phase is restricted to package 0.1.21.'}
      return $null
    }
    if($Phase -cnotin @('Capture','Resume') -or $DatabasePackageId -cne 'ATAPUtilities.Database' -or $BuildId -notmatch '\A[0-9]+\z' -or $BuildId -eq '21573'){throw 'Explicit new LF build capture/resume required.'}
    if($Phase -ceq 'Capture' -and $Stage -cne 'Experimental'){throw 'Capture is Experimental only.'}
    $instances=@{Experimental='Expwhertzing';Development='Devwhertzing';Integration='Integration';QA='QA';Production='Production'}
    $secrets=@{Experimental='dbConnectionString.ATAPUtilities.localhost.Exp.whertzing';Development='dbConnectionString.ATAPUtilities.localhost.Dev.whertzing';Integration='dbConnectionString.ATAPUtilities.localhost.Integration';QA='dbConnectionString.ATAPUtilities.localhost.QA';Production='dbConnectionString.ATAPUtilities.localhost.Production'}
    if(-not $instances.ContainsKey($Stage) -or -not [string]::Equals($SqlInstance,('UTAT022\'+$instances[$Stage]),[StringComparison]::OrdinalIgnoreCase) -or $ConnectionSecretName -cne $secrets[$Stage]){throw 'LF tier/UTAT022 target/secret mismatch.'}
    if($ApprovalSha256 -notmatch '\A[0-9A-Fa-f]{64}\z' -or -not (Test-Path -LiteralPath $ApprovalPath -PathType Leaf) -or (Get-FileHash -LiteralPath $ApprovalPath).Hash -ine $ApprovalSha256){throw 'LF phase approval hash mismatch.'}
    $approval=Get-Content -LiteralPath $ApprovalPath -Raw|ConvertFrom-Json
    $proof=Get-DatabaseLFSourceProof -SourcePath $SourcePath
    $expected=[ordered]@{SchemaVersion='1';Phase=$Phase;Version=$Version;Stage=$Stage;DatabasePackageId=$DatabasePackageId;BuildId=$BuildId;SourcePath=[IO.Path]::GetFullPath($SourcePath);SourceCommit=$proof.Commit;SourceFingerprint=$proof.Fingerprint;SqlInstance=$SqlInstance;ConnectionSecretName=$ConnectionSecretName;HostName='UTAT022';Catalog='ATAPUtilities'}
    foreach($key in $expected.Keys){if(-not [string]::Equals([string]$approval.$key,[string]$expected[$key],[StringComparison]::Ordinal)){throw ('LF approval binding mismatch: '+$key)}}
    if([string]::IsNullOrWhiteSpace($approval.OperatorApprovalId) -or [string]::IsNullOrWhiteSpace($approval.ReleaseId) -or $approval.ExecutionApproved -cne $true){throw 'LF explicit execution approval absent.'}
    $now=[DateTimeOffset]::UtcNow
    if($null -eq $approval.NotBeforeUtc -or $null -eq $approval.ExpiresUtc -or $now -lt [DateTimeOffset]$approval.NotBeforeUtc -or $now -ge [DateTimeOffset]$approval.ExpiresUtc){throw 'LF approval outside its window.'}
    $lock=$null
    try{
      $lock=[IO.File]::Open((Join-Path $ContextDirectory 'ATAPUtilities.Database.lf-release.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
      $capturePath=Join-Path $ContextDirectory 'ATAPUtilities.Database.lf-release.capture.json'
      $gate=[pscustomobject]@{Phase=$Phase;Approval=$approval;ApprovalSha256=$ApprovalSha256;Proof=$proof;SourcePath=$SourcePath;Lock=$lock;CapturePath=$capturePath;BuildId=$BuildId;Stage=$Stage;SqlInstance=$SqlInstance;Catalog='ATAPUtilities';Version=$Version;ContextDirectory=$ContextDirectory;Capture=$null}
      if($Phase -ceq 'Capture'){
        if(Test-Path -LiteralPath $capturePath){throw 'LF capture already completed; use approved resume.'}
        Write-DatabaseLFReceipt -Path (Join-Path $ContextDirectory 'ATAPUtilities.Database.lf-release.capture.started.json') -Value @{Status='CaptureStarted_NotStageSuccess';BuildId=$BuildId;ApprovalSha256=$ApprovalSha256;SourceCommit=$proof.Commit;SourceFingerprint=$proof.Fingerprint}
      }else{
        if(-not (Test-Path -LiteralPath $capturePath -PathType Leaf) -or $approval.CaptureSha256 -notmatch '\A[0-9a-fA-F]{64}\z' -or (Get-FileHash $capturePath).Hash -ine $approval.CaptureSha256){throw 'LF immutable capture receipt mismatch.'}
        $capture=Get-Content $capturePath -Raw|ConvertFrom-Json
        if($capture.Status -cne 'PendingReconciliation_NotStageSuccess' -or $capture.BuildId -cne $BuildId -or $capture.Version -cne $Version -or $capture.SourceCommit -cne $proof.Commit -or $capture.SourceFingerprint -cne $proof.Fingerprint -or $capture.ReleaseId -cne $approval.ReleaseId){throw 'LF capture identity/source drift.'}
        if((Get-Item -LiteralPath $capture.NupkgPath).Length -ne $capture.Length -or (Get-FileHash -LiteralPath $capture.NupkgPath).Hash -ine $capture.Sha256){throw 'LF captured package bytes drifted.'}
        foreach($kind in @('BeforeSample','Backup','CloneAcceptance','MaintenanceAcceptance')){
          $entry=$approval.$kind
          if($entry.Sha256 -notmatch '\A[0-9a-fA-F]{64}\z' -or -not (Test-Path -LiteralPath $entry.Path -PathType Leaf) -or (Get-FileHash $entry.Path).Hash -ine $entry.Sha256){throw ('LF evidence hash mismatch: '+$kind)}
          $e=Get-Content -LiteralPath $entry.Path -Raw|ConvertFrom-Json
          if($e.Status -cne 'Passed' -or $e.BuildId -cne $BuildId -or $e.PackageSha256 -ine $capture.Sha256 -or $e.Stage -cne $Stage -or $e.SqlInstance -cne $SqlInstance -or $e.Catalog -cne 'ATAPUtilities'){throw ('LF evidence binding mismatch: '+$kind)}
        }
        $gate.Capture=$capture
        Write-DatabaseLFReceipt -Path (Join-Path $ContextDirectory "ATAPUtilities.Database.lf-release.$($Stage.ToLowerInvariant()).resume.once.json") -Value @{Status='ResumeStarted_NotStageSuccess';BuildId=$BuildId;CaptureSha256=$approval.CaptureSha256;ApprovalSha256=$ApprovalSha256;SourceCommit=$proof.Commit}
      }
      return $gate
    }catch{if($lock){$lock.Dispose()};throw}
  }
  END {}
}

function Complete-DatabaseLFCapture {
  [CmdletBinding()]
  param([Parameter(Mandatory)]$Gate,[Parameter(Mandatory)][string]$NupkgPath)
  BEGIN { $fn='Complete-DatabaseLFCapture'; $mn='ATAP.Utilities.BuildTooling.BuildMaster' }
  PROCESS {
    if($Gate.Phase -cne 'Capture' -or [IO.Path]::GetFileName($NupkgPath) -cne 'ATAPUtilities.Database.0.1.21.nupkg'){throw 'LF capture package mismatch.'}
    $currentProof=Get-DatabaseLFSourceProof -SourcePath $Gate.SourcePath
    if($currentProof.Commit -cne $Gate.Proof.Commit -or $currentProof.Fingerprint -cne $Gate.Proof.Fingerprint){throw 'LF source changed while building.'}
    $receipt=[ordered]@{Status='PendingReconciliation_NotStageSuccess';BuildId=$Gate.BuildId;ReleaseId=$Gate.Approval.ReleaseId;Version=$Gate.Version;SourceCommit=$Gate.Proof.Commit;SourceFingerprint=$Gate.Proof.Fingerprint;ApprovalSha256=$Gate.ApprovalSha256;NupkgPath=[IO.Path]::GetFullPath($NupkgPath);Length=(Get-Item -LiteralPath $NupkgPath).Length;Sha256=(Get-FileHash -LiteralPath $NupkgPath).Hash;CapturedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-DatabaseLFReceipt -Path $Gate.CapturePath -Value $receipt
    [pscustomobject]$receipt
  }
  END {}
}
