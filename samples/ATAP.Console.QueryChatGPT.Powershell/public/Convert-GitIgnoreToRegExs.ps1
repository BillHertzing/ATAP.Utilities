function Convert-GitIgnoreToRegExs {
  param (
    # Path to the .gitignore file
    [Parameter(Mandatory)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
          $message = "File '$_' does not exist."
          Write-PSFMessage -Message $message -Level Error
          throw $message
        }
        if ([System.IO.Path]::GetFileName($_) -ne '.gitignore' ) {
          Write-PSFMessage -Message $message -Level Error
          $message = "The file name must be exactly 'gitignore'. Found '$($_.FullName)'."
          throw $message
        }
        return $true })]
    [string] $Path
  )
  # Test a string to see if it is a valid RegEx pattern
  function Test-Regex {
    param (
      [string]$Pattern
    )
    try {
      [void]([regex]::new($Pattern))
      return $true
    } catch {
      return $false
    }
  }

  # Convert patterns to regex (basic implementation)
  # Windows is file name case-insensitive, so we use [regex]::IgnoreCase
  # We are only expecting a single .gitignore file in a multi-root repository (at the root of the SoftwareRepository)
  function ConvertOneGitIgnoreLineToRegex($pattern) {
    # patterns that start with '\\' are locked relative to the location of .gitignore file
    # patterns that do not start with "/" match if the pattern appears anywhere in the FullPath of the file
    # patterns that end with '\\' are directories and gitignore will ignore all files and directories under that directory
    # '.' stands for any character in regex, so we need to escape it


    # Step 1: Escape regex special characters
    $escaped = [Regex]::Escape($pattern)

    Step 2: Convert glob wildcards to regex equivalents
    $escaped = $escaped -replace '\\*\\*', '.*'         # ** → .*
    $escaped = $escaped -replace '\\*', '[^\\/]*'       # * → anything but slash
    $escaped = $escaped -replace '[/\\]', '[\\/]+'      # / or \ → [\/]+

    # Step 3: Escape any literal '.' characters
    $escaped = $escaped -replace '(?<!\\)\.', '\\.'

    # Step 4: Anchor to match full path
    return "$escaped$"

    # switch ($pattern) {
    #   { $_ -match '^\\' } { $pattern = $pattern.Substring(1) }
    #   { $_ -match '\\$' } { $pattern = $pattern.Substring(0, $pattern.Length - 1) }
    # }
    # "^.*$pattern$"
  }

  # # Load .gitignore into memory as regex patterns
  # $ignoreRegexes = Get-Content $gitignoreFile | Where-Object { $_ -and -not $_.StartsWith('#') } |
  #   ForEach-Object {
  #     $regExPattern = ConvertOneGitIgnoreLineToRegex $_
  #     Test-Regex $regExPattern
  #     if ($?) {
  #       $regExPattern
  #     } else {
  #       # Write-PSFMessage -Message "Invalid regex pattern: $_" -Level Warning
  #       $null
  #     }
  #   }

  # Converting .gitignore to regexes, and accounting for case and globs, is hard!
  # for now, hardcode the following regexes
  # This is formatted for Everything search
  # file: path:github\ATAP !path:\.git\ !path:\.idea\ !path:\.vs\ !path:\_devLogs\ !path:\_generated\ !path:\_site\ !path:AutoDoc\ !path:ATAP.Utilities\Build\ !path:\bin\ !path:\docs\ !path:\node_modules\ !path:\MimeKit\ !path:\obj\ !path:\Releases\ !path:\Result_GenerateProgram\ !path:\Result_solution\ !path:\OfflinePackagesRepository\ !path:\wwwroot\ !endwith:bak !endwith:binlog !endwith:dll !endwith:pdb !fodyWeavers.xml$

  # This is formatted for VSC search, in a settings file (userSettings.jsonc in SharedCode)
  # "search.exclude": {
  #   "**/.git": true,
  #   "**/.idea": true,
  #   "**/.vs": true,
  #   "**/.vscode": true,
  #   "**/_devLogs": true,
  #   "**/_generated": true,
  #   "**/_site": true,
  #   "**/AutoDoc": true,
  #   "**/ATAP.Utilities/Build": true,
  #   "**/bin": true,
  #   "**/coverage": true,
  #   "**/dist": true,
  #   "**/docs": true,
  #   "**/node_modules": true,
  #   "**/obj": true,
  #   "**/out": true,
  #   "**/packages": true,
  #   "**/Releases": true,
  #   "**/Resources/OfflinePackagesRepository": true,
  #   "**/Result_GenerateProgram": true,
  #   "**/Result_solution": true,
  #   "**/TestResults": true,
  #   "**/www": true,
  #   "**/wwwroot": true,
  #   "**/*.bak": true,
  #   "**/*.binLog": true,
  #   "**/*.dll": true,
  #   "**/*.pdb": true,
  #   "**/fodyWeavers.xml": true,
  #   "**/xrefmap.xml": true
  # }

  # /.git/,/.idea/,/.vs/,/_devLogs/,/_generated/,/_site/,AutoDoc/,ATAP.Utilities/Build/,/bin/,/docs/,/node_modules/,/MimeKit/,/obj/,/Releases/,/Result_GenerateProgram/,/Result_solution/,/OfflinePackagesRepository/,/wwwroot/ endwith:bak endwith:binlog endwith:dll endwith:pdb fodyWeavers.xml$

  $ignoreRegexes = @(
    , '\\\.git\\'
    , '\\\.idea\\'
    , '\\\.vs\\'
    , '\\_devLogs\\'
    , '\\_generated\\'
    , '\\_site\\'
    , 'AutoDoc\\'
    , '\\ATAP.Utilities\\Build\\'
    , '\\bin\\'
    , '\\docs\\' # this looks like something generated
    , '\\src\\docs\\' # as does this and maybe duplicated
    , '\\node_modules\\'
    , '\\MimeKit\\'
    , '\\obj\\'
    , '\\out\\'
    , '\\packages\\'
    , '\\Releases\\'
    , '\\Result_GenerateProgram\\'
    , '\\Result_solution\\'
    , '\\OfflinePackagesRepository\\'
    , '\\TestResults\\'
    , '\\www\\'
    , '\\wwwroot\\'
    , '\.bak$'
    , '\.binlog$'
    , '\.dll$'
    , '\.pdb$'
    , 'fodyWeavers\.xml$'
    , 'xrefmap\.xml$'
  )
  # '\\\.vscode\\' do .vscode separately

  $ignoreRegexes
}

