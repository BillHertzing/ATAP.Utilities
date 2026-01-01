<#
.SYNOPSIS
Converts Markdown files to PDF using pandoc with automatic error handling.

.DESCRIPTION
Wraps pandoc conversion with fallback PDF engines and proper error handling.
Handles common MiKTeX and LaTeX issues automatically.

.PARAMETER InputFile
Path to the input Markdown file.

.PARAMETER OutputFile
Path for the output PDF file. If not specified, uses same name as input with .pdf extension.

.PARAMETER PreferredEngine
Preferred PDF engine: xelatex, pdflatex, wkhtmltopdf. Default is xelatex.

.EXAMPLE
ConvertTo-PDF -InputFile "Report.md" -OutputFile "Report.pdf"

.NOTES
AI assisted using Powershell.instructions.md as guidelines
#>

function ConvertTo-PDF {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputFile,

    [Parameter(Mandatory = $false)]
    [string]$OutputFile,

    [Parameter(Mandatory = $false)]
    [ValidateSet('xelatex', 'pdflatex', 'wkhtmltopdf')]
    [string]$PreferredEngine = 'xelatex'
  )

  BEGIN {
    $fn = 'ConvertTo-PDF'
    $mn = 'ATAP.Utilities.Powershell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if (-not $OutputFile) {
      $OutputFile = [System.IO.Path]::ChangeExtension($InputFile, '.pdf')
    }
  }

  PROCESS {
    if (-not $PSCmdlet.ShouldProcess($InputFile, "Convert to PDF")) { return }

    $engines = @($PreferredEngine, 'xelatex', 'wkhtmltopdf', 'pdflatex')

    foreach ($engine in $engines) {
      try {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Attempting conversion with $engine"

        $pandocArgs = @(
          $InputFile
          '-o', $OutputFile
          '--pdf-engine', $engine
        )

        if ($engine -eq 'xelatex') {
          $pandocArgs += @('--variable', 'geometry:margin=1in')
        }

        $result = & pandoc @pandocArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Successfully converted $InputFile to $OutputFile using $engine"
          return $OutputFile
        }
      }
      catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "Failed with $engine : $($_.Exception.Message)"
        continue
      }
    }

    $errorMessage = "All PDF engines failed for $InputFile"
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    throw $errorMessage
  }
}
