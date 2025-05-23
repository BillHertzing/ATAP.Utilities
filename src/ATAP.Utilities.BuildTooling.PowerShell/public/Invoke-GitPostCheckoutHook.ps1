# This script is called when a developer makes a commit on a local git repository
#  It executes in the context of the developer's terminal or IDE
# It expects to be invoked in a repository's root directory
function Invoke-GitPostCheckoutHook {
  # ensure that by default the Commit will NOT happen
  $exitcode = 1
  $VerbosePreference = 'Continue' # Continue  SilentlyContinue
  $DebugPreference = 'Continue'

  Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
  Write-Debug ("Current Working Directory = $(Get-Location)" )
  # Write-Debug ("Environment Variables at start of $($MyInvocation.MyCommand) = " + [Environment]::NewLine + $(Write-EnvironmentVariablesIndented 0 2 ))

  $moduleName = [System.Environment]::GetEnvironmentVariable('ModuleName')
  Write-Verbose ('Environment Variable ModuleName = ' + $moduleName)

  $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
  Write-Verbose ('Environment Variable LocalSourceReproDirectory = ' + $localSourceReproDirectory)

  $branchName = [System.Environment]::GetEnvironmentVariable('BranchName')
  Write-Verbose ('Environment Variable BranchName = ' + $branchName)

  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')
  Write-Verbose ('Environment Variable RelativeModulePath = ' + $relativeModulePath)

  # ToDo: add -fail-fast parameter

  # ToDo: add -force-allow parameter to allow precommit to pass even if checks fail or there are no files in the commit

  # Call Jenkins to

  # Regex Patterns used to extract data from Git, expects an opinionated layout to the project's directory structure
  $ProjectKindAndNameExtractorPattern = '(?<ProjectKind>' + $dirsep + 'src|test|database' + $dirsep + ')(?<ProjectSubdirectoryName>.*?' + $dirsep + ')'

  # shorthand
  $dirSep = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar)

  # List of AddedChangedModifiedRenamed files in the commit
  $changedFiles = (git diff --name-only --cached --diff-filter=ACMR)
  # ToDo: add error handling might be null on a brand new repository or after a git init, or if no files are in the commit
  if ($changedFiles.count -eq 0) {
    # ToDo: support --force-allow
    Write-Output "PrecommitHook not passing: Number of changed files = $($changedFiles.count)"
    return $exitcode
  }
  Write-Debug "Number of changed files = $($changedFiles.count)"


  # Kinds of Projects. Used to validate input that comes from git commands. Opinionated.
  $projectKindStrs = @{'src' = 'src'; 'test' = 'test'; 'database' = 'database' }
  # Project Languages. Used to classify projects based on the scriptblock
  $projectLanguageStrs = @{'C#' = { Write-Debug 'C#' }; 'SQL' = 'SQL'; 'Powershell' = 'Powershell' }

  # List of Projects in the commit (Source, Tests, or database), and the language (C#, SQL (Database), and Powershell) of each project
  $changedFileCustomProperties = @{}
  $sourceProjects = $changedFiles | ForEach-Object { $fn = $_
    Write-Debug "Working on file named $fn"
    $changedFileCustomProperties[$fn] = @{}

    [RegEx]::Matches($fn , $ProjectKindAndNameExtractorPattern) # populates the system environment variable Matches
    if ([Environment]::Matches) {
      # Kind of Project
      $ProjectKindStr = [Environment]::Matches.Captures.Groups['ProjectKind'].value
      # for security, don't accept the info returned by Git without validating it. Parse the string into one of the expected values
      $changedFileCustomProperties[$fn]['ProjectKind'] = switch -regex ($ProjectKindStr) {
        'src' {
          '^src$'
          break
        }
        '^test$' {
          'test'
          break
        }
        '^database$' {
          'database'
          break
        }
        default {
          Write-Output "PrecommitHook not passing: ProjectKindStr did not match exactly an expected value : $ProjectKindStr"
          return $exitcode
        }
      }
      $ProjectSubdirectoryName = [Environment]::Matches.Captures.Groups['ProjectSubdirectoryName'].value
      # ToDo: run validation tests on the SubdirectoryName
      $changedFileCustomProperties[$fn]['ProjectSubdirectoryName'] = $ProjectSubdirectoryName

    } else {
      # the changed file does not match the $ProjectKindAndNameExtractorPattern
      $changedFileCustomProperties[$fn]['UNEXPECTED'] = $true
      Write-Output "PrecommitHook not passing: committed file name did not match : $ProjectKindAndNameExtractorPattern"
      return $exitcode
    }
  }

  Write-Debug ("Changed File Custom Properties = $(Write-HashIndented $changedFileCustomProperties 0 2)" )

  # Create a list of Projects having changed files
  # Assign the language(s) of a project based on presence of certain files
  # presence of .csproj or .psd1 or .sql in the project (latest commit)

  # call jenkins to run the CI analyze/build/test/package/deploy pipeline

  $exitcode
}

