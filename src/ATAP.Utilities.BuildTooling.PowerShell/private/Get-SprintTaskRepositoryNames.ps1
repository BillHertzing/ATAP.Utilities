function Get-SprintTaskRepositoryNames {
  <#
  .SYNOPSIS
    Extracts repository names from sprint TASKS.md task headers.
  .DESCRIPTION
    Reads task lines and returns only repository markers that appear immediately
    after the **Task N.M** token. Other bracketed annotations in a task body are
    intentionally ignored.
  .PARAMETER TasksContent
    Lines from TASKS.md.
  .PARAMETER ExcludeRepos
    Repository names to exclude from the returned set.
  .OUTPUTS
    System.String[]
  .EXAMPLE
    Get-SprintTaskRepositoryNames -TasksContent (Get-Content .\TASKS.md)
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [AllowEmptyString()]
    [string[]]$TasksContent,

    [string[]]$ExcludeRepos = @('_Planning', 'SharedVSCode', 'Cross-Repo')
  )

  begin {
    $repoNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  }

  process {
    foreach ($line in $TasksContent) {
      if ($line -match '^\s*(?:[-*]\s*)?(?:\[[ xX]\]\s*)?\*\*Task\s+\d+(?:\.\d+)+\*\*\s+\[(?<Repo>[A-Za-z][A-Za-z0-9._-]+)\]') {
        $candidate = $Matches['Repo']
        if ($candidate -notin $ExcludeRepos) {
          [void]$repoNames.Add($candidate)
        }
      }
    }
  }

  end {
    return @($repoNames | Sort-Object)
  }
}