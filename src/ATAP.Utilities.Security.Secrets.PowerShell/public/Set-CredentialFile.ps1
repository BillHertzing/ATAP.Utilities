<#
.SYNOPSIS
Prompts for and writes a DPAPI-protected credential file.

.DESCRIPTION
Creates a credential XML file for the current Windows identity. The credential is protected by
Windows DPAPI and can therefore only be read by the same identity on the same host. A missing
credential directory or an existing credential file is never changed unless -Force is supplied.

.PARAMETER SharedSecureCredentialDirectory
Absolute directory that contains the credential XML file.

.PARAMETER CredentialFilename
Leaf filename for the credential XML file. The default includes the current user and computer.

.PARAMETER Force
Permits creation of a missing directory and replacement of an existing credential file.

.OUTPUTS
System.Management.Automation.PSCustomObject
An object describing the credential-file path and completed action. No credential value is returned.

.EXAMPLE
Set-CredentialFile -SharedSecureCredentialDirectory 'C:\ProgramData\ATAP\Credentials' -Force

.EXAMPLE
Set-CredentialFile -SharedSecureCredentialDirectory 'C:\ProgramData\ATAP\Credentials' -WhatIf

.NOTES
This function is intentionally not imported by the machine PowerShell profile. PowerShell
module autoloading resolves it only for callers that need credential-file access.
#>
function Set-CredentialFile {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([System.Management.Automation.PSCustomObject])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not [IO.Path]::IsPathFullyQualified($_)) {
          throw "Credential directory path must be absolute: '$_'."
        }
        $true
      })]
    [string]$SharedSecureCredentialDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^\\/:*?"<>|]+$')]
    [string]$CredentialFilename = "PowershellCredentials-$env:USERNAME-$env:COMPUTERNAME.xml",

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = 'Set-CredentialFile'
    $mn = 'ATAP.Utilities.Security.Secrets.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    $credentialFilePath = Join-Path -Path $SharedSecureCredentialDirectory -ChildPath $CredentialFilename
    $createdDirectory = $false
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $SharedSecureCredentialDirectory -PathType Container)) {
        if (-not $Force) {
          throw "Credential directory does not exist: '$SharedSecureCredentialDirectory'. Use -Force to create it."
        }

        if (-not $PSCmdlet.ShouldProcess($SharedSecureCredentialDirectory, 'Create credential directory')) {
          return [pscustomobject]@{
            CredentialFilePath = $credentialFilePath
            Action             = 'Skipped'
            CreatedDirectory   = $false
          }
        }

        $null = New-Item -ItemType Directory -Path $SharedSecureCredentialDirectory -Force -ErrorAction Stop
        $createdDirectory = $true
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Created credential directory '$SharedSecureCredentialDirectory'."
      }

      $fileExisted = Test-Path -LiteralPath $credentialFilePath -PathType Leaf
      if ($fileExisted -and -not $Force) {
        throw "Credential file already exists: '$credentialFilePath'. Use -Force to replace it."
      }

      if (-not $PSCmdlet.ShouldProcess($credentialFilePath, 'Export DPAPI-protected credential')) {
        return [pscustomobject]@{
          CredentialFilePath = $credentialFilePath
          Action             = 'Skipped'
          CreatedDirectory   = $createdDirectory
        }
      }

      $credential = Get-Credential
      if ($null -eq $credential) {
        throw 'Credential prompt returned no credential.'
      }

      $credential | Export-Clixml -LiteralPath $credentialFilePath -Force -ErrorAction Stop
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Exported credential file '$credentialFilePath'."

      return [pscustomobject]@{
        CredentialFilePath = $credentialFilePath
        Action             = if ($fileExisted) { 'Replaced' } else { 'Created' }
        CreatedDirectory   = $createdDirectory
      }
    }
    catch {
      $errorMessage = "Failed to write credential file '$credentialFilePath'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
