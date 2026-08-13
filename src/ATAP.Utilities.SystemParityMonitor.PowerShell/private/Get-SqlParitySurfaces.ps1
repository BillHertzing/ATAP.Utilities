function Get-SqlParitySurfaces {
  [CmdletBinding()]
  param()

  $surfaces = [System.Collections.Generic.List[object]]::new()
  $localAccountPrefix = [regex]::Escape("$env:COMPUTERNAME\")
  # Engine discovery goes through Win32_Service, the surface the least-privilege matrix names.
  #
  # An earlier revision used Get-Service instead, on the belief that the approved root\cimv2
  # ACE was insufficient for Win32_Service. Measured on both hosts 2026-08-11, that reasoning
  # was half right and the substitute was no better: the namespace ACE (Enable+RemoteEnable,
  # 0x21) is fine and other cimv2 classes query happily, but BOTH Win32_Service and Get-Service
  # were denied, because the Win32_Service provider calls Service Control Manager underneath.
  # The fix was read-only SCM plus per-service query rights (Task 14.72), which unblocks both.
  # CIM is kept because it is the documented surface and needs no second permission model.
  $engineServices = @(Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'MSSQL$*' -and $_.Name -ne 'MSSQLSERVER' } | Sort-Object Name)
  $instanceNames = @($engineServices | ForEach-Object { $_.Name.Substring(6) })
  $surfaces.Add([pscustomobject]@{
      Category = 'SQL'; Item = 'InstanceNames'; Value = ($instanceNames -join ';'); Source = 'Win32_Service'
    })

  foreach ($service in $engineServices) {
    $instanceName = $service.Name.Substring(6)
    $prefix = "Instance/$instanceName"
    # Value shape is deliberately unchanged. Win32_Service could fill the two <not-collected>
    # placeholders with StartName and StartMode, but that would alter every engine row and
    # perturb the Task 14.73 drift baseline. Populating them is a separate, deliberate change.
    $surfaces.Add([pscustomobject]@{
        Category = 'SQL'; Item = "$prefix/EngineService"; Value = "$($service.State)|<not-collected>|<not-collected>"; Source = 'Win32_Service'
      })
    try {
      $instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction Stop).$instanceName
      $serverKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer"
      $tcpKey = "$serverKey\SuperSocketNetLib\Tcp\IPAll"
      $defaults = Get-ItemProperty $serverKey -ErrorAction Stop
      $tcp = Get-ItemProperty $tcpKey -ErrorAction Stop
      $port = Resolve-ParitySqlTcpPort -TcpPort ([string] $tcp.TcpPort) -TcpDynamicPorts ([string] $tcp.TcpDynamicPorts)
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
SELECT name FROM msdb.dbo.sysjobs_view ORDER BY name;
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

      $pathsConform = Test-ParitySqlPathsConform `
        -DefaultData ([string] $defaults.DefaultData) `
        -DefaultLog ([string] $defaults.DefaultLog) `
        -BackupDirectory ([string] $defaults.BackupDirectory) `
        -ExpectedData $expectedData `
        -ExpectedLog $expectedLog `
        -ExpectedBackup $expectedBackup `
        -DatabaseFiles @($files)
      foreach ($row in @(
          @{ Item = "$prefix/Version"; Value = $version; Source = 'SERVERPROPERTY' }
          @{ Item = "$prefix/Logins"; Value = ($logins -join ';'); Source = 'sys.server_principals' }
          @{ Item = "$prefix/ServerRoles"; Value = ($roles -join ';'); Source = 'sys.server_role_members' }
          @{ Item = "$prefix/ServerPermissions"; Value = ($permissions -join ';'); Source = 'sys.server_permissions' }
          @{ Item = "$prefix/AgentJobs"; Value = ($jobs -join ';'); Source = 'msdb.dbo.sysjobs_view' }
          @{ Item = "$prefix/Endpoints"; Value = ($endpoints -join ';'); Source = 'sys.endpoints' }
          @{ Item = "$prefix/Tcp"; Value = "Port=$($tcp.TcpPort)|Dynamic=$($tcp.TcpDynamicPorts)|ConnectionPort=$port"; Source = 'Registry' }
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
