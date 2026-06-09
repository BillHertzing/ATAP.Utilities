function New-DatabaseSqlCommand {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $CommandText,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [int] $CommandTimeout = 30,

    [Parameter(Mandatory = $false)]
    [System.Data.CommandType] $CommandType = [System.Data.CommandType]::Text
  )

  if ($null -eq $SqlConnection) {
    throw 'SqlConnection cannot be null.'
  }

  if ($SqlConnection.State -ne [System.Data.ConnectionState]::Open -and [string] $SqlConnection.State -ne 'Open') {
    throw "SqlConnection must be open before creating a command. Current state is '$($SqlConnection.State)'."
  }

  $command = $SqlConnection.CreateCommand()
  $command.CommandText = $CommandText
  $command.CommandTimeout = $CommandTimeout
  $command.CommandType = $CommandType

  if ($Parameters) {
    foreach ($key in $Parameters.Keys) {
      $parameter = $command.CreateParameter()
      $parameter.ParameterName = if ($key.StartsWith('@')) { $key } else { "@$key" }
      $parameter.Value = if ($null -eq $Parameters[$key]) { [DBNull]::Value } else { $Parameters[$key] }
      [void] $command.Parameters.Add($parameter)
    }
  }

  return $command
}

function Invoke-DatabaseSqlDataSet {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $CommandText,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [int] $CommandTimeout = 30,

    [Parameter(Mandatory = $false)]
    [System.Data.CommandType] $CommandType = [System.Data.CommandType]::Text
  )

  $command = New-DatabaseSqlCommand `
    -SqlConnection $SqlConnection `
    -CommandText $CommandText `
    -Parameters $Parameters `
    -CommandTimeout $CommandTimeout `
    -CommandType $CommandType

  $adapter = $null
  try {
    $adapter = [Microsoft.Data.SqlClient.SqlDataAdapter]::new($command)
    $dataSet = [System.Data.DataSet]::new()
    [void] $adapter.Fill($dataSet)
    return , $dataSet
  }
  finally {
    if ($null -ne $adapter -and $adapter -is [System.IDisposable]) {
      $adapter.Dispose()
    }
    if ($command -is [System.IDisposable]) {
      $command.Dispose()
    }
  }
}

function Invoke-DatabaseSqlNonQuery {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $CommandText,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [int] $CommandTimeout = 30
  )

  $command = New-DatabaseSqlCommand `
    -SqlConnection $SqlConnection `
    -CommandText $CommandText `
    -Parameters $Parameters `
    -CommandTimeout $CommandTimeout

  try {
    return $command.ExecuteNonQuery()
  }
  finally {
    if ($command -is [System.IDisposable]) {
      $command.Dispose()
    }
  }
}

function Invoke-DatabaseSqlScalar {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $CommandText,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [int] $CommandTimeout = 30
  )

  $command = New-DatabaseSqlCommand `
    -SqlConnection $SqlConnection `
    -CommandText $CommandText `
    -Parameters $Parameters `
    -CommandTimeout $CommandTimeout

  try {
    return $command.ExecuteScalar()
  }
  finally {
    if ($command -is [System.IDisposable]) {
      $command.Dispose()
    }
  }
}

function Invoke-DatabaseSqlQuery {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object] $SqlConnection,

    [Parameter(Mandatory = $true)]
    [string] $CommandText,

    [Parameter(Mandatory = $false)]
    [hashtable] $Parameters,

    [Parameter(Mandatory = $false)]
    [int] $CommandTimeout = 30
  )

  $command = New-DatabaseSqlCommand `
    -SqlConnection $SqlConnection `
    -CommandText $CommandText `
    -Parameters $Parameters `
    -CommandTimeout $CommandTimeout

  $reader = $null
  try {
    $reader = $command.ExecuteReader()
    while ($reader.Read()) {
      $row = [ordered] @{}
      for ($i = 0; $i -lt $reader.FieldCount; $i++) {
        $value = $reader.GetValue($i)
        if ($value -is [DBNull]) {
          $value = $null
        }
        $row[$reader.GetName($i)] = $value
      }
      [PSCustomObject] $row
    }
  }
  finally {
    if ($null -ne $reader -and $reader -is [System.IDisposable]) {
      $reader.Dispose()
    }
    if ($command -is [System.IDisposable]) {
      $command.Dispose()
    }
  }
}
