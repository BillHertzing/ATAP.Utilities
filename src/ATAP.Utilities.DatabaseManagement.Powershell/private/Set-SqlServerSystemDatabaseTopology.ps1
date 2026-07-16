function Set-SqlServerSystemDatabaseTopology {
  <#
  .SYNOPSIS
  Relocates SQL Server system database files to topology-backed data and log paths.

  .DESCRIPTION
  Completes the path work that SQL Server Setup does not perform for master, model,
  msdb, and tempdb. The function updates file metadata and the master startup
  parameters, stops only the target engine service, moves persistent system files,
  restarts the service, and verifies every sys.master_files row for database IDs 1-4.
  Engine binaries and ERRORLOG remain in the SQL installation directory.

  The operation must run locally and elevated on the target SQL Server host. Callers
  performing remote provisioning should launch it in a local elevated process on that
  host after Install-DbaInstance returns.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory)] [string] $DatabaseHost,
    [Parameter(Mandatory)] [string] $SqlInstance,
    [Parameter(Mandatory)] [ValidateRange(1, 65535)] [int] $Port,
    [Parameter(Mandatory)] [string] $DataPath,
    [Parameter(Mandatory)] [string] $LogPath
  )

  $localNames = @('localhost', '.', '127.0.0.1', $env:COMPUTERNAME)
  if ($DatabaseHost -notin $localNames) {
    throw "System database relocation must execute locally on '$DatabaseHost'."
  }
  $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'System database relocation requires an elevated local process.'
  }

  $dataDirectory = $DataPath.TrimEnd('\')
  $logDirectory = $LogPath.TrimEnd('\')
  New-Item -ItemType Directory -Path $dataDirectory, $logDirectory -Force | Out-Null
  $connectionString = "Server=localhost,$Port;Database=master;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=30"
  $connection = [Data.SqlClient.SqlConnection]::new($connectionString)
  $connection.Open()
  try {
    $adapter = [Data.SqlClient.SqlDataAdapter]::new(
      "SELECT DB_NAME(database_id) DatabaseName, name LogicalName, type_desc TypeDesc, physical_name PhysicalName FROM sys.master_files WHERE database_id BETWEEN 1 AND 4",
      $connection)
    $table = [Data.DataTable]::new()
    [void]$adapter.Fill($table)
    $files = @($table.Rows | ForEach-Object {
      $directory = if ($_.TypeDesc -eq 'LOG') { $logDirectory } else { $dataDirectory }
      [pscustomobject]@{
        DatabaseName = [string]$_.DatabaseName
        LogicalName = [string]$_.LogicalName
        TypeDesc = [string]$_.TypeDesc
        PhysicalName = [string]$_.PhysicalName
        TargetPath = Join-Path $directory (Split-Path $_.PhysicalName -Leaf)
      }
    })

    $nonCanonical = @($files | Where-Object {
      $_.PhysicalName -notlike "$dataDirectory\*" -and $_.PhysicalName -notlike "$logDirectory\*"
    })
    if (-not $nonCanonical.Count) {
      return [pscustomobject]@{ Changed = $false; Instance = $SqlInstance; Files = $files; Passed = $true }
    }
    if (-not $PSCmdlet.ShouldProcess("$env:COMPUTERNAME\$SqlInstance", 'Relocate SQL Server system databases')) {
      return [pscustomobject]@{ Changed = $false; Instance = $SqlInstance; Files = $files; Passed = $false; Cancelled = $true }
    }

    foreach ($file in $files) {
      $databaseName = $file.DatabaseName.Replace(']', ']]')
      $logicalName = $file.LogicalName.Replace("'", "''")
      $targetPath = $file.TargetPath.Replace("'", "''")
      $command = $connection.CreateCommand()
      $command.CommandText = "ALTER DATABASE [$databaseName] MODIFY FILE (NAME=N'$logicalName', FILENAME=N'$targetPath')"
      [void]$command.ExecuteNonQuery()
    }
  } finally {
    $connection.Close()
  }

  $instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$SqlInstance
  if ([string]::IsNullOrWhiteSpace($instanceId)) { throw "Registry instance ID not found for '$SqlInstance'." }
  $parameterKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\Parameters"
  $parameters = Get-ItemProperty $parameterKey
  foreach ($property in $parameters.PSObject.Properties | Where-Object Name -match '^SQLArg\d+$') {
    if ($property.Value -like '-d*') {
      Set-ItemProperty $parameterKey $property.Name ("-d" + ($files | Where-Object LogicalName -eq 'master').TargetPath)
    } elseif ($property.Value -like '-l*') {
      Set-ItemProperty $parameterKey $property.Name ("-l" + ($files | Where-Object LogicalName -eq 'mastlog').TargetPath)
    }
  }

  $serviceName = "MSSQL`$$SqlInstance"
  Stop-Service $serviceName -Force
  (Get-Service $serviceName).WaitForStatus('Stopped', [timespan]::FromMinutes(2))
  $moved = @()
  foreach ($file in $files | Where-Object DatabaseName -ne 'tempdb') {
    if ($file.PhysicalName -ine $file.TargetPath) {
      if (Test-Path $file.TargetPath) { throw "System database relocation target already exists: '$($file.TargetPath)'." }
      Move-Item -LiteralPath $file.PhysicalName -Destination $file.TargetPath
      $moved += [pscustomobject]@{ From = $file.PhysicalName; To = $file.TargetPath }
    }
  }
  Start-Service $serviceName
  (Get-Service $serviceName).WaitForStatus('Running', [timespan]::FromMinutes(3))
  Start-Sleep -Seconds 8

  $verificationConnection = [Data.SqlClient.SqlConnection]::new($connectionString)
  $verificationConnection.Open()
  try {
    $adapter = [Data.SqlClient.SqlDataAdapter]::new(
      'SELECT physical_name FROM sys.master_files WHERE database_id BETWEEN 1 AND 4', $verificationConnection)
    $table = [Data.DataTable]::new()
    [void]$adapter.Fill($table)
    $afterFiles = @($table.Rows | ForEach-Object { [string]$_.physical_name })
  } finally {
    $verificationConnection.Close()
  }
  $remaining = @($afterFiles | Where-Object { $_ -notlike "$dataDirectory\*" -and $_ -notlike "$logDirectory\*" })
  if ($remaining.Count) { throw "System database relocation left noncanonical paths: $($remaining -join ', ')" }
  foreach ($file in $files | Where-Object DatabaseName -eq 'tempdb') {
    if ($file.PhysicalName -ine $file.TargetPath -and (Test-Path $file.PhysicalName)) {
      Remove-Item -LiteralPath $file.PhysicalName -Force
    }
  }

  [pscustomobject]@{
    Changed = $true
    Instance = $SqlInstance
    MovedFiles = $moved
    Files = $afterFiles
    Passed = $true
  }
}
