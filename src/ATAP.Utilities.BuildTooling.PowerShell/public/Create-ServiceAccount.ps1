#############################################################################
#region Create-ServiceAccount
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER  state
One of the set ('Present', 'Absent', 'Disabled', 'Active', 'Test')
'Present' - Create the new local user account, its home directory, and the module/profile directories for Core and Desktop Powershell, and copy or link the servicve account's 's powershell profile
'Absent' - Delete the service account's home directory recusivly, and remove the user account
'Report' - return a structure that contains information abou the presence/absence of any of the expected/necessary pieces of a local service account.
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE

ToDo! - Insert PlantUML diagram here how this Ansible Powershell script fits into the Ansible pipeline

.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 3 of using this function
.ATTRIBUTION

.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Create-ServiceAccount {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [ValidateNotNullOrEmpty()][string] $serviceAccount
    , [ValidateNotNullOrEmpty()][string] $serviceAccountPasswordKey
    , [ValidateNotNullOrEmpty()][string] $serviceAccountFullname
    , [ValidateNotNullOrEmpty()][string] $serviceAccountDescription
    , [ValidateNotNullOrEmpty()][string] $serviceAccountUserHomeDirectory
    , [ValidateNotNullOrEmpty()][string] $serviceAccountPowershellCoreProfileSourcePath
    , [ValidateNotNullOrEmpty()][string] $serviceAccountPowershellDesktopProfileSourcePath
    , [ValidateSet('Present', 'Absent', 'Disabled', 'Active', 'Test')][string] $state = 'Present'


  )
  ########################################
  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # Carbon works under both Core and Desktop
    # ToDo wrap in a try catch
    Import-Module Carbon -SkipEditionCheck
    # Is this script running under Ansible? if so the variable $Ansible will be defined, null otherwise
  }
  END {

    # Create Service Account User using carbon if the local user does not exist
    # The password should come from a vault (security vault)
    $password = ConvertTo-SecureString $serviceAccountPasswordKey -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($serviceAccount, $password )
    switch ($state) {
      'Present' {
        $result = [ordered]@{
          Success                         = $false
          InstallCUser                    = $false
          GrantLoginAsAServiceToCUser     = $false
          CreateHomeDirectory             = $false
          GrantFullControlToHomeDirectory = $false
          LinkPowershellCoreProfile       = $false
          LinkPowershellDesktopProfile    = $false
        }
        # The service account user cannot change its own password.
        try {
          Install-CUser -Credential $credential -Description $serviceAccountDescription -FullName $serviceAccountFullname -UserCannotChangePassword
        }
        catch {
          $result.InstallCUser = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to create the user $serviceAccount, error is $PSItem"
          $stringToReturn = $($result | ConvertTo-Yaml)
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return  $stringToReturn
        }
        $result.InstallCUser = $true

        # Grant the new user the right to login as a service
        try {
          Grant-CPrivilege -Identity $serviceAccount -Privilege SeServiceLogonRight
        }
        catch {
          $result.GrantLoginAsAServiceToCUser = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to grant the user $serviceAccount the SeServiceLogonRight privelege , error is $PSItem"
          $stringToReturn = $($result | ConvertTo-Yaml)
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return  $stringToReturn
        }
        $result.GrantLoginAsAServiceToCUser = $trueTest-Privilege -Identity whertzing -Privilege SeServiceLogonRight


        # Create a home directory for the Service Account User
        try {
          # send the command's normal stdout to $null
          New-Item -ItemType directory $serviceAccountUserHomeDirectory -Force > $null
        }
        catch {
          $result.CreateHomeDirectory = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to create the user's home directory $serviceAccountUserHomeDirectory, error is $PSItem"
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return $($result | ConvertTo-Yaml)
        }
        $result.CreateHomeDirectory = $true

        # Set the ACL permissions for the Service Account User's home directory
        try {
          #
          # Grant-CPermission -Identity $serviceAccount -Permission FullControl -Path $serviceAccountUserHomeDirectory   }
        }
        catch {
          $result.GrantFullControlToHomeDirectory = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to set ACL on the home directory $serviceAccountUserHomeDirectory for user $serviceAccount , error is $PSItem"
          $stringToReturn = $($result | ConvertTo-Yaml)
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return  $stringToReturn
        }
        $result.GrantFullControlToHomeDirectory = $true

        # Link the Powershell Core profile for the Service Account to the Service Account User's home directory's Powershell subdirectory
        try {
          # ToDo: Source location is from a module's Resources (?)
          # ToDo: a sync'd location for the production version
          # ToDo: modify the path to the target (another sync'd location) for the development version
          $powershellDirectory = Join-Path $serviceAccountUserHomeDirectory 'PowerShell'
          New-Item -ItemType directory $powershellDirectory -Force > $null
          Remove-Item -Path (Join-Path $powershellDirectory 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue
          New-Item -ItemType SymbolicLink -Path (Join-Path $powershellDirectory 'Microsoft.PowerShell_profile.ps1') -Target $serviceAccountPowershellCoreProfileSourcePath > $null
          $result.LinkPowershellCoreProfile = $PSItem
        }
        catch {
          Write-PSFMessage -Level Error -Message "Failed to link home directory $powershellDirectory to target $serviceAccountPowershellCoreProfileSourcePath for user $serviceAccount , error is $PSItem"
          $stringToReturn = $($result | ConvertTo-Yaml)
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return  $stringToReturn
        }
        $result.LinkPowershellCoreProfile = $true

        # Copy the Powershell Desktop profile for the Service Account to the Service Account User's home directory's WindowsPowershell subdirectory
        try {
          # ToDo: Source content is from the ATAP.Utilities.Powershell module
          # ToDo: Source content should be copied to the profile directory for Production or QualityAssurance. Source content should be linked if the JenkinsController is running with a 'Development' value for the JenkinsControllerEnvironment
          # ToDo: Content is installed to a Source location (Resources) relative to the module installation path (including version (and prerelease?)) when the module is installed
          # ToDo: Content is updated when a new version is released or is in development. When a new production release occurs, the ansible
          # ToDo: modify the path to the target Resources/Profiles/ for the development environment to develop the contents of the Service Account profile
          $powershellDirectory = Join-Path $serviceAccountUserHomeDirectory 'WindowsPowerShell'
          New-Item -ItemType directory $powershellDirectory -Force > $null
          Remove-Item -Path (Join-Path $powershellDirectory 'Microsoft.PowerShell_profile.ps1') -ErrorAction SilentlyContinue
          New-Item -ItemType SymbolicLink -Path (Join-Path $powershellDirectory 'Microsoft.PowerShell_profile.ps1') -Target $serviceAccountPowershellDesktopProfileSourcePath > $null
          $result.LinkPowershellDesktopProfile = $PSItem
        }
        catch {
          Write-PSFMessage -Level Error -Message "Failed to link home directory $powershellDirectory to target $serviceAccountPowershellCoreProfileSourcePath for user $serviceAccount , error is $PSItem"
          $stringToReturn = $($result | ConvertTo-Yaml)
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return  $stringToReturn
        }
        $result.LinkPowershellDesktopProfile = $true
        # Overall Success is now $true
        $result.Success = $true
        if ($Ansible) { $Ansible.Result = $($result | ConvertTo-Yaml) }
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
        break
      }
      'Absent' {
        $result = [ordered]@{
          Success                    = $false
          RemoveCUser                = $false
          RemoveHomeDirectory        = $false
          RemoveACLFromHomeDirectory = $false
        }

        # Remove the home directory for the Service Account User
        try {
          # send the command's normal stdout to $null
          Remove-Item -Recurse $serviceAccountUserHomeDirectory -Force > $null
        }
        catch {
          $result.CreateHomeDirectory = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to delete the user's home directory $serviceAccountUserHomeDirectory, error is $PSItem"
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return $($result | ConvertTo-Yaml)
        }
        $result.RemoveHomeDirectory = $true

        # remove the Service Account User
        try {
          Uninstall-CUser -Username $serviceAccount #-Verbose:$VerbosePreference -Whatif:$WhatIfPreference -Confirm:$ConfirmPreference
        }
        catch {
          $result.InstallCUser = $PSItem
          Write-PSFMessage -Level Error -Message "Failed to create the user $serviceAccount, error is $PSItem"
          Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
          return $($result | ConvertTo-Yaml)
        }
        $result.RemoveCUser = $true

        # Overall Success is now $true
        $result.Success = $true
        if ($Ansible) { $Ansible.Result = $($result | ConvertTo-Yaml) }
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
        break
      }
      'Disabled' {
        $result = [ordered]@{
          Success             = $false
          UserAccountDisabled = $false
        }

        # $result.Success = $true
        if ($Ansible) { $Ansible.Result = $($result | ConvertTo-Yaml) }
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
        break
      }
      'Active' {
        $result = [ordered]@{
          Success             = $false
          UserAccountDisabled = $false
        }
        # $result.Success = $true
        if ($Ansible) { $Ansible.Result = $($result | ConvertTo-Yaml) }
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
        break
      }
      'Test' {
        $result = [ordered]@{
          Success             = $false
          UserAccountExists = $false
          UserAccountDisabled = $false
          LoginAsAServiceEnabled = $false
        }

        # does the Service User Account exist?
        # Does the Service USer Account have the Login As Service  permission
        $result.LoginAsAServiceEnabled =  Test-CPrivilege -Identity $serviceAccount -Privilege SeServiceLogonRight
        # Does the home directory exist?
        # are the ACL permisisons as expected?
        # is there a Powershell Core profile?
        # is there a Powershell Desktop profile
        # if there is a service that is using this Service User Account, report it
        #

        # Overall Success is now $true
        $result.Success = $true
        if ($Ansible) { $Ansible.Result = $($result | ConvertTo-Yaml) }
        Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
        break
      }
    }

  }
}
