param (

  [string] $repoPath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\'
  , [string] $outputFile = 'C:\temp\embeddings.json'
  , [string[]] $targetExtensions = @(".cs", ".ps1", ".ts", ".js", ".md", ".json", ".jsonc", ".xml", ".yaml", ".yml", ".txt")
  # Note that having these directories in your .gitignore file will exclude them from the search
  , [string[]] $excludedDirs = @("_generated", "bin", "obj")
)

# Load .gitignore into memory as regex patterns
$gitignoreFile = Join-Path $repoPath ".gitignore"
$gitignorePatterns = if (Test-Path $gitignoreFile) {
  Get-Content $gitignoreFile | Where-Object { $_ -and -not $_.StartsWith("#") }
}
else { @() }

# Convert patterns to regex (basic implementation)
# Windows is file name case-insensitive, so we use [regex]::IgnoreCase
# We are only expecting a single .gitignore file in a multi-root repository (at the root of the repository)
function Convert-ToRegex($pattern) {
  # patterns that start with '/' are locked relative to the location of .gitignore file
  # patterns that do not start with "/" match if the pattern appears anywhere in the FullPath of the file
  # patterns that end with '/' are directories and gitignore will ignore all files and directories under that directory
  switch ($pattern) {
    { $_ -match '^/' } { $pattern = $pattern.Substring(1) }
    { $_ -match '/$' } { $pattern = $pattern.Substring(0, $pattern.Length - 1) }
  }
  "^.*$pattern$"
}

$ignoreRegexes = $gitignorePatterns | ForEach-Object { Convert-ToRegex $_ }

# Get candidate files
$allFiles = Get-ChildItem -Path $repoPath -Recurse -File  | Where-Object { $fileHandle = $_
    ($targetExtensions -contains $_.Extension) -and
  # (-not ($excludedDirs | Where-Object { $_ -in $fileHandle.FullName.Split([IO.Path]::DirectorySeparatorChar) })) -and
    (-not ($ignoreRegexes | Where-Object { $_ -match $fileHandle.FullName }))
}

# Shared state (PowerShell 7+ uses synchronized hashtables for thread-safe logging)
$longFiles = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$filesToBeProcessed = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Parallel processing
$results = @()
$allFiles | ForEach-Object -Parallel {
  param(
    [System.Collections.Concurrent.ConcurrentBag[string]] $filesToBeProcessed
    , [System.Collections.Concurrent.ConcurrentBag[string]]$longFiles
  )
  #Wait-Debugger
  $fn = $_.FullName
  write-out $fn
  Write-PSFMessage -Message "Processing file: $($_.FullName)" -Level Important
  $fileHandle = $_
  $content = Get-Content $fileHandle.FullName -Raw
  if ($content.Length -lt 8192) {
    $filesToBeProcessed.Add($fileHandle.FullName)
  }
  else {
    $longFiles.Add($fileHandle.FullName)
  }
  #debugging
  $identifier = [System.Diagnostics.Process]::GetCurrentProcess().Id
  $identifier
} -ArgumentList $filesToBeProcessed, $longFiles  -ThrottleLimit 8  | ForEach-Object { $results += $_ }

# Save embeddings
# $results | ConvertTo-Json -Depth 5 | Set-Content -Path $outputFile
Write-PSFMessage -Message "FilesToBeProcessed Count : $($filesToBeProcessed.count)" -Level Important
Write-PSFMessage -Message "longFiles Count : $($longFiles.count)" -Level Important

