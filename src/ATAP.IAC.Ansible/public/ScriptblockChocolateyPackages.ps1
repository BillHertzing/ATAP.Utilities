function ScriptblockChocolateyPackages  {

  param (
    [string] $name
    ,[object[]] $items
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  #$ChocolateyPackageInfos = $($ansibleInventoryStructure.SwCfgInfos).ChocolateyPackageInfos

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

  [void]$sb.Append(@"
- name: $name
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

"@)
  for ($index = 0; $index -lt $items.count; $index++) {
    # ToDo: configrootkey substitution in the added Parameters
    $addedParameters = . $addedParametersScriptblock $items[$index]['AddedParameters']
    [void]$sb.Append("    - {name: $($items[$index]['Name']), version: $($items[$index]['Version']), AllowPrerelease: $($items[$index]['AllowPrerelease']), AddedParameters: $addedParameters}")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
