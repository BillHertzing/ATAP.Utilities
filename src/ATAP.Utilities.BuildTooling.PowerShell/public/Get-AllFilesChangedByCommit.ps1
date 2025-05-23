<#
Useage:
$tempPath = 'D:\Temp\T1'
$currentRepositoryPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
$initialSHA = 'f731a579e3acc4934e31fd417f0888cb171023c4'
git log --format="%H" $initialSHA^..HEAD | ForEach-Object {
  Get-AllFilesChangedByCommit -CommitSHA $_ -TempPath $tempPath -currentRepositoryPath $currentRepositoryPath
}
gci (join-path $tempPath (Split-Path -Path $currentRepositoryPath -Leaf)) | sort LastWriteTime | %{$_.name}
#>

Function Get-AllFilesChangedByCommit {
  [CmdletBinding( DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern' )]
  Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    $CommitSHA,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    # ToDo: add validation script to ensure proper keys and values exists
    [ValidateNotNullOrEmpty()]
    $TempPath,
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    # ToDo: add validation script to ensure proper keys and values exists
    $currentRepositoryPath = $env:VSCExtensionProjectAbsolutePath
  )
  BEGIN {
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # $VerbosePreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    Write-PSFMessage -Level Debug -Message "currentRepositoryPath is $currentRepositoryPath" -Tag 'Trace'
    if (${pwd} -ne $currentRepositoryPath) {
      Set-Location -Path $currentRepositoryPath
    }
    # write a warning message to the user
    $status = git status --porcelain
    if ($null -ne $status) {
      $message = @"
The directory tree has changes since the last commit. This function will abort.
${$status - join Environment.NewLine}
"@
      Write-PSFMessage -Level Error -Message $message -Tag ''
      throw $message
    }
    # record the current Branch and HEAD commit
    $initialBranch = git branch --show-current
    $initialCommitSHA = git rev-parse HEAD
    # cleanup function to be called on an exit
    function Remove-Worktree {
      Param (
        [validateNotNullOrEmpty()]
        $TempWorktreePath,
        [validateNotNullOrEmpty()]
        $currentRepositoryPath
      )
      Set-Location -Path $currentRepositoryPath
      if ([string]::IsNullOrWhiteSpace($TempWorktreePath)) {
        $message = @'
The TempWorktreePath is null or empty. This function will abort.
'@
        Write-PSFMessage -Level Error -Message $message -Tag ''
        throw $message
      }
      # ToDo: wrap in a try-catch block for error handling
      git worktree remove -f $TempWorktreePath
    }
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {
    # Confirm that the CommitSHA is valid
    if ($(git cat-file -t $CommitSHA) -ne 'commit') {
      $message = @'
The CommitSHA is not valid. This function will abort.
'@
      Write-PSFMessage -Level Error -Message $message -Tag ''
      throw $message
    }
    # Get the list of files changed by the commit and copy to the tempdir. Same filename may exist in multiple source subdirectories
    # Extract only the filename part after the status and tab
    # wrap each in double quotes in case the filepath includes spaces
    # ToDo: wrap in a try-catch block for error handling
    [array]$modifiedOrAddedNamesStatusArray = git diff-tree --no-commit-id --name-status -r $commitSHA | Where-Object {
      $_ -match '^(A|M)\t' }

    [array]$modifiedOrAddedFilesArray = $modifiedOrAddedNamesStatusArray | ForEach-Object { $relativeFilePath = $_.Split("`t")[1]; $relativeFilePath -notcontains ' ' ? $relativeFilePath : '"' + $relativeFilePath + '"' }

    # Create a temporary worktree for the repository
    $TempWorktreePath = Join-Path -Path $TempPath -ChildPath (Split-Path -Path $currentRepositoryPath -Leaf) -AdditionalChildPath 'worktree'
    # ToDo: wrap in a try-catch block for error handling
    git worktree add --detach $TempWorktreePath -f --no-checkout > $null
    # Change the current working directory,
    #  because git works on the temporary worktree when invoked from the root of the temporary worktree
    Set-Location -Path $TempWorktreePath
    # configure sparse-checkout and checkout only modified or added files
    # very crucial. this is where we tell the temporary worktree git we are checking out only SOME of the files in the repository
    git config --worktree core.sparsecheckout true
    # ToDo: wrap in a try-catch block for error handling
    git sparse-checkout init

    # ToDo: wrap in a try-catch block for error handling
    for ($i = 0; $i -lt $modifiedOrAddedFilesArray.Count; $i++) {
      if ($i -eq 0) {
        git sparse-checkout set $modifiedOrAddedFilesArray[$i]
      } else {
        git sparse-checkout add $modifiedOrAddedFilesArray[$i]
      }
    }
    # ToDo: wrap in a try-catch block for error handling
    git checkout $CommitSHA

    # Create a subdirectory to hold the files and their contents that were changed on the commit
    $outputSHAPath = Join-Path -Path $TempPath -ChildPath (Split-Path -Path $currentRepositoryPath -Leaf) -AdditionalChildPath $CommitSHA
    if (-not (Test-Path -Path $outputSHAPath)) {
      # ToDo: wrap in a try-catch block for error handling
      New-Item -ItemType Directory -Path $outputSHAPath -Force > $null
    }

    # copy the files and subdirectorties recursively from the temporary worktree to the output
    Get-ChildItem $TempWorktreePath | ForEach-Object {
      $changedFilePath = $_.FullName
      $changedFilePath -notcontains ' ' ? $changedFilePath : '"' + $changedFilePath + '"'
      Write-PSFMessage -Level Important -Message $changedFilePath -Tag ''
      Copy-Item $changedFilePath -Destination $outputSHAPath -Recurse -Force
    }

    # remove the temporary worktree. This will cwd back to the original repository
    # ToDo: wrap in a try-catch block for error handling
    Remove-Worktree $TempWorktreePath $currentRepositoryPath
  }
  #endregion ProcessBlock
  #region EndBlock
  END {
    # Reset the repository to either the branch, if there was one when the function started,
    #  or if detached (no branch) reset the repository to the HEAD commit recorded when the function started
    if ($initialBranch) {
      # ToDo: wrap in a try-catch block for error handling
      git checkout $initialBranch
    } else {
      # ToDo: wrap in a try-catch block for error handling
      git checkout $initialCommitSHA
    }
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}


