function Get-AnsibleCertificates {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName ='DefaultParameterSetNameReplacementPattern'  )]
  param(
    [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Alias('CN')]
    [string[]] $computerNames
    , [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
    [Alias('Type')]
    [PSCredential] $typeOfCertificate
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'KeePass')]
    [hashtable] $vKeePassVault
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'SecretStore')]
    [hashtable] $vSecretStoreVault
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True , ParameterSetName = 'HashiCorp')]
    [hashtable] $vHashiCorpVault
    # , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    # [PSCredential] $credential
    #, [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] [switch] $useProfile

  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    switch ($PSCmdlet.ParameterSetName) {
      KeePass {
      }
      default { throw 'that ParameterSetName has not been implemented yet' }
    }

    # if ($useSelfSignedCert -and -not $useSelfSignedCert) {
    #   throw '-useSelfSignedCert requires the -useSSL switch'
    # }

    function InternalGetCertificateInfo {

      Write-PSFMessage -Level Debug -Message $("-ComputerName $computername -TypeOfCertificate $typeOfCertificate  typpeOfVault = $($PSCmdlet.ParameterSetName)  Credentialsupplied = TBD")
      $result = ''
      switch ($PSCmdlet.ParameterSetName) {
        KeePass {
          $result = @{
            CertificatePath          = 'FromVault'
            EncryptedPrivateKeyPath  = 'FromVault'
            PrivateKeyPassPhraseFile = 'FromVault'
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
        Write-Output $(InternalGetCertificateInfo)
      }
    }
    else {
      foreach ($computerName in $computerNames) {
        Write-Output $(InternalGetCertificateInfo)
      }
    }
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
