# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Gets pattern collections based on specified pattern tags

.DESCRIPTION
Creates and returns a hashtable containing pattern collections for the specified pattern tags.
Internal pattern structure includes Date, Name, email, Category, and Location collections with regular expression patterns.

.PARAMETER PatternTags
Array of strings specifying which pattern tags to include in the result

.EXAMPLE
Get-Patterns -PatternTags @('Date', 'Name')
Returns a hashtable with Date and Name pattern collections

.EXAMPLE
@('email', 'Location') | Get-Patterns
Returns a hashtable with email and Location pattern collections via pipeline

.INPUTS
System.String[]

.OUTPUTS
System.Collections.Hashtable

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

# Snippet used: "New-Cmdlet with String as primary input"
function Get-Patterns {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([hashtable])]
  param (
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $PatternTags
  )

  BEGIN {
    $fn = 'Get-Patterns'
    $mn = 'ATAP.Utilities.Powershell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    try {
      # ToDo: Remove this when packaging works
      if (-not (Get-Command -Name 'Get-ParameterValueFromNeoConfigurationRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
        . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Get-ParameterValueFromNeoConfigurationRoot.ps1"
      }
    }
    catch {
      $errorMessage = "Failed to load Get-ParameterValueFromNeoConfigurationRoot function. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $functionName -ModuleName $moduleName -Level Error -Message $errorMessage
      throw
    }

    # Snippet used: "Check and populate simple parameter"
    $PatternTags = Get-PVal -ParameterName 'PatternTags' -originalPSBoundParameters $PSBoundParameters -dottedPath 'PatternTags' -DefaultValue $PatternTags

    # Internal patterns hashtable structure with regex patterns
    $patterns = @{
      'Date'     = [System.Collections.ArrayList]@(
        # yyyy-mm-dd format
        '(?<year>\d{4})-(?<month>0[1-9]|1[0-2])-(?<day>0[1-9]|[12]\d|3[01])',
        # mm-dd-yyyy format
        '(?<month>0[1-9]|1[0-2])-(?<day>0[1-9]|[12]\d|3[01])-(?<year>\d{4})',
        # "Thursday, September 12" format
        '(?<dayofweek>Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s*(?<month>January|February|March|April|May|June|July|August|September|October|November|December)\s+(?<day>[1-9]|[12]\d|3[01])',
        # ISO 8601 date format
        '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?',
        # Short date formats like 12/25/2023 or 25/12/2023
        '(?<part1>\d{1,2})[\/\-\.](?<part2>\d{1,2})[\/\-\.](?<year>\d{4})'
      )
      'Name'     = [System.Collections.ArrayList]@(
        # Specific PCMSC names
        '(?<name> Tony Edwards | Caryn Harkins | Jennifer Gurss | Kas Shanks|Bob Brown)'
        # First and Last name
        # '(?<firstname>[A-Z][a-z]+)\s+(?<lastname>[A-Z][a-z]+)',
        # # Name with middle initial
        # '(?<firstname>[A-Z][a-z]+)\s+(?<middle>[A-Z]\.?)\s+(?<lastname>[A-Z][a-z]+)',
        # # Professional titles
        # '(?:Dr\.|Mr\.|Mrs\.|Ms\.|Prof\.)\s+(?<name>[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
        # # Single name (first or last)
        # # '(?<name>[A-Z][a-zA-Z\-\'] { 2, })',
        # # Full name with suffix
        # '(?<firstname>[A-Z][a-z]+)\s+(?<lastname>[A-Z][a-z]+)(?:\s+(?<suffix>Jr\. | Sr\. | III | IV))?'
      )
      'email'    = [System.Collections.ArrayList]@(
        # Standard email pattern
        '(?<email>[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z] { 2, })',
        # Email with subdomain
        '(?<email>[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\.[a-zA-Z] { 2, })',
        # Simple email validation
        '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z | a-z] { 2, }\b',
        # Email in angle brackets
        '<(?<email>[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z] { 2, })>',
        # Email with display name
        '(?<displayname>[\w\s]+)\s*<(?<email>[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z] { 2, })>'
      )
      'Category' = [System.Collections.ArrayList]@(
        # Activity-specific patterns (case insensitive)
        '(?i)\b(?<activity>hiking | biking | skiing | snowshoeing | apres | tgif | ride)\b',
        # Exact match for specified activities
        '(?<activity>hiking | biking | skiing | snowshoeing | Apres | TGIF | Ride)',
        # Activities with optional modifiers
        '(?i)(?<modifier>mountain | road | cross-country | downhill)?\s*(?<activity>hiking | biking | skiing | snowshoeing)\b',
        # Event type patterns
        '(?i)\b(?<eventtype>meetup | event | trip | tour | adventure)\b.*(?<activity>hiking | biking | skiing | snowshoeing | apres | tgif | ride)',
        # Activity with gear or equipment
        '(?i)(?<activity>hiking | biking | skiing | snowshoeing)\s+(?<equipment>boots | bike | skis | shoes | gear)'
      )
      'Location' = [System.Collections.ArrayList]@(
        # Specific PCMSC locations
        '(?<location>Maxwells, Kimble Junction|Lucky Ones Coffee|PCMR parking lot near First Time chair lift|xyz)'
        # # City, State format
        # '(?<city>[A-Z][a-zA-Z\s]+), \s*(?<state>[A-Z] { 2 } | [A-Z][a-zA-Z\s]+)',
        # # Street address
        # '(?<number>\d+)\s+(?<street>[A-Z][a-zA-Z\s]+(?:Street | St | Avenue | Ave | Road | Rd | Lane | Ln | Drive | Dr | Boulevard | Blvd))',
        # # GPS coordinates
        # '(?<latitude>-?\d+\.?\d*), \s*(?<longitude>-?\d+\.?\d*)',
        # # Zip code (US format)
        # '(?<zipcode>\d { 5 }(?:-\d { 4 })?)',
        # # Trail or park names
        # '(?<location>[A-Z][a-zA-Z\s]+(?:Trail | Park | Mountain | Lake | River | Creek | Valley | Ridge))'
      )
    }

    $resultHashtable = @{}
  }

  PROCESS {
    foreach ($tag in $PatternTags) {
      if ($PSCmdlet.ShouldProcess($tag, 'Add pattern tag to result')) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Processing pattern tag: $tag"

        # Add the patterns for the requested tag to the result hashtable
        if ($patterns.ContainsKey($tag)) {
          $resultHashtable[$tag] = $patterns[$tag]
        }
        else {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Pattern tag '$tag' not found in available patterns"
        }
      }
    }
  }

  END {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
    return $resultHashtable
  }
}
