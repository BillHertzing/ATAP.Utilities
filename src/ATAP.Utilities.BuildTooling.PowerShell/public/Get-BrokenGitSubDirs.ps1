# useage: $results = Get-BrokenGitSubDirs ; $results.keys | %{$key = $_;  $results[$key].keys | %{"$key $_ $($($($results[$key])[$_]) -join [environment]::NewLine)" }}
# does not get any stderr message
Function Get-BrokenGitSubDirs {
  [CmdletBinding(SupportsShouldProcess = $true)]
  $results = @{}
  Get-ChildItem |
  Where-Object { $_.psiscontainer -and ($_.name -notmatch '^\.') -and (Test-Path -Path $(Join-Path -Path $_.name -ChildPath '.git')) } |
  ForEach-Object { Set-Location $_.name
    $errors = git fsck
    $results[$_.name] = @{'ErrorCount' = $errors.length; 'ErrorList' = $errors }
    Set-Location ..
  }
  $results
}

