<#
.SYNOPSIS
Retrieves minute-by-minute financial data from Financial Modeling Prep API.

.DESCRIPTION
Downloads historical financial data at 1-minute intervals for a specified symbol and date.
Filters the data for the target date and optionally exports to CSV format.

.PARAMETER ApiKey
Financial Modeling Prep API key. If not provided, will attempt to retrieve from vault using ApiKeyVaultKey parameter.

.PARAMETER ApiKeyVaultKey
Vault key to retrieve the Financial Modeling Prep API key. Default is 'FinancialModelingPrepApiKey'.

.PARAMETER Symbol
Stock symbol to retrieve data for. Default is '%5EDJI' (Dow Jones Industrial Average).

.PARAMETER TargetDate
Target date for historical data in YYYY-MM-DD format. Default is '2025-11-01'.

.PARAMETER OutputPath
Optional path to export the filtered data as CSV.

.OUTPUTS
System.Object[]
Returns an array of financial data objects for the specified symbol and date.

.EXAMPLE
Get-FinancialModelingData -ApiKey 'your_api_key' -TargetDate '2025-11-01' -OutputPath 'DowJones_1min.csv'
Retrieves data and exports to CSV file.

.EXAMPLE
$data = Get-FinancialModelingData -ApiKeyVaultKey 'MyApiKey' -Symbol 'AAPL' -TargetDate '2025-01-15'
Retrieves Apple stock data for January 15, 2025 using API key from vault.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
function Get-FinancialModelingData {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $false, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [string]$ApiKeyVaultKey = 'FinancialModelingPrepApiKey',

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [string]$Symbol = '%5EDJI',

    [Parameter(Mandatory = $false, Position = 3, ValueFromPipelineByPropertyName = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$TargetDate = '2025-11-01',

    [Parameter(Mandatory = $false, Position = 4, ValueFromPipelineByPropertyName = $true)]
    [string]$OutputPath
  )

  BEGIN {
    $fn = 'Get-FinancialModelingData'
    $mn = 'ATAP.Utilities.FinancialAPI'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function started'

    # Load required helper functions
    try {
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1'
      }
    }
    catch {
      $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    }


    # Snippet: Check and populate simple parameter - ApiKey
    if ($PSBoundParameters.ContainsKey('ApiKey')) {
      $ApiKey = Get-PVal -ParameterName 'ApiKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ApiKey' -DefaultValue $ApiKey
    }
    elseif ($PSBoundParameters.ContainsKey('ApiKeyVaultKey') -or -not [string]::IsNullOrWhiteSpace($ApiKeyVaultKey)) {
      # Snippet: Check and populate simple parameter - ApiKeyVaultKey
      $ApiKeyVaultKey = Get-PVal -ParameterName 'ApiKeyVaultKey' -originalPSBoundParameters $PSBoundParameters -dottedPath 'ApiKeyVaultKey' -DefaultValue $ApiKeyVaultKey
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Retrieving API key from vault using key: $ApiKeyVaultKey"
      $ApiKey = Get-VaultPassword -VaultKey $ApiKeyVaultKey
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'API key retrieved successfully from vault'
    }
    else {
      $errorMessage = 'Either ApiKey or ApiKeyVaultKey parameter must be provided'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw $errorMessage
    }

    # # Validate API key is not empty
    # if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    #   $errorMessage = 'API key is empty or null after retrieval'
    #   Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
    #   throw $errorMessage
    # }

    # # Snippet: Check and populate simple parameter - Symbol
    # $Symbol = Get-PVal Symbol $PSBoundParameters Symbol

    # # Snippet: Check and populate simple parameter - TargetDate
    # $TargetDate = Get-PVal TargetDate $PSBoundParameters TargetDate

    # # Snippet: Check and populate simple parameter - OutputPath (optional)
    # if ($PSBoundParameters.ContainsKey('OutputPath')) {
    #   $OutputPath = Get-PVal OutputPath $PSBoundParameters OutputPath
    # }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Retrieving financial data for symbol: $Symbol, date: $TargetDate"
  }

  PROCESS {
    # Snippet: Try-Catch-Finally
    try {
      # Build the API URL - ensure proper URL encoding
      $BaseUrl = "https://financialmodelingprep.com/api/v3/historical-chart/1min?symbol=${Symbol}&apikey=${ApiKey}"

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "API URL constructed (key masked): https://financialmodelingprep.com/api/v3/historical-chart/1min/${Symbol}?apikey=***"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Calling $BaseUrl" -Tag 'RestCall'

      $response = Invoke-RestMethod -Uri $BaseUrl -Method Get -ErrorAction Stop

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Successfully returned from $BaseUrl" -Tag 'RestCall'

      # Check if response is an error message
      if ($response -is [string] -and $response -match 'Error Message|not present') {
        $errorMessage = "API returned error: $response"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw $errorMessage
      }

      # Check if response is empty or null
      if (-not $response -or $response.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Warning -Message "API returned no data for symbol: $Symbol"
        return @()
      }

      # Filter for only the target date (UTC in API response)
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Filtering data for target date: $TargetDate"
      $filtered = $response | Where-Object {
        ($_.date -like "$TargetDate*")
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Found $($filtered.Count) records for date: $TargetDate"

      # Export to CSV if OutputPath is specified
      if ($OutputPath) {
        if ($PSCmdlet.ShouldProcess($OutputPath, 'Export financial data to CSV')) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exporting data to: $OutputPath"
          $filtered | Export-Csv -Path $OutputPath -NoTypeInformation -ErrorAction Stop
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Successfully exported $($filtered.Count) records to $OutputPath"
        }
      }

      return $filtered
    }
    catch {
      $errorMessage = "Failed to retrieve financial data. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      # ToDo: accumulate the errors; potentially add to 'Problems'
      throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
    }
    finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving Function $fn in module $mn"
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
