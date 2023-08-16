$ScriptblockChocolateyPackages = {

  param (
    [string[]] $chocolateyPackageNames
    , [string[]] $tagnames
    , [hashtable] $ansibleInventoryStructure
  )

  $ChocolateyPackageInfos = $($ansibleInventoryStructure.SwCfgInfos).ChocolateyPackageInfos

  [System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()
  $addedParametersScriptblock = {
    param(
      [string[]]$addedParameters
    )
    if ($addedParameters) {
      foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
      # [void]$sbAddedParameters.Append('"')
      $sbAddedParameters.ToString()
      [void]$sbAddedParameters.Clear()
    }
  }

  [void]$sb.Append(@'
- name: install the chocolatey packages
  win_chocolatey:
  name: '{{ item.name }}'
  # version: '{{ item.version }}'
  allow_prerelease: "{{ 'true' if (item.allowprerelease == 'true') else 'false'}}"
  state: "{{ 'absent' if (action_type == 'uninstall') else 'present'}}"
  # {% if item.addedparameters is defined and item.addedparameters|length %}
  # 'package_params: ' "{{ item.addedparameters }}"
  # {% endif %}
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

'@
  )
  for ($index = 0; $index -lt $chocolateyPackageNames.count; $index++) {
    $packageName = $chocolateyPackageNames[$index]
    $packageVersion = $($ChocolateyPackageInfos[$packageName]).Version
    $allowPrerelease = $($ChocolateyPackageInfos[$packageName]).AllowPrerelease
    $addedParameters = . $addedParametersScriptblock $($ChocolateyPackageInfos[$packageName]).AddedParameters

    [void]$sb.Append("        - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
tags: [$($tagnames -join ',')]
ignore_errors: yes
"@
  )
}
