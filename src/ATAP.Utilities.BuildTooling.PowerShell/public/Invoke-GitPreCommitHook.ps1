# This script is called when a developer makes a commit on a local git repository
#  It executes in the context of the developer's terminal or IDE
# It expects to be invoked in a repository's root directory
# [pre-commit hook examples (Python)](https://github.com/pre-commit/pre-commit-hooks)

function Invoke-GitPreCommitHook {
  # ensure that by default the Commit will NOT happen
  $exitcode = 1
  $VerbosePreference = 'SilentlyContinue' # Continue  SilentlyContinue
  $DebugPreference = 'SilentlyContinue'
  Write-PSFMessage -Level Debug -Message "Workspace = $([System.Environment]::GetEnvironmentVariable('Workspace'))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Current Working Directory = $(Get-Location)" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable Environment = $($global:configRootKeys['ENVIRONMENTConfigRootKey']) = $([System.Environment]::GetEnvironmentVariable($global:configRootKeys['ENVIRONMENTConfigRootKey']))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable ModuleName = $([System.Environment]::GetEnvironmentVariable('ModuleName'))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable LocalSourceReproDirectory = $([System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory'))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable BranchName = $([System.Environment]::GetEnvironmentVariable('BranchName'))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable RelativeModulePath = $([System.Environment]::GetEnvironmentVariable('RelativeModulePath'))" -Tag 'Jenkins', 'Publish'
  Write-PSFMessage -Level Debug -Message "Environment Variable NU_GET_API_KEY_SECRET = $([System.Environment]::GetEnvironmentVariable('NU_GET_API_KEY_SECRET'))" -Tag 'Jenkins', 'Publish'

  $moduleName = [System.Environment]::GetEnvironmentVariable('ModuleName')
  $localSourceReproDirectory = [System.Environment]::GetEnvironmentVariable('LocalSourceReproDirectory')
  $branchName = [System.Environment]::GetEnvironmentVariable('BranchName')
  $relativeModulePath = [System.Environment]::GetEnvironmentVariable('RelativeModulePath')

  # ToDo: add -fail-fast Environment Variable

  # ToDo: add -force-allow Environment Variable to allow precommit to pass even if checks fail or there are no files in the commit

  # shorthand
  $dirSep = [Regex]::Escape([System.IO.Path]::DirectorySeparatorChar)

  # Regex Patterns used to extract data from Git, expects an opinionated layout to the project's direcotry structure
  $ProjectKindAndNameExtractorPattern = '(?<ProjectKind>' + $dirsep + 'src|test|database' + $dirsep + ')(?<ProjectSubdirectoryName>.*?' + $dirsep + ')'

  # List of AddedChangedModifiedRenamed files in the commit
  $changedFiles = (git diff --name-only --cached --diff-filter=ACMR)
  # ToDo: add error handling might be null on a brand new resoitory or after a git init, or if no files are in the commit
  if ($changedFiles.count -eq 0) {
    # ToDo: support --force-allow
    Write-Output "PrecommitHook not passing: Number of changed files = $($changedFiles.count)"
    return $exitcode
  }
  Write-Debug "Number of changed files = $($changedFiles.count)"

  # Validate all pre-commit requirements, fail the commit if any requirement is not met

  # ToDo: Read dynamic pre-commit checks from vetted source (and validate the checks before using them)
  # ToDo: Read dynamic pre-commit actions from vetted source (and validate the actions before using them)


  # Built-in PreCommit checks

  # Built-in checks per a project's language
  # Language: powershell: Project Subdirectory contains project manifest file (module's subdirectory name matches a file within having the same names and .psd1 suffix)
  # Language: powershell: Project Subdirectory contains project Module file (module's subdirectory name matches a file within having the same names and .psd1 suffix)
  # Language: powershell: Project Module File contains vlid Module file components and optional dot-sourcing commands for public and private subdirectories
  # Test-SheBangLine

  # Language: C#: Project Subdirectory contains .csproj file
  # Language: C#: Project Subdirectory contains Properties subdirectory which contains AssemblyInfo.cs file

  # Language: SQL: Project Subdirectory contains .sql file

  # Language: All: Project Subdirectory contains Documentation subdirectory, which contains a ReadMe.md file
  # Test-GiantFiles
# Test-GiantFiles
# Test-AST
# Test-CaseConflictForPlatforms
# Test-JsonSyntax
# Test-XMLSyntax
# Test-XYAMLSyntax
# Test-MergeConflict
# Test-PrivateKeys
# Test-PrettyJson
# Test-PrettyXML
# Test-PrettyCSharp
# Test-PrettyPowershell
# Test-PrettyJenkins
# Test-TestNames
# Test-Encoding
# Test-ByteOrderMark
# Test-LineEndings

  # Platform: *nix
  # Test-ShebangScriptsAreExecutable

  # Kinds of Projects. Used to validate input that comes from git commands. Opinionated.
  $projectKindStrs = @{'src' = 'src'; 'test' = 'test'; 'database' = 'database' }
  # Project Languages. Used to classify projects based on the scriptblock
  $projectLanguageStrs = @{'C#' = { Write-Debug 'C#' }; 'SQL' = 'SQL'; 'Powershell' = 'Powershell' }

  # List of Projects in the commit (Source, Tests, or Database), and the language (C#, SQL (Database), and Powershell) of each project
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

    }
    else {
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

  # Iterate every project
  # for-each ($PowershellModulesToValidate in $PSMOduleNames) {}
  $relativePathsToPowershellModulesToValidate = @('./ExamplePSModule\ExamplePSModule.psd1')

  # ToDo: add -fail-fast parameter
  $allowCommit = $true
  # Do the 'all' project tests on the appropriate project
  $allowCommit = $true
  # Do each language test on the appropriate project
  $allowCommit = $true
  # Do each kind test on the appropriate project
  $allowCommit = $true

   # ToDo: figure out how to transaction this, in case any of the operations in the 'allow commit' region fails
  if ($allowCommit) {
    # For each Powershell module project having a file in the commit
    $relativePathsToPowershellModulesToValidate | ForEach-Object { $ModulePath = $_
      Write-Debug ("Module path = $ModulePath" )
      if (-not (Test-Path $ModulePath)) {
        Write-Error "Module $ModulePath not found in $(Get-Location) "
      }
      . ./Update-PackageVersion.ps1 #ToDo: remove this line
      # bump up the version (or prerelease string) number in the.psd1 file
      $returnedExitCode = 0
      try {
      $returnedExitCode = Update-PackageVersion $ModulePath
      } catch {
        $resultException = $_.Exception
        $ResultExceptionMessage = $resultException.Message
        Write-Error ('Update-PackageVersion thew an error :' + $ResultExceptionMessage)
        $exitcode = 2
        return $exitcode
      }
      # update the cmdlets, functions, aliases, etc listed in the .psd1, and regenerate the .psm1 (ToDo: update only the portion of the /psm1 for public or private file changes)
    }
    # For each C# module project having a file in the commit
    # bump up the version number in the AssemblyInfo.cs file

  }
  #   bump up the version number in the.psd1 file
  #   update the cmdlets, functions, aliases, etc listed in the .psd1, and regenerate the .psm1 (ToDo: update only the portion of the /psm1 for public or private file changes)
  #   return success, let the commit proceed



  # For each DotNet project having a c#, csproj, or ResX file in the commit,
  #   Validate all 1st level pre-commit requirementsm, fail the commit if any requirement is not met
  #   bump up the version number (including prerelease string) in the AssemblyInfo file
  #   return success, let the commit proceed

  $exitcode = 0
  $exitcode
}


