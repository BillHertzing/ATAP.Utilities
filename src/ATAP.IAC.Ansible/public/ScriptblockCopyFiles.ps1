Function ScriptblockCopyFiles  {

  param (
    [string] $playName
    , [string[]] $items
    , [string[]] $tagnames
    , [hashtable] $ansibleInventoryStructure
  )

  [void]$sb.Append(@"
- name: Copy Source to Target (Copy Files)
  win_copy file:
  src: '{{ item.source }}'
  dest: '{{ item.destination }}'
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

"@)
  for ($index = 0; $index -lt $items.count; $index++) {
    $source = $($items[$index]['Items'])['Source']
    if ($source -match 'ConfigRootKey') { $source = SubstitueConfigRootKey $source }
 $target = $($items[$index]['Items'])['Target']
if ($target -match 'ConfigRootKey') { $target = SubstitueConfigRootKey $target }

    [void]$sb.Append("      - {source: $source, target: $target") #Owner, #ACL
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
