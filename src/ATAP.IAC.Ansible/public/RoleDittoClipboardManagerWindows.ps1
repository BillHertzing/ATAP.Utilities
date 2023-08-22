

$TaskScriptblock = {

  [void]$sb.Append(@"
  $(. ./ScriptblockChocolateyPackages -packages @(,
  '{name: ditto, version: latest, allowprerelease: false, addedparameters:  }'
  ) -tags @(,'DittoClipboardManagerWindows'))
  $(. ./ScriptblockRegistryValues -RVs @(
    '{path: HKCU:\Software\Ditto, name: NetworkStringPassword, data: "LetMeIn", type: SZ}'
    '{path: HKCU:\Software\Ditto, name: CustomSendToList2, data: "<CustomFriends> </CustomFriends>", type: SZ}'
    '{path: HKCU:\Software\Ditto, name: sendclient_ip_0, data: "utat01", type: SZ}'
    '{path: HKCU:\Software\Ditto, name: sendclient_autosend_0, data: "1", type: dword}'
  ) -tags @(,'DittoClipboardManagerWindows'))

  # Settings (path dblclick and copy paths wth quotes)
"@)
}

$VarScriptblock = {
}

$MetaScriptblock = {
  [void]$sb.Append(@"
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to install Ditto via Chocolatey and configure it
  attribution:
  company: ATAP.org
  role_name: DittoClipboardManagerWindows
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
"@)
  }
