<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function _LabelLocationForEllipse {
  [CmdletBinding(
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # ToDo: insert XCenterEllipseCoordinate help description
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $XCenterEllipseCoordinate
    # ToDo: insert YCenterEllipseCoordinate help description
    , [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $YCenterEllipseCoordinate
    # ToDo: insert XEllipseRadius help description
    , [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $XEllipseRadius
    # ToDo: insert YEllipseRadius help description
    , [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $YEllipseRadius
    # ToDo: insert LabelAngle help description
    , [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $LabelAngle
    # ToDo: insert LabelDistance help description
    , [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    $LabelDistance

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function _LabelLocation' -Tag 'Trace'

    $results = [PSCustomObject]@{
      XCoordinate  = 0
      YCoordinate  = 0
      Success      = $false
      ErrorMessage = ''
    }
  }

  PROCESS {
    if ($PSCmdlet.ShouldProcess("Target", "Operation")) {
      try {
        # Convert angle to radians – .NET trigonometric functions use radians.
        $theta = $LabelAngle * [Math]::PI / 180

        # Point *on* the ellipse at that angle
        $xEdge = $XCenterEllipseCoordinate + $XEllipseRadius * [Math]::Cos($theta)
        $yEdge = $YCenterEllipseCoordinate + $YEllipseRadius * [Math]::Sin($theta)

        # Direction vector of length 1 in the same bearing
        $dxUnit = [Math]::Cos($theta)
        $dyUnit = [Math]::Sin($theta)
        # Final label coordinates: move `LabelDistance` further along the same ray
        $xLabel = $xEdge + ($LabelDistance * $dxUnit)
        $yLabel = $yEdge + ($LabelDistance * $dyUnit)

        # ----- update the pre-existing results object --------------------
        $results.XCoordinate = $xLabel  # [double]::Round($xEdge + $LabelDistance * $dx, 3)
        $results.YCoordinate = $yLabel # [double]::Round($yEdge + $LabelDistance * $dy, 3)
        $results.Success = $true
      }
      catch {
        $results.Success = $false
        $results.ErrorMessage = $_.Exception.Message
      }
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function _LabelLocation' -Tag 'Trace'
    return $results
  }
}
