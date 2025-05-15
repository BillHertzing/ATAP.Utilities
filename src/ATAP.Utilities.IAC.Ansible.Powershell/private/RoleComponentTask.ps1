function RoleComponentTask  {

  param (
    [string] $taskName
    ,[string] $taskInfo
    ,[hashtable[]] $playInfos
    ,[string[]] $tagnames
    ,[System.Text.StringBuilder] $sb
  )

  foreach ($play in $playInfos) {
    $ScriptBlockName = $play.Kind -replace 'AnsiblePlayBlock', 'Scriptblock'
    # execute the scriptblock, pass the list of arguments
    $args = @{name = $play.Name; items = $play.Items.Items; tagnames =  @(,$roleName); sb = $sb }
    & $ScriptBlockName @args
  }

  [void]$sb.Append(@"
"@)

}
