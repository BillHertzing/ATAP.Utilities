function Remove-OverviewSprintWorkspace {
<#
.SYNOPSIS
Archives a sprint-specific Overview code-workspace file.

.DESCRIPTION
Moves OverviewSprintNNNN.code-workspace into the planning repository archive
folder used by SprintEndAgent:
_Planning/SprintRetrospective/WorkspaceArchive/.

The command refuses to overwrite a different archived workspace. If the archive
target already exists with identical content, the source file is removed and the
result reports that the workspace was already archived.

.PARAMETER SprintNumber
Sprint number used to resolve the default OverviewSprintNNNN.code-workspace
source file.

.PARAMETER GitRoot
Root directory containing stable repositories, sprint worktrees, and the
_Planning repository.

.PARAMETER SourceWorkspacePath
Source sprint workspace file. Defaults to OverviewSprintNNNN.code-workspace
under GitRoot, with legacy OverViewSprintNNNN.code-workspace fallback.

.PARAMETER ArchiveDirectoryPath
Destination archive directory. Defaults to
<GitRoot>/_Planning/SprintRetrospective/WorkspaceArchive.

.PARAMETER Force
Suppresses confirmation prompts for the archive operation.

.OUTPUTS
PSCustomObject describing the archive operation.

.EXAMPLE
Remove-OverviewSprintWorkspace -SprintNumber 7 -WhatIf

.EXAMPLE
Remove-OverviewSprintWorkspace -SprintNumber 7 -GitRoot 'D:\Repos' -Force

.NOTES
Called from SprintEndAgent. AI assisted using Powershell.instructions.md as
guidelines.

.LINK
New-OverviewSprintWorkspace
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$GitRoot = "C:\Dropbox\$env:USERNAME\GitHub",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceWorkspacePath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ArchiveDirectoryPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    function Write-RemoveOverviewMessage {
      param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Debug', 'Verbose', 'Important', 'Warning', 'Error')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
      )

      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $Level -Message $Message
      } elseif ($Level -in @('Verbose', 'Debug')) {
        Write-Verbose $Message
      } elseif ($Level -eq 'Warning') {
        Write-Warning $Message
      } elseif ($Level -eq 'Error') {
        Write-Error $Message
      }
    }

    function Test-SameFileContent {
      param(
        [Parameter(Mandatory = $true)]
        [string]$LeftPath,

        [Parameter(Mandatory = $true)]
        [string]$RightPath
      )

      $left = Get-FileHash -LiteralPath $LeftPath -Algorithm SHA256 -ErrorAction Stop
      $right = Get-FileHash -LiteralPath $RightPath -Algorithm SHA256 -ErrorAction Stop
      return $left.Hash -eq $right.Hash
    }
  }

  process {
    $sprintText = '{0:D4}' -f $SprintNumber

    if ($Force) {
      $ConfirmPreference = 'None'
    }

    if (-not (Test-Path -LiteralPath $GitRoot -PathType Container)) {
      throw "GitRoot '$GitRoot' does not exist or is not a directory."
    }

    if (-not $SourceWorkspacePath) {
      $preferredSourcePath = Join-Path -Path $GitRoot -ChildPath "OverviewSprint$sprintText.code-workspace"
      $legacySourcePath = Join-Path -Path $GitRoot -ChildPath "OverViewSprint$sprintText.code-workspace"

      if (Test-Path -LiteralPath $preferredSourcePath -PathType Leaf) {
        $SourceWorkspacePath = $preferredSourcePath
      } elseif (Test-Path -LiteralPath $legacySourcePath -PathType Leaf) {
        $SourceWorkspacePath = $legacySourcePath
      } else {
        $SourceWorkspacePath = $preferredSourcePath
      }
    }

    if (-not (Test-Path -LiteralPath $SourceWorkspacePath -PathType Leaf)) {
      throw "Overview sprint workspace '$SourceWorkspacePath' does not exist."
    }

    if (-not $ArchiveDirectoryPath) {
      $planningRoot = Join-Path -Path $GitRoot -ChildPath '_Planning'
      $ArchiveDirectoryPath = Join-Path -Path $planningRoot -ChildPath 'SprintRetrospective\WorkspaceArchive'
    }

    $archiveWorkspacePath = Join-Path -Path $ArchiveDirectoryPath -ChildPath (Split-Path -Path $SourceWorkspacePath -Leaf)
    $alreadyArchived = $false
    $wasArchived = $false
    $sourceRemoved = $false
    $message = ''

    if (Test-Path -LiteralPath $archiveWorkspacePath -PathType Leaf) {
      if (-not (Test-SameFileContent -LeftPath $SourceWorkspacePath -RightPath $archiveWorkspacePath)) {
        throw "Archive target '$archiveWorkspacePath' already exists and differs from source '$SourceWorkspacePath'."
      }

      $alreadyArchived = $true
      $action = "Remove duplicate source; archive already exists at '$archiveWorkspacePath'"
      if ($PSCmdlet.ShouldProcess($SourceWorkspacePath, $action)) {
        Remove-Item -LiteralPath $SourceWorkspacePath -Force -ErrorAction Stop
        $sourceRemoved = $true
        $message = 'Archive target already existed with identical content; removed duplicate source workspace.'
        Write-RemoveOverviewMessage -Level Important -Message $message
      } else {
        $message = 'WhatIf: archive target already exists with identical content; source workspace would be removed.'
      }
    } else {
      $action = "Archive to '$archiveWorkspacePath'"
      if ($PSCmdlet.ShouldProcess($SourceWorkspacePath, $action)) {
        if (-not (Test-Path -LiteralPath $ArchiveDirectoryPath -PathType Container)) {
          New-Item -ItemType Directory -Path $ArchiveDirectoryPath -Force -ErrorAction Stop | Out-Null
        }

        Move-Item -LiteralPath $SourceWorkspacePath -Destination $archiveWorkspacePath -ErrorAction Stop
        $wasArchived = $true
        $sourceRemoved = $true
        $message = "Archived sprint workspace to '$archiveWorkspacePath'."
        Write-RemoveOverviewMessage -Level Important -Message $message
      } else {
        $message = "WhatIf: source workspace would be archived to '$archiveWorkspacePath'."
      }
    }

    [PSCustomObject]@{
      SprintNumber         = $sprintText
      SourceWorkspacePath  = $SourceWorkspacePath
      ArchiveDirectoryPath = $ArchiveDirectoryPath
      ArchiveWorkspacePath = $archiveWorkspacePath
      WasArchived          = $wasArchived
      AlreadyArchived      = $alreadyArchived
      SourceRemoved        = $sourceRemoved
      WasChanged           = ($wasArchived -or $sourceRemoved)
      Message              = $message
    }
  }
}
