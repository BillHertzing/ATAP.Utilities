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
    Output sprint workspace file. Defaults to Overview.Sprint.NNNN.code-workspace under GitRoot.
  .PARAMETER DeveloperUsername
    Developer username used in sprint metadata and ephemeral SQL instance names.
  .PARAMETER DeveloperAssignments
    Optional developer-to-host assignments. Each item must contain non-empty
    username and host properties. The composite (username, host) pair is the
    identity, so one username can be assigned to multiple hosts. When omitted,
    assignments are preserved from the existing output, the source workspace,
    or the latest earlier sprint workspace, in that order. If no configured
    assignments exist, the current developer and computer form one assignment.
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

    [object[]]$DeveloperAssignments,

    [ValidateNotNullOrEmpty()]
    [string]$BuildMasterBaseUrl = 'https://utat022:50017',

    [ValidateNotNullOrEmpty()]
    [string]$ProGetBaseUrl = 'https://utat022:50000'
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

    function ConvertTo-DeveloperAssignments {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Assignments
      )

      $normalizedAssignments = @()
      $assignmentKeys = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

      foreach ($assignment in $Assignments) {
        if ($null -eq $assignment) {
          throw 'Developer assignment cannot be null.'
        }

        $username = if ($assignment -is [System.Collections.IDictionary]) {
          [string]$assignment['username']
        } else {
          [string]$assignment.username
        }
        $hostName = if ($assignment -is [System.Collections.IDictionary]) {
          [string]$assignment['host']
        } else {
          [string]$assignment.host
        }

        $username = $username.Trim()
        $hostName = $hostName.Trim()
        if ([string]::IsNullOrWhiteSpace($username) -or [string]::IsNullOrWhiteSpace($hostName)) {
          throw 'Each developer assignment must contain non-empty username and host properties.'
        }

        $assignmentKey = '{0}@{1}' -f $username, $hostName
        if (-not $assignmentKeys.Add($assignmentKey)) {
          throw "Duplicate developer assignment '$assignmentKey'."
        }

        $normalizedAssignments += [PSCustomObject]@{
          username = $username
          host     = $hostName.ToLowerInvariant()
        }
      }

      return @($normalizedAssignments | Sort-Object `
          @{ Expression = { $_.username.ToLowerInvariant() } }, `
          @{ Expression = { $_.host.ToLowerInvariant() } })
    }

    function Get-WorkspaceDeveloperAssignments {
      [CmdletBinding()]
      param(
        [Parameter(Mandatory)]
        [object]$Workspace
      )

      if ($Workspace.PSObject.Properties['developers'] -and $null -ne $Workspace.developers) {
        return @($Workspace.developers)
      }

      return @()
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
      $OutputWorkspacePath = Join-Path -Path $GitRoot -ChildPath ('Overview.Sprint.{0}.code-workspace' -f $sprintText)
    }

    if (-not (Test-Path -LiteralPath $SourceWorkspacePath -PathType Leaf)) {
      throw "Source workspace file not found: $SourceWorkspacePath"
    }

    $workspace = ConvertFrom-WorkspaceJsonContent -Content (Get-Content -LiteralPath $SourceWorkspacePath -Raw -ErrorAction Stop)

    $configuredDeveloperAssignments = @()
    if ($PSBoundParameters.ContainsKey('DeveloperAssignments')) {
      $configuredDeveloperAssignments = @($DeveloperAssignments)
    } else {
      if (Test-Path -LiteralPath $OutputWorkspacePath -PathType Leaf) {
        $existingOutputWorkspace = ConvertFrom-WorkspaceJsonContent -Content (
          Get-Content -LiteralPath $OutputWorkspacePath -Raw -ErrorAction Stop)
        $configuredDeveloperAssignments = @(
          Get-WorkspaceDeveloperAssignments -Workspace $existingOutputWorkspace)
      }

      if ($configuredDeveloperAssignments.Count -eq 0) {
        $configuredDeveloperAssignments = @(Get-WorkspaceDeveloperAssignments -Workspace $workspace)
      }

      if ($configuredDeveloperAssignments.Count -eq 0) {
        $priorWorkspace = Get-ChildItem -LiteralPath $GitRoot -File `
          -Filter 'Overview.Sprint.*.code-workspace' -ErrorAction SilentlyContinue |
          Where-Object {
            $_.FullName -ne $OutputWorkspacePath -and
            $_.Name -match '^Overview\.Sprint\.(?<Sprint>\d{4})\.code-workspace$' -and
            [int]$Matches['Sprint'] -lt $SprintNumber
          } |
          Sort-Object Name -Descending |
          Select-Object -First 1

        if ($priorWorkspace) {
          $priorWorkspaceContent = ConvertFrom-WorkspaceJsonContent -Content (
            Get-Content -LiteralPath $priorWorkspace.FullName -Raw -ErrorAction Stop)
          $configuredDeveloperAssignments = @(
            Get-WorkspaceDeveloperAssignments -Workspace $priorWorkspaceContent)
        }
      }

      if ($configuredDeveloperAssignments.Count -eq 0) {
        $configuredDeveloperAssignments = @([PSCustomObject]@{
            username = $DeveloperUsername
            host     = $env:COMPUTERNAME
          })
      }
    }

    $normalizedDeveloperAssignments = @(
      ConvertTo-DeveloperAssignments -Assignments $configuredDeveloperAssignments)
    if ($normalizedDeveloperAssignments.Count -eq 0) {
      throw 'At least one developer assignment is required.'
    }

    Set-ObjectPropertyValue -InputObject $workspace -Name 'developers' -Value $normalizedDeveloperAssignments
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

    if ($PSCmdlet.ShouldProcess($OutputWorkspacePath, "Write Overview.Sprint.$sprintText workspace")) {
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
