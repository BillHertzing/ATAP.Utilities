

Function Search-WindowsIndexs {
param (  
    [Parameter(ValueFromPipeline = $true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Pattern)  

    if($Path -eq ""){$Path = $PWD;} 

    $pattern = $pattern -replace "\*", "%"  
    $path = $path + "\%"

    $con = New-Object -ComObject ADODB.Connection
    $rs = New-Object -ComObject ADODB.Recordset

    $con.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")
    $rs.Open("SELECT System.ItemPathDisplay FROM SYSTEMINDEX WHERE System.FileName LIKE '" + $pattern + "' AND System.ItemPathDisplay LIKE '" + $path + "'" , $con)

    While(-Not $rs.EOF){
        $rs.Fields.Item("System.ItemPathDisplay").Value
        $rs.MoveNext()
    }
}

<#

Function SearchRating {
    param (  
        [Parameter(ValueFromPipeline = $true)][string[]]$Path,
        [Parameter(Mandatory=$true)][string[]]$Pattern,
        [Parameter(Mandatory=$true)][int32[]]$Rating
    )

    $con = New-Object -ComObject ADODB.Connection
    $con.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")
    $rs = New-Object -ComObject ADODB.Recordset

    ForEach($Dir in $Path) {
        $Pattern | ForEach-Object{
            $FilePath = $Dir + "\%"
            $FileName = $_ -replace "\*", "%"  

            $Query = "SELECT System.ItemPathDisplay,System.Rating FROM SYSTEMINDEX WHERE System.FileName LIKE '{0}' AND System.ItemPathDisplay LIKE '{1}'" -f $FileName, $FilePath
            $rs.Open($Query, $con)
    
            While(-Not $rs.EOF){
                if ($Rating -contains $rs.Fields.Item("System.Rating").Value){
                    [PSCustomObject]@{
                            Path   = $rs.Fields.Item("System.ItemPathDisplay").Value
                            Rating = $rs.Fields.Item("System.Rating").Value
                        }   
                }
                $rs.MoveNext()
            }
        }
    }
}

# Example that will search (using the Windows Index) for all the MP3 files in the directory c:\Junk and its subdirectories
# and return a PSCustomObject for any whose System.Rating value is found in the Rating parameter
SearchRating -path c:\junk -Pattern "*.mp3" -Rating 1,2,3


#>