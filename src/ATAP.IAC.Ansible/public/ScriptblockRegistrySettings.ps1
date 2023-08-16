$ScriptblockRegistrySettings = {

  param (
    [string] $playName
    , [string[]] $registrySettingNames
    , [string[]] $tagnames
    , [hashtable] $ansibleInventoryStructure
  )

  $RegistrySettingInfos = $($ansibleInventoryStructure.SwCfgInfos).RegistrySettingInfos

  [void]$sb.Append(@"
  - name: $playName
    win_regedit:
      path: "{{ item.path }}"
      name: "{{ item.name }}"
      data: "{{ item.data|default(none) }}"
      type: "{{ item.type|default('dword') }}"
    loop:

"@
  )
  for ($index = 0; $index -lt $registrySettingsNames.count; $index++) {

    [void]$sb.Append('          - ' + $RegistrySettingInfos[$(RegistrySettingsNames[$index])])
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
tags: [$($tagnames -join ',')]
ignore_errors: yes
"@
  )
}
