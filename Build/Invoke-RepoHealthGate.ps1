<#
.SYNOPSIS
Runs repository-wide health gates outside individual package flows.

.DESCRIPTION
Resolves one canonical ATAP.Utilities artifacts context from caller-supplied or process
values, exposes it to every child RepoHealth test, and retains NUnit evidence under
_generated per SC-0033. The gate performs no restore, build, pack, or publication.

.PARAMETER RepoRoot
Repository root.

.PARAMETER OutputPath
NUnit XML result path under _generated.

.PARAMETER ArtifactsRoot
Non-secret host-local artifacts root outside Dropbox.

.PARAMETER ArtifactsWorktreeId
Canonical worktree identifier.

.PARAMETER ArtifactsExecutionId
Caller-supplied execution identifier.

.PARAMETER ArtifactsPath
Canonical path. When omitted, derived from the other three values.

.PARAMETER PesterOutput
Pester output verbosity.

.EXAMPLE
pwsh -File Build\Invoke-RepoHealthGate.ps1 -ArtifactsRoot D:\ATAPArtifacts -ArtifactsWorktreeId wt-a -ArtifactsExecutionId repohealth-42
#>
#Requires -Version 7.0
#Requires -Module Pester
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateNotNullOrEmpty()][string]$RepoRoot=(Resolve-Path(Join-Path $PSScriptRoot '..')).Path,
  [AllowEmptyString()][string]$OutputPath='',
  [string]$ArtifactsRoot=$env:ATAP_ARTIFACTS_ROOT,
  [string]$ArtifactsWorktreeId=$env:ATAP_ARTIFACTS_WORKTREE_ID,
  [string]$ArtifactsExecutionId=$env:ATAP_ARTIFACTS_EXECUTION_ID,
  [string]$ArtifactsPath=$env:ATAP_ARTIFACTS_PATH,
  [ValidateSet('None','Normal','Detailed','Diagnostic')][string]$PesterOutput='Normal'
)
function Invoke-RepoHealthGate {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RepoRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsRoot,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsWorktreeId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactsExecutionId,
    [AllowEmptyString()][string]$ArtifactsPath='',
    [ValidateSet('None','Normal','Detailed','Diagnostic')][string]$PesterOutput='Normal'
  )
  begin {
    $fn='Invoke-RepoHealthGate';$mn='ATAP.Utilities.RepoHealth'
    if(-not(Get-Command -Name Write-PSFMessage -CommandType Function,Cmdlet -ErrorAction SilentlyContinue)){
      function Write-PSFMessage{param([string]$FunctionName,[string]$ModuleName,[string]$Level,[string]$Message,[string[]]$Tag);if($Level-in@('Important','Warning','Error')){[Console]::Out.WriteLine("$Level [$FunctionName] $Message")}}
    }
    $resolvedRepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path;$testPath=Join-Path $resolvedRepoRoot 'tests\RepoHealth'
    if(-not(Test-Path -LiteralPath $testPath -PathType Container)){throw "Repo health test path not found: $testPath"}
    $resolvedArtifactsRoot=[IO.Path]::GetFullPath($ArtifactsRoot)
    $expectedArtifactsPath=[IO.Path]::GetFullPath((Join-Path $resolvedArtifactsRoot 'dotnet' 'ATAP.Utilities' $ArtifactsWorktreeId $ArtifactsExecutionId))
    $resolvedArtifactsPath=if([string]::IsNullOrWhiteSpace($ArtifactsPath)){$expectedArtifactsPath}else{[IO.Path]::GetFullPath($ArtifactsPath)}
    if($resolvedArtifactsPath-cne$expectedArtifactsPath-or$resolvedArtifactsPath-match'(?i)[\\/]Dropbox[\\/]' -or $resolvedArtifactsPath.StartsWith($resolvedRepoRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "ArtifactsPath '$resolvedArtifactsPath' violates the canonical external path contract '$expectedArtifactsPath'."}
    $artifactsOwner="ATAP.Utilities|$ArtifactsWorktreeId|$ArtifactsExecutionId"
  }
  process {
    if(-not$PSCmdlet.ShouldProcess($testPath,'Invoke repo health Pester gate')){return $null}
    $outputDirectory=Split-Path -Path $OutputPath -Parent;if($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)){[IO.Directory]::CreateDirectory($outputDirectory)|Out-Null}
    $names=@('ATAP_ARTIFACTS_ROOT','ATAP_ARTIFACTS_WORKTREE_ID','ATAP_ARTIFACTS_EXECUTION_ID','ATAP_ARTIFACTS_PATH','ATAP_ARTIFACTS_OWNER')
    $previous=@{};foreach($name in $names){$previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
    try{
      $env:ATAP_ARTIFACTS_ROOT=$resolvedArtifactsRoot;$env:ATAP_ARTIFACTS_WORKTREE_ID=$ArtifactsWorktreeId;$env:ATAP_ARTIFACTS_EXECUTION_ID=$ArtifactsExecutionId;$env:ATAP_ARTIFACTS_PATH=$resolvedArtifactsPath;$env:ATAP_ARTIFACTS_OWNER=$artifactsOwner
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "RepoHealth gate starting with ArtifactsPath '$resolvedArtifactsPath'."
      $configuration=[PesterConfiguration]::Default;$configuration.Run.Path=@($testPath);$configuration.Run.PassThru=$true;$configuration.Run.Exit=$false;$configuration.Run.Throw=$false;$configuration.Filter.Tag=@('RepoHealth');$configuration.Output.Verbosity=$PesterOutput;$configuration.TestResult.Enabled=$true;$configuration.TestResult.OutputFormat='NUnitXml';$configuration.TestResult.OutputPath=$OutputPath
      $result=Invoke-Pester -Configuration $configuration;$failedContainers=if($result.PSObject.Properties.Name-contains'FailedContainersCount'){[int]$result.FailedContainersCount}else{@($result.FailedContainers).Count}
      if($result.Result-ne'Passed'-or$result.FailedCount-gt0-or$failedContainers-gt0){throw "RepoHealth gate failed: Result=$($result.Result), failing tests=$($result.FailedCount), failed containers=$failedContainers. See '$OutputPath'."}
      $result
    }finally{
      foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$previous[$name],'Process')}
    }
  }
  end{}
}
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path $RepoRoot '_generated\repo-health\RepoHealth.TestResults.xml'}
if($MyInvocation.InvocationName-ne'.' -and $MyInvocation.InvocationName-ne'&'){
  Invoke-RepoHealthGate -RepoRoot $RepoRoot -OutputPath $OutputPath -ArtifactsRoot $ArtifactsRoot -ArtifactsWorktreeId $ArtifactsWorktreeId -ArtifactsExecutionId $ArtifactsExecutionId -ArtifactsPath $ArtifactsPath -PesterOutput $PesterOutput
}