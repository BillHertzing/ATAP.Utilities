<#
.SYNOPSIS
Builds the ordered list of base paths under which Get-HostSettings looks for ATAP.IAC's
HostSettings.ps1.

.DESCRIPTION
Get-IACHostSettingsCandidatePath exists so the probe order is data, not control flow buried inside
Get-HostSettings, and so it can be tested without a real ATAP.IAC checkout.

Order, most specific first:

  1. An explicit -IACBasePath.
  2. $env:ATAP_IAC_BASE_PATH, process scope then user scope. An operator naming a path outranks
     anything discovered.
  3. The CURRENT sprint's ATAP.IAC worktree, under each search root, discovered by pattern.
  4. The stable ATAP.IAC worktree, under each search root.
  5. The copy shipped inside the installed ATAP.Utilities.PowerShell module.

Step 3 is the reason this helper exists. It used to be a hard-coded literal naming
`ATAP.IAC-wt-9-Sprint-0007-work-items`, which stopped existing at the end of Sprint 0007. Every
sprint since, HostSettings resolution silently fell through to the stable worktree, so a
HostSettings edit made in a sprint worktree -- which is what the repository's boundary rule requires
for sprint work -- had no runtime effect at all. See SC-0252.

Sprint worktrees are ranked by sprint number, then by worktree number, both DESCENDING and both
compared as INTEGERS. A lexical sort is wrong here: 'ATAP.IAC-wt-9-Sprint-0007' sorts above
'ATAP.IAC-wt-15-Sprint-0012' as a string.

Nothing is filtered for existence. Get-HostSettings probes each candidate for the file it wants, so
a candidate that does not exist simply does not match. Callers get the full, ordered intent.

.PARAMETER IACBasePath
An explicit ATAP.IAC root supplied by the caller. Wins over everything.

.PARAMETER SearchRoot
Directories that contain repository checkouts side by side (the "GitHub root"). Each is searched for
a sprint worktree and for the stable `ATAP.IAC` folder. Duplicates are collapsed.

.PARAMETER ProgramFilesResourcePath
The `Resources` folder inside the installed ATAP.Utilities.PowerShell module, used as the last
resort when no source checkout is present.

.OUTPUTS
System.String[] -- the ordered candidate base paths, de-duplicated, no empties.

.EXAMPLE
Get-IACHostSettingsCandidatePath -SearchRoot 'C:\Dropbox\whertzing\GitHub'

Returns the sprint worktree first, then the stable checkout.

.EXAMPLE
Get-IACHostSettingsCandidatePath -IACBasePath 'D:\fixture\ATAP.IAC'

Returns the explicit path first, ahead of any discovered worktree.

.NOTES
AI assisted using Powershell.instructions.md as guidelines.
Private helper for Get-HostSettings. Not exported.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-IACHostSettingsCandidatePath {
  [CmdletBinding()]
  [OutputType([string[]])]
  param(
    [Parameter(Mandatory = $false)]
    [string]$IACBasePath,

    [Parameter(Mandatory = $false)]
    [string[]]$SearchRoot,

    [Parameter(Mandatory = $false)]
    [string]$ProgramFilesResourcePath
  )

  BEGIN {
    $fn = 'Get-IACHostSettingsCandidatePath'
    $mn = 'ATAP.Utilities.PowerShell'
    if (Get-Command -Name 'Write-PSFMessage' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started' -Tag 'hostsettings'
    }

    # ATAP.IAC-wt-<worktree>-Sprint-<nnnn>-<slug>
    $sprintWorktreePattern = '^ATAP\.IAC-wt-(?<worktree>\d+)-[Ss]print-(?<sprint>\d+)\b'

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    $addCandidate = {
      param([string]$Path)
      if ([string]::IsNullOrWhiteSpace($Path)) { return }
      if (-not $candidatePaths.Contains($Path)) { [void]$candidatePaths.Add($Path) }
    }
  }

  PROCESS {
    try {
      & $addCandidate $IACBasePath
      & $addCandidate ([System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'Process'))
      & $addCandidate ([System.Environment]::GetEnvironmentVariable('ATAP_IAC_BASE_PATH', 'User'))

      # Collapse roots that resolve to the same directory. On this workstation MyDocuments is
      # redirected into the Dropbox tree, so 'MyDocuments\GitHub' and the literal Dropbox GitHub
      # path are the same folder.
      $roots = [System.Collections.Generic.List[string]]::new()
      foreach ($root in @($SearchRoot)) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $normalized = try { [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/') } catch { $root }
        if (-not ($roots -contains $normalized)) { [void]$roots.Add($normalized) }
      }

      # Sprint worktrees first, newest sprint wins. Match each name explicitly rather than relying
      # on $Matches from a Where-Object filter, which holds the last successful match and not
      # necessarily the row being projected.
      foreach ($root in $roots) {
        $newestSprintWorktree =
          Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
              $m = [regex]::Match($_.Name, $sprintWorktreePattern)
              if ($m.Success) {
                [PSCustomObject]@{
                  FullName = $_.FullName
                  Sprint   = [int]$m.Groups['sprint'].Value
                  Worktree = [int]$m.Groups['worktree'].Value
                }
              }
            } |
            Sort-Object Sprint, Worktree -Descending |
            Select-Object -First 1

        if ($newestSprintWorktree) { & $addCandidate $newestSprintWorktree.FullName }
      }

      # Then the stable checkout under each root.
      foreach ($root in $roots) {
        & $addCandidate (Join-Path $root 'ATAP.IAC')
      }

      & $addCandidate $ProgramFilesResourcePath

      return $candidatePaths.ToArray()
    }
    catch {
      if (Get-Command -Name 'Write-PSFMessage' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Get-IACHostSettingsCandidatePath failed. Exception: $($_.Exception.Message)" -Tag 'hostsettings'
      }
      throw
    }
  }

  END {
    if (Get-Command -Name 'Write-PSFMessage' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed' -Tag 'hostsettings'
    }
  }
}
