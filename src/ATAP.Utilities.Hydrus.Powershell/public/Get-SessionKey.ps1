
#############################################################################
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: Write examples
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-SessionKey {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern'  )]
  param(
    [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Alias('In')]
    [string] $inputSessionKey
    ,[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('Perms')]
    [string] $requestedPermissions
    ,[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [Alias('CN')]
    [string[]] $computerNames
    ,[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $PassThru
    # , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'KeePass')]
    # [hashtable] $vKeePassVault
    # , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'SecretStore')]
    # [hashtable] $vSecretStoreVault
    # , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'HashiCorp')]
    # [hashtable] $vHashiCorpVault
    # , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    # [PSCredential] $credential
    #, [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $useProfile

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $proto = 'http'
    $hostname = '127.0.0.1'
    $port=45869
    $page='session_key'
    $webRequestArgs = @()
    $webRequestArgsString = $webRequestArgs -join '&'
    switch ($PSCmdlet.ParameterSetName) {
      'DefaultParameterSetNameReplacementPattern' {
      }
      default { throw 'that ParameterSetName has not been implemented yet' }
    }

    function InternalGetSessionKey {

      Write-PSFMessage -Level Debug -Message $("-ComputerName $computername -InputSessionKey $InputSessionKey -proto $proto -hostname $hostname -port $port -page $page -webRequestArgsString $webRequestArgsString")
      $result = ''
      switch ($PSCmdlet.ParameterSetName) {
        'DefaultParameterSetNameReplacementPattern' {
          $headers = @{"Hydrus-Client-API-Access-Key"=$InputSessionKey}
          $URI = [UriBuilder]::new($proto, $hostname, $port, $page, $webRequestArgsString)
          $sessionKey = $($(Invoke-WebRequest -URI $URI -Headers $headers).Content | convertfrom-json).session_key
          if($PassThru) {
            $result = @{
              computerNames          = $computerNames
              RequestedPermissions  = $requestedPermissions
              InputSessionKey = $inputSessionKey
              SessionKey = $sessionKey
            }

          }else {
            $sessionKey
          }
        }
        # ToDo add the other two kinds of vaults
      }
      $result
    }

    $originalPSBoundParameters = $PSBoundParameters

  }

  PROCESS {
    if (-not $PSBoundParameters.ContainsKey('computerNames')) {
      foreach ($obj in $input) {
        if ($obj.PSobject.Properties.Name -contains 'computerNames') {
          $computerName = $obj.computerNames
        }

        # @(,'utat01','utat022')
        Write-Output $(InternalGetSessionKey)
      }
    }
    else {
      foreach ($computerName in $computerNames) {
        Write-Output $(InternalGetSessionKey)
      }
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
#############################################################################

