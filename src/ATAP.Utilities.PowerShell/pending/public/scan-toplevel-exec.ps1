# AST audit v2: .ps1 files that DEFINE a function AND have top-level executable
# code (script-root statements that are not function definitions and not benign
# 'using' statements). Such code runs on dot-source and/or '&'.
# Each file is classified by role so module-loaded files (the real hazard) stand out.

$root = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items'
$skip = '\\(\.git|node_modules|bin|obj|_generated|packages|TestResults|\.vs)\\'

$files = Get-ChildItem -LiteralPath $root -Recurse -Filter *.ps1 -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch $skip }

$FuncAstType  = [System.Management.Automation.Language.FunctionDefinitionAst]
$CmdAstType   = [System.Management.Automation.Language.CommandAst]
$UsingAstType = [System.Management.Automation.Language.UsingStatementAst]

function Get-Role([string]$rel) {
  switch -Regex ($rel) {
    '(\.Tests\.ps1$)|(\\tests\\)'                                 { 'TEST'; break }
    '\\(Obsolete|archive|_AdminRequiresHoldingPen|OlderDBsForReference)\\' { 'OBSOLETE/ARCHIVE'; break }
    '\\Profiles\\'                                                { 'PROFILE (runs by design)'; break }
    '\\(Plans|Scripts|tools|samples)\\'                           { 'ENTRY-SCRIPT'; break }
    '\\(public|private)\\'                                        { 'MODULE-LOADED'; break }
    default                                                       { 'STANDALONE-SCRIPT' }
  }
}

$report = [System.Collections.Generic.List[object]]::new()

foreach ($f in $files) {
  $tokens = $null; $perr = $null
  try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$perr) }
  catch { continue }
  if (-not $ast) { continue }

  $blocks = @($ast.BeginBlock, $ast.ProcessBlock, $ast.EndBlock) | Where-Object { $_ }
  $topStatements = foreach ($b in $blocks) { $b.Statements }
  if (-not $topStatements) { continue }

  $funcDefs = @($topStatements | Where-Object { $_ -is $FuncAstType })
  if ($funcDefs.Count -eq 0) { continue }
  $funcNames = @($funcDefs | ForEach-Object { $_.Name })

  # Top-level statements that are neither function definitions nor benign 'using' lines.
  $execStatements = @($topStatements | Where-Object {
    -not ($_ -is $FuncAstType) -and -not ($_ -is $UsingAstType)
  })
  if ($execStatements.Count -eq 0) { continue }

  $callsOwn = $false; $guarded = $false
  foreach ($s in $execStatements) {
    foreach ($c in $s.FindAll({ param($n) $n -is $CmdAstType }, $true)) {
      $cn = $c.GetCommandName()
      if ($cn -and ($funcNames -contains $cn)) { $callsOwn = $true }
    }
    if ($s.Extent.Text -match 'MyInvocation') { $guarded = $true }
  }

  $first   = $execStatements | Sort-Object { $_.Extent.StartLineNumber } | Select-Object -First 1
  $snippet = (($first.Extent.Text -split "`r?`n")[0]).Trim()
  if ($snippet.Length -gt 58) { $snippet = $snippet.Substring(0, 55) + '...' }

  $report.Add([pscustomobject]@{
    Role          = Get-Role $f.FullName.Substring($root.Length + 1)
    RelPath       = $f.FullName.Substring($root.Length + 1)
    ExecStmts     = $execStatements.Count
    CallsOwn      = $callsOwn
    Guard         = $guarded
    Line          = $first.Extent.StartLineNumber
    FirstStmt     = $snippet
  })
}

Write-Host ""
Write-Host "Scanned $($files.Count) .ps1 files. Function files with real top-level code: $($report.Count)"
Write-Host ""

foreach ($role in 'MODULE-LOADED','STANDALONE-SCRIPT','ENTRY-SCRIPT','PROFILE (runs by design)','TEST','OBSOLETE/ARCHIVE') {
  $rows = $report | Where-Object Role -eq $role | Sort-Object { -not $_.CallsOwn }, RelPath
  Write-Host ("===== {0}  ({1}) =====" -f $role, @($rows).Count)
  if ($rows) {
    $rows | Format-Table RelPath, ExecStmts, CallsOwn, Guard, Line, FirstStmt -AutoSize -Wrap
  } else { Write-Host "  (none)`n" }
}
