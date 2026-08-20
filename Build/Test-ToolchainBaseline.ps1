<# .SYNOPSIS Validates the pinned SDK toolchain without mutation.
.DESCRIPTION All dotnet probes use RepoRoot and asynchronously drain stdout/stderr.
No restore, build, workload, install, feed, publish, or other mutation is performed. #>
#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [string]$ExpectedRollForward = 'latestPatch',
  [bool]$ExpectedAllowPrerelease = $false,
  [string]$ProbeProject = '',
  [switch]$RequireContinuousIntegrationBuild,
  [switch]$PassThru
)
function Invoke-ToolchainProcess {
  [CmdletBinding()]
  param([string]$FilePath, [string[]]$ArgumentList, [string]$WorkingDirectory)
  $psi = [Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath; $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  foreach ($argument in $ArgumentList) { $psi.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new(); $process.StartInfo = $psi
  try {
    if (-not $process.Start()) { throw "Process '$FilePath' did not start." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    [pscustomobject]@{ ExitCode=$process.ExitCode; StdOut=$stdout.TrimEnd(); StdErr=$stderr.TrimEnd() }
  } finally { $process.Dispose() }}
function ConvertTo-SdkVersionInfo {
  [CmdletBinding()] param([string]$Version)
  $value = $Version.Trim()
  if ($value -notmatch '^(?<a>\d+)\.(?<b>\d+)\.(?<c>\d+)(?<pre>-[0-9A-Za-z.-]+)?$') { throw "Invalid SDK version '$Version'." }
  $third = [int]$Matches.c; $core = "$($Matches.a).$($Matches.b).$third"
  [pscustomobject]@{ Raw=$value; Core=$core; Major=[int]$Matches.a; Minor=[int]$Matches.b
    FeatureBand=[int][Math]::Floor($third/100); IsPrerelease=!!$Matches.pre; Comparable=[version]$core }
}
function Test-ToolchainBaseline {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$RepoRoot, [string]$ExpectedRollForward='latestPatch',
    [bool]$ExpectedAllowPrerelease=$false, [string]$ProbeProject='', [switch]$RequireContinuousIntegrationBuild)
  $failures=[Collections.Generic.List[object]]::new(); $facts=[ordered]@{}
  $fail={param($c,$m)$failures.Add([pscustomobject]@{Code=$c;Message=$m})}
  $finish={param($r)[pscustomobject]@{Success=($failures.Count-eq 0);RepoRoot=$r;Failures=@($failures);FailureCodes=@($failures.Code);Facts=$facts}}
  try { $root=(Resolve-Path -LiteralPath $RepoRoot -ErrorAction Stop).Path; if(-not(Test-Path -LiteralPath $root -PathType Container)){throw 'Not a directory.'} }
  catch { &$fail 'ATAPTOOLCHAIN015' $_.Exception.Message; return (&$finish $RepoRoot) }
  $run={param($arguments,$code)try{$p=Invoke-ToolchainProcess -FilePath 'dotnet' -ArgumentList $arguments -WorkingDirectory $root;if($p.ExitCode){throw "exit $($p.ExitCode): $($p.StdErr)"};$p}catch{&$fail $code $_.Exception.Message;$null}}
  $facts.RepoRoot=$root; $pin=$null; $globalPath=Join-Path $root 'global.json'
  if(-not(Test-Path -LiteralPath $globalPath -PathType Leaf)){&$fail 'ATAPTOOLCHAIN001' "Missing '$globalPath'."}
  else{try{$json=Get-Content -LiteralPath $globalPath -Raw|ConvertFrom-Json -ErrorAction Stop;if(-not$json.sdk.version){throw 'sdk.version absent.'}
      $pin=ConvertTo-SdkVersionInfo $json.sdk.version;$facts.PinnedVersion=$pin.Raw;$facts.RollForward=[string]$json.sdk.rollForward
      if($facts.RollForward-cne$ExpectedRollForward){&$fail 'ATAPTOOLCHAIN008' 'rollForward mismatch.'}
      $allow=$json.sdk.PSObject.Properties['allowPrerelease'];if($null-eq$allow){&$fail 'ATAPTOOLCHAIN009' 'allowPrerelease absent.'}
      else{$facts.AllowPrerelease=[bool]$allow.Value;if($facts.AllowPrerelease-ne$ExpectedAllowPrerelease){&$fail 'ATAPTOOLCHAIN009' 'allowPrerelease mismatch.'}}
    }catch{&$fail 'ATAPTOOLCHAIN002' $_.Exception.Message}}
  $installed=@();$p=&$run @('--list-sdks') 'ATAPTOOLCHAIN004'
  if($p){$installed=@($p.StdOut-split'\r?\n'|ForEach-Object{if($_-match'^(?<v>\S+)\s+\[(?<p>.+)\]$'){[pscustomobject]@{Version=$Matches.v;Path=$Matches.p}}})}
  $facts.InstalledSdks=@($installed.Version);if($pin-and$installed.Version-notcontains$pin.Raw){&$fail 'ATAPTOOLCHAIN003' 'Pinned SDK not installed.'}
  $selected=$null;$p=&$run @('--version') 'ATAPTOOLCHAIN004'
  if($p){try{$selected=ConvertTo-SdkVersionInfo (($p.StdOut-split'\r?\n'|Select-Object -Last 1).Trim());$facts.SelectedVersion=$selected.Raw}catch{&$fail 'ATAPTOOLCHAIN004' $_.Exception.Message}}
  if($selected){if($selected.IsPrerelease){&$fail 'ATAPTOOLCHAIN006' 'Selected SDK is prerelease.'}
    if($pin){if($selected.Comparable-lt$pin.Comparable){&$fail 'ATAPTOOLCHAIN005' 'Selected SDK is older.'}
      $inside=switch($ExpectedRollForward){'disable'{$selected.Core-eq$pin.Core;break}{$_-in'patch','latestPatch'}{$selected.Major-eq$pin.Major-and$selected.Minor-eq$pin.Minor-and$selected.FeatureBand-eq$pin.FeatureBand;break}{$_-in'feature','latestFeature'}{$selected.Major-eq$pin.Major-and$selected.Minor-eq$pin.Minor;break}{$_-in'minor','latestMinor'}{$selected.Major-eq$pin.Major;break}default{$true}}
      if(-not$inside){&$fail 'ATAPTOOLCHAIN007' 'Outside roll-forward window.'}}}
  $p=&$run @('msbuild','-version','-nologo') 'ATAPTOOLCHAIN010'
  if($p){$versionLine=$p.StdOut-split'\r?\n'|Where-Object{$_-match'^\d+\.\d+'}|Select-Object -Last 1
    if($versionLine){$facts.MSBuildVersion=$versionLine.Trim();$facts.MSBuildCommand='dotnet msbuild'}else{&$fail 'ATAPTOOLCHAIN010' 'No MSBuild version returned.'}}
  $p=&$run @('nuget','--version') 'ATAPTOOLCHAIN013'
  if($p){if($p.StdOut-match'(?<v>\d+\.\d+(?:\.\d+){1,2})'){$facts.NuGetCliVersion=$Matches.v}else{&$fail 'ATAPTOOLCHAIN013' 'No NuGet version.'}}
  if($ProbeProject){$candidate=if([IO.Path]::IsPathRooted($ProbeProject)){$ProbeProject}else{Join-Path $root $ProbeProject};if(Test-Path -LiteralPath $candidate -PathType Leaf){$project=(Resolve-Path -LiteralPath $candidate).Path}else{$project=$null;&$fail 'ATAPTOOLCHAIN014' 'Probe project missing.'}}
  else{$project=Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -Filter '*.csproj' -File -ErrorAction SilentlyContinue|Where-Object FullName -NotMatch '[\\/](bin|obj)[\\/]'|Sort-Object FullName|Select-Object -First 1 -ExpandProperty FullName;if(-not$project){&$fail 'ATAPTOOLCHAIN014' 'No probe project.'}}
  if($project){$facts.ProbeProject=$project;$propertyArguments=@('msbuild',$project,'-nologo','-getProperty:Deterministic','-getProperty:ContinuousIntegrationBuild');if($RequireContinuousIntegrationBuild){$propertyArguments+='-property:ContinuousIntegrationBuild=true'};$p=&$run $propertyArguments 'ATAPTOOLCHAIN014'
    if($p){try{$props=$p.StdOut|ConvertFrom-Json -ErrorAction Stop;$facts.Deterministic=([string]$props.Properties.Deterministic).Trim();$facts.ContinuousIntegrationBuild=([string]$props.Properties.ContinuousIntegrationBuild).Trim()
        if($facts.Deterministic-cne'true'){&$fail 'ATAPTOOLCHAIN011' 'Deterministic is not true.'};if($RequireContinuousIntegrationBuild-and$facts.ContinuousIntegrationBuild-cne'true'){&$fail 'ATAPTOOLCHAIN012' 'ContinuousIntegrationBuild is not true.'}
      }catch{&$fail 'ATAPTOOLCHAIN014' $_.Exception.Message}}}
  &$finish $root
}
if($MyInvocation.InvocationName-ne'.'-and$MyInvocation.InvocationName-ne'&'){
  $r=Test-ToolchainBaseline -RepoRoot $RepoRoot -ExpectedRollForward $ExpectedRollForward -ExpectedAllowPrerelease $ExpectedAllowPrerelease -ProbeProject $ProbeProject -RequireContinuousIntegrationBuild:$RequireContinuousIntegrationBuild
  if($PassThru){$r};if($r.Success){[Console]::Out.WriteLine('RESULT: PASS');exit 0}
  foreach($f in $r.Failures){[Console]::Error.WriteLine("$($f.Code): $($f.Message)")};[Console]::Error.WriteLine('RESULT: FAIL');exit 1
}
