# Load contract: dot-source this file to define New-SprintStage1. No top-level
# code executes on load — all side effects occur only when the function is called.
function New-SprintStage1 {
  <#
  .SYNOPSIS
    Bootstraps Stage 1 of a new sprint: determines the sprint number, creates
    SharedVSCode and _Planning branches/workTrees, creates NTFS junctions, and
    applies SharedVSCode context to _Planning.
  .DESCRIPTION
    Performs, in order:
      1. Determines the next sprint number from the most recent retrospective
         document in _Planning/SprintRetrospective.
      2. Creates a GitHub issue, branch, and worktree for SharedVSCode.
      3. Creates a GitHub issue, branch, and worktree for _Planning.
      4. Creates NTFS junctions in the _Planning worktree pointing to the
         SharedVSCode sprint worktree.
      5. Applies SharedVSCode context (templateRef, hooksPath, commitTemplate)
         to the _Planning worktree.
      6. Creates a sprint NuGet.config in the SharedVSCode worktree referencing
          all five ProGet feeds (experimental, development, integration, qa, stable)
          plus nuget.org.
      7. Leaves the `_Planning` sprint worktree ready for Step 2 to create the
         sprint task artifact set: `TASKS.html`, `Tasks.Accomplished.html`,
         `Tasks.ProceduralDetails.html`, and the synchronized `TASKS.md`.

    If any step fails the function captures the error into the appropriate field
    of the return object and stops further processing for that repo while still
    returning a populated result.
  .PARAMETER GitRoot
    Root directory containing all Git repositories.
  .PARAMETER Owner
    GitHub owner / organisation name.
  .PARAMETER SprintNumber
    Explicit sprint number (four-digit zero-padded string, e.g. '0006').
    When omitted the function auto-detects from the latest retrospective.
  .PARAMETER JunctionFolderNames
    Folder names to junction from SharedVSCode into _Planning.
    Defaults to @('.claude', '.github', '.vscode').
  .PARAMETER DryRun
    Preview all sprint-start actions without creating GitHub issues, branches,
    worktrees, junctions, SharedVSCode context, or NuGet.config files.
  .OUTPUTS
    PSCustomObject — see the return structure in the code.
  .EXAMPLE
    $stage1 = New-SprintStage1
    $stage1 | ConvertTo-Json -Depth 4
  .EXAMPLE
    $stage1 = New-SprintStage1 -SprintNumber '0006'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    SprintStartAgent.md — Steps 1-3
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    [string]$GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [string]$Owner,

    [ValidatePattern('^\d{4}$')]
    [string]$SprintNumber,

    [string[]]$JunctionFolderNames = @('.claude', '.github', '.vscode'),

    [string]$ProGetBaseUrl = 'http://localhost:50000',

    [switch]$DryRun
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($DryRun) {
      $WhatIfPreference = $true
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message 'DryRun enabled — no external side effects will be performed.'
    }

    if ([string]::IsNullOrWhiteSpace($Owner)) {
      $overviewPath = Join-Path $GitRoot 'OverView.code-workspace'
      if (Test-Path -LiteralPath $overviewPath -PathType Leaf) {
        try {
          $workspace = Get-Content -LiteralPath $overviewPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
          $Owner = $workspace.githubOwner
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning `
            -Message "Could not read githubOwner from $overviewPath`: $($_.Exception.Message). Falling back to `$env:USERNAME."
        }
      }
      if ([string]::IsNullOrWhiteSpace($Owner)) {
        $Owner = $env:USERNAME
      }
    }

    # --- Ensure external dependencies are available ---
    if (-not $DryRun) {
      Assert-GitAvailable

      if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
        throw 'The GitHub CLI (gh) is required but was not found on PATH.'
      }
    }

    # Dot-source Set-WorktreeJunctions if not already loaded
    $setWtJunctionsPath = Join-Path $GitRoot 'ATAP.Utilities' 'src' `
      'ATAP.Utilities.BuildTooling.PowerShell' 'public' 'Set-WorktreeJunctions.ps1'
    if (-not (Get-Command -Name 'Set-WorktreeJunctions' -CommandType Function -ErrorAction SilentlyContinue)) {
      if ($DryRun) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'DryRun: skipping Set-WorktreeJunctions dependency load.'
      } elseif (Test-Path $setWtJunctionsPath) {
        . $setWtJunctionsPath
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Set-WorktreeJunctions.ps1 not found at $setWtJunctionsPath"
        throw "Set-WorktreeJunctions.ps1 not found at $setWtJunctionsPath"
      }
    }

    # Dot-source Initialize-DownstreamSprintFromSharedVSCode if not already loaded
    if (-not (Get-Command -Name 'Initialize-DownstreamSprintFromSharedVSCode' -CommandType Function -ErrorAction SilentlyContinue)) {
      $initializeDownstreamPath = Join-Path $GitRoot 'ATAP.Utilities' 'src' `
        'ATAP.Utilities.BuildTooling.PowerShell' 'public' 'Initialize-DownstreamSprintFromSharedVSCode.ps1'
      if ($DryRun) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'DryRun: skipping Initialize-DownstreamSprintFromSharedVSCode dependency load.'
      } elseif (Test-Path $initializeDownstreamPath) {
        . $initializeDownstreamPath
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
          -Message "Initialize-DownstreamSprintFromSharedVSCode.ps1 not found at $initializeDownstreamPath"
        throw "Initialize-DownstreamSprintFromSharedVSCode.ps1 not found at $initializeDownstreamPath"
      }
    }
  }

  process {
    # ----- Build the result object -----
    $result = [PSCustomObject]@{
      nextSprintNumber     = $null
      previousSprintNumber = $null
      dryRun               = $DryRun.IsPresent
      sharedVSCode         = @{
        issueNumber  = $null
        branchName   = $null
        worktreePath = $null
        created      = $false
        error        = $null
      }
      planning             = @{
        issueNumber      = $null
        branchName       = $null
        worktreePath     = $null
        created          = $false
        junctionsCreated = $false
        planningComplete = $false
        error            = $null
      }
    }

    # ===================================================================
    # Step 1 — Determine the next sprint number
    # ===================================================================
    if ($PSBoundParameters.ContainsKey('SprintNumber')) {
      $sprintNum = $SprintNumber
      $prevNum = '{0:D4}' -f ([int]$sprintNum - 1)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Using explicit sprint number $sprintNum"
    } else {
      $planningRoot = Join-Path $GitRoot '_Planning'
      $retroDir = Join-Path $planningRoot 'SprintRetrospective'

      $retrospectives = Get-ChildItem $retroDir `
        -Filter 'Notebook-SprintWorkSession-*-End.md' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

      if ($retrospectives) {
        $lastRetro = $retrospectives[0].Name
        if ($lastRetro -match 'SprintWorkSession-(\d{4})-End') {
          $lastSprintN = [int]$Matches[1]
          $newSprintN = $lastSprintN + 1
        } else {
          $newSprintN = 1
        }
      } else {
        $newSprintN = 1
      }

      $sprintNum = '{0:D4}' -f $newSprintN
      $prevNum = '{0:D4}' -f ($newSprintN - 1)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
        -Message "Auto-detected sprint number $sprintNum (previous: $prevNum)"
    }

    $result.nextSprintNumber = $sprintNum
    $result.previousSprintNumber = $prevNum

    # ===================================================================
    # Step 2 — SharedVSCode: issue + branch + worktree
    # ===================================================================
    $svRepoPath = Join-Path $GitRoot 'SharedVSCode'
    $svIssueNum = $null

    # 2a. Create GitHub issue
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating GitHub issue for SharedVSCode sprint $sprintNum"

      if ($PSCmdlet.ShouldProcess("$Owner/SharedVSCode", "Create GitHub issue 'Sprint $sprintNum work items'")) {
        $ghOutput = gh issue create `
          --repo "$Owner/SharedVSCode" `
          --title "Sprint $sprintNum work items" `
          --label 'sprint' `
          --body "Sprint $sprintNum work items for SharedVSCode" 2>&1

        if ($LASTEXITCODE -ne 0) {
          throw "gh issue create failed (exit $LASTEXITCODE): $ghOutput"
        }

        # gh returns the issue URL; extract the number from the end
        if ($ghOutput -match '/issues/(\d+)') {
          $svIssueNum = [int]$Matches[1]
        } else {
          throw "Could not parse issue number from gh output: $ghOutput"
        }

        $result.sharedVSCode.issueNumber = $svIssueNum
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "SharedVSCode issue #$svIssueNum created"
      }
    } catch {
      $errorMessage = "Failed to create SharedVSCode GitHub issue. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    if ($DryRun -and $null -eq $svIssueNum) {
      $svIssueNum = 'DRYRUN'
      $result.sharedVSCode.issueNumber = $svIssueNum
    }

    # 2b. Fetch latest main
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message 'Fetching and checking out SharedVSCode main'

      if ($PSCmdlet.ShouldProcess($svRepoPath, 'git fetch/checkout/pull main')) {
        git -C $svRepoPath fetch origin 2>&1 | Out-Null
        git -C $svRepoPath checkout main 2>&1 | Out-Null
        git -C $svRepoPath pull origin main 2>&1 | Out-Null
      }
    } catch {
      $errorMessage = "Failed to update SharedVSCode main. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    # 2c. Create branch and worktree
    $svBranch = "$svIssueNum-Sprint-$sprintNum-work-items"
    $svWorktreePath = Join-Path $GitRoot "SharedVSCode-wt-$svIssueNum-Sprint-$sprintNum-work-items"
    $result.sharedVSCode.branchName = $svBranch
    $result.sharedVSCode.worktreePath = $svWorktreePath

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating SharedVSCode worktree at $svWorktreePath on branch $svBranch"

      if ($PSCmdlet.ShouldProcess($svWorktreePath, "git worktree add -b $svBranch")) {
        $wtOutput = git -C $svRepoPath worktree add $svWorktreePath -b $svBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git worktree add failed (exit $LASTEXITCODE): $wtOutput"
        }
        $result.sharedVSCode.created = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "SharedVSCode worktree created at $svWorktreePath"
      }
    } catch {
      $errorMessage = "Failed to create SharedVSCode worktree. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.sharedVSCode.error = $errorMessage
      return $result
    }

    # ===================================================================
    # Step 3 — _Planning: issue + branch + worktree + junctions + context
    # ===================================================================
    $planRepoPath = Join-Path $GitRoot '_Planning'
    $planIssueNum = $null

    # 3a. Create GitHub issue
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating GitHub issue for _Planning sprint $sprintNum"

      if ($PSCmdlet.ShouldProcess("$Owner/_Planning", "Create GitHub issue 'Sprint $sprintNum work items'")) {
        $ghOutput = gh issue create `
          --repo "$Owner/_Planning" `
          --title "Sprint $sprintNum work items" `
          --label 'sprint' `
          --body "Sprint $sprintNum work items for _Planning" 2>&1

        if ($LASTEXITCODE -ne 0) {
          throw "gh issue create failed (exit $LASTEXITCODE): $ghOutput"
        }

        if ($ghOutput -match '/issues/(\d+)') {
          $planIssueNum = [int]$Matches[1]
        } else {
          throw "Could not parse issue number from gh output: $ghOutput"
        }

        $result.planning.issueNumber = $planIssueNum
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "_Planning issue #$planIssueNum created"
      }
    } catch {
      $errorMessage = "Failed to create _Planning GitHub issue. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    if ($DryRun -and $null -eq $planIssueNum) {
      $planIssueNum = 'DRYRUN'
      $result.planning.issueNumber = $planIssueNum
    }

    # 3b. Fetch latest main
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
        -Message 'Fetching and checking out _Planning main'

      if ($PSCmdlet.ShouldProcess($planRepoPath, 'git fetch/checkout/pull main')) {
        git -C $planRepoPath fetch origin 2>&1 | Out-Null
        git -C $planRepoPath checkout main 2>&1 | Out-Null
        git -C $planRepoPath pull origin main 2>&1 | Out-Null
      }
    } catch {
      $errorMessage = "Failed to update _Planning main. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3c. Create branch and worktree
    $planBranch = "$planIssueNum-Sprint-$sprintNum-work-items"
    $planWorktreePath = Join-Path $GitRoot "_Planning-wt-$planIssueNum-Sprint-$sprintNum-work-items"
    $result.planning.branchName = $planBranch
    $result.planning.worktreePath = $planWorktreePath

    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating _Planning worktree at $planWorktreePath on branch $planBranch"

      if ($PSCmdlet.ShouldProcess($planWorktreePath, "git worktree add -b $planBranch")) {
        $wtOutput = git -C $planRepoPath worktree add $planWorktreePath -b $planBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
          throw "git worktree add failed (exit $LASTEXITCODE): $wtOutput"
        }
        $result.planning.created = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "_Planning worktree created at $planWorktreePath"
      }
    } catch {
      $errorMessage = "Failed to create _Planning worktree. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3d. Create NTFS junctions in the _Planning worktree
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Creating NTFS junctions in _Planning worktree pointing to SharedVSCode sprint worktree'

      if ($PSCmdlet.ShouldProcess($planWorktreePath, 'Set-WorktreeJunctions')) {
        $junctionResult = Set-WorktreeJunctions `
          -SourceRepoPath $planRepoPath `
          -WorktreePath $planWorktreePath `
          -DevSourceRepoPath $svWorktreePath `
          -DevSourceRepoFolderNames $JunctionFolderNames

        if ($junctionResult.Success) {
          $result.planning.junctionsCreated = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "_Planning junctions created: $($junctionResult.JunctionsCreated) junction(s)"
        } else {
          $junctionErrors = ($junctionResult.Errors -join '; ')
          throw "Set-WorktreeJunctions completed but reported errors: $junctionErrors"
        }
      }
    } catch {
      $errorMessage = "Failed to create _Planning junctions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # 3e. Apply SharedVSCode context to _Planning
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message 'Applying SharedVSCode context to _Planning worktree'

      if ($PSCmdlet.ShouldProcess($planWorktreePath, 'Initialize-DownstreamSprintFromSharedVSCode')) {
        $workspaceFiles = @(Get-ChildItem -Path $planWorktreePath -Filter '*.code-workspace' |
            Select-Object -ExpandProperty FullName)

        if ($workspaceFiles.Count -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message 'No .code-workspace files found in _Planning worktree; skipping context initialization'
        } else {
          $templateRef = "SharedVSCode-wt-$svIssueNum-Sprint-$sprintNum-work-items"
          Initialize-DownstreamSprintFromSharedVSCode `
            -WorkspaceFiles $workspaceFiles `
            -TemplateRef $templateRef `
            -Profile "sprint-$sprintNum"

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "_Planning context applied with templateRef $templateRef"
        }
      }
    } catch {
      $errorMessage = "Failed to apply SharedVSCode context to _Planning. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      $result.planning.error = $errorMessage
      return $result
    }

    # ===================================================================
    # Step 4 — Create sprint NuGet.config in SharedVSCode worktree
    # ===================================================================
    try {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
        -Message "Creating sprint NuGet.config in SharedVSCode worktree at $svWorktreePath"

      $nugetConfigPath = Join-Path $svWorktreePath 'NuGet.config'
      $nugetConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <!-- ProGet feeds - local dev workstation (5-tier model, sprint branch) -->
    <!-- ProGet installed on port 50000 (configured in ProGet.config, symlinked from ATAP.IAC) -->
    <!-- Override port in NuGet.config if ProGet moves to a different port -->
    <!-- allowInsecureConnections is required because localhost ProGet uses HTTP, not HTTPS -->
    <!-- ToDo: [Security Concern] make the feeds require HTTPS -->
    <add key="nuget-experimental"
      value="$ProGetBaseUrl/nuget/nuget-experimental/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-development"
      value="$ProGetBaseUrl/nuget/nuget-development/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-integration"
      value="$ProGetBaseUrl/nuget/nuget-integration/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-qa"
      value="$ProGetBaseUrl/nuget/nuget-qa/v3/index.json"
      allowInsecureConnections="true" />
    <add key="nuget-stable"
      value="$ProGetBaseUrl/nuget/nuget-stable/v3/index.json"
      allowInsecureConnections="true" />
    <!-- nuget.org - primary source for all third-party packages -->
    <add key="nuget.org"
      value="https://api.nuget.org/v3/index.json"
      protocolVersion="3" />
  </packageSources>
  <packageSourceCredentials>
    <!-- ToDo: [Security Improvement] original design protected the Proget Feeds with individual keys,
      current design allows anonymous reads Security Improvement would be to make an API key required for each feed-->
    <!-- No credentials needed - anonymous read is enabled for all feeds -->
    <!-- ProGet admin API key is stored in Bitwarden as env var PROGET_ADMIN_API_KEY -->
    <!-- NuGet CLI usage: dotnet nuget push with -api-key flag using PROGET_ADMIN_API_KEY env var -->
    <!-- No credentials block needed for anonymous read access on the experimental feed and maybe production -->
  </packageSourceCredentials>

  <packageRestore>
    <!-- The <packageRestore> section in nuget.config controls whether NuGet is allowed to restore missing packages -->
    <!--and those two settings are the defaults.-->
    <!-- These settings respect NuGet's config hierarchy - a nuget.config at the solution/repo level overrides -->
    <!-- the machine-level config at %ProgramData%\NuGet\Config. So explicitly setting both to True -->
    <!-- in the repo-level config ensures restore works consistently even if a CI server's -->
    <!-- machine-level config has them disabled.-->
    <!-- Explicitly set defaults so CI machines with a restrictive machine-level config are overridden -->
    <add key="enabled" value="True" />
    <add key="automatic" value="True" />
  </packageRestore>

  <disabledPackageSources>
    <!-- Promotion feeds - not used for restore, only for publish/promote via BuildMaster -->
    <!-- Uncomment to enable additional feeds for restore if needed -->
    <!--
    <add key="ProGet-Development" value="false" />
    <add key="ProGet-Testing"     value="false" />
    <add key="ProGet-Production"  value="false" />
    -->
  </disabledPackageSources>

<!-- ==================== Package Source Mapping ====================
    Required to resolve NuGet warning NU1507.
    When Central Package Management (CPM) is enabled via Directory.Packages.props
    (ManagePackageVersionsCentrally=true), NuGet requires that all defined package
    sources be mapped to package name patterns. Without this, NuGet warns that
    it cannot deterministically decide which source to use for a given package.

    Rules:
      - Every active packageSource must have at least one <package pattern="..." /> entry.
      - The wildcard pattern "*" on nuget.org catches all third-party packages
        not explicitly mapped to another source.
      - The "ATAP.*" and AceCommander.* patterns on the ProGet feeds ensures internal packages are
        resolved exclusively from the local ProGet instance and are never
        accidentally queried from nuget.org.
      - Packages that match a pattern on a source will ONLY be resolved from
        that source - NuGet will not fall back to other sources.

    See: https://aka.ms/nuget-package-source-mapping
    See: https://learn.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1507
  -->
  <packageSourceMapping>
    <!-- All standard third-party packages come from nuget.org -->
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <!-- Internal ATAP packages: on sprint branches, resolve only from nuget-experimental.
         Higher-tier feeds are listed for restore visibility but ATAP.* packages are only
         pinned to nuget-experimental here. BuildMaster promotes packages up the tier chain.
         See SC-INFRA-001 in TASKS.md for the full package migration/promotion design. -->
    <packageSource key="nuget-experimental">
      <package pattern="ATAP.*" />
      <package pattern="AceCommander.*" />
    </packageSource>
    <!-- nuget-development through nuget-stable: required entries for NU1507 compliance.
         All 5 feeds must have a mapping entry when listed as active sources. -->
    <packageSource key="nuget-development">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-integration">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-qa">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
    <packageSource key="nuget-stable">
      <package pattern="AceCommander.*" />
      <package pattern="ATAP.*" />
    </packageSource>
  </packageSourceMapping>
  <auditSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </auditSources>

  <!-- ==================== Legacy / Archived Package Sources ====================
    These feeds were used historically and are retained for reference.
    They are NOT active - do not remove the enclosing XML comment.
    To re-enable a feed: move its <add> element into the active <packageSources>
    block above and add a corresponding <packageSource> entry in <packageSourceMapping>.

    <packageSources>
      <add key="MyGet ATAP Utilities Feed"
        value="https://www.myget.org/F/atap-utilities/api/v3/index.json" />
      <add key="ServiceStack MyGet feed"
        value="https://www.myget.org/F/servicestack" />
      <add key="dotnet-public"
        value="https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-public/nuget/v3/index.json" />
      <add key="dotnet-tools"
        value="https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json" />
      <add key="Telerik Packages"
        value="https://nuget.telerik.com/nuget" />
      <add key="Microsoft Visual Studio Offline Packages"
        value="C:\Program Files (x86)\Microsoft SDKs\NuGetPackages\" />
      <add key="LocalBaGet"
        value="http://localhost:50040/v3/index.json"
        allowInsecureConnections="true" />
    </packageSources>
  -->

</configuration>
"@

      if ($PSCmdlet.ShouldProcess($nugetConfigPath, 'Set-Content NuGet.config')) {
        Set-Content -Path $nugetConfigPath -Value $nugetConfigContent -Encoding utf8
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
          -Message "Sprint NuGet.config created at $nugetConfigPath"
      }
    } catch {
      $errorMessage = "Failed to create sprint NuGet.config. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # NuGet.config creation failure is non-fatal; log and continue
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message "Sprint Stage 1 complete for sprint $sprintNum"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
      -Message 'Step 2 planning must create or refresh the sprint task artifact set in the _Planning worktree: active board (`TASKS.html` or later `TASKS_V*.html`), `Tasks.Accomplished.html`, `Tasks.ProceduralDetails.html`, and a synchronized `TASKS.md`.'

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}
