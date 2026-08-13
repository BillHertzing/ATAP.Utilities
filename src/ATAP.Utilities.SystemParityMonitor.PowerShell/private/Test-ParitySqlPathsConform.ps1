function Test-ParitySqlPathsConform {
  [CmdletBinding()]
  param(
    [AllowNull()]
    [string] $DefaultData,

    [AllowNull()]
    [string] $DefaultLog,

    [AllowNull()]
    [string] $BackupDirectory,

    [Parameter(Mandatory)]
    [string] $ExpectedData,

    [Parameter(Mandatory)]
    [string] $ExpectedLog,

    [Parameter(Mandatory)]
    [string] $ExpectedBackup,

    [AllowEmptyCollection()]
    [string[]] $DatabaseFiles = @()
  )

  begin {
    $fn = 'Test-ParitySqlPathsConform'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
  }

  process {
    if ([string]::IsNullOrWhiteSpace($DefaultData) -or
      [string]::IsNullOrWhiteSpace($DefaultLog) -or
      [string]::IsNullOrWhiteSpace($BackupDirectory)) {
      return $false
    }

    $DefaultData.TrimEnd('\') -ieq $ExpectedData -and
      $DefaultLog.TrimEnd('\') -ieq $ExpectedLog -and
      $BackupDirectory.TrimEnd('\') -ieq $ExpectedBackup -and
      @($DatabaseFiles | Where-Object { $_ -notlike "$ExpectedData\*" -and $_ -notlike "$ExpectedLog\*" }).Count -eq 0
  }

  end {}
}
