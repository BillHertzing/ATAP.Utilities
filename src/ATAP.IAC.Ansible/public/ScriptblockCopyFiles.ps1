$ScriptblockCopyFiles = {

  param (
    [ordered[]] $filesToCopy
    , [string[]] $tagnames
    , [hashtable] $ansibleInventoryStructure
  )

  $CopyFileInfos = $($ansibleInventoryStructure.SwCfgInfos).CopyFileInfos


  [void]$sb.Append(@'
- name: Copy Source to Target (Copy Files)
  win_copy file:
  source: '{{ item.name }}'
  # version: '{{ item.version }}'
  target: "{{ 'true' if (item.allowprerelease == 'true') else 'false'}}"
  state: "{{ 'absent' if (action_type == 'uninstall') else 'present'}}"
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

'@
  )
  for ($index = 0; $index -lt $filesToCopyNames.count; $index++) {
    $pairName = $filesToCopyNames[$index]
    $source = $($FilesToCopyInfos[$pairName]).Source
    $target = $($FilesToCopyInfos[$pairName]).Target
    $permissions = $($FilesToCopyInfos[$pairName]). Permissions

    # ToDo: add template copy and merge

    [void]$sb.Append("        - {source: $source, target: $target, permissions: $    $permissions = $($FilesToCopyInfos[$pairName]).Target
}")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
tags: [$($tagnames -join ',')]
ignore_errors: yes
"@
  )
}
