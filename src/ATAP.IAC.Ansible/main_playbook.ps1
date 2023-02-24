# Define the main playbook
param (
  [string] $ymlGenericTemplate
  , [string] $Path
)

function Contents {
  param(
    [string] $name
  )
  # $global:settings that are defined per-host are stored in $settingHash
  $lines = @"
- name: Main Playbook
  hosts: Windows
  become: true
  gather_facts: false
  vars:
    action_type: 'Check'
  tasks:
    - name: Include roles
      include_role:
        name: "7zip"
"@

  return $lines
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', 'Main Playbook'
  # Use the Linux newline character
  $ymlContents += $(Contents -split "`r`n") -join "`r"
  Set-Content -Path $Path -Value $ymlContents

