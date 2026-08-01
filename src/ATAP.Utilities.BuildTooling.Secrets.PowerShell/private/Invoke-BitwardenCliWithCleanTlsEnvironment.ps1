function Resolve-BitwardenCliNodeExtraCaCertsPath {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter()]
    [string] $FunctionName = 'Resolve-BitwardenCliNodeExtraCaCertsPath',

    [Parameter()]
    [string] $ModuleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
  )

  foreach ($scope in @('Process', 'User', 'Machine')) {
    $configuredPath = [System.Environment]::GetEnvironmentVariable('ATAP_BITWARDEN_NODE_EXTRA_CA_CERTS', $scope)
    if (-not [string]::IsNullOrWhiteSpace($configuredPath) -and (Test-Path -LiteralPath $configuredPath -PathType Leaf)) {
      return $configuredPath
    }
  }

  if ($script:BitwardenCliNodeExtraCaCertsPath -and (Test-Path -LiteralPath $script:BitwardenCliNodeExtraCaCertsPath -PathType Leaf)) {
    return $script:BitwardenCliNodeExtraCaCertsPath
  }

  $certificates = @()
  foreach ($storePath in @('Cert:\CurrentUser\Root', 'Cert:\LocalMachine\Root')) {
    if (Test-Path -LiteralPath $storePath) {
      $certificates += Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -like '*Avast Web/Mail Shield Root*' }
    }
  }

  $certificates = @($certificates | Sort-Object -Property Thumbprint -Unique)
  if ($certificates.Count -eq 0) {
    return $null
  }

  $basePath = $env:LOCALAPPDATA
  if ([string]::IsNullOrWhiteSpace($basePath)) {
    $basePath = [System.IO.Path]::GetTempPath()
  }

  $certificateDirectory = Join-Path -Path $basePath -ChildPath 'ATAP\Certificates'
  $null = New-Item -Path $certificateDirectory -ItemType Directory -Force -ErrorAction Stop

  $pemPath = Join-Path -Path $certificateDirectory -ChildPath 'BitwardenNodeExtraCaCertificates.pem'
  $builder = [System.Text.StringBuilder]::new()
  foreach ($certificate in $certificates) {
    $null = $builder.AppendLine('-----BEGIN CERTIFICATE-----')
    $null = $builder.AppendLine([Convert]::ToBase64String($certificate.RawData, [Base64FormattingOptions]::InsertLineBreaks))
    $null = $builder.AppendLine('-----END CERTIFICATE-----')
  }

  [System.IO.File]::WriteAllText($pemPath, $builder.ToString(), [System.Text.Encoding]::ASCII)
  $script:BitwardenCliNodeExtraCaCertsPath = $pemPath

  if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
    Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level Debug `
      -Message "Exported Windows trusted root certificate bundle for bw Node TLS at '$pemPath'" -Tag 'BitwardenCLI'
  }

  return $pemPath
}

function Invoke-BitwardenCliWithCleanTlsEnvironment {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [scriptblock] $ScriptBlock,

    [Parameter()]
    [string[]] $VariableName = @('OPENSSL_CONF', 'OPENSSL_HOME', 'RANDFILE'),

    [Parameter()]
    [string] $FunctionName = 'Invoke-BitwardenCliWithCleanTlsEnvironment',

    [Parameter()]
    [string] $ModuleName = 'ATAP.Utilities.BuildTooling.Secrets.PowerShell'
  )

  $savedValues = @{}

  $savedValues['NODE_EXTRA_CA_CERTS'] = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Process')
  if ([string]::IsNullOrWhiteSpace($savedValues['NODE_EXTRA_CA_CERTS']) -or -not (Test-Path -LiteralPath $savedValues['NODE_EXTRA_CA_CERTS'] -PathType Leaf)) {
    $nodeExtraCaCertsPath = Resolve-BitwardenCliNodeExtraCaCertsPath -FunctionName $FunctionName -ModuleName $ModuleName
    if (-not [string]::IsNullOrWhiteSpace($nodeExtraCaCertsPath)) {
      [System.Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $nodeExtraCaCertsPath, 'Process')
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level Debug `
          -Message "Temporarily setting NODE_EXTRA_CA_CERTS for bw invocation to '$nodeExtraCaCertsPath'" -Tag 'BitwardenCLI'
      }
    }
  }

  foreach ($name in $VariableName) {
    if ([string]::IsNullOrWhiteSpace($name)) {
      continue
    }

    $savedValues[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
    if ($null -ne $savedValues[$name]) {
      if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
        Write-PSFMessage -FunctionName $FunctionName -ModuleName $ModuleName -Level Debug `
          -Message "Temporarily clearing inherited Process env '$name' before bw invocation" -Tag 'BitwardenCLI'
      }

      Remove-Item -LiteralPath "Env:$name" -Force -ErrorAction SilentlyContinue
    }
  }

  try {
    & $ScriptBlock
  }
  finally {
    foreach ($name in $savedValues.Keys) {
      $value = $savedValues[$name]
      if ($null -eq $value) {
        Remove-Item -LiteralPath "Env:$name" -Force -ErrorAction SilentlyContinue
      }
      else {
        [System.Environment]::SetEnvironmentVariable($name, [string]$value, 'Process')
      }
    }
  }
}
