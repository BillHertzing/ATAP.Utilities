function Test-WinRM {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern' )]
  param(
    [parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Alias('CN')]
    [string[]] $computerNames
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [PSCredential] $credential
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $useSSL
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $useSelfSignedCert
    #, [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $useProfile

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    if ($useSelfSignedCert -and -not $useSelfSignedCert) {
      throw '-useSelfSignedCert requires the -useSSL switch'
    }

    # if ($useProfile) {
    #   # this depends upon the `WithProfile` configuration being registered on the remote host
    #   $configurationName = 'WithProfile'
    # }
    $sessionOption = $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)
    $scriptBlockToRun = { hostname }

    function RunRemoteCommand {
      Write-PSFMessage -Level Debug -Message $($("-ComputerName $computername -ScriptBlock {$scriptBlockToRun} -Credential $credential.ToString() $(if($useSSL){ ' -useSSL '})") + $(if ($useSelfSignedCert) { ' -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)' }))
      $result = ''
      if ($useSSL) {
        if ($useSelfSignedCert) {
          $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential -UseSSL -SessionOption $sessionOption
        }
        else {
          $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential -UseSSL
        }
      }
      else {
        $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential
      }
      # $hostpackageInfos[$computerName] = Get-ChocolateyInstalledPackages -CN $computerName
      $result
    }
    $test = $PSBoundParameters
  }

  PROCESS {
    if (-not $PSBoundParameters.ContainsKey('ComputerNames')) {
      foreach ($obj in $input) {
        if ($obj.PSobject.Properties.Name -contains 'ComputerNames') {
          if ($obj.PSobject.Properties.Name -contains 'Credentials') {
            $credential = $obj.Credential
          }
          $ComputerName = $obj.ComputerNames
        }
        # @(,'utat01','utat022')
        Write-Output $(RunRemoteCommand)
      }
    }
    else {
      foreach ($computerName in $ComputerNames) {
        Write-Output $(RunRemoteCommand)
      }
    }

  }
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  }
}
