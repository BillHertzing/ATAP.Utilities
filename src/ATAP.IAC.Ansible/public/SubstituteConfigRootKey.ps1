# ToDo: Move to Powershell buildtooling
function SubstitueConfigRootKey {
  param(
    [string]$str
  )
  # ToDo: handle multiple substitutions
  if ( $str -match '\$global:configRootKeys\[(["\''])(.*?)["'']]') {
    $configRootKey = $matches[2]
    return  $str -replace '\$global:configRootKeys\[(["\''])(.*?)["'']]',$global:configRootKeys[$configRootKey]
  }
  else {
    return $str
  }
}
