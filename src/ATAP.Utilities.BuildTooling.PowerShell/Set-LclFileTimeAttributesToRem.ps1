
#$rem = Get-ChildItem -r -path \\ncat016\Dropbox\Photo
#$lcl = Get-ChildItem -r -path C:\Dropbox\Photo

$smaller = 0
if ($rem.length -gt $lcl.length) { $smaller = $lcl.length } else { $smaller = $rem.length }
$smaller = 10

for ($i = 0; $i -lt $smaller; $i++) {
  if ($lcl[$i].basename -eq $rem[$i].basename) {
    if ($lcl[$i].CreationTimeUtc -ne $rem[$i].CreationTimeUtc) {
      if ($PSCmdlet.ShouldProcess("$rem[$i].name", 'Copy CreationTimeUTC ')) {
        $lcl[$i].CreationTimeUtc = $rem[$i].CreationTimeUtc 
      }
    }
    if ($lcl[$i].LastWriteTimeUtc -ne $rem[$i].LastWriteTimeUtc) {
      if ($PSCmdlet.ShouldProcess("$rem[$i].name", 'Copy LastWriteTimeUtc ')) {
        $lcl[$i].LastWriteTimeUtc = $rem[$i].LastWriteTimeUtc 
      }
    }
  }
  else {
    Write-Output "at index $i, lcl = $lcl[$i].basename, rem = $rem[$i].basename"
  }
}
  