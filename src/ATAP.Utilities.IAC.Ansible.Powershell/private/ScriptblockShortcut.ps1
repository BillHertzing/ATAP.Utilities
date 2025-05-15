function ScriptblockShortcut  {

  param (
    [string] $playName
    ,[object[]] $items
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  #$ShortcutInfos = $($ansibleInventoryStructure.SwCfgInfos).ShortcutInfos

  [void]$sb.Append(@"
  - name: $playName

  "@)

  [void]$sb.Append(@'
  ansible.windows.win_powershell:
    executable: pwsh.exe
    script:
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("{{ item.shortcutpath }}")
    $Shortcut.TargetPath = "{{ item.targetpath }}"
    $Shortcut.Arguments = "{{ item.parameter }}"
    $Shortcut.Save()
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

'@)
  for ($index = 0; $index -lt $items.count; $index++) {
    [void]$sb.Append("    - {shortcutpath: $($items[$index]['Shortcutpath']), targetpath: $($items[$index]['Targetpath']), parameter: $($items[$index]['Parameter'])")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
