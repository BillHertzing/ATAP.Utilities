#############################################################################
#region Install-DataEncryptionCertificate
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
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Install-DataEncryptionCertificate {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern' )]
    # ToDo: Figure out how to ensure this command can be run on a list of remote computers and a list of users on each
  # ToDo: parameter validation on each computer and as each user
  param (
    [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
   [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [Alias('RequestPath')]
    [string] $DataEncryptionCertificateRequestPath
    , [parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [ValidateScript({ Test-Path $(Split-Path $_) -PathType Container })]
    [Alias('CertificatePath')]
    [string] $DataEncryptionCertificatePath
    ,[parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
    [switch] $Force

  )
  #endregion Parameters

  #region BeginBlock
  BEGIN {
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      if (Test-Path $DataEncryptionCertificatePath) {
      # If a certificate by that name already exists, fail, unless -force is true, then remove the exisitng certificate
      if ($force) {
        if ($PSCmdlet.ShouldProcess($null, "Remove-Item -Path $DataEncryptionCertificatePath")) {
          Remove-Item -Path $DataEncryptionCertificatePath -EA Stop
        }
      }
      else {
        Throw "The Certificate file already exists use -Force to overwrite it: $DataEncryptionCertificatePath"
      }
    }

  # ToDo: validate Certreq.exe is present and executable
}
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    if ($PSCmdlet.ShouldProcess($null, "Create and install a new Data Encryption Certificate $DataEncryptionCertificatePath from $DataEncryptionCertificateRequestPath (certreq -new $DataEncryptionCertificateRequestPath $DataEncryptionCertificatePath) ")) {
      try {
        $DataEncryptionCertificateInstallationResults = CertReq.exe -new $DataEncryptionCertificateRequestPath $DataEncryptionCertificatePath
      }
      catch { # if an exception ocurrs
        # handle the exception
        $where = $PSItem.InvocationInfo.PositionMessage
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        #Log('Error',"CertReq.exe -new  $DataEncryptionCertificateRequestPath $DataEncryptionCertificatePath failed with $FailedItem : $ErrorMessage at `n $where.")
        Throw "CertReq.exe -new  $DataEncryptionCertificateRequestPath $DataEncryptionCertificatePath failed with $FailedItem : $ErrorMessage at `n $where."
      }
    }

    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion Install-DataEncryptionCertificate
#############################################################################


