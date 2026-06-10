function Convert-DiagramsToImages {
  <#
  .SYNOPSIS
  Renders PlantUML and Draw.io diagram sources into image files.

  .DESCRIPTION
  Convert-DiagramsToImages accepts diagram files or directories, finds supported
  source diagrams, and mirrors their repository-relative paths under the output
  root. The default output location is the repository-level
  _generated/diagrams directory, which keeps generated documentation artifacts
  out of editable source documentation folders.

  PlantUML files are rendered by invoking Java with a PlantUML jar. Draw.io
  files are exported by invoking the Draw.io desktop command line.

  .PARAMETER Path
  One or more diagram files or directories. Directories are searched
  recursively.

  .PARAMETER OutputRoot
  Directory where rendered images are written. Defaults to _generated/diagrams
  under the repository root.

  .PARAMETER PlantUmlJar
  Path to plantuml.jar.

  .PARAMETER DrawioExe
  Path to draw.io.exe.

  .PARAMETER Format
  Image format to emit. PlantUML and Draw.io both support PNG and SVG.

  .OUTPUTS
  PSCustomObject for each rendered or skipped diagram.

  .EXAMPLE
  Convert-DiagramsToImages -Path .\Database\Documentation

  .EXAMPLE
  Convert-DiagramsToImages -Path .\Database\Documentation, .\src\ATAP.Utilities.IAC.Ansible.Powershell\Documentation -Format SVG

  .NOTES
  Requires Java for PlantUML rendering and Draw.io desktop for Draw.io exports.
  Supports -WhatIf and -Confirm through ShouldProcess.

  .LINK
  https://plantuml.com/command-line
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias('FullName')]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputRoot,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $PlantUmlJar = 'C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $DrawioExe = 'C:\Program Files\draw.io\draw.io.exe',

    [Parameter(Mandatory = $false)]
    [ValidateSet('PNG', 'SVG')]
    [string] $Format = 'PNG'
  )

  begin {
    $fn = 'Convert-DiagramsToImages'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    function Write-DiagramMessage {
      param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug', 'Verbose', 'Warning', 'Error')]
        [string] $Level = 'Verbose'
      )

      if (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level $Level -Message $Message
        return
      }

      switch ($Level) {
        'Debug' { Write-Verbose $Message }
        'Verbose' { Write-Verbose $Message }
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
      }
    }

    function Get-RepositoryRoot {
      $current = (Get-Location).ProviderPath
      while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current '.git')) {
          return $current
        }

        $parent = Split-Path -Path $current -Parent
        if ($parent -eq $current) {
          break
        }

        $current = $parent
      }

      return (Get-Location).ProviderPath
    }

    function Get-DiagramKind {
      param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath
      )

      $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
      switch ($extension) {
        '.drawio' { return 'DrawIO' }
        '.dio' { return 'DrawIO' }
        '.puml' { return 'PlantUML' }
        '.plantuml' { return 'PlantUML' }
        '.pu' { return 'PlantUML' }
        '.uml' { return 'PlantUML' }
        default { return $null }
      }
    }

    function Resolve-DiagramFiles {
      param(
        [Parameter(Mandatory = $true)]
        [string] $InputPath
      )

      $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
      foreach ($item in $resolved) {
        $pathItem = Get-Item -LiteralPath $item.ProviderPath -ErrorAction Stop
        if ($pathItem.PSIsContainer) {
          Get-ChildItem -LiteralPath $pathItem.FullName -Recurse -File |
            Where-Object { Get-DiagramKind -FilePath $_.FullName }
        }
        elseif (Get-DiagramKind -FilePath $pathItem.FullName) {
          $pathItem
        }
      }
    }

    $repoRoot = Get-RepositoryRoot
    if (-not $OutputRoot) {
      $OutputRoot = Join-Path $repoRoot '_generated\diagrams'
    }

    $outputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)
    $extension = $Format.ToLowerInvariant()

    Write-DiagramMessage -Level Debug -Message "Starting $fn with output root '$outputRootFull'."
  }

  process {
    foreach ($inputPath in $Path) {
      foreach ($diagram in Resolve-DiagramFiles -InputPath $inputPath) {
        $kind = Get-DiagramKind -FilePath $diagram.FullName
        $relativeSource = [System.IO.Path]::GetRelativePath($repoRoot, $diagram.FullName)
        $relativeDirectory = Split-Path -Path $relativeSource -Parent
        $destinationDirectory = if ($relativeDirectory) {
          Join-Path $outputRootFull $relativeDirectory
        }
        else {
          $outputRootFull
        }
        $destinationFileName = '{0}.{1}' -f [System.IO.Path]::GetFileNameWithoutExtension($diagram.Name), $extension
        $destinationPath = Join-Path $destinationDirectory $destinationFileName

        $needsRender = -not (Test-Path -LiteralPath $destinationPath) -or
          ((Get-Item -LiteralPath $destinationPath).LastWriteTimeUtc -lt $diagram.LastWriteTimeUtc)

        if (-not $needsRender) {
          [pscustomobject]@{
            Source = $diagram.FullName
            Output = $destinationPath
            Kind = $kind
            Format = $Format
            Status = 'Current'
          }
          continue
        }

        if ($kind -eq 'PlantUML' -and -not (Test-Path -LiteralPath $PlantUmlJar -PathType Leaf)) {
          throw "PlantUML jar was not found at '$PlantUmlJar'."
        }

        if ($kind -eq 'DrawIO' -and -not (Test-Path -LiteralPath $DrawioExe -PathType Leaf)) {
          throw "Draw.io executable was not found at '$DrawioExe'."
        }

        if ($PSCmdlet.ShouldProcess($destinationPath, "Render $kind diagram")) {
          if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            $null = New-Item -Path $destinationDirectory -ItemType Directory -Force
          }

          try {
            if ($kind -eq 'PlantUML') {
              Write-DiagramMessage -Level Debug -Message "Rendering PlantUML '$($diagram.FullName)' to '$destinationPath'."
              $plantUmlFormat = "-t$extension"
              $plantUmlOutputDirectory = Split-Path -Path $destinationPath -Parent
              & java -jar $PlantUmlJar $plantUmlFormat -o $plantUmlOutputDirectory $diagram.FullName
            }
            else {
              Write-DiagramMessage -Level Debug -Message "Exporting Draw.io '$($diagram.FullName)' to '$destinationPath'."
              & $DrawioExe --export --output $destinationPath --format $extension $diagram.FullName
            }

            if ($LASTEXITCODE -ne 0) {
              throw "$kind renderer exited with code $LASTEXITCODE."
            }
          }
          catch {
            Write-DiagramMessage -Level Error -Message "Failed to render '$($diagram.FullName)': $($_.Exception.Message)"
            throw
          }
        }

        [pscustomobject]@{
          Source = $diagram.FullName
          Output = $destinationPath
          Kind = $kind
          Format = $Format
          Status = 'Rendered'
        }
      }
    }
  }

  end {
    Write-DiagramMessage -Level Debug -Message "Completed $fn."
  }
}
