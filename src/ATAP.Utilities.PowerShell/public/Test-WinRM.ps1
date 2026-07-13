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
    # -ConfigurationName routes the test through a registered session configuration
    # (for example 'ATAP.PS7.Profiled', registered via Register-ProfiledRemotingEndpoint,
    # SC-0267) instead of the default endpoint. Left unset, behavior is unchanged.
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [string] $configurationName

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    if ($useSelfSignedCert -and -not $useSelfSignedCert) {
      throw '-useSelfSignedCert requires the -useSSL switch'
    }

    $sessionOption = $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)
    $scriptBlockToRun = { hostname }

    function RunRemoteCommand {
      Write-PSFMessage -Level Debug -Message $($("-ComputerName $computername -ScriptBlock {$scriptBlockToRun} -Credential $credential.ToString() $(if($useSSL){ ' -useSSL '})") + $(if ($useSelfSignedCert) { ' -SessionOption $(New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck)' }) + $(if ($configurationName) { " -ConfigurationName $configurationName" }))
      $result = ''
      $configurationNameArgs = if ($configurationName) { @{ ConfigurationName = $configurationName } } else { @{} }
      if ($useSSL) {
        if ($useSelfSignedCert) {
          $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential -UseSSL -SessionOption $sessionOption @configurationNameArgs
        }
        else {
          $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential -UseSSL @configurationNameArgs
        }
      }
      else {
        $result = Invoke-Command -ComputerName $computername -ScriptBlock $scriptBlockToRun -Credential $credential @configurationNameArgs
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
