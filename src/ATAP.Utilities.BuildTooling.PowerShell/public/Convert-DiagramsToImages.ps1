function Convert-DiagramsToImages {
  <#
        .SYNOPSIS
            Converts PlantUML / DrawIO include‑tags inside a Markdown file to static PNGs and
            ensures a following `![diagram]()` reference.

        .DESCRIPTION
            • Accepts Markdown file paths **from the pipeline** or via the -Path parameter.
            • Renders each `<!-- plantuml: … -->` or `<!-- drawio: … -->` tag to PNG (only when the
              source diagram is newer than the PNG).
            • Adds or updates the following `![diagram](Images/xxx.png)` line.
            • Optional `-ToDocx` turns the updated .md into a .docx via Pandoc.
            • Supports `-WhatIf` / `-Confirm` thanks to `SupportsShouldProcess`.

        .EXAMPLE
            Get-ChildItem *.md | Convert-DiagramsToImages -Verbose -WhatIf

        .NOTES
            AI assisted using Powershell.instructions.md as guidelines
    #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  param(
    # Accept paths from the pipeline **or** -Path parameter
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
    [Alias('FullName')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $Path,

    # Rendering / output settings
    [string] $ImageDir = 'Images',
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $PlantUmlJar = 'C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar',
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $DrawioExe = 'C:\Program Files\draw.io\draw.io.exe',

    # DOCX generation
    [switch] $ToDocx,
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string] $PandocExe = 'C:\ProgramData\chocolatey\bin\pandoc.exe',
    [string] $ReferenceDoc = ''
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Entering function Convert-DiagramsToImages"

    function Invoke-PngUpdate {
      param(
        [ValidateSet('plantuml', 'drawio')][string] $Type,
        [string] $SourceAbs,
        [string] $PngAbs,
        [string] $PngDir,
        [System.Management.Automation.PSCmdlet] $PSCmdlet
      )

      # Only proceed if ShouldProcess approves
      if (-not $PSCmdlet.ShouldProcess($PngAbs, 'Render diagram to PNG')) { return }

      $needsRender = -not (Test-Path $PngAbs) -or ((Get-Item $PngAbs).LastWriteTime -lt (Get-Item $SourceAbs).LastWriteTime)
      if (-not $needsRender) { return }

      try {
        switch ($Type) {
          'plantuml' {
            Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Rendering PlantUML → $PngAbs"
            java -jar $PlantUmlJar -tpng $SourceAbs -o $PngDir | Out-Null
            Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Successfully rendered PlantUML → $PngAbs"
          }
          'drawio' {
            Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Exporting DrawIO → $PngAbs"
            & $DrawioExe --export --output "$PngAbs" --format png "$SourceAbs" | Out-Null
            Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Successfully exported DrawIO → $PngAbs"
          }
        }
      }
      catch {
        $errorMessage = "Failed to render diagram. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Error -Message $errorMessage
        throw
      }
      finally {
        Write-PSFMessage -FunctionName 'Invoke-PngUpdate' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Exiting Invoke-PngUpdate function"
      }
    }

    # Regex to capture the tag and an optional existing diagram line
    $TagPattern = @'
<!--\s*
 (?<type>plantuml|drawio)\s*:\s*
 (["']?)                 # optional opening quote  → $2
 (?<path>[^"'>]+?)       # diagram path
 \2\s*-->               # closing quote if present
 (?:\s*\r?\n)*          # optional blank lines
 (?<diagram>\s*!\[diagram\]\([^)]*\))?  # an existing diagram line (optional)
'@ -replace '\s+#.*', ''  # strip inline comments so the pattern compiles cleanly

    $tagPattern = "(?<FirstLine><!--\s*(?<type>plantuml|drawio)\s*:\s*([""']){0,1}(?<path>[^>]+?)\1\s*-->)(?<blankLines>:\s*\r?\n)*(?<diagram>\s*!\[diagram\]\([^\)]*\))?"

  }

  PROCESS {
    # Resolve & validate the Markdown file
    $File = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($File.Extension -ne '.md') {
      Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Warning -Message "Skipping non-markdown file: $($File.FullName)"
      return
    }

    $MarkdownRoot = $File.Directory.FullName
    $Content = Get-Content $File.FullName -Raw -Encoding UTF8
    $state = @{ changed = $false } # track whether we actually modify the file

    $Content = [regex]::Replace(
      $Content, $TagPattern,
      {
        param($m)

        $type = $m.Groups['type'].Value.Trim()
        $srcRel = $m.Groups['path'].Value.Trim()
        $srcAbs = Resolve-Path -LiteralPath (Join-Path $MarkdownRoot $srcRel)

        # Construct output paths
        $pngName = ([IO.Path]::GetFileNameWithoutExtension($srcAbs)) + '.png'
        $pngDir = Join-Path $MarkdownRoot $ImageDir
        $null = if (-not (Test-Path $pngDir) -and $PSCmdlet.ShouldProcess($pngDir, 'Create image directory')) {
          New-Item -ItemType Directory -Path $pngDir | Out-Null
        }

        $pngAbs = Join-Path $pngDir $pngName
        $pngRel = "$ImageDir/$pngName" -replace ' ', '%20'

        Invoke-PngUpdate -Type $type -SourceAbs $srcAbs -PngAbs $pngAbs -PngDir $pngDir -PSCmdlet $PSCmdlet

        # Decide whether to add or update the ![diagram] line
        $diagramLine = "![diagram]($pngRel)"
        $hasDiagramLine = $m.Groups['diagram'].Success

        if ($hasDiagramLine -and $m.Groups['diagram'].Value -eq $diagramLine) {
          # Already correct – leave untouched
          return $m.Value
        }

        $state.changed = $true   # flag for later write‑back

        if ($hasDiagramLine) {
          # Replace existing diagram line
          return ($m.Value -replace [regex]::Escape($m.Groups['diagram'].Value), "`n$diagramLine")
        }
        else {
          # Append a fresh diagram line
          return "$($m.Value)`n$diagramLine"
        }
      },
      'IgnoreCase, Multiline, IgnorePatternWhitespace'
    )

    # Write the Markdown back if modified
    if ($state.changed -and $PSCmdlet.ShouldProcess($File.FullName, 'Update Markdown file')) {
      Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Updating $($File.FullName)"
      Set-Content -LiteralPath $File.FullName -Value $Content -Encoding UTF8
    }

    # Optional DOCX export
    if ($ToDocx) {
      $docxOut = [IO.Path]::ChangeExtension($File.FullName, '.docx')
      if ($PSCmdlet.ShouldProcess($docxOut, 'Generate DOCX via Pandoc')) {
        try {
          $pandocArgs = @(
            "`"$($File.FullName)`"",
            '--from', 'gfm',
            '--to', 'docx',
            '--wrap', 'none',
            '--resource-path', "`"$(Join-Path $MarkdownRoot $ImageDir)`"",
            '--embed-resources',
            '-o', "`"$docxOut`""
          )
          if ($ReferenceDoc) { $pandocArgs += @('--reference-doc', $ReferenceDoc) }
          & $PandocExe @pandocArgs
          Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Successfully generated DOCX: $docxOut"
        }
        catch {
          $errorMessage = "Failed to generate DOCX. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Error -Message $errorMessage
          throw
        }
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName 'Convert-DiagramsToImages' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Leaving function Convert-DiagramsToImages"
  }
}


