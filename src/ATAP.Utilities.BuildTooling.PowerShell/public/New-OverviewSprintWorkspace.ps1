function New-OverviewSprintWorkspace {
  <#
  .SYNOPSIS
    Creates a sprint-specific Overview code-workspace file.
  .DESCRIPTION
    Clones the stable Overview.code-workspace file, rewrites folder entries to
    matching sprint worktree folders when present, updates powershell.cwd, and
    adds sprint-ephemeral metadata used by BuildMaster, SQL Server, and ProGet
    workflows. No secret-vault metadata is emitted — sprint start neither creates
    nor references secrets (SC-0172).
  .PARAMETER SprintNumber
    Sprint number to encode in the workspace file name and metadata.
  .PARAMETER GitRoot
    Root directory containing the repository stable and sprint worktrees.
  .PARAMETER SourceWorkspacePath
    Source Overview workspace file. Defaults to Overview.code-workspace under GitRoot.
  .PARAMETER OutputWorkspacePath
    Output sprint workspace file. Defaults to Overview.SprintNNNN.code-workspace under GitRoot.
  .PARAMETER DeveloperUsername
    Developer username used in sprint metadata and ephemeral SQL instance names.
  .PARAMETER BuildMasterBaseUrl
    Base URL for BuildMaster metadata.
  .PARAMETER ProGetBaseUrl
    Base URL for ProGet metadata.
  .OUTPUTS
    PSCustomObject describing the generated workspace file.
  .EXAMPLE
    New-OverviewSprintWorkspace -SprintNumber 7
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    Overview.code-workspace
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 9999)]
    [int]$SprintNumber,

    [ValidateNotNullOrEmpty()]
    [string]$GitRoot = "C:\Dropbox\$env:USERNAME\GitHub",

    [string]$SourceWorkspacePath,

    [string]$OutputWorkspacePath,

    [ValidateNotNullOrEmpty()]
    [string]$DeveloperUsername = $env:USERNAME,

    [ValidateNotNullOrEmpty()]
    [string]$BuildMasterBaseUrl = 'http://localhost:50017',

    [ValidateNotNullOrEmpty()]
    [string]$ProGetBaseUrl = 'http://localhost:50000'
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    function ConvertFrom-WorkspaceJsonContent {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Content
      )

      try {
        return $Content | ConvertFrom-Json -ErrorAction Stop
      } catch {
        # Strip whole-line `// ...` comments only (must be preceded by whitespace
        # or line start) plus trailing commas before `]` / `}`. Inline `//` inside
        # string values is left alone.
        $stripped = $Content -replace '(?m)^\s*//.*$', ''
        $stripped = $stripped -replace ',(\s*[\]}])', '$1'
        return $stripped | ConvertFrom-Json -ErrorAction Stop
      }
    }

    function Set-ObjectPropertyValue {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowNull()]
        [object]$Value
      )

      if ($InputObject.PSObject.Properties[$Name]) {
        $InputObject.$Name = $Value
      } else {
        Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
      }
    }

    function Resolve-SprintWorktreeFolderName {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SprintText,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryRoot
      )

      $searchPattern = "$RepositoryName-wt-*-Sprint-$SprintText-work-items"
      $worktree = Get-ChildItem -LiteralPath $RepositoryRoot -Directory -Filter $searchPattern -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 1

      if ($worktree) { return $worktree.Name }
      return $RepositoryName
    }
  }

  process {
    $sprintText = '{0:D4}' -f $SprintNumber

    if (-not $SourceWorkspacePath) {
      $preferredSourcePath = Join-Path -Path $GitRoot -ChildPath 'Overview.code-workspace'
      $legacySourcePath = Join-Path -Path $GitRoot -ChildPath 'OverView.code-workspace'
      if (Test-Path -LiteralPath $preferredSourcePath -PathType Leaf) {
        $SourceWorkspacePath = $preferredSourcePath
      } elseif (Test-Path -LiteralPath $legacySourcePath -PathType Leaf) {
        $SourceWorkspacePath = $legacySourcePath
      } else {
        throw "No Overview.code-workspace source file found under $GitRoot."
      }
    }

    if (-not $OutputWorkspacePath) {
      $OutputWorkspacePath = Join-Path -Path $GitRoot -ChildPath ('Overview.Sprint{0}.code-workspace' -f $sprintText)
    }

    if (-not (Test-Path -LiteralPath $SourceWorkspacePath -PathType Leaf)) {
      throw "Source workspace file not found: $SourceWorkspacePath"
    }

    $workspace = ConvertFrom-WorkspaceJsonContent -Content (Get-Content -LiteralPath $SourceWorkspacePath -Raw -ErrorAction Stop)
    $folderNames = @()
    $newFolders = @()

    foreach ($folder in @($workspace.folders)) {
      $folderPath = [string]$folder.path
      $repoName = Split-Path -Path ($folderPath -replace '/', '\') -Leaf
      if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = $folderPath }
      if ($repoName -match '^(?<Repo>.+)-wt-\d+-Sprint-\d{4}-work-items$') {
        $repoName = $Matches['Repo']
      }

      $sprintFolderName = Resolve-SprintWorktreeFolderName -RepositoryName $repoName -SprintText $sprintText -RepositoryRoot $GitRoot
      $folderNames += $sprintFolderName
      $newFolders += [PSCustomObject]@{ path = $sprintFolderName }
    }

    Set-ObjectPropertyValue -InputObject $workspace -Name 'folders' -Value $newFolders

    if (-not $workspace.PSObject.Properties['settings'] -or $null -eq $workspace.settings) {
      Set-ObjectPropertyValue -InputObject $workspace -Name 'settings' -Value ([PSCustomObject]@{})
    }

    $planningFolder = @($folderNames | Where-Object { $_ -like '_Planning-wt-*-Sprint-*-work-items' } | Select-Object -First 1)
    if ($planningFolder.Count -gt 0) {
      Set-ObjectPropertyValue -InputObject $workspace.settings -Name 'powershell.cwd' -Value $planningFolder[0]
    }

    # Sprint start neither creates nor references secret-vault items (SC-0172,
    # FSS-32), so the workspace manifest no longer carries a bitwarden
    # connection-string secret-name section. Connection-string secrets are
    # provisioned out of band.
    $sprintEphemeral = [PSCustomObject]@{
      sprintNumber      = $sprintText
      developerUsername = $DeveloperUsername
      buildMaster       = [PSCustomObject]@{
        baseUrl       = $BuildMasterBaseUrl
        variableNames = @('SprintNumber', 'UserName', 'SprintBranchName')
      }
      sqlInstances      = [PSCustomObject]@{
        stable    = @('Integration', 'QA', 'Production')
        ephemeral = @("Dev$DeveloperUsername", "Exp$DeveloperUsername")
        master    = @('Integration:master', 'QA:master', 'Production:master', "Dev$DeveloperUsername`:master", "Exp$DeveloperUsername`:master")
      }
      proget            = [PSCustomObject]@{
        baseUrl = $ProGetBaseUrl
        feeds   = $workspace.progetFeeds
      }
    }

    Set-ObjectPropertyValue -InputObject $workspace -Name 'sprintEphemeral' -Value $sprintEphemeral
    Set-ObjectPropertyValue -InputObject $workspace -Name 'generatedBy' -Value $fn
    Set-ObjectPropertyValue -InputObject $workspace -Name 'generatedAt' -Value (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')

    if ($PSCmdlet.ShouldProcess($OutputWorkspacePath, "Write Overview.Sprint$sprintText workspace")) {
      $outputJson = $workspace | ConvertTo-Json -Depth 30
      Set-Content -LiteralPath $OutputWorkspacePath -Value $outputJson -Encoding UTF8 -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Created $OutputWorkspacePath"
    }

    [PSCustomObject]@{
      OutputWorkspacePath = $OutputWorkspacePath
      SourceWorkspacePath = $SourceWorkspacePath
      SprintNumber        = $sprintText
      FolderCount         = @($newFolders).Count
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
