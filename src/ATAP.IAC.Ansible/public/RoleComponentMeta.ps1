function RoleComponentMeta  {

  param (
    [string] $roleName
    ,[string] $description
    ,[string[]] $dependencies
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  [void]$sb.Append(@"
galaxy_info:
  author: William Hertzing for ATAP.org
  description: $description
  attribution:
  company: ATAP.org
  role_name: $roleName
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: [$($dependencies -join ',')]
"@)

}
