# AI assisted using Powershell.instructions.md as guidelines
# AI Agent Instructions do not perform any logging in this file

<#
.SYNOPSIS
Resolves and validates a parameter value against an allowed list

.DESCRIPTION
Takes a parameter value and validates it against a list of allowed values using case-insensitive comparison.
Returns the correctly cased value from the allowed list if a match is found, otherwise throws an error.

.PARAMETER PValue
The parameter value to validate and resolve

.PARAMETER Allowed
Array of allowed values to validate against

.EXAMPLE
Resolve-ParameterValueToList -PValue "test" -Allowed @("Test", "Prod", "Dev")
Returns "Test" (correctly cased from allowed list)

.EXAMPLE
"staging" | Resolve-ParameterValueToList -Allowed @("Staging", "Production")
Returns "Staging" via pipeline input

.EXAMPLE
Resolve-ParameterValueToList -PValue "invalid" -Allowed @("Valid1", "Valid2")
Throws error because "invalid" is not in the allowed list

.INPUTS
System.String

.OUTPUTS
System.String

.NOTES
DEPRECATED: Use Get-ParameterValueFromNeoConfigurationRoot (alias Get-PVal) with the -ValidValues parameter instead.
Example: Get-PVal -ParameterName 'Env' -originalPSBoundParameters $PSBoundParameters -ValidValues @('Production','Testing')
AI assisted using Powershell.instructions.md as guidelines
Performs case-insensitive validation but returns the correctly cased value from the allowed list

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Resolve-ParameterValueToList {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias('Resolve-PVal')]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PValue,

    [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Allowed
  )

  BEGIN {
    $fn = 'Resolve-ParameterValueToList'
    $mn = 'ATAP.Utilities.Powershell'
    # AI Agent Instructions do not log in this file
    Write-Warning "Resolve-ParameterValueToList is deprecated. Use Get-PVal with -ValidValues instead."
  }

  PROCESS {
    if ($PSCmdlet.ShouldProcess($PValue, 'Validate parameter value against allowed list')) {
      # Snippet used: "Try-Catch-Finally"
      try {
        # Validate parameter
        $PValLC = $PValue.ToString().ToLowerInvariant()
        $match = $Allowed | Where-Object { $_.ToLowerInvariant() -eq $PValLC }

        if ($null -ne $match) {
          # Return the correctly cased value from the allowed list
          $resolvedValue = $match
          return $resolvedValue
        }
        else {
          $errorMessage = "Parameter Value '$PValue' must be one of: $($Allowed -join ', ')."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage -Tag 'Validation', 'Error'
          throw $errorMessage
        }
      }
      catch {
        $errorMessage = "Failed to resolve parameter value '$PValue'. Exception: $($_.Exception.Message)"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
        throw # the unadorned throw will throw the $_ exception and keep the stack trace intact
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
