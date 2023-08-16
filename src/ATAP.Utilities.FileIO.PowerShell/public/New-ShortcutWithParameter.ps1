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
function New-ShortcutWithParameter {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # ShortcutPath help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    #[ValidateCount(0,5)]
    #[ValidateSet("sun", "moon", "earth")]
    #[Alias('CN')]
    [string]$ShortcutPath
    , # TargetPath help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    #[ValidateCount(0,5)]
    #[ValidateSet("sun", "moon", "earth")]
    #[Alias('CN')]
    [string]$TargetPath
    , # Parameter help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    #[ValidateCount(0,5)]
    #[ValidateSet("sun", "moon", "earth")]
    #[Alias('CN')]
    [string]$Parameter
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $WshShell = New-Object -ComObject WScript.Shell
  }

  PROCESS {
    if ($pscmdlet.ShouldProcess('Target', 'Operation')) {


      $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
      $Shortcut.TargetPath = $TargetPath
      $Shortcut.Arguments = $Parameter
      $Shortcut.Save()
      Write-PSFMessage -Level Debug -Message 'Shortcut created at: $ShortcutPath' -Tag 'Trace'
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
