function Enter-CoordResourceLease {
  <#
  .SYNOPSIS
    Acquires the exclusive local lease for a coordination resource.
  .DESCRIPTION
    The caller must establish custody and the identity of StateDirectory before
    calling. The returned stream owns the lease until disposed. This local lease
    does not establish distributed exclusion or authorize board mutation.
  #>
  [CmdletBinding()]
  [OutputType([System.IO.FileStream])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$StateDirectory
  )

  process {
    $directory = [IO.Path]::GetFullPath($StateDirectory)
    if (-not [IO.Directory]::Exists($directory)) {
      throw "Coordination state directory does not exist: $directory"
    }
    $leasePath = [IO.Path]::Combine($directory, 'resource.lock')
    return [IO.FileStream]::new($leasePath, [IO.FileMode]::OpenOrCreate,
      [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  }
}
