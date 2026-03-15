function ScriptblockUserWindows  {

  param (
    [string] $name
    ,[object[]] $items
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  [System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

  [void]$sb.Append(@"
- name: $name
  ansible.windows.win_user:
    name: '{{ item.username }}'
    fullname: '{{ item.fullname }}'
    description: '{{ item.description }}'
    groups: '{{ item.groups }}'
    password: '{{ item.password }}'
  	password_never_expires: true
    account_disabled: false
    state: "{{ 'absent' if (action_type == 'uninstall') else 'present'}}"
  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
  loop:

"@  )
  for ($index = 0; $index -lt $items.count; $index++) {
    [void]$sb.Append("    - {name: $($items[$index]['username']), fullname: $($items[$index]['fullname']), description: $($items[$index]['description']), groups: $($items[$index]['groups']), password: $($items[$index]['password']) ")
    [void]$sb.Append("`n")
  }

  [void]$sb.Append(@"
  tags: [$($tagnames -join ',')]
  ignore_errors: yes

"@)
}
