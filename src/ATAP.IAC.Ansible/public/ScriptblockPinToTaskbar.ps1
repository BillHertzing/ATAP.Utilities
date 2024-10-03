function ScriptblockPinToTaskbar  {
  # This is difficult in Win 10 and win 11. Here are some resources
  # [PowerShell Commands for PinnedItem Item to Taskbar (This PC, User's Profile & Disk D:)](https://learn.microsoft.com/en-us/answers/questions/1309489/powershell-commands-for-pinneditem-item-to-taskbar)

  param (
    [string] $playName
    ,[object[]] $items
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  #$PinToTaskbarInfos = $($ansibleInventoryStructure.SwCfgInfos).PinToTaskbarInfos

  [void]$sb.Append(@"
  - name: $playName

  "@)

  [void]$sb.Append(@'
  # until packages are working, download the script
  ansible.windows.win_powershell: # This method is currently suspect
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
