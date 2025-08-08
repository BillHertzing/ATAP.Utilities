function Get-ServicePathBin {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$ServiceName
  )

  process {
    foreach ($name in $ServiceName) {
      try {
        $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$name'"
        [PSCustomObject]@{
          ServiceName = $name
          PathName    = $svc.PathName
        }
      }
      catch {
        Write-PSFMessage -Level Error -Message "Could not retrieve service '$name'. Exception: $($_.Exception.Message)" -Exception $_.Exception
        throw $_
      }
    }
  }
}
