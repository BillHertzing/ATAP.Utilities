<#
.SYNOPSIS
    Imports seed data into the Tags database after Flyway versioned migrations complete.

.DESCRIPTION
    This callback script is executed by Flyway after all versioned migrations have been applied.
    It imports seed data from CSV files using a hierarchical approach that resolves parent references.

.NOTES
    Flyway Callback: afterVersioned
    Database: Tags
    Files: Tags_SeedData.csv, RelationshipTypes_SeedData.csv
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ConnectionString,

    [Parameter(Mandatory = $false)]
    [string]$ServerInstance = $env:FLYWAY_PLACEHOLDERS_SERVERINSTANCE,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = 'Tags'
)

# Import PSFramework for logging if available
try {
    Import-Module PSFramework -ErrorAction Stop
    $usePSFramework = $true
}
catch {
    $usePSFramework = $false
}

function Write-Log {
    param([string]$Message, [string]$Level = 'Information')

    if ($usePSFramework) {
        switch ($Level) {
            'Error' { Write-PSFMessage -Level Warning -Message $Message }
            'Warning' { Write-PSFMessage -Level Warning -Message $Message }
            default { Write-PSFMessage -Level Important -Message $Message }
        }
    }
    else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

# Get script directory for data files
$scriptPath = $PSScriptRoot
$dataPath = Join-Path $scriptPath '..\Data'

Write-Log "Starting Tags database seed data import"
Write-Log "Data path: $dataPath"

# Build connection parameters
$sqlParams = @{
    Database               = $DatabaseName
    TrustServerCertificate = $true
}

if ($ConnectionString) {
    # Parse connection string for server
    if ($ConnectionString -match 'Server=([^;]+)') {
        $sqlParams['ServerInstance'] = $Matches[1]
    }
}
elseif ($ServerInstance) {
    $sqlParams['ServerInstance'] = $ServerInstance
}
else {
    $sqlParams['ServerInstance'] = $env:COMPUTERNAME
}

Write-Log "Connecting to $($sqlParams['ServerInstance'])\$DatabaseName"

try {
    # Import RelationshipTypes first (no dependencies)
    $relTypesFile = Join-Path $dataPath 'RelationshipTypes_SeedData.csv'
    if (Test-Path $relTypesFile) {
        Write-Log "Importing RelationshipTypes from $relTypesFile"

        $relTypes = Import-Csv -Path $relTypesFile -Header 'ResourceKey', 'IsBidirectionalDefault', 'InverseTypeKey', 'DefaultDescription', 'IsActive', 'SortOrder'

        foreach ($rt in $relTypes) {
            $inverseKey = if ($rt.InverseTypeKey -eq 'NULL') { 'NULL' } else { "'$($rt.InverseTypeKey)'" }

            $sql = @"
IF NOT EXISTS (SELECT 1 FROM dbo.RelationshipTypes WHERE ResourceKey = '$($rt.ResourceKey)')
BEGIN
    INSERT INTO dbo.RelationshipTypes (ResourceKey, IsBidirectionalDefault, InverseTypeKey, DefaultDescription, IsActive, SortOrder)
    VALUES ('$($rt.ResourceKey)', $($rt.IsBidirectionalDefault), $inverseKey, '$($rt.DefaultDescription)', $($rt.IsActive), $($rt.SortOrder))
END
"@
            Invoke-Sqlcmd @sqlParams -Query $sql
        }

        Write-Log "RelationshipTypes import complete"
    }

    # Import Tags (hierarchical - requires two passes)
    $tagsFile = Join-Path $dataPath 'Tags_SeedData.csv'
    if (Test-Path $tagsFile) {
        Write-Log "Importing Tags from $tagsFile"

        $tags = Import-Csv -Path $tagsFile -Header 'ParentResourceKey', 'ResourceKey', 'DefaultLabel', 'IsActive', 'SortOrder'

        # First pass: Insert all tags without parent references
        foreach ($tag in $tags) {
            $sql = @"
IF NOT EXISTS (SELECT 1 FROM dbo.Tags WHERE ResourceKey = '$($tag.ResourceKey)')
BEGIN
    INSERT INTO dbo.Tags (ParentTagID, ResourceKey, DefaultLabel, IsActive, SortOrder)
    VALUES (NULL, '$($tag.ResourceKey)', N'$($tag.DefaultLabel)', $($tag.IsActive), $($tag.SortOrder))
END
"@
            Invoke-Sqlcmd @sqlParams -Query $sql
        }

        # Second pass: Update parent references
        foreach ($tag in $tags) {
            if ($tag.ParentResourceKey -ne 'NULL' -and $tag.ParentResourceKey -ne '') {
                $sql = @"
UPDATE dbo.Tags
SET ParentTagID = (SELECT TagID FROM dbo.Tags WHERE ResourceKey = '$($tag.ParentResourceKey)')
WHERE ResourceKey = '$($tag.ResourceKey)'
  AND ParentTagID IS NULL
"@
                Invoke-Sqlcmd @sqlParams -Query $sql
            }
        }

        Write-Log "Tags import complete"
    }

    # Report counts
    $tagCount = (Invoke-Sqlcmd @sqlParams -Query "SELECT COUNT(*) AS Cnt FROM dbo.Tags").Cnt
    $relTypeCount = (Invoke-Sqlcmd @sqlParams -Query "SELECT COUNT(*) AS Cnt FROM dbo.RelationshipTypes").Cnt

    Write-Log "Import summary: $tagCount tags, $relTypeCount relationship types"
}
catch {
    Write-Log "Error during import: $($_.Exception.Message)" -Level 'Error'
    throw
}

Write-Log "Tags database seed data import completed successfully"
