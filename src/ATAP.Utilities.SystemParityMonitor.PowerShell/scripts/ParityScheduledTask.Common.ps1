function Resolve-ParityScheduledTaskBwsCredential {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $CredentialDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateSet('ReadOnly', 'ReadWrite')]
    [string] $TokenPurpose = 'ReadOnly'
  )

  $tokenLabelByPurpose = @{
    ReadOnly = 'CommonCIForBitwardenReadOnly'
    ReadWrite = 'CommonCIForBitwardenReadWrite'
  }

  $currentSamName = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -split '\\')[-1]
  if ([string]::IsNullOrWhiteSpace($CredentialDirectory)) {
    $CredentialDirectory = Join-Path 'C:\ProgramData\ATAP\BitwardenCredentials' $currentSamName
  }

  $tokenLabel = $tokenLabelByPurpose[$TokenPurpose]
  $tokenPath = Join-Path $CredentialDirectory "$env:COMPUTERNAME`_$currentSamName`_BWS_$tokenLabel`_AccessToken.xml"
  if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
    throw "BWS $TokenPurpose access-token file for $tokenLabel was not found at '$tokenPath'. Provision it with Initialize-BWSAccessToken -TokenPurpose $TokenPurpose as the scheduled-task identity."
  }

  $command = Get-Command -Name 'Get-BWSAccessToken' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue
  if (-not $command) {
    try {
      Import-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell' -MinimumVersion '0.1.29' -ErrorAction Stop
    } catch {
      $sourceHelperPath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.BuildTooling.PowerShell\public\Get-BWSAccessToken.ps1'
      if (-not (Test-Path -LiteralPath $sourceHelperPath -PathType Leaf)) {
        throw "Get-BWSAccessToken was not available from the installed module and was not found at '$sourceHelperPath'."
      }

      . $sourceHelperPath
    }

    $command = Get-Command -Name 'Get-BWSAccessToken' -CommandType Function, Cmdlet -ErrorAction Stop
  }

  if (-not $command.Parameters.ContainsKey('TokenPurpose')) {
    throw 'Get-BWSAccessToken must support -TokenPurpose; install ATAP.Utilities.BuildTooling.PowerShell 0.1.29 or newer.'
  }

  $credential = Get-BWSAccessToken -CredentialDirectory $CredentialDirectory -TokenPurpose $TokenPurpose -ErrorAction Stop
  [pscustomobject]@{
    CredentialDirectory = $CredentialDirectory
    TokenPath = $tokenPath
    TokenPurpose = $TokenPurpose
    TokenLabel = $tokenLabel
    Credential = $credential
  }
}

function Invoke-ParityScheduledTaskBwsProbe {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string] $CredentialDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateSet('ReadOnly', 'ReadWrite')]
    [string] $TokenPurpose = 'ReadOnly'
  )

  $tokenResult = Resolve-ParityScheduledTaskBwsCredential -CredentialDirectory $CredentialDirectory -TokenPurpose $TokenPurpose
  $bwsCommand = Get-Command -Name 'bws' -CommandType Application -ErrorAction Stop
  $env:BWS_ACCESS_TOKEN = $tokenResult.Credential.GetNetworkCredential().Password

  try {
    $secretListOutput = & $bwsCommand.Source secret list --output json --color no 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "bws secret list failed with exit code $LASTEXITCODE. Output: $($secretListOutput -join [Environment]::NewLine)"
    }

    $secretCount = @($secretListOutput | ConvertFrom-Json -ErrorAction Stop).Count
    [pscustomobject]@{
      Success = $true
      CredentialDirectory = $tokenResult.CredentialDirectory
      TokenPath = $tokenResult.TokenPath
      TokenPurpose = $tokenResult.TokenPurpose
      TokenLabel = $tokenResult.TokenLabel
      BwsPath = $bwsCommand.Source
      SecretCount = $secretCount
    }
  } finally {
    Remove-Item -LiteralPath Env:BWS_ACCESS_TOKEN -ErrorAction SilentlyContinue
  }
}

function Write-ParityScheduledTaskEvent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Error', 'Warning', 'Information')]
    [string] $EntryType,

    [Parameter(Mandatory = $true)]
    [int] $EventId,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [Parameter(Mandatory = $false)]
    [string] $LogName = 'Application',

    [Parameter(Mandatory = $false)]
    [string] $Source = 'ATAP.SystemParityMonitor'
  )

  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
      New-EventLog -LogName $LogName -Source $Source -ErrorAction Stop
    }

    Write-EventLog -LogName $LogName -Source $Source -EntryType $EntryType -EventId $EventId -Message $Message -ErrorAction Stop
    [pscustomobject]@{
      Success = $true
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      Error = $null
    }
  } catch {
    [pscustomobject]@{
      Success = $false
      LogName = $LogName
      Source = $Source
      EventId = $EventId
      EntryType = $EntryType
      Error = $_.Exception.Message
    }
  }
}
