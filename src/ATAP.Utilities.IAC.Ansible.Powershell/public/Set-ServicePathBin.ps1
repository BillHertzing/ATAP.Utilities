function Set-ServicePathBin {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory)]
    [string]$ServiceName,

    [Parameter(Mandatory)]
    [string]$BinPath
  )

  try {
    if ($PSCmdlet.ShouldProcess($ServiceName, "Set binPath to: $BinPath")) {
      $result = sc.exe config $ServiceName binPath= $BinPath

      if ($result -match '\[SC\] ChangeServiceConfig SUCCESS') {
        Write-PSFMessage -Level Important -Message "Set binPath for '$ServiceName' successfully."
      }
      else {
        $errorMessage = "Failed to set binPath for '$ServiceName'. Result: $result"
        Write-PSFMessage -Level Error -Message $errorMessage
        throw $errorMessage
      }
    }
  }
  catch {
    $errorMessage = "Error while setting binPath for '$ServiceName'. Exception: $($_.Exception.Message)"
    Write-PSFMessage -Level Error -Message $errorMessage -Exception $_.Exception
    throw $_
  }
}
