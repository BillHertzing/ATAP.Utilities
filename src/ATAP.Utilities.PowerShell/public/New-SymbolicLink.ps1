function New-SymbolicLink {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern' )]
  param(
    [parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()][Alias('symlink')]
    [string] $symbolicLinkPath
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $targetPath
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $force

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    if (-not $(Test-Path $targetPath -PathType Leaf)) {
      $message = "targetPath = $targetPath does not exist"
      Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
      # toDo catch the errors, add to 'Problems'
      Throw $message
    }

    if (-not (Test-Path -Path $(Split-Path -Path $symbolicLinkPath -Parent ) -PathType Container)) {
      $message = "symbolicLinkPath = $symbolicLinkPath; the directory for the new symboliclink does not exist"
      Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
      # toDo catch the errors, add to 'Problems'
      Throw $message
    }

    # TGoDo: switch on something like "heavyvalidation"
    # ToDo vaidate the exisitng directory can be written to by this user

    function MainFunction {
      Write-PSFMessage -Level Debug -Message "symbolicLinkPath $symbolicLinkPath  targetPath $targetPath  force: $force"
    }
    if (-not $force) {
      # fail if the symboliclink already exists
      if ( - $(Test-Path $symbolicLinkPath -PathType Leaf)) {
        $message = "symbolicLinkPath = $symbolicLinkPath already exists, use -force to overwrite it"
        Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
        Throw $message
      }
      else {
        New-Item -ItemType SymbolicLink -Path $symbolicLinkPath -Target $targetPath
      }
    }
    else {
      # remove the symbolicLink
      Remove-Item -Path $symbolicLinkPath -ErrorAction SilentlyContinue
      #create a new symbolicLink
      New-Item -ItemType SymbolicLink -Path $symbolicLinkPath -Target $targetPath
    }

  }

  PROCESS {
    # ToDO - process an array of these pairs or get them through the pipeline
    MainFunction
  }
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  }
}
