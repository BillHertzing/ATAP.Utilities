function ScriptblockSymbolicLinks {

  param (
    [string] $playName
    , [object[]] $items
    , [string[]] $tagnames
  )

  [void]$sb.Append(@"
- name: $playName
  ansible.windows.win_powershell:
    executable: pwsh.exe
    script:
      Remove-Item -path {{ item.link }} -ErrorAction SilentlyContinue
      New-Item -ItemType SymbolicLink -path "{{ item.link }}" -Target "{{ item.original }}"
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

"@)
  for ($index = 0; $index -lt $items.count; $index++) {

    $target = SubstituteConfigRootKey $($items[$index])['target']
    $original = SubstituteConfigRootKey $($items[$index])['source']
    [void]$sb.Append("    - {link: $target, original: $original}") # ToDo Owner and ACL
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
