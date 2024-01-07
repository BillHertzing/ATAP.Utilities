function ScriptblockRegistrySettings  {

  param (
    [string] $name
    ,[object[]] $items
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  [void]$sb.Append(@"
- name: $name
  win_regedit:
    path: "{{ item.path }}"
    name: "{{ item.name }}"
    data: "{{ item.data|default(none) }}"
    type: "{{ item.type|default('dword') }}"
  loop:

"@)
  for ($index = 0; $index -lt $items.count; $index++) {
    $data= $data -match $([regex]::Escape($items[$index]['Data'])) ? {SubstitueConfigRootKey $($items[$index]['Data'])} : $($items[$index]['Data'])

    [void]$sb.Append("  - {path: $($items[$index]['Path']), name: $($items[$index]['Name']), data: $data, type: $($items[$index]['Type']),}")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
