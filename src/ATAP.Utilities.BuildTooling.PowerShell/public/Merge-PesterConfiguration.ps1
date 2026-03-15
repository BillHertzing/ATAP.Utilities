# Public/Merge-PesterConfiguration.ps1
function Merge-PesterConfiguration {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [PesterConfiguration]$BaseConfig,

    [Parameter(Mandatory)]
    [PesterConfiguration]$OverrideConfig
  )

  $defaultConfig = [PesterConfiguration]::Default
  foreach ($property in $OverrideConfig.PSObject.Properties) {
    $propName = $property.Name
    $value = $OverrideConfig.$propName
    if ($value -ne $defaultConfig.$propName) {
      $BaseConfig.$propName = $value
    }
  }
}
