BeforeAll {
  . (Join-Path $PSScriptRoot '../../private/Enter-CoordResourceLease.ps1')
}

Describe 'Enter-CoordResourceLease' -Tag 'Unit' {
  It 'excludes a second owner until the first lease is disposed' {
    $directory = Join-Path $TestDrive 'state'
    $null = New-Item -ItemType Directory -Path $directory
    $first = Enter-CoordResourceLease -StateDirectory $directory
    try {
      { Enter-CoordResourceLease -StateDirectory $directory } | Should -Throw
    } finally {
      $first.Dispose()
    }
    $second = Enter-CoordResourceLease -StateDirectory $directory
    try { $second.CanWrite | Should -BeTrue } finally { $second.Dispose() }
  }

  It 'does not create a missing state directory' {
    $directory = Join-Path $TestDrive 'missing'
    { Enter-CoordResourceLease -StateDirectory $directory } | Should -Throw
    Test-Path -LiteralPath $directory | Should -BeFalse
  }
}
