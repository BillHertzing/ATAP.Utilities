param (

  [string] $repoPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\'
  , [string] $outputFile = 'C:\temp\embeddings.json'
  , [string[]] $targetExtensions = @('.cs', '.ps1', '.ts', '.js', '.md', '.json', '.jsonc', '.xml', '.yaml', '.yml', '.txt')
  # Note that having these directories in your .gitignore file will exclude them from the search
  , [string[]] $excludedDirs = @('_generated', 'bin', 'obj')
)

# use all the defaults for the parameters to Convert-GitIgnoreToRegExs
$ignoreRegexes = Convert-GitIgnoreToRegExs -path $(Join-Path $repoPath '.gitignore')

# Get candidate files
$fileHandles = Get-ChildItem -Path $repoPath -Recurse -File | Where-Object { $fileHandle = $_
  # prettier-ignore
  # ($targetExtensions -contains $fileHandle.Extension) -and # -&& for shortcircuit # <# PSScriptAnalyzerDisableFormatting #>
  # (-not ($excludedDirs | Where-Object { $_ -in $fileHandle.FullName.Split([IO.Path]::DirectorySeparatorChar) })) -and
    (-not (
    $ignoreRegexes | Where-Object { $fileHandle.FullName -match $_ }
  ))
}
Write-PSFMessage -Message "Found $($fileHandles.Count) files to process." -Level Debug -Tag 'SendToSEQ'
# Shared state (PowerShell 7+ uses synchronized hashtables for thread-safe logging)
$customLongFileHandles = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
$customFileHandlesToBeProcessed = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()

for ($fileHandlesIndex = 0; $fileHandlesIndex -lt $fileHandles.Count; $fileHandlesIndex++) {
  $fileHandle = $fileHandles[$fileHandlesIndex]
  #Write-PSFMessage -Message "Processing file: $($fileHandle.FullName)" -Level Debug -Tag 'SendToSEQ'
  if ($fileHandle.Length -lt 8192) {
    $customFileHandlesToBeProcessed.Add(@{ FullName = $fileHandle.FullName; Length = $fileHandle.Length })
  } else {
    $customLongFileHandles.Add([PSCustomObject]@{ FullName = $fileHandle.FullName; Length = $fileHandle.Length })
  }
}

# Parallel processing
#$results = @()
# $allFiles | ForEach-Object { # -Parallel {
# param(
#   [System.Collections.Concurrent.ConcurrentBag[string]] $filesToBeProcessed
#   , [System.Collections.Concurrent.ConcurrentBag[string]]$longFiles
# )
#Wait-Debugger
# $content = Get-Content $fileHandle.FullName -Raw
# if ($content.Length -lt 8192) {
#   $filesToBeProcessed.Add($fileHandle.FullName)
# }
# else {
#   $longFiles.Add($fileHandle.FullName)
# }
#debugging
#$identifier = [System.Diagnostics.Process]::GetCurrentProcess().Id
#$identifier
# }  # -ArgumentList $filesToBeProcessed, $longFiles -ThrottleLimit 8 | ForEach-Object { $results += $_ }

# Save embeddings
# $results | ConvertTo-Json -Depth 5 | Set-Content -Path $outputFile
Write-PSFMessage -Message "FilesToBeProcessed Count : $($customFileHandlesToBeProcessed.count)" -Level Debug
Write-PSFMessage -Message "longFiles Count : $($customLongFileHandles.count)" -Level Debug
$customLongFileHandles
| Sort-Object Length -Descending
| ForEach-Object { $fileHandle = $_
  Write-PSFMessage -Message "longFile: $($fileHandle.Length) $($fileHandle.FullName)" -Level Debug
}
return [PSCustomObject]@{
  LongFiles     = $customLongFileHandles
  ToBeProcessed = $customFileHandlesToBeProcessed
}
