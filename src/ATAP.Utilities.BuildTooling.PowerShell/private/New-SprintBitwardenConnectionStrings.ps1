function New-SprintBitwardenConnectionStrings {
  <#
  .SYNOPSIS
    Creates Bitwarden secure-note items containing SQL Server connection
    strings for the sprint database instances.
  .DESCRIPTION
    UNTESTED - first draft of Bitwarden CLI integration for sprint connection
    strings. Uses the bw CLI with the BW_SESSION environment variable.

    Creates one Bitwarden secure-note item per database for the sprint's
    ephemeral instance (Sprint<NNNN>_<username>) — individual items rather
    than grouping all DBs as fields in a single item.

    Also creates items for the permanent QA instance (Sprint<NNNN>QA).

    Item name pattern:
      ATAP_Sprint<NNNN>_<username>_<database>_ConnectionString  (ephemeral)
      ATAP_Sprint<NNNN>_QA_<database>_ConnectionString          (QA)

    Prerequisites:
      - Bitwarden CLI (bw) must be on PATH
      - $env:BW_SESSION must be set (login script sets this at logon)
      - The vault must be unlocked
  .PARAMETER SprintNumber
    The sprint number (e.g., '0005').
  .PARAMETER DatabaseHost
    Host address for the SQL Server instances.
  .PARAMETER Username
    The current user's name, used in the Development environment label.
  .OUTPUTS
    Array of PSCustomObjects with instanceName, secretName, environment, fields, created, and error fields.
  .EXAMPLE
    New-BitwardenSprintConnectionStrings -SprintNumber '0005' -DatabaseHost 'localhost' -Username 'whertzing'
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
    UNTESTED: This function has NOT been validated against a live Bitwarden vault.
    READY FOR TESTING after sprint-0006 changes.
    TODO: Verify bw create item payload format with current BW CLI version.
    TODO: Determine if connection strings should use Integrated Security or
          SQL authentication (currently uses Integrated Security).
    TODO: Determine if TrustServerCertificate should be configurable.
  .LINK
    New-SprintStage2
  #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SprintNumber,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseHost,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Username
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    # Validate BW_SESSION
    if ([string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
      throw 'BW_SESSION environment variable is not set. Cannot create Bitwarden items.'
    }

    # Validate bw CLI is available
    if (-not (Get-Command -Name 'bw' -ErrorAction SilentlyContinue)) {
      throw 'Bitwarden CLI (bw) is required but was not found on PATH.'
    }
  }

  process {
    # Define sprint SQL instances — ephemeral sprint instance and permanent QA
    $instances = @(
      @{
        InstanceName  = "Sprint${SprintNumber}_${Username}"
        NamespacePart = $Username      # used in the secret key
      }
      @{
        InstanceName  = "Sprint${SprintNumber}QA"
        NamespacePart = 'QA'           # used in the secret key
      }
    )

    # Databases to create individual connection string secrets for
    $databases = @('master', 'ATAPUtilities', 'AceCommander')

    $results = [System.Collections.ArrayList]::new()

    foreach ($inst in $instances) {
      $instanceName = $inst.InstanceName
      $nsPart = $inst.NamespacePart

      foreach ($db in $databases) {
        $secretName = "ATAP_Sprint${SprintNumber}_${nsPart}_${db}_ConnectionString"

        $entry = [PSCustomObject]@{
          instanceName = $instanceName
          secretName   = $secretName
          database     = $db
          created      = $false
          error        = $null
        }

        # Connection string for this instance + database
        # UNTESTED: Assumes SQL Server with Integrated Security.
        # TODO: Make TrustServerCertificate configurable via parameter.
        $connStr = "Server=${DatabaseHost}\${instanceName};Database=${db};Integrated Security=True;TrustServerCertificate=True;"

        # Build the Bitwarden item JSON — one item per DB, notes hold the connection string
        # UNTESTED: Item schema follows Bitwarden CLI v2024+ conventions.
        # TODO: Verify against output of: bw get template item --session $env:BW_SESSION
        $bwItem = @{
          organizationId = $null
          folderId       = $null
          type           = 2            # 2 = Secure Note
          name           = $secretName
          notes          = $connStr
          secureNote     = @{ type = 0 }
          fields         = @()
          reprompt       = 0
        }

        if ($PSCmdlet.ShouldProcess($secretName, 'Create Bitwarden secure note with connection string')) {
          try {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
              -Message "Creating Bitwarden item: $secretName" -Tag 'BitwardenCLI'

            # Encode the item JSON for the bw CLI
            $itemJson = $bwItem | ConvertTo-Json -Depth 5 -Compress
            # UNTESTED: Piping to bw encode then bw create item.
            # The BW CLI expects base64-encoded JSON for create operations.
            $encoded = $itemJson | bw encode --session $env:BW_SESSION

            # Create the item in the vault
            $createOutput = $encoded | bw create item --session $env:BW_SESSION 2>&1

            if ($LASTEXITCODE -ne 0) {
              throw "bw create item failed (exit $LASTEXITCODE): $createOutput"
            }

            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Bitwarden item created: $secretName"
            $entry.created = $true
          } catch {
            $errMsg = "Failed to create Bitwarden item '$secretName'. Exception: $($_.Exception.Message)"
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errMsg
            $entry.error = $errMsg
          }
        }

        [void]$results.Add($entry)
      }
    }

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
