#Requires -Version 7.0
function Expand-DatabaseChangePackage {
  <#
.SYNOPSIS
    Unpacks a database change package (.nupkg) to a destination folder for inspection or deployment.

.DESCRIPTION
    Extracts all files from a .nupkg archive to the specified destination folder using
    System.IO.Compression.ZipFile. When no destination is supplied, a temp folder named
    dbpkg-expand-<GUID> is created under $env:TEMP. Returns the absolute path of the
    destination folder.

    The caller is responsible for cleaning up the destination folder when it is a temp
    path (i.e., when -DestinationPath was not explicitly provided).

.PARAMETER NupkgPath
    Path to the .nupkg file to expand. Must exist and have a .nupkg extension.

.PARAMETER DestinationPath
    Optional. Target folder for extraction. Created if it does not exist.
    Defaults to "$env:TEMP\dbpkg-expand-<NewGuid>".

.OUTPUTS
    [string] Absolute path of the destination folder where files were extracted.

.EXAMPLE
    $expanded = Expand-DatabaseChangePackage -NupkgPath 'C:\pkg\ATAPUtilities.Database.1.2.3.nupkg'
    # Extracts to a GUID temp folder; returns that path.

.EXAMPLE
    Expand-DatabaseChangePackage -NupkgPath '.\pkg\ATAPUtilities.Database.1.2.3.nupkg' `
                                  -DestinationPath 'C:\inspect\ATAPUtilities.Database.1.2.3'
    # Extracts to the supplied path; returns it.
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$NupkgPath,

    [Parameter(Mandatory = $false)]
    [string]$DestinationPath
  )

  begin {
    $fn = 'Expand-DatabaseChangePackage'
    $mn = 'ATAP.Utilities.DatabaseManagement.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering $fn" -Tag 'Trace'
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
  }

  process {
    # ── Validate source ───────────────────────────────────────────────────────
    $resolvedNupkg = $null
    try {
      $resolvedNupkg = (Resolve-Path -LiteralPath $NupkgPath -ErrorAction Stop).Path
    } catch {
      $msg = "Nupkg file not found: '$NupkgPath'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
          [System.IO.FileNotFoundException]::new($msg),
          'NupkgNotFound',
          [System.Management.Automation.ErrorCategory]::ObjectNotFound,
          $NupkgPath
        )
      )
    }

    if (-not $resolvedNupkg.EndsWith('.nupkg', [System.StringComparison]::OrdinalIgnoreCase)) {
      $msg = "File does not have a .nupkg extension: '$resolvedNupkg'."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'Error'
      $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
          [System.ArgumentException]::new($msg),
          'InvalidFileExtension',
          [System.Management.Automation.ErrorCategory]::InvalidArgument,
          $resolvedNupkg
        )
      )
    }

    # ── Determine destination ─────────────────────────────────────────────────
    if (-not $DestinationPath) {
      $DestinationPath = Join-Path $env:TEMP "dbpkg-expand-$([System.Guid]::NewGuid().ToString('N'))"
    }

    $destAbsolute = [System.IO.Path]::GetFullPath($DestinationPath)

    if ($PSCmdlet.ShouldProcess($resolvedNupkg, "Extract to '$destAbsolute'")) {
      # Create destination if it does not exist
      if (-not (Test-Path $destAbsolute)) {
        New-Item -ItemType Directory -Path $destAbsolute -Force | Out-Null
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Created destination folder: $destAbsolute" -Tag 'Extract'
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Extracting '$resolvedNupkg' → '$destAbsolute'" -Tag 'Extract'
      [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedNupkg, $destAbsolute)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Extraction complete. Destination: $destAbsolute" -Tag 'Extract'
    }

    Write-Output $destAbsolute
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting $fn" -Tag 'Trace'
  }
}
