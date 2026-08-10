function Get-SqlParitySurfaces {
  [CmdletBinding()]
  param()

  $surfaces = [System.Collections.Generic.List[object]]::new()
  $localAccountPrefix = [regex]::Escape("$env:COMPUTERNAME\")
  # `SvcParityAudit` has only the approved root\cimv2 Enable/RemoteEnable ACE. That
  # is intentionally insufficient for the Win32_Service query on the deployed hosts.
  # Service Control Manager status queries provide the identity with the required
  # engine discovery without widening the WMI namespace to method execution.
  $engineServices = @(Get-Service -Name 'MSSQL$*' -ErrorAction SilentlyContinue |
      Where-Object Name -ne 'MSSQLSERVER' | Sort-Object Name)
  $instanceNames = @($engineServices | ForEach-Object { $_.Name.Substring(6) })
  $surfaces.Add([pscustomobject]@{
      Category = 'SQL'; Item = 'InstanceNames'; Value = ($instanceNames -join ';'); Source = 'Get-Service'
    })

  foreach ($service in $engineServices) {
    $instanceName = $service.Name.Substring(6)
    $prefix = "Instance/$instanceName"
    $surfaces.Add([pscustomobject]@{
        Category = 'SQL'; Item = "$prefix/EngineService"; Value = "$($service.Status)|<not-collected>|<not-collected>"; Source = 'Get-Service'
      })
    try {
      $instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction Stop).$instanceName
      $serverKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer"
      $tcpKey = "$serverKey\SuperSocketNetLib\Tcp\IPAll"
      $defaults = Get-ItemProperty $serverKey -ErrorAction Stop
      $tcp = Get-ItemProperty $tcpKey -ErrorAction Stop
      $port = [int]$tcp.TcpPort
      $expectedRoot = "C:\LocalDBs\$instanceName"
      $expectedData = "$expectedRoot\Data"
      $expectedLog = "$expectedRoot\Log"
      $expectedBackup = "$expectedRoot\Backup"

      $connection = [Data.SqlClient.SqlConnection]::new(
        "Server=localhost,$port;Database=master;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=15")
      $connection.Open()
      try {
        $query = @'
SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) ProductVersion;
SELECT name, type_desc, is_disabled FROM sys.server_principals
 WHERE type IN ('S','U','G') AND name NOT LIKE '##%' AND name NOT LIKE 'NT SERVICE\%'
 AND name NOT LIKE 'NT AUTHORITY\%' AND name NOT LIKE 'BUILTIN\%' ORDER BY name;
SELECT member.name MemberName, rolep.name RoleName FROM sys.server_role_members rm
 JOIN sys.server_principals rolep ON rolep.principal_id=rm.role_principal_id
 JOIN sys.server_principals member ON member.principal_id=rm.member_principal_id ORDER BY member.name,rolep.name;
SELECT grantee.name Grantee, permission_name, state_desc FROM sys.server_permissions permission
 JOIN sys.server_principals grantee ON grantee.principal_id=permission.grantee_principal_id ORDER BY grantee.name,permission_name,state_desc;
SELECT name FROM msdb.dbo.sysjobs ORDER BY name;
SELECT name, type_desc, state_desc FROM sys.endpoints WHERE endpoint_id >= 2 ORDER BY name;
SELECT physical_name FROM sys.master_files ORDER BY database_id,file_id;
'@
        $command = $connection.CreateCommand(); $command.CommandText = $query
        $reader = $command.ExecuteReader()
        [void]$reader.Read(); $version = [string]$reader.GetValue(0)
        [void]$reader.NextResult(); $logins = @(); while ($reader.Read()) { $logins += ("$($reader.GetValue(0))|$($reader.GetValue(1))|Disabled=$($reader.GetValue(2))" -replace $localAccountPrefix, '<host>\').ToUpperInvariant() }
        [void]$reader.NextResult(); $roles = @(); while ($reader.Read()) { $roles += ("$($reader.GetValue(0))|$($reader.GetValue(1))" -replace $localAccountPrefix, '<host>\').ToUpperInvariant() }
        [void]$reader.NextResult(); $permissions = @(); while ($reader.Read()) { $permissions += ("$($reader.GetValue(0))|$($reader.GetValue(1))|$($reader.GetValue(2))" -replace $localAccountPrefix, '<host>\').ToUpperInvariant() }
        [void]$reader.NextResult(); $jobs = @(); while ($reader.Read()) { $jobs += [string]$reader.GetValue(0) }
        [void]$reader.NextResult(); $endpoints = @(); while ($reader.Read()) { $endpoints += "$($reader.GetValue(0))|$($reader.GetValue(1))|$($reader.GetValue(2))" }
        [void]$reader.NextResult(); $files = @(); while ($reader.Read()) { $files += [string]$reader.GetValue(0) }
        $reader.Close()
      } finally { $connection.Close() }

      $pathsConform = $defaults.DefaultData.TrimEnd('\') -ieq $expectedData -and
        $defaults.DefaultLog.TrimEnd('\') -ieq $expectedLog -and
        $defaults.BackupDirectory.TrimEnd('\') -ieq $expectedBackup -and
        @($files | Where-Object { $_ -notlike "$expectedData\*" -and $_ -notlike "$expectedLog\*" }).Count -eq 0
      foreach ($row in @(
          @{ Item = "$prefix/Version"; Value = $version; Source = 'SERVERPROPERTY' }
          @{ Item = "$prefix/Logins"; Value = ($logins -join ';'); Source = 'sys.server_principals' }
          @{ Item = "$prefix/ServerRoles"; Value = ($roles -join ';'); Source = 'sys.server_role_members' }
          @{ Item = "$prefix/ServerPermissions"; Value = ($permissions -join ';'); Source = 'sys.server_permissions' }
          @{ Item = "$prefix/AgentJobs"; Value = ($jobs -join ';'); Source = 'msdb.dbo.sysjobs' }
          @{ Item = "$prefix/Endpoints"; Value = ($endpoints -join ';'); Source = 'sys.endpoints' }
          @{ Item = "$prefix/Tcp"; Value = "Port=$port|Dynamic=$($tcp.TcpDynamicPorts)"; Source = 'Registry' }
          @{ Item = "$prefix/Paths"; Value = "Data=$($defaults.DefaultData)|Log=$($defaults.DefaultLog)|Backup=$($defaults.BackupDirectory)|FilesConform=$pathsConform"; Source = 'Registry+sys.master_files' }
        )) {
        $surfaces.Add([pscustomobject]@{ Category = 'SQL'; Item = $row.Item; Value = $row.Value; Source = $row.Source })
      }
    } catch {
      $surfaces.Add([pscustomobject]@{
          Category = 'SQL'; Item = "$prefix/AuditError"; Value = $_.Exception.Message; Source = 'Get-SqlParitySurfaces'
        })
    }
  }
  @($surfaces)
}
