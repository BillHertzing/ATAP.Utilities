# A function to get the Windows Security Identifier (SID) given a user name
Function Get-SIDfromAccountName {
  [CmdletBinding(DefaultParameterSetName = 'Local')]

  Param(
    [Parameter(mandatory = $true)]$userName
    , [Parameter(ParameterSetName = 'Remote')]
    [Parameter(mandatory = $false)]$ComputerName
  )
  $usracct = ''
  $command = 'Get-CimInstance -Query "Select * from Win32_UserAccount where name = ''$userName''"'
  switch ($PSCmdlet.ParameterSetName) {
    Local {
      # No change to the basee command
    }
    Remote {
      $command = $command + " -ComputerName $ComputerName"
    }
  }
  Write-PSFMessage -Level Debug -Message "command = $command"
  $usracct = Invoke-Expression $command
  return $usracct.sid
}
