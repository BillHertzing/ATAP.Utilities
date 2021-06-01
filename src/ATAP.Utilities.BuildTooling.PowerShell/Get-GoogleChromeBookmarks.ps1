

# Attribution: [Testing Google Chrome Bookmarks with PowerShell](https://jdhitsolutions.com/blog/powershell-3-0/2591/friday-fun-testing-google-chrome-bookmarks-with-powershell/) Validate link r by Jeff Hickseturns 200, dated 2012-11-23

#comment based help is here

[cmdletbinding()]

Param (
[Parameter(Position=0)]
[ValidateScript({Test-Path $_})]
[string]$File = "$env:localappdata\Google\Chrome\User Data\Default\Bookmarks",
[switch]$Validate
)

Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

#A nested function to enumerate bookmark folders
Function Get-BookmarkFolder {
[cmdletbinding()]
Param(
[Parameter(Position=0,ValueFromPipeline=$True)]
$Node
)

Process {

 foreach ($child in $node.children) {
   #get parent folder name
   $parent = $node.Name
   if ($child.type -eq 'Folder') {
     Write-Verbose "Processing $($child.Name)"
     Get-BookmarkFolder $child
   }
   else {
        $hash= [ordered]@{
          Folder = $parent
          Name = $child.name
          URL = $child.url
          Added = [datetime]::FromFileTime(([double]$child.Date_Added)*10)
          Valid = $Null
          Status = $Null
        }
        If ($Validate) {
          Write-Verbose "Validating $($child.url)"
          if ($child.url -match "^http") {
            #only test if url starts with http or https
            Try {
              $r = Invoke-WebRequest -Uri $child.url -DisableKeepAlive -UseBasicParsing
              if ($r.statuscode -eq 200) {
                $hash.Valid = $True
              } #if statuscode
              else {
                $hash.valid = $False
              }
              $hash.status = $r.statuscode
              Remove-Variable -Name r -Force
            }
            Catch {
              Write-Warning "Could not validate $($child.url)"
              $hash.valid = $False
              $hash.status = $Null
            }

            } #if url

    } #if validate
        #write custom object
        New-Object -TypeName PSobject -Property $hash
  } #else url
 } #foreach
 } #process
} #end function

#convert Google Chrome Bookmark filefrom JSON
$data = Get-Content $file | Out-String | ConvertFrom-Json

#these should be the top level "folders"
$data.roots.bookmark_bar | Get-BookmarkFolder
$data.roots.other | Get-BookmarkFolder
$data.roots.synced | Get-BookmarkFolder

Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
