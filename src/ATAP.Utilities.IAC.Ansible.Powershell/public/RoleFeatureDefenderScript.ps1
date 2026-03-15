
$allservices = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services
$servicesmatching = $allservices | Where-Object {
    $(Get-ItemProperty -Path $($_.name -replace 'HKEY_LOCAL_MACHINE','HKLM:') -Name 'Description' -ErrorAction SilentlyContinue) -match 'defend'
}
$servicesmatching += $allservices | Where-Object {$_.name -match 'mpssvc'}
$serviceDetails = @()
$servicesmatching | ForEach-Object{
  $path = $_ -replace 'HKEY_LOCAL_MACHINE','HKLM:'
  $name = $($_.name -split '\\')[-1]
  $serviceDetails += @{
    Name = $name
    Start = Get-ItemPropertyValue -Name 'Start' -path $path
    Description = Get-ItemPropertyValue -Name 'Description' -path $path
  }
}
$serviceDetails| ConvertTo-Json -Depth 99
