function Write-ParityMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string] $FunctionName,

    [Parameter(Mandatory = $true)]
    [string] $ModuleName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Debug', 'Verbose', 'Important', 'Error')]
    [string] $Level,

    [Parameter(Mandatory = $true)]
    [string] $Message,

    [string[]] $Tag
  )

  begin {
  }

  process {
    if (Get-Command -Name 'Write-PSFMessage' -ErrorAction SilentlyContinue) {
      $parameters = @{
        FunctionName = $FunctionName
        ModuleName = $ModuleName
        Level = $Level
        Message = $Message
      }

      if ($Tag) {
        $parameters.Tag = $Tag
      }

      Write-PSFMessage @parameters
    }
  }

  end {
  }
}
